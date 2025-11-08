import 'package:supabase_flutter/supabase_flutter.dart';

class ZoomMeetingModel {
  final SupabaseClient _client = Supabase.instance.client;

  /// Retorna la lista de reuniones asociadas a una room_id.
  /// Si roomId está vacío o nulo retorna lista vacía.
  Future<List<Map<String, dynamic>>> listByRoom(String roomId) async {
    if (roomId == null || roomId.trim().isEmpty) return <Map<String, dynamic>>[];

    try {
      final resp = await _client
          .from('zoom_meetings')
          .select('*')
          .eq('room_id', roomId)
          .order('start_time', ascending: true) as List<dynamic>?;

      if (resp == null) return <Map<String, dynamic>>[];
      return resp.cast<Map<String, dynamic>>();
    } catch (e) {
      // Puedes registrar aquí si quieres debugging
      // print('[ZoomMeetingModel] error listByRoom: $e');
      return <Map<String, dynamic>>[];
    }
  }

  /// (Opcional) función auxiliar para buscar por zoom_id
  Future<Map<String, dynamic>?> findByZoomId(String zoomId) async {
    if (zoomId.trim().isEmpty) return null;
    try {
      final resp = await _client
          .from('zoom_meetings')
          .select('*')
          .eq('zoom_id', zoomId)
          .maybeSingle();
      if (resp == null) return null;
      return resp as Map<String, dynamic>;
    } catch (e) {
      // print('[ZoomMeetingModel] findByZoomId error: $e');
      return null;
    }
  }
}