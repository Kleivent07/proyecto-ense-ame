import 'package:my_app/src/models/reuniones_model.dart';

class MeetingService {
  final MeetingModel _model = MeetingModel();

  /// Valida si el usuario puede unirse a la reunión según su rol
  Future<bool> puedeUnirseAReunion({
    required String userId,
    required String meetingId,
    required bool esEstudiante,
  }) async {
    if (!esEstudiante) return true; // Profesores pueden unirse a cualquier reunión
    return await _model.estudianteTieneAccesoAReunion(userId, meetingId);
  }

  /// Obtiene reuniones agendadas por estudiante
  Future<List<Map<String, dynamic>>> reunionesAgendadas(String userId) {
    return _model.reunionesAgendadasPorEstudiante(userId);
  }
}