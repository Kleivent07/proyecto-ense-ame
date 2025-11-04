// Ejecuta: node send-test-webhook.js
const fetch = require('node-fetch');
const crypto = require('crypto');

const secret = process.env.ZOOM_EVENT_SECRET || '<PEGA_AQUI_ZOOM_EVENT_SECRET>'; // mejor usar .env
const url = process.env.WEBHOOK_URL || 'http://localhost:3000/zoom-webhook';

// Ejemplo de body (puedes cambiar event y payload)
const bodyObj = {
  event: 'meeting.started',
  payload: { object: { id: '12345', topic: 'Test' } }
};

const body = JSON.stringify(bodyObj);
const hmac = crypto.createHmac('sha256', secret).update(body).digest('base64');

(async () => {
  try {
    console.log('Sending webhook to', url);
    console.log('x-zm-signature:', hmac);
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-zm-signature': hmac
      },
      body
    });
    const text = await res.text();
    console.log('Status', res.status);
    console.log('Body:', text);
  } catch (err) {
    console.error(err);
  }
})();