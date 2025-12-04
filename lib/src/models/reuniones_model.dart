import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:my_app/src/BackEnd/services/notifications_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Modelo para manejar las reuniones en Supabase (tabla `meetings`).
class MeetingModel {
  final _client = Supabase.instance.client;

  /// Método helper para manejar errores de JWT expirado (nullable)
  Future<T?> _executeWithRetry<T>(Future<T?> Function() operation) async {
    try {
      return await operation();
    } catch (e) {
      if (e.toString().contains('JWT expired') || e.toString().contains('PGRST303')) {
        debugPrint('[MEETINGS] JWT expirado, renovando token...');
        try {
          await _client.auth.refreshSession();
          debugPrint('[MEETINGS] Token renovado, reintentando operación...');
          return await operation();
        } catch (refreshError) {
          debugPrint('[MEETINGS] Error renovando token: $refreshError');
          return null;
        }
      }
      rethrow;
    }
  }

  /// Método helper para operaciones que devuelven bool
  Future<bool> _executeBoolWithRetry(Future<bool> Function() operation) async {
    try {
      return await operation();
    } catch (e) {
      if (e.toString().contains('JWT expired') || e.toString().contains('PGRST303')) {
        debugPrint('[MEETINGS] JWT expirado, renovando token...');
        try {
          await _client.auth.refreshSession();
          debugPrint('[MEETINGS] Token renovado, reintentando operación...');
          return await operation();
        } catch (refreshError) {
          debugPrint('[MEETINGS] Error renovando token: $refreshError');
          return false;
        }
      }
      debugPrint('[MEETINGS] Error en operación bool: $e');
      return false;
    }
  }

  /// Método helper específico para listas
  Future<List<Map<String, dynamic>>> _executeListWithRetry(
    Future<List<Map<String, dynamic>>> Function() operation
  ) async {
    try {
      return await operation();
    } catch (e) {
      if (e.toString().contains('JWT expired') || e.toString().contains('PGRST303')) {
        debugPrint('[MEETINGS] JWT expirado, renovando token...');
        try {
          await _client.auth.refreshSession();
          debugPrint('[MEETINGS] Token renovado, reintentando operación...');
          return await operation();
        } catch (refreshError) {
          debugPrint('[MEETINGS] Error renovando token: $refreshError');
          return [];
        }
      }
      debugPrint('[MEETINGS] Error en operación de lista: $e');
      return [];
    }
  }


  Future<Map<String, dynamic>?> createMeeting({
    required String tutorName,
    required String studentName,
    required String studentId, // <-- AGREGA ESTE PARÁMETRO
    required String roomId,
    String? subject,
    required DateTime scheduledAt,
    String? tutorId,
    String? token,
    required BuildContext context,
  }) async {
    return await _executeWithRetry(() async {
      try {
        debugPrint('DEBUG createMeeting currentUser id = ${_client.auth.currentUser?.id}');
        final currentUserId = tutorId ?? _client.auth.currentUser?.id;

        final payload = <String, dynamic>{
          'tutor_name': tutorName,
          'tutor_id': currentUserId,
          'student_name': studentName,
          'room_id': roomId,
          'subject': subject,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          if (token != null) 'token': token,
        };

        final res = await _client.from('meetings').insert(payload).select().maybeSingle();
        if (res is Map<String, dynamic>) {
          // 👇 INSERTA EN student_meetings
          if (studentId.isNotEmpty && res['id'] != null) {
            await _client.from('student_meetings').insert({
              'student_id': studentId,
              'meeting_id': res['id'],
            });

            // Notificación para el estudiante
            await NotificationsService.showNotification(
              title: 'Reunión agendada',
              body: 'Tu reunión ha sido agendada exitosamente.',
              userId: studentId,
              tipo: 'reunion',
              referenciaId: res['id'],
            );
            await programarNotificacionReunion(
              titulo: 'Reunión próxima',
              mensaje: 'Tu reunión comienza ahora.',
              fechaReunion: scheduledAt.toLocal(),
              context: context,
              userId: studentId,
              tipo: 'reunion',
              referenciaId: res['id'],
            );
          }

          // Notificar al profesor y guardar en la base de datos
          await NotificationsService.showNotification(
            title: 'Reunión creada',
            body: '¡Tu reunión ha sido creada exitosamente!',
            userId: currentUserId,
            tipo: 'reunion',
            referenciaId: res['id'],
          );
          await programarNotificacionReunion(
            titulo: 'Reunión próxima',
            mensaje: 'Tu reunión comienza ahora.',
            fechaReunion: scheduledAt.toLocal(),
            context: context,
            userId: currentUserId,
            tipo: 'reunion',
            referenciaId: res['id'],
          );
          return res;
        }
        return null;
      } catch (e, st) {
        debugPrint('Error creating meeting: $e\n$st');
        return null;
      }
    });
  }

  Future<List<Map<String, dynamic>>> listMeetings() async {
    final inicio = DateTime.now();
    final resultado = await _executeListWithRetry(() async {
      try {
        final resp = await _client.from('meetings').select().order('scheduled_at', ascending: false);
        if (resp is List) {
          return resp.map((e) => Map<String, dynamic>.from(e)).toList();
        }
        return [];
      } catch (e, st) {
        debugPrint('Error listing meetings: $e\n$st');
        return [];
      }
    });
    final fin = DateTime.now();
    final duracion = fin.difference(inicio).inMilliseconds;
    print('⏱️ Tiempo de respuesta listMeetings: ${duracion} ms');
    return resultado;
  }

  Future<List<Map<String, dynamic>>> listMeetingsByTutor([String? tutorId]) async {
    return await _executeListWithRetry(() async {
      try {
        final id = tutorId ?? _client.auth.currentUser?.id;
        if (id == null) return [];
        final resp = await _client.from('meetings').select().eq('tutor_id', id).order('scheduled_at', ascending: false);
        if (resp is List) {
          return resp.map((e) => Map<String, dynamic>.from(e)).toList();
        }
        return [];
      } catch (e, st) {
        debugPrint('Error listing meetings by tutor: $e\n$st');
        return [];
      }
    });
  }

  Future<Map<String, dynamic>?> findByRoom(String roomId) async {
    return await _executeWithRetry(() async {
      try {
        final resp = await _client.from('meetings').select().eq('room_id', roomId).maybeSingle();
        if (resp is Map<String, dynamic>) return resp;
        return null;
      } catch (e, st) {
        debugPrint('Error finding meeting by room ($roomId): $e\n$st');
        return null;
      }
    });
  }

  Future<Map<String, dynamic>?> updateMeetingByRoom(String roomId, {
    String? tutorName,
    String? studentName,
    String? subject,
    DateTime? scheduledAt,
    String? token,
    String? tutorId,
  }) async {
    return await _executeWithRetry(() async {
      try {
        final updates = <String, dynamic>{
          if (tutorName != null) 'tutor_name': tutorName,
          if (studentName != null) 'student_name': studentName,
          if (subject != null) 'subject': subject,
          if (scheduledAt != null) 'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          // ✅ Solo agregar token si existe en el esquema y no es null
          if (token != null) 'token': token,
          if (tutorId != null) 'tutor_id': tutorId,
        };

        if (updates.isEmpty) return null;
        final res = await _client.from('meetings').update(updates).eq('room_id', roomId).select().maybeSingle();
        if (res is Map<String, dynamic>) return res;
        return null;
      } catch (e, st) {
        debugPrint('Error updating meeting ($roomId): $e\n$st');
        return null;
      }
    });
  }

  Future<Map<String, dynamic>?> claimTutorForRoom(String roomId, String tutorId, {String? tutorName}) async {
    return await _executeWithRetry(() async {
      try {
        final res = await _client.from('meetings').update({
          'tutor_id': tutorId,
          if (tutorName != null) 'tutor_name': tutorName,
        }).eq('room_id', roomId).select().maybeSingle();
        return (res is Map<String, dynamic>) ? res : null;
      } catch (e, st) {
        debugPrint('Error claiming tutor for room ($roomId): $e\n$st');
        return null;
      }
    });
  }

  Future<bool> deleteMeetingByRoom(String roomId) async {
    return await _executeBoolWithRetry(() async {
      try {
        await _client.from('meetings').delete().eq('room_id', roomId);
        return true;
      } catch (e, st) {
        debugPrint('Error deleting meeting ($roomId): $e\n$st');
        return false;
      }
    });
  }

  // ✅ Métodos que funcionan sin columna 'token'
  
  /// ✅ Obtener reuniones completadas que necesitan calificación (usando solo campos básicos)
  Future<List<Map<String, dynamic>>> getMeetingsNeedingRating(String studentId) async {
    return await _executeListWithRetry(() async {
      try {
        // ✅ Buscar reuniones pasadas (que ya terminaron hace al menos 5 minutos)
        final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5)).toUtc().toIso8601String();
        final resp = await _client
            .from('meetings')
            .select('*')
            .lt('scheduled_at', fiveMinutesAgo) // Solo reuniones que terminaron hace al menos 5 min
            .order('scheduled_at', ascending: false);

        // Convertir a List<Map<String, dynamic>>
        final meetings = (resp as List).map((e) => Map<String, dynamic>.from(e)).toList();

        // Filtrar las que no han sido calificadas por este estudiante
        final List<Map<String, dynamic>> needingRating = [];
        
        for (final meeting in meetings) {
          final meetingId = meeting['id'];
          if (meetingId == null) continue;

          // Verificar si ya fue calificada
          final existingRating = await _client
              .from('tutor_ratings')
              .select('id')
              .eq('meeting_id', meetingId)
              .eq('student_id', studentId)
              .maybeSingle();
          
          if (existingRating == null) {
            // No ha sido calificada, agregarla con valores por defecto
            final meetingData = Map<String, dynamic>.from(meeting);
            meetingData['subject'] = meetingData['subject'] ?? 'Tutoría General';
            meetingData['tutor_name'] = meetingData['tutor_name'] ?? 'Tutor';
            meetingData['student_name'] = meetingData['student_name'] ?? 'Estudiante';
            needingRating.add(meetingData);
          }
        }

        debugPrint('[MEETINGS] Reuniones que necesitan calificación: ${needingRating.length}');
        return needingRating;
      } catch (e) {
        debugPrint('[MEETINGS] Error obteniendo reuniones para calificar: $e');
        return [];
      }
    });
  }

  /// ✅ Marcar reunión como completada (SIN usar columnas que no existen)
  Future<Map<String, dynamic>?> completeMeeting(String roomId) async {
    return await _executeWithRetry(() async {
      try {
        debugPrint('[MEETINGS] 🔍 Buscando reunión con roomId: $roomId');
        final meeting = await findByRoom(roomId);
        if (meeting == null) {
          debugPrint('[MEETINGS] ❌ No se encontró reunión con roomId: $roomId');
          return null;
        }

        debugPrint('[MEETINGS] 📋 Reunión encontrada: ${meeting['subject']} - ${meeting['tutor_name']}');

        // Marcar como completada modificando status y student_name
        final completionMarker = 'COMPLETED_${DateTime.now().millisecondsSinceEpoch}';

        final updatedMeeting = await _client.from('meetings').update({
          'student_name': completionMarker,
          'status': 'completada', // <-- ESTA LÍNEA ES CLAVE
        }).eq('room_id', roomId).select().maybeSingle();

        if (updatedMeeting is Map<String, dynamic>) {
          debugPrint('[MEETINGS] ✅ Reunión $roomId marcada como completada');
          return Map<String, dynamic>.from(updatedMeeting);
        }

        debugPrint('[MEETINGS] ❌ No se pudo actualizar la reunión $roomId');
        return null;
      } catch (e) {
        debugPrint('[MEETINGS] ❌ Error completando reunión: $e');
        return null;
      }
    });
  }

  /// ✅ Marcar que se mostró la calificación (MEJORADO - no ocultar completamente)
  Future<bool> markRatingShown(String roomId) async {
    return await _executeBoolWithRetry(() async {
      try {
        // ✅ Solo marcar que se mostró, pero mantener elegible para calificación manual
        final meeting = await findByRoom(roomId);
        if (meeting == null) return false;

        final originalSubject = meeting['subject']?.toString() ?? 'Tutoría General';
        
        // ✅ Solo agregar [SHOWN] en lugar de [RATED] para permitir calificación manual posterior
        if (!originalSubject.contains('[SHOWN]')) {
          await _client.from('meetings').update({
            'subject': '$originalSubject [SHOWN]', // Marcar que se mostró el diálogo
          }).eq('room_id', roomId);

          debugPrint('[MEETINGS] Diálogo de calificación marcado como mostrado para $roomId');
        }
        
        return true;
      } catch (e) {
        debugPrint('[MEETINGS] Error marcando diálogo mostrado: $e');
        return false;
      }
    });
  }

  /// ✅ Marcar que un participante se unió (versión simplificada sin updated_at)
  Future<bool> markParticipantJoined(String roomId, String userId, {bool isStudent = true}) async {
    return await _executeBoolWithRetry(() async {
      try {
        debugPrint('[MEETINGS] Participante $userId marcado como unido a $roomId (sin actualizar DB)');
        // ✅ Por ahora solo loggeamos, no actualizamos nada para evitar errores
        return true;
      } catch (e) {
        debugPrint('[MEETINGS] Error marcando participante: $e');
        return false;
      }
    });
  }

  /// ✅ Verificar si una reunión necesita mostrar calificación
  Future<bool> needsRatingDialog(String roomId, String studentId) async {
    return await _executeBoolWithRetry(() async {
      try {
        final meeting = await findByRoom(roomId);
        if (meeting == null) return false;

        // ✅ Verificar si ya se mostró el diálogo (subject contiene [RATED])
        final subject = meeting['subject']?.toString() ?? '';
        if (subject.contains('[RATED]')) {
          return false;
        }

        // ✅ Verificar si la reunión fue completada (student_name contiene COMPLETED_)
        final studentName = meeting['student_name']?.toString() ?? '';
        if (studentName.startsWith('COMPLETED_')) {
          // Verificar si no existe calificación
          final existingRating = await _client
              .from('tutor_ratings')
              .select('id')
              .eq('meeting_id', meeting['id'])
              .eq('student_id', studentId)
              .maybeSingle();
          
          return existingRating == null; // Solo mostrar si no existe calificación
        }

        return false;
      } catch (e) {
        debugPrint('[MEETINGS] Error verificando necesidad de diálogo: $e');
        return false;
      }
    });
  }
  Future<void> programarNotificacionReunion({
    required String titulo,
    required String mensaje,
    required DateTime fechaReunion, // DEBE SER LOCAL
    required BuildContext context,
    String? userId,
    String? tipo,
    String? referenciaId,
  }) async {
    await NotificationsService.programarNotificacionReunion(
      titulo: titulo,
      mensaje: mensaje,
      fechaReunion: fechaReunion,
      context: context,
      userId: userId,
      tipo: tipo ?? 'reunion',
      referenciaId: referenciaId,
    );
  }

  /// Verifica si un estudiante tiene acceso a una reunión
  Future<bool> estudianteTieneAccesoAReunion(String studentId, String meetingId) async {
    final existe = await Supabase.instance.client
        .from('student_meetings')
        .select()
        .eq('student_id', studentId)
        .eq('meeting_id', meetingId)
        .maybeSingle();
    return existe != null;
  }

  /// Lista reuniones agendadas por estudiante
  Future<List<Map<String, dynamic>>> reunionesAgendadasPorEstudiante(String studentId) async {
    final relaciones = await Supabase.instance.client
        .from('student_meetings')
        .select('meeting_id')
        .eq('student_id', studentId);

    if (relaciones == null || relaciones.isEmpty) return [];

    final ids = relaciones.map((r) => r['meeting_id']).toList();
    if (ids.isEmpty) return [];

    final reuniones = await Supabase.instance.client
        .from('meetings')
        .select()
        .inFilter('id', ids);

    return List<Map<String, dynamic>>.from(reuniones);
  }
}

