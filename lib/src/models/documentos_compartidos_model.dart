import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class DocumentoCompartido {
  final String id;
  final String emisorId;
  final String receptorId;
  final String? solicitudId;
  final String nombreArchivo;
  final String urlArchivo;
  final String? descripcion;
  final String tipoArchivo;
  final int tamano;
  final DateTime fechaSubida;
  final bool visto;
  final String? emisorNombre;
  final String? receptorNombre;

  DocumentoCompartido({
    required this.id,
    required this.emisorId,
    required this.receptorId,
    this.solicitudId,
    required this.nombreArchivo,
    required this.urlArchivo,
    this.descripcion,
    required this.tipoArchivo,
    required this.tamano,
    required this.fechaSubida,
    required this.visto,
    this.emisorNombre,
    this.receptorNombre,
  });

  factory DocumentoCompartido.fromMap(Map<String, dynamic> map) {
    return DocumentoCompartido(
      id: map['id']?.toString() ?? '',
      emisorId: map['emisor_id']?.toString() ?? '',
      receptorId: map['receptor_id']?.toString() ?? '',
      solicitudId: map['solicitud_id']?.toString(),
      nombreArchivo: map['nombre_archivo']?.toString() ?? '',
      urlArchivo: map['url_archivo']?.toString() ?? '',
      descripcion: map['descripcion']?.toString(),
      tipoArchivo: map['tipo_archivo']?.toString() ?? '',
      tamano: map['tamano'] ?? 0,
      fechaSubida: DateTime.parse(map['fecha_subida'] ?? DateTime.now().toIso8601String()),
      visto: map['visto'] ?? false,
      emisorNombre: map['emisor_nombre']?.toString(),
      receptorNombre: map['receptor_nombre']?.toString(),
    );
  }
}

class ConversacionDocumentos {
  final String otroUsuarioId;
  final String otroUsuarioNombre;
  final String? solicitudId;
  final List<DocumentoCompartido> documentos;
  final int documentosNoVistos;
  final DocumentoCompartido? ultimoDocumento;

  ConversacionDocumentos({
    required this.otroUsuarioId,
    required this.otroUsuarioNombre,
    this.solicitudId,
    required this.documentos,
    required this.documentosNoVistos,
    this.ultimoDocumento,
  });
}

class DocumentosCompartidosModel {
  final SupabaseClient _client = Supabase.instance.client;

  // 📋 OBTENER CONVERSACIONES DE DOCUMENTOS (COMO WHATSAPP)
  Future<List<ConversacionDocumentos>> obtenerConversacionesDocumentos() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      // Obtener todas las solicitudes activas del usuario
      final solicitudes = await _client
          .from('solicitudes_tutorias')
          .select('id, estudiante_id, profesor_id')
          .eq('estado', 'aceptada')
          .or('estudiante_id.eq.$userId,profesor_id.eq.$userId');

      final conversaciones = <ConversacionDocumentos>[];

      for (final solicitud in solicitudes) {
        final estudianteId = solicitud['estudiante_id'].toString();
        final profesorId = solicitud['profesor_id'].toString();
        final solicitudId = solicitud['id'].toString();
        
        // Determinar quién es el "otro usuario"
        final otroUsuarioId = userId == estudianteId ? profesorId : estudianteId;
        
        // Obtener nombre del otro usuario
        final otroUsuario = await _client
            .from('usuarios')
            .select('nombre, apellido')
            .eq('id', otroUsuarioId)
            .maybeSingle();
        
        final nombre = otroUsuario?['nombre'] ?? '';
        final apellido = otroUsuario?['apellido'] ?? '';
        final otroUsuarioNombre = '$nombre $apellido'.trim();

        // Obtener documentos de esta conversación
        final documentosRaw = await _client
            .from('documentos_compartidos')
            .select('*')
            .eq('solicitud_id', solicitudId)
            .order('fecha_subida', ascending: false);

        final documentos = documentosRaw
            .map((doc) => DocumentoCompartido.fromMap(doc))
            .toList();

        // Contar documentos no vistos
        final noVistos = documentos
            .where((doc) => doc.receptorId == userId && !doc.visto)
            .length;

        if (documentos.isNotEmpty || true) { // Mostrar siempre las conversaciones
          conversaciones.add(ConversacionDocumentos(
            otroUsuarioId: otroUsuarioId,
            otroUsuarioNombre: otroUsuarioNombre,
            solicitudId: solicitudId,
            documentos: documentos,
            documentosNoVistos: noVistos,
            ultimoDocumento: documentos.isNotEmpty ? documentos.first : null,
          ));
        }
      }

      return conversaciones;
    } catch (e) {
      debugPrint('[DOCS] Error obteniendo conversaciones: $e');
      return [];
    }
  }

  // 📤 ENVIAR DOCUMENTO
  Future<bool> enviarDocumento({
    required String receptorId,
    required String solicitudId,
    required PlatformFile archivo,
    String? descripcion,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      // Subir archivo al storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = archivo.extension ?? '';
      final cleanName = archivo.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final uniqueName = '${timestamp}_${cleanName}';
      final storagePath = 'documentos_compartidos/$userId/$uniqueName';

      await _client.storage
          .from('documentos')
          .uploadBinary(storagePath, archivo.bytes!);

      // Obtener URL pública
      final publicUrl = _client.storage
          .from('documentos')
          .getPublicUrl(storagePath);

      // Guardar en base de datos
      await _client.from('documentos_compartidos').insert({
        'emisor_id': userId,
        'receptor_id': receptorId,
        'solicitud_id': solicitudId,
        'nombre_archivo': archivo.name,
        'url_archivo': publicUrl,
        'descripcion': descripcion ?? 'Documento enviado',
        'tipo_archivo': extension,
        'tamano': archivo.size,
        'visto': false,
      });

      return true;
    } catch (e) {
      debugPrint('[DOCS] Error enviando documento: $e');
      return false;
    }
  }

  // 👁️ MARCAR DOCUMENTOS COMO VISTOS
  Future<void> marcarDocumentosComoVistos(String solicitudId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client
          .from('documentos_compartidos')
          .update({'visto': true})
          .eq('solicitud_id', solicitudId)
          .eq('receptor_id', userId)
          .eq('visto', false);
    } catch (e) {
      debugPrint('[DOCS] Error marcando como vistos: $e');
    }
  }

  // 📊 OBTENER DOCUMENTOS DE UNA CONVERSACIÓN ESPECÍFICA
  Future<List<DocumentoCompartido>> obtenerDocumentosConversacion(String solicitudId) async {
    try {
      final documentosRaw = await _client
          .from('documentos_compartidos')
          .select('*')
          .eq('solicitud_id', solicitudId)
          .order('fecha_subida', ascending: true);

      return documentosRaw
          .map((doc) => DocumentoCompartido.fromMap(doc))
          .toList();
    } catch (e) {
      debugPrint('[DOCS] Error obteniendo documentos de conversación: $e');
      return [];
    }
  }
}