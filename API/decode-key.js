const fs = require('fs');

const env = fs.readFileSync('./.env', 'utf8').split(/\r?\n/).reduce((acc, line) => {
  const m = line.match(/^\s*([^=]+)=(.*)$/);
  if (m) acc[m[1]] = m[2].trim();
  return acc;
}, {});

const key = env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!key) {
  console.error('No se encontró SUPABASE_SERVICE_ROLE_KEY en .env o variables de entorno.');
  process.exit(2);
}

console.log('Key length:', key.length);

function decodeJwtNoVerify(jwt) {
  const parts = jwt.split('.');
  if (parts.length < 2) return null;
  try {
    return JSON.parse(Buffer.from(parts[1].replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8'));
  } catch (e) {
    return null;
  }
}

const payload = decodeJwtNoVerify(key);
console.log('Decoded payload:', payload);
