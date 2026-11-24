// E13 · Classroom: importa título, portada y duración de un link de Vimeo o YouTube.
// GET /api/oembed?url=<link>  →  { provider, videoId, hash, title, thumbnail, duration }
// Se resuelve del lado del servidor por CORS. Solo consulta vimeo.com y youtube.com: las URLs
// que se piden se arman acá con el id del video, nunca con lo que manda el cliente tal cual.
// YouTube no da la duración por oEmbed: se intenta leerla de la página del video (lengthSeconds);
// si falla, duration = null y Sau la escribe a mano en el editor.

export function parseVideoUrl(raw) {
  let u;
  try { u = new URL(String(raw || '').trim()); } catch (e) { return null; }
  const host = u.hostname.replace(/^www\.|^m\./, '');
  if (host === 'youtu.be') {
    const id = u.pathname.split('/')[1];
    return /^[\w-]{11}$/.test(id || '') ? { provider: 'youtube', videoId: id } : null;
  }
  if (host === 'youtube.com' || host === 'youtube-nocookie.com') {
    let id = u.searchParams.get('v');
    const m = u.pathname.match(/^\/(?:shorts|embed|live)\/([\w-]{11})/);
    if (!id && m) id = m[1];
    return /^[\w-]{11}$/.test(id || '') ? { provider: 'youtube', videoId: id } : null;
  }
  if (host === 'vimeo.com' || host === 'player.vimeo.com') {
    const parts = u.pathname.split('/').filter(Boolean);
    const i = parts.findIndex(p => /^\d+$/.test(p));
    if (i < 0) return null;
    const hash = u.searchParams.get('h') || (parts[i + 1] && /^[0-9a-f]+$/i.test(parts[i + 1]) ? parts[i + 1] : null);
    return { provider: 'vimeo', videoId: parts[i], hash };
  }
  return null;
}

async function getJson(url) {
  const r = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0 (compatible; MOVE-classroom/1.0)' }, signal: AbortSignal.timeout(8000) });
  if (!r.ok) throw new Error('status ' + r.status);
  return r.json();
}

async function youtubeDuration(id) {
  try {
    const r = await fetch(`https://www.youtube.com/watch?v=${id}&hl=es`, {
      headers: { 'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36', 'Accept-Language': 'es' },
      signal: AbortSignal.timeout(8000)
    });
    if (!r.ok) return null;
    const html = await r.text();
    const m = html.match(/"lengthSeconds":"(\d+)"/) || html.match(/"approxDurationMs":"(\d+)"/);
    if (!m) return null;
    const n = Number(m[1]);
    return m[0].includes('Ms') ? Math.round(n / 1000) : n;
  } catch (e) { return null; }
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  if (req.method !== 'GET') { res.status(405).json({ error: 'method_not_allowed' }); return; }
  const v = parseVideoUrl(req.query && req.query.url);
  if (!v) { res.status(400).json({ error: 'link_no_valido' }); return; }
  try {
    if (v.provider === 'vimeo') {
      const page = `https://vimeo.com/${v.videoId}${v.hash ? '/' + v.hash : ''}`;
      const d = await getJson(`https://vimeo.com/api/oembed.json?width=1280&url=${encodeURIComponent(page)}`);
      res.status(200).json({ ...v, title: d.title || null, thumbnail: d.thumbnail_url || null, duration: Number(d.duration) || null });
      return;
    }
    const watch = `https://www.youtube.com/watch?v=${v.videoId}`;
    const [d, duration] = await Promise.all([
      getJson(`https://www.youtube.com/oembed?format=json&url=${encodeURIComponent(watch)}`),
      youtubeDuration(v.videoId)
    ]);
    res.status(200).json({ ...v, title: d.title || null, thumbnail: `https://i.ytimg.com/vi/${v.videoId}/hqdefault.jpg`, duration });
  } catch (e) {
    // El link se entiende pero no se pudo importar (privado, sin red…): el editor sigue en manual
    res.status(200).json({ ...v, title: null, thumbnail: v.provider === 'youtube' ? `https://i.ytimg.com/vi/${v.videoId}/hqdefault.jpg` : null, duration: null, error: 'no_se_pudo_importar' });
  }
}
