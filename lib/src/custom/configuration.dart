class Configuration {
static String mVersion = "1.0.0"; //version de la app
//variables server desarrollo
static String mSupabaseUrl = "https://dzqgzcmbbqllljkjqnfb.supabase.co";
static String mSupabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6cWd6Y21iYnFsbGxqa2pxbmZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkxNzI1ODIsImV4cCI6MjA3NDc0ODU4Mn0.jMCG6qhTYEmIn3up83opYi9lmDDGbCi4i-1ppfP5Wto";




  // LOCAL (Android emulator)
  // static const apiBase = 'http://10.0.2.2:3000';

  // LOCAL (iOS simulator or web)
  // static const apiBase = 'http://localhost:3000';

  // NETWORK (device real)
  // static const apiBase = 'http://192.168.100.12:3000';

  // NGROK (public HTTPS)
  // static const apiBase = 'https://abc123.ngrok.io';

  // Elige la que corresponda y descomenta
  static const apiBase = 'http://10.0.2.2:3000';

}

// No guardar secretos en el cliente
//password: mQhiWQN8Oyz93qLQ
