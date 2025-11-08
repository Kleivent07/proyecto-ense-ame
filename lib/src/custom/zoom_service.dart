// Reescrito para usar Configuration.apiBase, endpoint /create-zoom-meeting
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../custom/configuration.dart';

class ZoomService {
  final String baseUrl = Configuration.apiBase;

  /// Crear reunión en el backend Node.
  /// - [accessToken] es opcional (token de sesión Supabase). Si se provee, se añade en Authorization.
  Future<Map<String, dynamic>> crearReunion({
    required String topic,
    DateTime? startTime,
    required int duration,
    required String hostId,
    String? roomId,
    String? accessToken,
  }) async {
    // Endpoint que usa la app (crear reunión)
    final url = Uri.parse('$baseUrl/create-zoom-meeting');

    // Si no se pasó startTime, no enviarlo (Zoom puede crear reunión "inmediata")
    final body = <String, dynamic>{
      'topic': topic,
      'duration': duration,
      'host_user_id': hostId,
      'room_id': roomId,
    };
    if (startTime != null) {
      // Enviamos ISO8601 en UTC que es robusto tanto para backend como para Zoom
      body['start_time'] = startTime.toUtc().toIso8601String();
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final response = await http.post(url, headers: headers, body: jsonEncode(body));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      // Mejor detalle del error para debugging
      String detail = response.body;
      try {
        final parsed = jsonDecode(response.body);
        detail = parsed.toString();
      } catch (_) {}
      throw Exception('Error al crear la reunión (${response.statusCode}): $detail');
    }
  }
}
