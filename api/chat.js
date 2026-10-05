// El modelo lo decide el servidor: si Groq depreca otro, se arregla con la env var GROQ_MODEL.
const MODEL = process.env.GROQ_MODEL || 'openai/gpt-oss-120b';
// gpt-oss es un modelo de razonamiento: los tokens de razonamiento cuentan contra el tope de salida.
// Con reasoning_effort:'low' se midieron ~15-50 tokens de razonamiento; el margen deja holgura (varias veces
// ese máximo) para que el content no quede vacío, sin inflar el tope de salida original.
const REASONING_MARGIN = 400;

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: { message: 'method_not_allowed' } }); return; }

  const incoming = (req.body && typeof req.body === 'object') ? req.body : {};
  if (!Array.isArray(incoming.messages) || incoming.messages.length === 0) {
    res.status(400).json({ error: { message: 'messages requerido' } });
    return;
  }

  // Ignorar el model del body: se usa siempre el del servidor.
  const { model: _ignored, ...rest } = incoming;
  const body = { ...rest, model: MODEL };

  if (MODEL.startsWith('openai/gpt-oss')) {
    if (body.reasoning_effort === undefined) body.reasoning_effort = 'low';
    if (body.include_reasoning === undefined) body.include_reasoning = false;
    // Groq documenta max_completion_tokens para gpt-oss; se suma el margen de razonamiento.
    const wanted = body.max_completion_tokens ?? body.max_tokens ?? 1000;
    delete body.max_tokens;
    body.max_completion_tokens = wanted + REASONING_MARGIN;
  }

  let response;
  try {
    response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${process.env.GROQ_API_KEY}` },
      body: JSON.stringify(body)
    });
  } catch (e) {
    console.error('[chat] groq unreachable', e && e.name);
    res.status(502).json({ error: { message: 'upstream_unreachable' } });
    return;
  }

  let data = null;
  try { data = await response.json(); } catch (e) { /* respuesta no-JSON */ }

  if (!response.ok) {
    const err = (data && data.error) || {};
    const message = err.message || 'upstream_error';
    console.error('[chat] groq', response.status, err.code, message);
    res.status(response.status).json({ error: { message, type: err.type, code: err.code } });
    return;
  }
  if (!data) {
    console.error('[chat] groq', response.status, undefined, 'invalid_json');
    res.status(502).json({ error: { message: 'upstream_invalid_response' } });
    return;
  }
  res.status(200).json(data);
}
