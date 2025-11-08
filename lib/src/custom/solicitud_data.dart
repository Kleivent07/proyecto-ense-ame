class SolicitudData {
  final String id;
  final String estudianteId;
  final String profesorId;
  final String estado;
  final DateTime fechaSolicitud;
  final String nombreTutor;
  final String nombreEstudiante;
  final String mensaje; // <-- nuevo

  SolicitudData({
    this.id = '',
    required this.estudianteId,
    required this.profesorId,
    this.estado = 'none',
    DateTime? fechaSolicitud,
    this.nombreTutor = '',
    this.nombreEstudiante = '',
    this.mensaje = '', // <-- nuevo
  }) : fechaSolicitud = fechaSolicitud ?? DateTime.now();

  /// Crea una instancia desde un Map (tolerante a distintos shapes).
  factory SolicitudData.fromMap(Map<String, dynamic> map) {
    String parseName(Map<String, dynamic>? node) {
      if (node == null) return '';
      final usuarios = node['usuarios'] is Map ? node['usuarios'] as Map<String, dynamic> : node;
      final nombre = (usuarios['nombre'] ?? '')?.toString();
      final apellido = (usuarios['apellido'] ?? '')?.toString();
      final full = '$nombre $apellido'.trim();
      return full;
    }

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      try {
        final s = v.toString();
        final dt = DateTime.tryParse(s);
        if (dt != null) return dt;
      } catch (_) {}
      return DateTime.now();
    }

    final estudianteId = (map['estudiante_id'] ?? map['estudianteId'] ?? map['estudiante']?['id'] ?? '')?.toString() ?? '';
    final profesorId = (map['profesor_id'] ?? map['profesorId'] ?? map['profesor']?['id'] ?? '')?.toString() ?? '';
    final estado = (map['estado'] ?? '')?.toString() ?? '';
    final fecha = parseDate(map['fecha_solicitud'] ?? map['created_at'] ?? map['fecha'] ?? map['fechaSolicitud']);
    final nombreTutor = parseName(map['tutor'] as Map<String, dynamic>? ?? map['profesor'] as Map<String, dynamic>?);
    final nombreEstudiante = parseName(map['estudiante'] as Map<String, dynamic>?);

    final mensaje = (map['mensaje'] ?? map['message'] ?? '')?.toString() ?? '';

    return SolicitudData(
      id: (map['id'] ?? '')?.toString() ?? '',
      estudianteId: estudianteId,
      profesorId: profesorId,
      estado: estado.isEmpty ? 'none' : estado,
      fechaSolicitud: fecha,
      nombreTutor: nombreTutor,
      nombreEstudiante: nombreEstudiante,
      mensaje: mensaje,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'estudiante_id': estudianteId,
      'profesor_id': profesorId,
      'estado': estado,
      'fecha_solicitud': fechaSolicitud.toIso8601String(),
      'nombre_tutor': nombreTutor,
      'nombre_estudiante': nombreEstudiante,
      'mensaje': mensaje, // <-- nuevo
    };
  }

  String toJson() => toMap().toString();

  SolicitudData copyWith({
    String? id,
    String? estudianteId,
    String? profesorId,
    String? estado,
    DateTime? fechaSolicitud,
    String? nombreTutor,
    String? nombreEstudiante,
    String? mensaje, // <-- nuevo
  }) {
    return SolicitudData(
      id: id ?? this.id,
      estudianteId: estudianteId ?? this.estudianteId,
      profesorId: profesorId ?? this.profesorId,
      estado: estado ?? this.estado,
      fechaSolicitud: fechaSolicitud ?? this.fechaSolicitud,
      nombreTutor: nombreTutor ?? this.nombreTutor,
      nombreEstudiante: nombreEstudiante ?? this.nombreEstudiante,
      mensaje: mensaje ?? this.mensaje,
    );
  }

  @override
  String toString() {
    return 'SolicitudData(id: $id, estudianteId: $estudianteId, profesorId: $profesorId, estado: $estado, fechaSolicitud: $fechaSolicitud, nombreTutor: $nombreTutor, nombreEstudiante: $nombreEstudiante, mensaje: $mensaje)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SolicitudData &&
        other.id == id &&
        other.estudianteId == estudianteId &&
        other.profesorId == profesorId &&
        other.estado == estado &&
        other.fechaSolicitud == fechaSolicitud &&
        other.nombreTutor == nombreTutor &&
        other.nombreEstudiante == nombreEstudiante &&
        other.mensaje == mensaje;
  }

  @override
  int get hashCode {
    return Object.hash(id, estudianteId, profesorId, estado, fechaSolicitud, nombreTutor, nombreEstudiante, mensaje);
  }
}

