import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class TutorRatingModel {
  final _client = Supabase.instance.client;

  /// Constante para el mínimo de calificaciones necesarias para mostrar estadísticas
  static const int MIN_RATINGS_TO_SHOW = 3;

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

  /// ✅ Generar ID único identificable para la calificación
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

  /// ✅ CREAR CALIFICACIÓN REAL (ARREGLADO - validar tutor_id)
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

        debugPrint('[RATING] 🌟 Creando calificación real:');
        debugPrint('[RATING] Meeting ID: $meetingId');
        debugPrint('[RATING] Tutor ID: $tutorId');
        debugPrint('[RATING] Student ID: $studentId');
        debugPrint('[RATING] Rating: $rating estrellas');

        // ✅ Verificar que la reunión existe y obtener información
        final meeting = await _client
            .from('meetings')
            .select('*')
            .eq('id', meetingId)
            .single();

        debugPrint('[RATING] 📋 Reunión encontrada: ${meeting['subject']} - ${meeting['tutor_name']}');

        // ✅ Verificar si ya existe una calificación
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

        // ✅ ARREGLAR: Obtener tutor_id válido de la reunión si el proporcionado no es válido
        String validTutorId = tutorId;
        
        // ✅ Si tutor_id no es un UUID válido, usar el de la reunión o crear uno genérico
        if (!_isValidUUID(tutorId)) {
          debugPrint('[RATING] ⚠️ tutor_id no válido: $tutorId');
          
          final meetingTutorId = meeting['tutor_id']?.toString();
          if (meetingTutorId != null && _isValidUUID(meetingTutorId)) {
            validTutorId = meetingTutorId;
            debugPrint('[RATING] ✅ Usando tutor_id de la reunión: $validTutorId');
          } else {
            // ✅ Como último recurso, usar el studentId (el que califica)
            validTutorId = studentId;
            debugPrint('[RATING] ⚠️ Usando studentId como tutor_id temporal: $validTutorId');
          }
        }

        // ✅ Generar ID único identificable
        final uniqueRatingId = _generateRatingId(
          meetingId: meetingId,
          tutorId: validTutorId,
          studentId: studentId,
        );

        // ✅ Obtener información del tutor (con manejo de errores)
        final tutorInfo = await _getTutorInfo(validTutorId);

        // ✅ Preparar datos para insertar
        final insertData = <String, dynamic>{
          'meeting_id': meetingId,
          'tutor_id': validTutorId, // ✅ Usar el tutor_id válido
          'student_id': studentId,
          'rating': rating,
          'comments': comments,
          'rating_id': uniqueRatingId,
          'tutor_name': tutorInfo['name'],
          'subject': subject ?? meeting['subject']?.toString()?.replaceAll('[SHOWN]', '').trim() ?? 'Tutoría General',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };

        debugPrint('[RATING] 💾 Insertando calificación: ${insertData.toString()}');

        final insertResult = await _client
            .from('tutor_ratings')
            .insert(insertData)
            .select()
            .single();

        debugPrint('[RATING] ✅ Calificación creada exitosamente con ID: $uniqueRatingId');

        return {
          'success': true, 
          'message': 'Calificación enviada exitosamente', 
          'data': insertResult,
          'rating_id': uniqueRatingId,
        };
      }) ?? {'success': false, 'message': 'Error de conexión'};
    } catch (e) {
      debugPrint('[RATING] ❌ Error creando calificación: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// ✅ Verificar si un string es un UUID válido
  bool _isValidUUID(String str) {
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(str);
  }

  /// ✅ Obtener información del tutor (con mejor manejo de errores)
  Future<Map<String, String>> _getTutorInfo(String tutorId) async {
    try {
      // ✅ Solo buscar si es un UUID válido
      if (!_isValidUUID(tutorId)) {
        debugPrint('[RATING] tutor_id no es UUID válido, usando valores por defecto');
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

  /// ✅ OBTENER REUNIONES COMPLETADAS QUE NECESITAN CALIFICACIÓN (MEJORADO)
  Future<List<Map<String, dynamic>>> getRatableCompletedMeetings(String studentId) async {
    try {
      return await _executeWithRetry<List<Map<String, dynamic>>>(() async {
        debugPrint('[RATING] 🔍 Buscando reuniones completadas para estudiante: $studentId');

        // ✅ Obtener reuniones pasadas (que ya terminaron hace al menos 1 minuto)
        final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1)).toUtc().toIso8601String();
        final meetings = await _client
            .from('meetings')
            .select('*')
            .lt('scheduled_at', oneMinuteAgo) // Solo reuniones que ya pasaron
            .order('scheduled_at', ascending: false);

        debugPrint('[RATING] 📅 Reuniones pasadas encontradas: ${meetings.length}');

        final List<Map<String, dynamic>> ratableMeetings = [];

        for (final meeting in meetings) {
          final meetingId = meeting['id'];
          if (meetingId == null) continue;

          // ✅ Verificar si ya fue calificada por este estudiante
          final existingRating = await _client
              .from('tutor_ratings')
              .select('id, rating_id')
              .eq('meeting_id', meetingId)
              .eq('student_id', studentId)
              .maybeSingle();

          if (existingRating == null) {
            // ✅ No ha sido calificada - verificar si fue completada o es elegible
            final studentName = meeting['student_name']?.toString() ?? '';
            final subject = meeting['subject']?.toString() ?? '';
            
            // ✅ Criterios para mostrar:
            // 1. Fue marcada como completada (COMPLETED_) O
            // 2. Es una reunión pasada (más de 1 minuto) que no ha sido marcada como [RATED]
            bool isEligible = false;
            
            if (studentName.startsWith('COMPLETED_')) {
              // ✅ Fue explícitamente completada
              isEligible = true;
              debugPrint('[RATING] 🎯 Reunión completada explícitamente: ${meeting['room_id']}');
            } else {
              // ✅ Reunión pasada que podría necesitar calificación
              final scheduledAt = DateTime.parse(meeting['scheduled_at']).toLocal();
              final now = DateTime.now();
              final minutesPassed = now.difference(scheduledAt).inMinutes;
              
              if (minutesPassed > 5 && !subject.contains('[RATED]')) {
                isEligible = true;
                debugPrint('[RATING] ⏰ Reunión pasada elegible: ${meeting['room_id']} (${minutesPassed} min)');
              }
            }
            
            if (isEligible) {
              final meetingData = Map<String, dynamic>.from(meeting);
              // ✅ Limpiar el subject de marcadores
              final cleanSubject = subject.replaceAll('[RATED]', '').replaceAll('[SHOWN]', '').trim();
              meetingData['subject'] = cleanSubject.isEmpty ? 'Tutoría General' : cleanSubject;
              meetingData['tutor_name'] = meetingData['tutor_name'] ?? 'Tutor';
              meetingData['student_name'] = 'Estudiante'; // Limpiar el marker
              
              ratableMeetings.add(meetingData);
              debugPrint('[RATING] ✅ Reunión agregada para calificar: ${meetingData['subject']} - ${meetingData['tutor_name']}');
            }
          } else {
            debugPrint('[RATING] ⏭️ Reunión ya calificada: ${meeting['room_id']}');
          }
        }

        debugPrint('[RATING] 🎯 Reuniones que necesitan calificación: ${ratableMeetings.length}');
        return ratableMeetings;
      }) ?? [];
    } catch (e) {
      debugPrint('[RATING] ❌ Error obteniendo reuniones calificables: $e');
      return [];
    }
  }

  /// ✅ OBTENER CALIFICACIONES DE UN ESTUDIANTE (ARREGLADO - sin relación FK)
  Future<List<Map<String, dynamic>>> getStudentSubmittedRatings(String studentId) async {
    try {
      return await _executeWithRetry<List<Map<String, dynamic>>>(() async {
        debugPrint('[RATING] 📋 Obteniendo calificaciones enviadas por estudiante: $studentId');

        // ✅ Obtener solo las calificaciones sin JOIN
        final ratings = await _client
            .from('tutor_ratings')
            .select('*')
            .eq('student_id', studentId)
            .order('created_at', ascending: false);

        debugPrint('[RATING] 📊 Calificaciones base encontradas: ${ratings.length}');

        // ✅ Enriquecer cada calificación con datos de la reunión manualmente
        final enrichedRatings = <Map<String, dynamic>>[];
        
        for (final rating in ratings) {
          final meetingId = rating['meeting_id'];
          if (meetingId == null) continue;

          try {
            // ✅ Obtener datos de la reunión por separado
            final meetingData = await _client
                .from('meetings')
                .select('subject, tutor_name, scheduled_at, room_id')
                .eq('id', meetingId)
                .maybeSingle();

            if (meetingData != null) {
              // ✅ Combinar datos de calificación + reunión
              final enrichedRating = Map<String, dynamic>.from(rating);
              enrichedRating['meetings'] = meetingData;
              enrichedRating['meeting_subject'] = meetingData['subject'] ?? 'Tutoría General';
              enrichedRating['meeting_tutor_name'] = meetingData['tutor_name'] ?? 'Tutor';
              enrichedRating['meeting_scheduled_at'] = meetingData['scheduled_at'];
              enrichedRating['meeting_room_id'] = meetingData['room_id'];
              
              enrichedRatings.add(enrichedRating);
              debugPrint('[RATING] ✅ Calificación enriquecida: ${enrichedRating['subject']} - ${enrichedRating['tutor_name']}');
            } else {
              // ✅ Si no encontramos la reunión, agregar con datos básicos
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
              debugPrint('[RATING] ⚠️ Reunión no encontrada, usando datos básicos');
            }
          } catch (e) {
            debugPrint('[RATING] ❌ Error obteniendo datos de reunión $meetingId: $e');
            // ✅ Agregar sin datos de reunión como fallback
            final fallbackRating = Map<String, dynamic>.from(rating);
            fallbackRating['meetings'] = {
              'subject': rating['subject'] ?? 'Tutoría General',
              'tutor_name': rating['tutor_name'] ?? 'Tutor',
              'scheduled_at': rating['created_at'],
            };
            enrichedRatings.add(fallbackRating);
          }
        }

        debugPrint('[RATING] ✅ Total calificaciones enriquecidas: ${enrichedRatings.length}');
        return enrichedRatings;
      }) ?? [];
    } catch (e) {
      debugPrint('[RATING] ❌ Error obteniendo calificaciones del estudiante: $e');
      return [];
    }
  }

  /// ✅ OBTENER ESTADÍSTICAS DE TUTOR (REAL)
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

        // Distribución de calificaciones
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

  /// ✅ Verificar calificación existente de estudiante
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

  /// ✅ Actualizar una calificación existente
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
          // Si falla por rating_id, intentar por id normal
          updateResult = await _client
              .from('tutor_ratings')
              .update(updateData)
              .eq('id', ratingId)
              .select()
              .single();
        }

        debugPrint('[RATING] ✅ Calificación actualizada: ID=$ratingId, Rating=$rating');

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