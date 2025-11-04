const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) {
  console.error('Falta SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY en env');
  process.exit(1);
}
const supabase = createClient(url, key);

(async () => {
  try {
    const row = {
      zoom_id: 'test-123',
      room_id: null,
      topic: 'test insert',
      start_time: new Date().toISOString(),
      duration: 10,
      timezone: 'UTC',
      join_url: null,
      start_url: null,
      passcode: null,
      status: 'test',
      recording_url: null,
      host_id: null,
      created_by: null,
      settings: {},
      created_at: new Date().toISOString()
    };

    const { data, error } = await supabase
      .from('zoom_meetings')
      .insert([row])
      .select()
      .limit(1);

    if (error) {
      console.error('INSERT ERROR:', error);
    } else {
      console.log('INSERT OK, returned data:', data);
    }

    // ahora leer las últimas filas para confirmar
    const { data: rows, error: selError } = await supabase
      .from('zoom_meetings')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(5);

    if (selError) {
      console.error('SELECT ERROR:', selError);
    } else {
      console.log('Últimas filas:', rows);
    }
  } catch (e) {
    console.error('Exception:', e);
  }
})();