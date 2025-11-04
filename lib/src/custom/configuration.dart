class Configuration {
  static String mVersion = "1.0.0";
  // URL pública de Supabase (puedes conservarla)
  static String mSupabaseUrl = "https://dzqgzcmbbqllljkjqnfb.supabase.co";
  // NO guardar keys sensibles en el cliente. Usa la anon key si necesitas acceso directo desde Flutter.
  static String mSupabaseAnonKey = "YOUR_SUPABASE_ANON_KEY_HERE";

  // Zoom: dejar vacío en el cliente. El servidor maneja client_secret y token.
  static String mZoomAppID = "";
  static String mZoomAppClient = "";
  static String mZoomAppSecret = "";
}
