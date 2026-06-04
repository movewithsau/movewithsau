export const config = {
  runtime: 'edge',
  maxDuration: 30
};

export default async function handler(req) {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  const body = await req.json();

  // For programa mode the frontend sends stream:true, otherwise respond normally
  const useStream = body.stream === true;
  const anthropicBody = { ...body };
  if (!useStream) delete anthropicBody.stream;

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': process.env.ANTHROPIC_KEY,
      'anthropic-version': '2023-06-01'
    },
    body: JSON.stringify(anthropicBody)
  });

  if (useStream) {
    // Pipe the SSE stream directly back — connection stays alive, no timeout
    return new Response(res.body, {
      status: res.status,
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }

  // Non-streaming fallback (bloques, workouts)
  const data = await res.json();
  return new Response(JSON.stringify(data), {
    status: res.status,
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
  });
}
