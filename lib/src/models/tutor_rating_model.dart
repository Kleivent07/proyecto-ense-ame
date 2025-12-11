import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class TutorRatingModel {
  final _client = Supabase.instance.client;

  static const int MIN_RATINGS_TO_SHOW = 3;

  /// Manejo de JWT expirado
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

  /// Generar ID único para la calificación
  String _generateRatingId({
    required String meetingId,
    required String tutorId,
    required String studentId,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tutorPrefix = tutorId.length >= 8 ? tutorId.substring(0, 8) : tutorId;
    final meetingPrefix = meetingId.length >= 8 ? meetingId.substring(0, 8) : meetingId;
    return 'RATING_${tutorPrefix}_${meetingPrefix}_$timestamp';
  }

  /// Verificar si un string es un UUID válido
  bool _isValidUUID(String str) {
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(str);
  }

  /// Obtener información del tutor
  Future<Map<String, String>> _getTutorInfo(String tutorId) async {
    try {
      if (!_isValidUUID(tutorId)) {
        return {'name': 'Tutor', 'email': ''};
      }
      final tutorData = await _client
          .from('usuarios')
          .select('nombre, apellido, email')
          .eq('id', tutorId)
          .maybeSingle();
      if (tutorData != null) {
        return {
          'name': '${tutorData['nombre'] ?? ''} ${tutorData['apellido'] ?? ''}'.trim(),
          'email': tutorData['email'] ?? '',
        };
      }
    } catch (e) {
      debugPrint('[RATING] Error obteniendo info del tutor: $e');
    }
    return {'name': 'Tutor', 'email': ''};
  }

  /// Crear calificación
  Future<Map<String, dynamic>> createRating({
    required String meetingId,
    required String tutorId,
    required String studentId,
    String? subject,
    required int rating,
    String? comments,
  }) async {
    try {
      return await _executeWithRetry<Map<String, dynamic>>(() async {
        if (rating < 1 || rating > 5) {
          return {'success': false, 'message': 'La calificación debe estar entre 1 y 5 estrellas'};
        }

        final meeting = await _client
            .from('meetings')
            .select('*')
            .eq('id', meetingId)
            .maybeSingle();

        if (meeting == null) {
          return {'success': false, 'message': 'La reunión no existe'};
        }

        // Solo permitir si la reunión está completada
        if (meeting['status']?.toString() != 'completada') {
          return {'success': false, 'message': 'Solo puedes calificar reuniones completadas'};
        }

        final existingRating = await _client
            .from('tutor_ratings')
            .select('id, rating_id')
            .eq('meeting_id', meetingId)
            .eq('student_id', studentId)
            .maybeSingle();

        if (existingRating != null) {
          return {
            'success': false,
            'message': 'Ya has calificado esta reunión',
            'existing_rating_id': existingRating['rating_id'],
          };
        }

        String validTutorId = tutorId;
        if (!_isValidUUID(tutorId)) {
          final meetingTutorId = meeting['tutor_id']?.toString();
          if (meetingTutorId != null && _isValidUUID(meetingTutorId)) {
            validTutorId = meetingTutorId;
          } else {
            validTutorId = studentId;
          }
        }

        final uniqueRatingId = _generateRatingId(
          meetingId: meetingId,
          tutorId: validTutorId,
          studentId: studentId,
        );

        final tutorInfo = await _getTutorInfo(validTutorId);

        final insertData = <String, dynamic>{
          'meeting_id': meetingId,
          'tutor_id': validTutorId,
          'student_id': studentId,
          'rating': rating,
          'comments': comments,
          'rating_id': uniqueRatingId,
          'tutor_name': tutorInfo['name'],
          'subject': (subject ?? meeting['subject']?.toString() ?? '')
              .replaceAll('[SHOWN]', '')
              .trim(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };

        final insertResult = await _client
            .from('tutor_ratings')
            .insert(insertData)
            .select()
            .single();

        return {
          'success': true,
          'message': 'Calificación enviada exitosamente',
          'data': insertResult,
          'rating_id': uniqueRatingId,
        };
      }) ?? {'success': false, 'message': 'Error de conexión'};
    } catch (e) {
      debugPrint('[RATING] Error creando calificación: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Obtener reuniones completadas que necesitan calificación
  Future<List<Map<String, dynamic>>> getRatableCompletedMeetings(String studentId) async {
    try {
      return await _executeWithRetry<List<Map<String, dynamic>>>(() async {
        final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1)).toUtc().toIso8601String();
        final meetings = await _client
            .from('meetings')
            .select('*')
            .lt('scheduled_at', oneMinuteAgo)
            .order('scheduled_at', ascending: false);

        final List<Map<String, dynamic>> ratableMeetings = [];
        for (final meeting in meetings) {
          final meetingId = meeting['id'];
          if (meetingId == null) continue;

          // Solo permitir si la reunión está completada
          if (meeting['status']?.toString() != 'completada') {
            continue;
          }

          final existingRating = await _client
              .from('tutor_ratings')
              .select('id, rating_id')
              .eq('meeting_id', meetingId)
              .eq('student_id', studentId)
              .maybeSingle();

          if (existingRating == null) {
            final subject = meeting['subject']?.toString() ?? '';
            bool isEligible = false;

            // Calcula minutos transcurridos de forma segura
            int minutesPassed = 0;
            try {
              final scheduledAt = DateTime.parse(meeting['scheduled_at']).toLocal();
              minutesPassed = DateTime.now().difference(scheduledAt).inMinutes;
            } catch (_) {
              minutesPassed = 0;
            }

            // Criterios para mostrar:
            // 1) Marcada como completada (COMPLETED_)
            // 2) Pasó más de 5 min y no contiene [RATED]
            final studentName = meeting['student_name']?.toString() ?? '';
            if (studentName.startsWith('COMPLETED_')) {
              isEligible = true;
            } else {
              if (minutesPassed > 5 && !subject.contains('[RATED]')) {
                isEligible = true;
              }
            }
            debugPrint('[RATING] meeting ${meetingId} minutos transcurridos: $minutesPassed, elegible: $isEligible');
            if (isEligible) {
              final meetingData = Map<String, dynamic>.from(meeting);
              final cleanSubject = subject.replaceAll('[RATED]', '').replaceAll('[SHOWN]', '').trim();
              meetingData['subject'] = cleanSubject.isEmpty ? 'Tutoría General' : cleanSubject;
              // No sobrescribas el nombre real del estudiante
              ratableMeetings.add(meetingData);
            }
          }
        }
        return ratableMeetings;
      }) ?? [];
    } catch (e) {
      debugPrint('[RATING] Error obteniendo reuniones calificables: $e');
      return [];
    }
  }

  /// Obtener calificaciones enviadas por estudiante
  Future<List<Map<String, dynamic>>> getStudentSubmittedRatings(String studentId) async {
    try {
      return await _executeWithRetry<List<Map<String, dynamic>>>(() async {
        final ratings = await _client
            .from('tutor_ratings')
            .select('*')
            .eq('student_id', studentId)
            .order('created_at', ascending: false);

        final enrichedRatings = <Map<String, dynamic>>[];
        for (final rating in ratings) {
          final meetingId = rating['meeting_id'];
          if (meetingId == null) continue;
          try {
            final meetingData = await _client
                .from('meetings')
                .select('subject, tutor_name, scheduled_at, room_id')
                .eq('id', meetingId)
                .maybeSingle();
            if (meetingData != null) {
              final enrichedRating = Map<String, dynamic>.from(rating);
              enrichedRating['meetings'] = meetingData;
              enrichedRating['meeting_subject'] = meetingData['subject'] ?? 'Tutoría General';
              enrichedRating['meeting_tutor_name'] = meetingData['tutor_name'] ?? 'Tutor';
              enrichedRating['meeting_scheduled_at'] = meetingData['scheduled_at'];
              enrichedRating['meeting_room_id'] = meetingData['room_id'];
              enrichedRatings.add(enrichedRating);
            } else {
              final basicRating = Map<String, dynamic>.from(rating);
              basicRating['meetings'] = {
                'subject': rating['subject'] ?? 'Tutoría General',
                'tutor_name': rating['tutor_name'] ?? 'Tutor',
                'scheduled_at': rating['created_at'],
              };
              basicRating['meeting_subject'] = rating['subject'] ?? 'Tutoría General';
              basicRating['meeting_tutor_name'] = rating['tutor_name'] ?? 'Tutor';
              basicRating['meeting_scheduled_at'] = rating['created_at'];
              enrichedRatings.add(basicRating);
            }
          } catch (e) {
            final fallbackRating = Map<String, dynamic>.from(rating);
            fallbackRating['meetings'] = {
              'subject': rating['subject'] ?? 'Tutoría General',
              'tutor_name': rating['tutor_name'] ?? 'Tutor',
              'scheduled_at': rating['created_at'],
            };
            enrichedRatings.add(fallbackRating);
          }
        }
        return enrichedRatings;
      }) ?? [];
    } catch (e) {
      debugPrint('[RATING] Error obteniendo calificaciones del estudiante: $e');
      return [];
    }
  }

  /// Obtener estadísticas de tutor
  Future<Map<String, dynamic>> getTutorStats(String tutorId) async {
    try {
      return await _executeWithRetry<Map<String, dynamic>>(() async {
        final ratings = await _client
            .from('tutor_ratings')
            .select('rating')
            .eq('tutor_id', tutorId);

        if (ratings.isEmpty) {
          return {
            'tutor_id': tutorId,
            'average_rating': 0.0,
            'total_ratings': 0,
            'rating_distribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
            'has_enough_ratings': false,
          };
        }

        final total = ratings.length;
        final sum = ratings.fold<int>(0, (sum, rating) => sum + (rating['rating'] as int));
        final average = sum / total;

        final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
        for (final rating in ratings) {
          final stars = rating['rating'] as int;
          distribution[stars] = (distribution[stars] ?? 0) + 1;
        }

        return {
          'tutor_id': tutorId,
          'average_rating': double.parse(average.toStringAsFixed(1)),
          'total_ratings': total,
          'rating_distribution': distribution,
          'has_enough_ratings': total >= MIN_RATINGS_TO_SHOW,
        };
      }) ?? {
        'tutor_id': tutorId,
        'average_rating': 0.0,
        'total_ratings': 0,
        'rating_distribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        'has_enough_ratings': false,
      };
    } catch (e) {
      debugPrint('[RATING] Error obteniendo estadísticas: $e');
      return {
        'tutor_id': tutorId,
        'average_rating': 0.0,
        'total_ratings': 0,
        'rating_distribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        'has_enough_ratings': false,
      };
    }
  }

  /// Verificar calificación existente de estudiante para una reunión
  Future<Map<String, dynamic>?> getStudentRatingForMeeting({
    required String meetingId,
    required String studentId,
  }) async {
    try {
      return await _executeWithRetry<Map<String, dynamic>?>(() async {
        final rating = await _client
            .from('tutor_ratings')
            .select('*')
            .eq('meeting_id', meetingId)
            .eq('student_id', studentId)
            .maybeSingle();
        if (rating != null) {
          return Map<String, dynamic>.from(rating);
        }
        return null;
      });
    } catch (e) {
      debugPrint('[RATING] Error verificando calificación existente: $e');
      return null;
    }
  }

  /// Actualizar una calificación existente
  Future<Map<String, dynamic>> updateRating({
    required String ratingId,
    required int rating,
    String? subject,
    String? comments,
  }) async {
    try {
      return await _executeWithRetry<Map<String, dynamic>>(() async {
        if (rating < 1 || rating > 5) {
          return {'success': false, 'message': 'La calificación debe estar entre 1 y 5 estrellas'};
        }

        final updateData = <String, dynamic>{
          'rating': rating,
          'comments': comments,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };

        if (subject != null) {
          updateData['subject'] = subject;
        }

        dynamic updateResult;
        try {
          updateResult = await _client
              .from('tutor_ratings')
              .update(updateData)
              .eq('rating_id', ratingId)
              .select()
              .single();
        } catch (e) {
          updateResult = await _client
              .from('tutor_ratings')
              .update(updateData)
              .eq('id', ratingId)
              .select()
              .single();
        }

        return {
          'success': true,
          'message': 'Calificación actualizada exitosamente',
          'data': updateResult,
        };
      }) ?? {'success': false, 'message': 'Error de conexión'};
    } catch (e) {
      debugPrint('[RATING] Error actualizando calificación: $e');
      return {'success': false, 'message': 'Error inesperado: ${e.toString()}'};
    }
  }
}