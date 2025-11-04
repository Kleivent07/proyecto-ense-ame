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
  const { data, error } = await supabase
    .from('zoom_meetings')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(10);

  if (error) {
    console.error('Supabase error:', error);
  } else {
    console.log('Últimas filas en zoom_meetings:');
    console.log(data);
  }
})();