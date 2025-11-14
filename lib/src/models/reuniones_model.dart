import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Modelo para manejar las reuniones en Supabase (tabla `meetings`).
/// Campos esperados (parciales): id, tutor_name, tutor_id, student_name,
/// room_id, subject, scheduled_at, token (opcional), record (boolean),
/// recording_url (opcional).
class MeetingModel {
  final _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> createMeeting({
    required String tutorName,
    String? studentName,
    required String roomId,
    String? subject,
    required DateTime scheduledAt,
    String? tutorId,
    String? token,
    bool? record,
    String? recordingUrl,
  }) async {
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
        if (record != null) 'record': record,
        if (recordingUrl != null) 'recording_url': recordingUrl,
      };

      final res = await _client.from('meetings').insert(payload).select().maybeSingle();
      if (res is Map<String, dynamic>) return res;
      return null;
    } catch (e, st) {
      debugPrint('Error creating meeting: $e\n$st');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listMeetings() async {
    try {
      final resp = await _client.from('meetings').select().order('scheduled_at', ascending: false);
      if (resp is List) return List<Map<String, dynamic>>.from(resp);
      return [];
    } catch (e, st) {
      debugPrint('Error listing meetings: $e\n$st');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> listMeetingsByTutor([String? tutorId]) async {
    try {
      final id = tutorId ?? _client.auth.currentUser?.id;
      if (id == null) return [];
      final resp = await _client.from('meetings').select().eq('tutor_id', id).order('scheduled_at', ascending: false);
      if (resp is List) return List<Map<String, dynamic>>.from(resp);
      return [];
    } catch (e, st) {
      debugPrint('Error listing meetings by tutor: $e\n$st');
      return [];
    }
  }

  Future<Map<String, dynamic>?> findByRoom(String roomId) async {
    try {
      final resp = await _client.from('meetings').select().eq('room_id', roomId).maybeSingle();
      if (resp is Map<String, dynamic>) return resp;
      return null;
    } catch (e, st) {
      debugPrint('Error finding meeting by room ($roomId): $e\n$st');
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateMeetingByRoom(String roomId, {
    String? tutorName,
    String? studentName,
    String? subject,
    DateTime? scheduledAt,
    String? token,
    String? tutorId,
    bool? record,
    String? recordingUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        if (tutorName != null) 'tutor_name': tutorName,
        if (studentName != null) 'student_name': studentName,
        if (subject != null) 'subject': subject,
        if (scheduledAt != null) 'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        if (token != null) 'token': token,
        if (tutorId != null) 'tutor_id': tutorId,
        if (record != null) 'record': record,
        if (recordingUrl != null) 'recording_url': recordingUrl,
      };

      if (updates.isEmpty) return null;
      final res = await _client.from('meetings').update(updates).eq('room_id', roomId).select().maybeSingle();
      if (res is Map<String, dynamic>) return res;
      return null;
    } catch (e, st) {
      debugPrint('Error updating meeting ($roomId): $e\n$st');
      return null;
    }
  }

  Future<Map<String, dynamic>?> claimTutorForRoom(String roomId, String tutorId, {String? tutorName}) async {
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
  }

  Future<bool> deleteMeetingByRoom(String roomId) async {
    try {
      await _client.from('meetings').delete().eq('room_id', roomId);
      return true;
    } catch (e, st) {
      debugPrint('Error deleting meeting ($roomId): $e\n$st');
      return false;
    }
  }
}