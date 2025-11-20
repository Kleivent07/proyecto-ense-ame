import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RatingModel {
  final SupabaseClient _client = Supabase.instance.client;

  /// Método helper para manejar errores de JWT expirado
  Future<T?> _executeWithRetry<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (e) {
      if (e.toString().contains('JWT expired') || e.toString().contains('PGRST303')) {
        debugPrint('[RATING] JWT expirado, renovando token...');
        try {
          await _client.auth.refreshSession();
          debugPrint('[RATING] Token renovado, reintentando operación...');
          return await operation();
        } catch (refreshError) {
          debugPrint('[RATING] Error renovando token: $refreshError');
          return null;
        }
      }
      rethrow;
    }
  }

  /// Crear una nueva calificación para un tutor
  Future<Map<String, dynamic>> createRating({
    required String meetingId,
    required String tutorId,
    required String studentId,
    required int rating,
    String? comments,
  }) async {
    try {
      final result = await _executeWithRetry(() async {
        // Verificar si ya existe una calificación para esta reunión
        final existingRating = await _client
            .from('tutor_ratings')
            .select('id')
            .eq('meeting_id', meetingId)
            .eq('student_id', studentId)
            .maybeSingle();

        if (existingRating != null) {
          return {
            'success': false,
            'message': 'Ya has calificado esta reunión anteriormente'
          };
        }

        // Insertar nueva calificación
        final insertResult = await _client.from('tutor_ratings').insert({
          'meeting_id': meetingId,
          'tutor_id': tutorId,
          'student_id': studentId,
          'rating': rating,
          'comments': comments,
        }).select().single();

        debugPrint('[RATING] ✅ Calificación creada: $insertResult');
        return {
          'success': true,
          'message': 'Calificación guardada correctamente',
          'data': insertResult
        };
      });

      return result ?? {
        'success': false,
        'message': 'Error de conexión'
      };
    } catch (e) {
      debugPrint('[RATING] ❌ Error creando calificación: $e');
      return {
        'success': false,
        'message': 'Error al guardar la calificación: $e'
      };
    }
  }

  /// Obtener calificaciones de un tutor
  Future<Map<String, dynamic>> getTutorRatings(String tutorId) async {
    try {
      final result = await _executeWithRetry(() async {
        // Obtener últimas calificaciones detalladas
        final recentRatings = await _client
            .from('tutor_ratings')
            .select('rating, comments, created_at')
            .eq('tutor_id', tutorId)
            .order('created_at', ascending: false)
            .limit(10);

        return {
          'success': true,
          'average': 0.0,
          'count': recentRatings.length,
          'recent_ratings': recentRatings
        };
      });

      return result ?? {
        'success': false,
        'average': 0.0,
        'count': 0,
        'recent_ratings': []
      };
    } catch (e) {
      debugPrint('[RATING] ❌ Error obteniendo calificaciones: $e');
      return {
        'success': false,
        'average': 0.0,
        'count': 0,
        'recent_ratings': []
      };
    }
  }

  /// Verificar si un estudiante ya calificó una reunión
  Future<bool> hasStudentRatedMeeting(String meetingId, String studentId) async {
    try {
      final result = await _executeWithRetry(() async {
        final rating = await _client
            .from('tutor_ratings')
            .select('id')
            .eq('meeting_id', meetingId)
            .eq('student_id', studentId)
            .maybeSingle();

        return rating != null;
      });

      return result ?? false;
    } catch (e) {
      debugPrint('[RATING] ❌ Error verificando calificación: $e');
      return false;
    }
  }

  /// Obtener reuniones completadas que el estudiante puede calificar
  Future<List<Map<String, dynamic>>> getUnratedMeetingsForStudent(String studentId) async {
    try {
      final result = await _executeWithRetry(() async {
        // Obtener reuniones donde participó el estudiante y aún no ha calificado
        final meetings = await _client
            .from('meetings')
            .select('id, tutor_name, tutor_id, subject, scheduled_at')
            .lt('scheduled_at', DateTime.now().toIso8601String()) // Reuniones pasadas
            .order('scheduled_at', ascending: false);

        // Filtrar reuniones no calificadas
        List<Map<String, dynamic>> unratedMeetings = [];
        
        for (var meeting in meetings) {
          final hasRated = await hasStudentRatedMeeting(meeting['id'], studentId);
          if (!hasRated) {
            unratedMeetings.add(meeting);
          }
        }

        return unratedMeetings;
      });

      return result ?? [];
    } catch (e) {
      debugPrint('[RATING] ❌ Error obteniendo reuniones no calificadas: $e');
      return [];
    }
  }
}