const fetch = require('node-fetch');

const clientId = process.env.ZOOM_CLIENT_ID;
const clientSecret = process.env.ZOOM_CLIENT_SECRET;
const accountId = process.env.ZOOM_ACCOUNT_ID; // opcional

if (!clientId || !clientSecret) {
  console.error('Falta ZOOM_CLIENT_ID o ZOOM_CLIENT_SECRET en las variables de entorno.');
  process.exit(1);
}

(async () => {
  try {
    // Obtener token (account_credentials)
    const basic = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
    const tokenBody = accountId ? `grant_type=account_credentials&account_id=${encodeURIComponent(accountId)}` : 'grant_type=account_credentials';
    const tokenRes = await fetch('https://zoom.us/oauth/token', {
      method: 'POST',
      headers: { Authorization: `Basic ${basic}`, 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
      body: tokenBody
    });
    const tokenText = await tokenRes.text();
    const tokenJson = JSON.parse(tokenText);
    if (!tokenRes.ok) {
      console.error('Error obteniendo token:', tokenRes.status, tokenJson);
      process.exit(1);
    }
    const accessToken = tokenJson.access_token;
    console.log('Token OK, obteniendo usuarios...');

    // Llamar a GET /users para listar usuarios de la cuenta
    const usersRes = await fetch('https://api.zoom.us/v2/users', {
      method: 'GET',
      headers: { Authorization: `Bearer ${accessToken}`, Accept: 'application/json' }
    });
    const usersText = await usersRes.text();
    const usersJson = JSON.parse(usersText);
    if (!usersRes.ok) {
      console.error('Error al listar usuarios:', usersRes.status, usersJson);
      process.exit(1);
    }

    if (Array.isArray(usersJson.users) && usersJson.users.length) {
      console.log('Usuarios encontrados (email, first_name, last_name, type):');
      usersJson.users.forEach(u => {
        console.log(`- ${u.email}  |  ${u.first_name || ''} ${u.last_name || ''}  |  type:${u.type}  |  id:${u.id}`);
      });
    } else {
      console.log('No se encontraron usuarios en la cuenta o la respuesta no contiene users:', usersJson);
    }
  } catch (e) {
    console.error('Error:', e);
  }
})();
