import 'package:supabase_flutter/supabase_flutter.dart';

class ZoomMeetingModel {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> create(Map<String, dynamic> payload) async {
    // payload should include at least: room_id, topic, start_time (iso), duration, created_by
    try {
      final resp = await _client.from('zoom_meetings').insert(payload).select().maybeSingle();
      if (resp == null) return null;
      return (resp is Map<String, dynamic>) ? resp : Map<String, dynamic>.from(resp);
    } catch (e) {
      print('[ZOOM] create error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listByRoom(String roomId) async {
    try {
      final resp = await _client.from('zoom_meetings').select().eq('room_id', roomId).order('created_at', ascending: false);
      if (resp == null) return [];
      final List rows = (resp is List) ? resp : [resp];
      return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (e) {
      print('[ZOOM] listByRoom error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    try {
      final resp = await _client.from('zoom_meetings').select().eq('id', id).maybeSingle();
      if (resp == null) return null;
      return (resp is Map<String, dynamic>) ? resp : Map<String, dynamic>.from(resp);
    } catch (e) {
      print('[ZOOM] getById error: $e');
      return null;
    }
  }

  Future<bool> update(String id, Map<String, dynamic> changes) async {
    try {
      final resp = await _client.from('zoom_meetings').update(changes).eq('id', id);
      return true;
    } catch (e) {
      print('[ZOOM] update error: $e');
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _client.from('zoom_meetings').delete().eq('id', id);
      return true;
    } catch (e) {
      print('[ZOOM] delete error: $e');
      return false;
    }
  }
}