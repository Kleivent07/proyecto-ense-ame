import 'package:supabase_flutter/supabase_flutter.dart';
import '../custom/solicitud_data.dart';

class SolicitudModel {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> crearSolicitud(SolicitudData solicitud) async {
    try {
      await _supabase.from('solicitudes_tutorias').insert(solicitud.toMap());
    } catch (e) {
      throw Exception('Error al crear solicitud: $e');
    }
  }

  // Solicitudes de profesor
  Future<List<SolicitudData>> obtenerSolicitudesPorProfesor(String profesorId) async {
    try {
      final data = await _supabase
          .from('solicitudes_tutorias')
          .select('*, tutor:profesor_id(usuarios(*))')
          .eq('profesor_id', profesorId);

      List<SolicitudData> solicitudes = [];
      for (var s in data) {
        // Obtener nombre del estudiante separado
        final estudianteData = await _supabase
            .from('usuarios')
            .select('nombre, apellido')
            .eq('id', s['estudiante_id'])
            .single();
        s['estudiante'] = {'usuarios': estudianteData};

        solicitudes.add(SolicitudData.fromMap(s));
      }
      return solicitudes;
    } catch (e) {
      throw Exception('Error al obtener solicitudes del profesor: $e');
    }
  }

  // Solicitudes de estudiante
  Future<List<SolicitudData>> obtenerSolicitudesPorEstudiante(String estudianteId) async {
    try {
      final data = await _supabase
          .from('solicitudes_tutorias')
          .select('*, tutor:profesor_id(usuarios(*))')
          .eq('estudiante_id', estudianteId);

      List<SolicitudData> solicitudes = [];
      for (var s in data) {
        // Obtener nombre del estudiante (opcional, ya lo tenemos)
        final estudianteData = await _supabase
            .from('usuarios')
            .select('nombre, apellido')
            .eq('id', s['estudiante_id'])
            .single();
        s['estudiante'] = {'usuarios': estudianteData};

        solicitudes.add(SolicitudData.fromMap(s));
      }
      return solicitudes;
    } catch (e) {
      throw Exception('Error al obtener solicitudes del estudiante: $e');
    }
  }

  Future<void> actualizarEstado(String idSolicitud, String nuevoEstado) async {
    try {
      await _supabase
          .from('solicitudes_tutorias')
          .update({'estado': nuevoEstado})
          .eq('id', idSolicitud);
    } catch (e) {
      throw Exception('Error al actualizar estado: $e');
    }
  }

  Future<void> eliminarSolicitud(String idSolicitud) async {
    try {
      await _supabase.from('solicitudes_tutorias').delete().eq('id', idSolicitud);
    } catch (e) {
      throw Exception('Error al eliminar solicitud: $e');
    }
  }
}
