import 'package:supabase_flutter/supabase_flutter.dart';

class PerfilRepository {
  static Future<bool> createPerfil({
    required String email,
    required String password,
    required String nombre,
    required String clase,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // Crear usuario en Auth
      final resAuth = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      // Verificar si se creó el usuario
      if (resAuth.user == null) {
        print('Error al crear usuario: usuario no creado.');
        return false;
      }

      // Insertar perfil en la tabla "perfiles" incluyendo email
      final response = await supabase.from('perfiles').insert({
        'id': resAuth.user!.id,
        'email': email,          // <-- Nuevo
        'nombre': nombre,
        'clase': clase,
      }).select();

      if (response.isEmpty) {
        print('Error al insertar perfil en la tabla.');
        return false;
      }

      return true; // Todo correcto
    } catch (e) {
      print('Excepción al crear perfil: $e');
      return false;
    }
  }
}
