import 'package:my_app/src/BackEnd/custom/solicitud_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class SolicitudModel {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> crearSolicitud(SolicitudData solicitud) async {
    try {
      final map = solicitud.toMap();

      // Columnas reales en la tabla según lo que pegaste:
      final allowedColumns = <String>{
        'id',
        'estudiante_id',
        'profesor_id',
        'estado',
        'mensaje',
        'fecha_solicitud',
        'fecha_respuesta',
        'nombre_estudiante',
      };

      // Filtrar solo las claves que existen en la tabla
      final filtered = <String, dynamic>{};
      for (final entry in map.entries) {
        final key = entry.key;
        final value = entry.value;

        // Si la key no está permitida, saltarla
        if (!allowedColumns.contains(key)) continue;

        // Evitar insertar id vacío (Postgres falla al convertir '' a uuid)
        if (key == 'id') {
          final s = value?.toString() ?? '';
          if (s.trim().isEmpty) {
            // saltar la clave 'id' para que la BD asigne el id por defecto
            continue;
          }
        }

        // Evitar insertar estudiante_id/profesor_id vacíos (también UUID)
        if ((key == 'estudiante_id' || key == 'profesor_id')) {
          final s = value?.toString() ?? '';
          if (s.trim().isEmpty) {
            // Si faltan estos ids, mejor no insertarlos y fallar lógicamente en la app antes
            continue;
          }
        }

        filtered[key] = value;
      }

      // Asegurar fecha_solicitud si no viene
      filtered.putIfAbsent('fecha_solicitud', () => DateTime.now().toUtc().toIso8601String());

      // Debug temporal (opcional): muestra qué se intenta insertar
      // print('DEBUG crearSolicitud filtered payload: $filtered');

      await _supabase.from('solicitudes_tutorias').insert([filtered]);
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
          .eq('profesor_id', profesorId)
          .order('fecha_solicitud', ascending: false);

      List<SolicitudData> solicitudes = [];
      for (var s in data) {
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
          .eq('estudiante_id', estudianteId)
          .order('fecha_solicitud', ascending: false);

      List<SolicitudData> solicitudes = [];
      for (var s in data) {
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

