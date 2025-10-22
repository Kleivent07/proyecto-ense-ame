class SolicitudData {
  String id;
  String estudianteId;
  String profesorId;
  String estado;
  DateTime fechaSolicitud;
  String nombreTutor;
  String nombreEstudiante;

  SolicitudData({
    this.id = '',
    required this.estudianteId,
    required this.profesorId,
    required this.estado,
    required this.fechaSolicitud,
    this.nombreTutor = '',
    this.nombreEstudiante = '',
  });

  factory SolicitudData.fromMap(Map<String, dynamic> map) {
    final tutorUsuarios = map['tutor'] != null ? map['tutor']['usuarios'] : null;
    final estudianteUsuarios = map['estudiante'] != null ? map['estudiante']['usuarios'] : null;

    final nombreTutor = tutorUsuarios != null
        ? '${tutorUsuarios['nombre'] ?? ''} ${tutorUsuarios['apellido'] ?? ''}'.trim()
        : '';

    final nombreEstudiante = estudianteUsuarios != null
        ? '${estudianteUsuarios['nombre'] ?? ''} ${estudianteUsuarios['apellido'] ?? ''}'.trim()
        : '';

    return SolicitudData(
      id: map['id'] ?? '',
      estudianteId: map['estudiante_id'] ?? '',
      profesorId: map['profesor_id'] ?? '',
      estado: map['estado'] ?? 'none',
      fechaSolicitud: DateTime.parse(map['fecha_solicitud']),
      nombreTutor: nombreTutor,
      nombreEstudiante: nombreEstudiante,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'estudiante_id': estudianteId,
      'profesor_id': profesorId,
      'estado': estado,
      'fecha_solicitud': fechaSolicitud.toIso8601String(),
    };
  }
}
