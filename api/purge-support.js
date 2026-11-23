// Borrado de 7 días del chat con Sau (bloque E4). SIN ACTIVAR: no está en vercel.json.
// Para activarlo, Sau agrega en vercel.json:  { "path": "/api/purge-support?run=1", "schedule": "0 9 * * *" }
//
// Qué borra (y nada más):
//   - filas de public.support_messages que devuelve la vista support_messages_purgeable:
//     no destacadas (starred = false), de hace más de 7 días, y nunca un mensaje del cliente
//     que Sau todavía no respondió (la vista lo excluye);
//   - los archivos de esas filas (media_path) en el bucket support-chat.
// No toca ninguna otra tabla ni otro bucket. El DELETE repite los filtros (starred=false y fecha)
// como segunda barrera.
//
// Por defecto corre "en seco": devuelve lo que borraría sin borrar. Solo borra con ?run=1.
// Exige Authorization: Bearer CRON_SECRET (Vercel Cron lo manda solo si la variable existe).
const SUPABASE_URL = 'https://qsvhlsfutymvpwrmbtsb.supabase.co';
const SUPABASE_KEY = 'sb_publishable_J7aLsH4Y-D4JR0LVN-IFeg_l_aXjAiO';
const BUCKET = 'support-chat';
const BATCH = 100;

function headers(extra) {
  return { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}`, ...extra };
}

export default async function handler(req, res) {
  const auth = req.headers['authorization'] || '';
  if (!process.env.CRON_SECRET || auth !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  const run = String((req.query && req.query.run) || '') === '1';
  const cutoff = new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString();

  let rows;
  try {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/support_messages_purgeable?select=id,media_path,created_at&order=id.asc&limit=5000`, { headers: headers() });
    if (!r.ok) throw new Error(`vista ${r.status}`);
    rows = await r.json();
  } catch (e) {
    console.error('[purge-support] no se pudo leer la vista', e && e.message);
    return res.status(500).json({ error: 'read_failed' });
  }
  // Segunda barrera en el código: nada más nuevo que el corte
  rows = (rows || []).filter(m => m && m.id != null && m.created_at < cutoff);
  const files = rows.map(m => m.media_path).filter(Boolean);
  if (!run) {
    return res.status(200).json({ dry: true, cutoff, messages: rows.length, files: files.length, ids: rows.map(m => m.id) });
  }

  let deletedFiles = 0, deletedRows = 0;
  for (let i = 0; i < rows.length; i += BATCH) {
    const chunk = rows.slice(i, i + BATCH);
    const paths = chunk.map(m => m.media_path).filter(Boolean);
    if (paths.length) {
      const r = await fetch(`${SUPABASE_URL}/storage/v1/object/${BUCKET}`, {
        method: 'DELETE', headers: headers({ 'Content-Type': 'application/json' }), body: JSON.stringify({ prefixes: paths })
      });
      if (!r.ok) { console.error('[purge-support] storage', r.status); return res.status(500).json({ error: 'storage_failed', deletedRows, deletedFiles }); }
      deletedFiles += paths.length;
    }
    const ids = chunk.map(m => Number(m.id)).filter(Number.isFinite).join(',');
    const r = await fetch(`${SUPABASE_URL}/rest/v1/support_messages?id=in.(${ids})&starred=eq.false&created_at=lt.${encodeURIComponent(cutoff)}`, {
      method: 'DELETE', headers: headers({ Prefer: 'return=representation' })
    });
    if (!r.ok) { console.error('[purge-support] delete', r.status); return res.status(500).json({ error: 'delete_failed', deletedRows, deletedFiles }); }
    const gone = await r.json().catch(() => []);
    deletedRows += Array.isArray(gone) ? gone.length : 0;
  }
  return res.status(200).json({ dry: false, cutoff, deletedRows, deletedFiles });
}
