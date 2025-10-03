import 'package:supabase_flutter/supabase_flutter.dart';

class LoginModel {
  /// Obtiene el perfil del usuario por email
  static Future<Map<String, dynamic>?> getPerfil(String email) async {
    try {
      final supabase = Supabase.instance.client;

      // maybeSingle() devuelve null si no encuentra nada
      final response = await supabase
          .from('perfiles') // Tu tabla de perfiles
          .select()
          .eq('email', email)
          .maybeSingle();

      if (response == null) return null;

      // Cast seguro a Map<String, dynamic>
      return Map<String, dynamic>.from(response);
    } catch (e) {
      print("Error en getPerfil: $e");
      return null;
    }
  }

  /// Valida el login usando Supabase Auth v2
  static Future<bool> login(String email, String password) async {
    try {
      final supabase = Supabase.instance.client;

      final resAuth = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (resAuth.session != null && resAuth.user != null) {
        print('Login exitoso: ${resAuth.user!.email}');
        return true;
      } else {
        // Login fallido
        print('Login fallido: usuario o contraseña incorrectos.');
        return false;
      }
    } catch (e) {
      print('Excepción al intentar login: $e');
      return false;
    }
  }

  /// Opcional: obtener usuario logueado actual
  static Map<String, dynamic>? getUsuarioActual() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    return {
      'id': user.id,
      'email': user.email,
    };
  }
}
