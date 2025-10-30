// ignore_for_file: unnecessary_null_comparison, unnecessary_type_check

import 'package:supabase_flutter/supabase_flutter.dart';

class EstudianteService {
  final supabase = Supabase.instance.client;

  // Crear registro inicial
  Future<bool> crearEstudianteInicial(String userId) async {
    try {
      final insertResult = await supabase.from('estudiantes').insert({
        'id': userId,
        'carrera': 'Sin definir',
        'semestre': 1,
        'intereses': 'Sin definir',
        'disponibilidad': 'Por definir',
      }).select();

      if (insertResult == null || (insertResult is List && insertResult.isEmpty)) {
        print('No se pudo crear el registro inicial del estudiante');
        return false;
      }

      print('Registro inicial de estudiante creado correctamente');
      return true;
    } catch (e) {
      print('Error creando registro inicial de estudiante: $e');
      return false;
    }
  }

  // Leer perfil del estudiante por userId
  Future<Map<String, dynamic>?> obtenerEstudiante(String userId) async {
    try {
      final data = await supabase
          .from('estudiantes')
          .select()
          .eq('id', userId)
          .maybeSingle();

      print('Perfil del estudiante: $data');
      return data;
    } catch (e) {
      print('Error obteniendo perfil del estudiante: $e');
      return null;
    }
  }

  // Actualizar datos del estudiante
  Future<bool> actualizarEstudiante({
    required String userId,
    String? carrera,
    int? semestre,
    String? intereses,
    String? disponibilidad,
  }) async {
    try {
      final updateResult = await supabase.from('estudiantes').update({
        if (carrera != null) 'carrera': carrera,
        if (semestre != null) 'semestre': semestre,
        if (intereses != null) 'intereses': intereses,
        if (disponibilidad != null) 'disponibilidad': disponibilidad,
      }).eq('id', userId).select();

      if (updateResult == null || (updateResult is List && updateResult.isEmpty)) {
        print('No se pudieron actualizar los datos del estudiante');
        return false;
      }

      print('Datos del estudiante actualizados correctamente');
      return true;
    } catch (e) {
      print('Error actualizando datos del estudiante: $e');
      return false;
    }
  }

  // Eliminar perfil del estudiante
  Future<bool> eliminarEstudiante(String userId) async {
    try {
      final deleteResult = await supabase.from('estudiantes').delete().eq('id', userId);

      print('Perfil del estudiante eliminado: $deleteResult');
      return true;
    } catch (e) {
      print('Error eliminando perfil del estudiante: $e');
      return false;
    }
  }
}

