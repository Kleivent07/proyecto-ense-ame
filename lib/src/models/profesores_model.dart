import 'package:supabase_flutter/supabase_flutter.dart';

class ProfesorService {
  final supabase = Supabase.instance.client;

  Future<bool> crearProfesorInicial(String userId) async {
    try {
      final insertResult = await supabase.from('profesores').insert({
        'id': userId,
        'especialidad': 'Sin definir',
        'carrera_profesion': 'Ninguna',
        'disponibilidad': 'Por definir',
      }).select();

      if (insertResult == null || (insertResult is List && insertResult.isEmpty)) {
        print('No se pudo crear el registro inicial del profesor');
        return false;
      }

      print('Registro inicial de profesor creado correctamente');
      return true;
    } catch (e) {
      print('Error creando registro inicial de profesor: $e');
      return false;
    }
  }
  Future<Map<String, dynamic>?> obtenerProfesor(String userId) async {
    try {
      final data = await supabase
          .from('profesores')
          .select()
          .eq('id', userId)
          .maybeSingle();

      print('Perfil del profesor: $data');
      return data;
    } catch (e) {
      print('Error obteniendo perfil del profesor: $e');
      return null;
    }
  }
  Future<bool> actualizarProfesor({
    required String userId,
    String? especialidad,
    String? carreraProfesion,
    String? experiencia,
    String? disponibilidad,
  }) async {
    try {
      final updateResult = await supabase.from('profesores').update({
        if (especialidad != null) 'especialidad': especialidad,
        if (carreraProfesion != null) 'carrera_profesion': carreraProfesion,
        if (experiencia != null) 'experiencia': experiencia,
        if (disponibilidad != null) 'disponibilidad': disponibilidad,
      }).eq('id', userId).select();

      if (updateResult == null || (updateResult is List && updateResult.isEmpty)) {
        print('No se pudieron actualizar los datos del profesor');
        return false;
      }

      print('Datos del profesor actualizados correctamente');
      return true;
    } catch (e) {
      print('Error actualizando datos del profesor: $e');
      return false;
    }
  }
  Future<bool> eliminarProfesor(String userId) async {
    try {
      final deleteResult = await supabase.from('profesores').delete().eq('id', userId);

      print('Perfil del profesor eliminado: $deleteResult');
      return true;
    } catch (e) {
      print('Error eliminando perfil del profesor: $e');
      return false;
    }
  }
  
}