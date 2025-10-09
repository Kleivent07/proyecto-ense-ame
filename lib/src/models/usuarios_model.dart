// ignore_for_file: unnecessary_null_comparison, unnecessary_type_check
import 'package:my_app/src/models/estudiantes_model.dart';
import 'package:my_app/src/models/profesores_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Usuario {
  final supabase = Supabase.instance.client;

  /// Devuelve {'ok': bool, 'message': String}
  Future<Map<String, dynamic>> registrarUsuario({
    required String email,
    required String password,
    required String nombre,
    String? apellido,
    required DateTime fechaNacimiento,
    required String clase,
    String? biografia,
  }) async {
    try {
      final res = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      // Si res.user es null puede significar que se requiere confirmación de e-mail (dependiendo de la configuración de Supabase)
      final user = res.user;
      if (user == null) {
        // No hay user en la respuesta: el signup pudo haberse realizado pero está pendiente de confirmación
        print('registrarUsuario: signUp OK pero user == null -> confirmar email necesario');
        return {
          'ok': true,
          'message':
              'Cuenta creada. Revisa tu correo y confirma tu cuenta para iniciar sesión.'
        };
      }

      final userId = user.id;
      final fechaStr = fechaNacimiento.toIso8601String().split('T').first;

      final insertResult = await supabase.from('usuarios').insert({
        'id': user.id,
        'nombre': nombre,
        'apellido': apellido ?? '',
        'email': email, 
        'fecha_nacimiento': fechaStr,
        'clase': clase[0].toUpperCase() + clase.substring(1).toLowerCase(),
        'biografia': biografia ?? '',
      }).select();

      // Postgrest devuelve normalmente una lista con la fila insertada
      if (insertResult == null ||
          (insertResult is List && (insertResult as List).isEmpty)) {
        print('registrarUsuario: insert no devolvió resultados: $insertResult');
        // Nota: no intentamos borrar el auth user aquí (no es recomendable desde el cliente)
        return {'ok': false, 'message': 'No se pudo crear el perfil en la base de datos.'};
      }
      if (clase.toLowerCase() == 'estudiante') {
        await EstudianteService().crearEstudianteInicial(userId);
      } else if (clase.toLowerCase() == 'tutor') {
        await ProfesorService().crearProfesorInicial(userId);
      }

      print('Usuario registrado con éxito (auth + perfil)');
      return {'ok': true, 'message': 'Usuario registrado con éxito'};
    } on AuthException catch (authErr) {
      // AuthException puede o no venir; se captura y se devuelve mensaje
      print('AuthException en registrarUsuario: $authErr');
      return {'ok': false, 'message': authErr.message ?? authErr.toString()};
    } catch (e) {
      print('Error inesperado en registrarUsuario: $e');
      return {'ok': false, 'message': e.toString()};
    }
  }

  // login usuario
  Future<void> login(String email, String password) async {
    try {
      final res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.session == null || res.user == null) {
        throw 'Email o contraseña incorrectos';
      }

      print('Sesión iniciada con éxito');
    } catch (e) {
      print('Error al iniciar sesión: $e');
      rethrow;
    }
  }

  // Leer perfil del usuario actual
  Future<Map<String, dynamic>?> obtenerPerfil() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      print('No hay usuario autenticado');
      return null;
    }

    final data = await supabase
        .from('usuarios')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    print('Perfil obtenido: $data');
    return data;
  }

  // Actualizar perfil del usuario actual
  Future<void> actualizarPerfil({
    required String nuevoNombre,
    required String nuevaBiografia,
  }) async {
    final userId = supabase.auth.currentUser!.id;

    await supabase.from('usuarios').update({
      'nombre': nuevoNombre,
      'biografia': nuevaBiografia,
    }).eq('id', userId);

    print('Perfil actualizado');
  }

  Future<void> eliminarPerfil() async {
    final userId = supabase.auth.currentUser!.id;

    await supabase.from('usuarios').delete().eq('id', userId);
    print('Perfil eliminado');
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    print('Sesión cerrada');
  }
}
