export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const { title, message, target } = req.body;

  if (!title || !message) return res.status(400).json({ error: 'title y message requeridos' });

  const appId = 'ea0326eb-977e-4b7f-aaa1-ecf0f4cb355c';
  const apiKey = process.env.ONESIGNAL_REST_API_KEY;

  const body = {
    app_id: appId,
    headings: { en: title, es: title },
    contents: { en: message, es: message },
  };

  if (!target || target === 'all') {
    body.filters = [
      { field: 'tag', key: 'role', relation: '=', value: 'client' }
    ];
  } else if (target.username) {
    body.filters = [
      { field: 'tag', key: 'username', relation: '=', value: target.username }
    ];
  }

  const response = await fetch('https://onesignal.com/api/v1/notifications', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Basic ${apiKey}`
    },
    body: JSON.stringify(body)
  });

  const data = await response.json();
  if (!response.ok) return res.status(500).json({ error: data.errors?.[0] || 'Error OneSignal' });
  return res.status(200).json({ ok: true, recipients: data.recipients });
}
