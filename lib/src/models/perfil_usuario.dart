import 'package:supabase_flutter/supabase_flutter.dart';

/// Detecta el usuario conectado
User? getUsuarioActual() {
  return Supabase.instance.client.auth.currentUser;
}

/// Carga el perfil del usuario conectado
Future<Map<String, dynamic>?> cargarPerfil() async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? '';
    if (user == null || userId.isEmpty) {
      print('Usuario no autenticado');
      return null;
    }

    // directamente obtenemos el Map sin .execute() ni .data
    final perfil = await Supabase.instance.client
        .from('perfiles')
        .select('email, nombre, clase, imagen_url')
        .eq('id', userId)
        .maybeSingle(); // devuelve Map<String,dynamic>? o null

    if (perfil == null) {
      print('Perfil no encontrado');
      return null;
    }
    // Verificamos si tiene imagen
    if (perfil['imagen_url'] != null && perfil['imagen_url'].isNotEmpty) {
      print('Usuario tiene imagen de perfil: ${perfil['imagen_url']}');
    } else {
      print('Usuario NO tiene imagen de perfil');
    }

    return perfil;
  } catch (e) {
    print('Error al cargar perfil: $e');
    return null;
  }
}

/// Guarda los cambios en el perfil
Future<bool> guardarPerfil(Map<String, dynamic> perfil) async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? '';
    if (user == null || userId.isEmpty) return false;

    await Supabase.instance.client
        .from('perfiles')
        .update({
          'nombre': perfil['nombre'],
          'email': perfil['email'],
          'clase': perfil['clase'],
          'imagen_url': perfil['imagen_url'],
        })
        .eq('id', userId);

    return true;
  } catch (e) {
    print('Error al guardar perfil: $e');
    return false;
  }
}
