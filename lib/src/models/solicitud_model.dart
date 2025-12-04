import 'package:my_app/src/BackEnd/custom/solicitud_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_app/src/BackEnd/services/notifications_service.dart';
import 'package:flutter/foundation.dart';

class SolicitudModel {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<SolicitudData> crearSolicitud(SolicitudData solicitud) async {
    try {
      final map = solicitud.toMap();
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

      final filtered = <String, dynamic>{};
      for (final entry in map.entries) {
        final key = entry.key;
        final value = entry.value;
        if (!allowedColumns.contains(key)) continue;

        if (key == 'id') {
          final s = value?.toString() ?? '';
          if (s.trim().isEmpty) continue;
        }
        if (key == 'estudiante_id' || key == 'profesor_id') {
          final s = value?.toString() ?? '';
          if (s.trim().isEmpty) {
            throw Exception('Faltan IDs requeridos');
          }
        }
        filtered[key] = value;
      }

      filtered.putIfAbsent('estado', () => 'pendiente');
      filtered.putIfAbsent('fecha_solicitud', () => DateTime.now().toUtc().toIso8601String());

      final inserted = await _supabase
          .from('solicitudes_tutorias')
          .insert(filtered)
          .select()
          .single();

      // Enriquecer con nombre del estudiante
      final estudianteData = await _supabase
          .from('usuarios')
          .select('nombre, apellido')
          .eq('id', inserted['estudiante_id'])
          .single();
      inserted['estudiante'] = {'usuarios': estudianteData};

      // Notificar al profesor (una sola vez, dirigida)
      final estudianteNombre = inserted['nombre_estudiante'] ?? 'Estudiante';
      final profesorId = inserted['profesor_id']?.toString();
      final estudianteId = inserted['estudiante_id']?.toString();
      final solicitudIdStr = inserted['id']?.toString();

      // Identificar el usuario actual
      final currentUserId = _supabase.auth.currentUser?.id;

      // Para el tutor (solo si el usuario actual es el tutor)
      if (profesorId != null && solicitudIdStr != null && currentUserId == profesorId) {
        debugPrint('[SOLICITUD] Notificación al tutor:');
        await NotificationsService.showNotification(
          title: 'Solicitud recibida',
          body: 'Has recibido una solicitud de tutoría de $estudianteNombre',
          userId: profesorId,
          tipo: 'solicitud_recibida',
          referenciaId: solicitudIdStr,
        );
      }

      // Para el estudiante (solo si el usuario actual es el estudiante)
      if (estudianteId != null && solicitudIdStr != null && currentUserId == estudianteId) {
        debugPrint('[SOLICITUD] Notificación al estudiante:');
        await NotificationsService.showNotification(
          title: 'Solicitud enviada',
          body: 'Tu solicitud fue enviada al tutor',
          userId: estudianteId,
          tipo: 'solicitud_enviada',
          referenciaId: solicitudIdStr,
        );
      }

      return SolicitudData.fromMap(inserted);
    } on PostgrestException catch (e) {
      // Traduce duplicados con nombre de constraint
      if (e.code == '23505') {
        final detalle = e.details ?? 'Registro duplicado';
        throw Exception('Conflicto (duplicado): $detalle');
      }
      throw Exception('Error Postgrest: ${e.message}');
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

  Future<SolicitudData> actualizarEstado(String idSolicitud, String nuevoEstado) async {
    try {
      // Actualizar estado + fecha_respuesta
      await _supabase
          .from('solicitudes_tutorias')
          .update({
            'estado': nuevoEstado,
            'fecha_respuesta': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', idSolicitud);

      // Leer fila actualizada (incluir joins si los necesitas)
      final s = await _supabase
          .from('solicitudes_tutorias')
          .select('*, tutor:profesor_id(usuarios(*))')
          .eq('id', idSolicitud)
          .maybeSingle();

      if (s == null) {
        throw Exception('No se encontró la solicitud actualizada');
      }

      // Adjuntar nombre de estudiante como hace el resto del modelo
      final estudianteData = await _supabase
          .from('usuarios')
          .select('nombre, apellido')
          .eq('id', s['estudiante_id'])
          .single();
      s['estudiante'] = {'usuarios': estudianteData};

      final estudianteNombre = s['nombre_estudiante'] ?? 'Estudiante';
      String mensaje = '';
      String tipo = 'solicitud';
      if (nuevoEstado == 'aceptada') {
        mensaje = '¡Tu solicitud fue aceptada! Puedes iniciar el chat con el profesor.';
        tipo = 'chat';
      } else if (nuevoEstado == 'rechazada') {
        mensaje = 'Tu solicitud fue rechazada.';
      }

      // Notificación al estudiante (solo si el usuario actual es el estudiante)
      final currentUserId = _supabase.auth.currentUser?.id;
      final estudianteId = s['estudiante_id']?.toString();

      // Notificación al estudiante (solo si el usuario actual es el estudiante)
      if (mensaje.isNotEmpty && estudianteId != null && currentUserId == estudianteId) {
        await NotificationsService.showNotification(
          title: 'Estado de solicitud',
          body: '$mensaje ($estudianteNombre)',
          userId: estudianteId,
          tipo: tipo,
          referenciaId: idSolicitud,
        );
      }

      return SolicitudData.fromMap(s);
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

