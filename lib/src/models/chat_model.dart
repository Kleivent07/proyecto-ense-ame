import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../BackEnd/custom/configuration.dart';
import '../BackEnd/util/constants.dart'; // ✨ IMPORTAR CONSTANTES

class ChatModel {
  final SupabaseClient _client = Supabase.instance.client;
  Timer? _pollTimer;
  String? _lastCreatedAt;
  String? _currentSolicitudId;

  // Helper para conversión segura de tipos
  Map<String, dynamic> _safeMap(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  List<Map<String, dynamic>> _safeMapList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((item) => _safeMap(item)).toList();
    }
    return [];
  }

  // Verificar acceso a la solicitud
  Future<bool> hasAccessToSolicitud(String solicitudId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await _client
          .from('solicitudes_tutorias')
          .select('id, estado, estudiante_id, profesor_id')
          .eq('id', solicitudId)
          .eq('estado', 'aceptada')
          .maybeSingle();

      if (response == null) return false;
      
      final data = _safeMap(response);
      final estudiante = data['estudiante_id'];
      final profesor = data['profesor_id'];
      
      return (user.id == estudiante || user.id == profesor);
    } catch (e) {
      print('[CHAT] Error verificando acceso: $e');
      return false;
    }
  }

  // Obtener nombre del usuario
  Future<String> _getUserName(String userId) async {
    try {
      final response = await _client
          .from('usuarios')
          .select('nombre, apellido')
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null) {
        final data = _safeMap(response);
        final nombre = data['nombre']?.toString() ?? '';
        final apellido = data['apellido']?.toString() ?? '';
        return '$nombre $apellido'.trim();
      }
    } catch (e) {
      print('[CHAT] Error obteniendo nombre de usuario: $e');
    }
    return 'Usuario';
  }

  // Cargar mensajes de una solicitud con nombres de usuarios
  Future<List<Map<String, dynamic>>> loadMessages(String solicitudId, {int limit = 50}) async {
    try {
      final response = await _client
          .from('chat_messages')
          .select('*')
          .eq('solicitud_id', solicitudId)
          .order('created_at', ascending: true)
          .limit(limit);

      final messages = _safeMapList(response);
      
      // Enriquecer mensajes con nombres de usuarios
      for (var message in messages) {
        final senderId = message['sender_id']?.toString();
        if (senderId != null && senderId.isNotEmpty) {
          final userName = await _getUserName(senderId);
          message['sender_name'] = userName;
        }
      }
      
      return messages;
    } catch (e) {
      print('[CHAT] Error cargando mensajes: $e');
      return [];
    }
  }

  // Enviar mensaje
  Future<bool> sendMessage(String solicitudId, String content, {List<Map<String, dynamic>>? attachments}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      print('[CHAT] Usuario no autenticado');
      return false;
    }

    // Verificar acceso primero
    if (!await hasAccessToSolicitud(solicitudId)) {
      print('[CHAT] Sin acceso a la solicitud');
      return false;
    }

    try {
      final messageData = {
        'solicitud_id': solicitudId,
        'sender_id': user.id,
        'content': content,
        'attachments': attachments ?? [],
      };

      final response = await _client
          .from('chat_messages')
          .insert(messageData)
          .select()
          .single();

      final responseData = _safeMap(response);
      print('[CHAT] Mensaje enviado exitosamente: ${responseData['id']}');
      return true;
    } catch (e) {
      print('[CHAT] Error enviando mensaje: $e');
      return false;
    }
  }

  // Crear mensaje inicial con el contenido de la solicitud
  Future<bool> createInitialMessage(String solicitudId) async {
    try {
      // Verificar si ya existe mensaje inicial
      final existing = await _client
          .from('chat_messages')
          .select('id')
          .eq('solicitud_id', solicitudId)
          .limit(1);
          
      final existingList = _safeMapList(existing);
      if (existingList.isNotEmpty) {
        return true; // Ya existe mensaje inicial
      }
      
      // Obtener datos de la solicitud
      final solicitudData = await loadSolicitudData(solicitudId);
      if (solicitudData == null || solicitudData.isEmpty) return false;
      
      final mensaje = solicitudData['mensaje']?.toString() ?? '';
      if (mensaje.isEmpty) return true; // No hay mensaje que mostrar
      
      // Crear mensaje inicial del estudiante
      final estudianteId = solicitudData['estudiante_id']?.toString();
      if (estudianteId == null || estudianteId.isEmpty) return false;
      
      final messageData = {
        'solicitud_id': solicitudId,
        'sender_id': estudianteId,
        'content': '📝 Solicitud inicial: $mensaje',
        'attachments': [],
        'created_at': solicitudData['fecha_solicitud'], // Usar fecha original
      };

      await _client
          .from('chat_messages')
          .insert(messageData);
          
      print('[CHAT] Mensaje inicial creado para solicitud $solicitudId');
      return true;
    } catch (e) {
      print('[CHAT] Error creando mensaje inicial: $e');
      return false;
    }
  }

  // Listar conversaciones con nombres
  Future<List<Map<String, dynamic>>> listConversations() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final solicitudesResponse = await _client
          .from('solicitudes_tutorias')
          .select('id, mensaje, estado, estudiante_id, profesor_id, fecha_solicitud, nombre_estudiante')
          .eq('estado', 'aceptada')
          .or('estudiante_id.eq.${user.id},profesor_id.eq.${user.id}')
          .order('fecha_solicitud', ascending: false);

      final solicitudes = _safeMapList(solicitudesResponse);
      final conversations = <Map<String, dynamic>>[];
      
      for (final solicitudData in solicitudes) {
        final solicitud = _safeMap(solicitudData);
        
        // Obtener nombres de los participantes
        final estudianteId = solicitud['estudiante_id']?.toString() ?? '';
        final profesorId = solicitud['profesor_id']?.toString() ?? '';
        
        String otherUserName = 'Usuario';
        if (user.id == estudianteId && profesorId.isNotEmpty) {
          // Soy estudiante, buscar nombre del profesor
          otherUserName = await _getUserName(profesorId);
        } else if (user.id == profesorId && estudianteId.isNotEmpty) {
          // Soy profesor, buscar nombre del estudiante
          otherUserName = await _getUserName(estudianteId);
        }
        
        // Obtener el último mensaje si existe
        final lastMessageResponse = await _client
            .from('chat_messages')
            .select('id, content, created_at, sender_id')
            .eq('solicitud_id', solicitud['id'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        final lastMessage = lastMessageResponse != null ? _safeMap(lastMessageResponse) : null;

        conversations.add({
          'solicitud': {
            ...solicitud,
            'other_user_name': otherUserName,
          },
          'last_message': lastMessage,
          'room_id': null,
        });
      }

      return conversations;
    } catch (e) {
      print('[CHAT] Error listando conversaciones: $e');
      return [];
    }
  }

  // Cargar datos de la solicitud
  Future<Map<String, dynamic>?> loadSolicitudData(String solicitudId) async {
    try {
      final response = await _client
          .from('solicitudes_tutorias')
          .select('id, estado, estudiante_id, profesor_id, mensaje, fecha_solicitud, nombre_estudiante')
          .eq('id', solicitudId)
          .maybeSingle();

      return response != null ? _safeMap(response) : null;
    } catch (e) {
      print('[CHAT] Error cargando solicitud: $e');
      return null;
    }
  }

  // Polling para nuevos mensajes
  Future<void> startPolling(String solicitudId, void Function(Map<String, dynamic>) onNewMessage,
      {Duration interval = const Duration(seconds: 3)}) async {
    
    if (!await hasAccessToSolicitud(solicitudId)) return;
    
    _currentSolicitudId = solicitudId;
    _lastCreatedAt = null;
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(interval, (_) async {
      try {
        final response = await _client
            .from('chat_messages')
            .select('*')
            .eq('solicitud_id', solicitudId)
            .order('created_at', ascending: false)
            .limit(10);

        final messages = _safeMapList(response);
        
        if (messages.isEmpty) return;
        
        final newest = messages.first['created_at']?.toString();

        // Primera vez: solo establecer timestamp
        if (_lastCreatedAt == null) {
          _lastCreatedAt = newest;
          return;
        }

        // Emitir solo mensajes nuevos con nombres
        for (var messageData in messages.reversed) {
          final message = _safeMap(messageData);
          final created = message['created_at']?.toString();
          if (created != null && _lastCreatedAt != null && created.compareTo(_lastCreatedAt!) > 0) {
            final senderId = message['sender_id']?.toString();
            if (senderId != null && senderId.isNotEmpty) {
              message['sender_name'] = await _getUserName(senderId);
            }
            onNewMessage(message);
          }
        }

        _lastCreatedAt = newest ?? _lastCreatedAt;
      } catch (e) {
        print('[CHAT] Error en polling: $e');
      }
    });
  }

  // Subir archivos (CORREGIR URLs)
  Future<List<Map<String, dynamic>>?> uploadFiles(List<PlatformFile> files) async {
    try {
      final List<Map<String, dynamic>> uploaded = [];
      
      print('[CHAT] 🚀 Iniciando subida de ${files.length} archivo(s)');
      print('[CHAT] 📦 Usando bucket: ${Constants.bucketAvatar}');
      
      for (final file in files) {
        if (file.bytes == null && file.path == null) {
          print('[CHAT] ⚠️ Saltando archivo sin datos: ${file.name}');
          continue;
        }
        
        final Uint8List bytes = file.bytes ?? await File(file.path!).readAsBytes();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final userId = _client.auth.currentUser?.id ?? 'anonymous';
        final extension = file.name.split('.').last.toLowerCase();
        final cleanName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final uniqueName = '${timestamp}_${cleanName}';
        final storagePath = 'chat_files/${userId}/$uniqueName';
        
        print('[CHAT] 📤 Subiendo: ${file.name} (${bytes.length} bytes)');
        print('[CHAT] 📍 Ruta: $storagePath');
        
        try {
          // ✨ SUBIR ARCHIVO CON CONFIGURACIÓN ESPECÍFICA
          await _client.storage
              .from(Constants.bucketAvatar)
              .uploadBinary(
                storagePath, 
                bytes, 
                fileOptions: FileOptions(
                  contentType: _getFileTypeByExtension(extension),
                  cacheControl: '3600',
                  upsert: true, // ✨ PERMITIR SOBRESCRIBIR
                )
              );

          // ✨ GENERAR URL PÚBLICA
          final publicUrl = _client.storage
              .from(Constants.bucketAvatar)
              .getPublicUrl(storagePath);
          
          // ✨ VERIFICAR QUE LA URL FUNCIONA
          print('[CHAT] 🔗 URL generada: $publicUrl');
          
          // ✨ TEST RÁPIDO DE LA URL
          try {
            final testResponse = await http.head(Uri.parse(publicUrl)).timeout(
              const Duration(seconds: 5)
            );
            print('[CHAT] ✅ URL verificada - Status: ${testResponse.statusCode}');
          } catch (testError) {
            print('[CHAT] ⚠️ URL no verificable (pero continuando): $testError');
          }
          
          uploaded.add({
            'name': file.name,
            'url': publicUrl,
            'size': file.size,
            'type': _getFileTypeFromName(file.name),
            'storagePath': storagePath,
            'extension': extension,
          });
          
          print('[CHAT] ✅ Archivo subido: ${file.name}');
          
        } catch (uploadError) {
          print('[CHAT] ❌ Error subiendo ${file.name}: $uploadError');
          
          // ✨ DIAGNOSTICAR ERROR ESPECÍFICO
          final errorStr = uploadError.toString().toLowerCase();
          if (errorStr.contains('bucket') || errorStr.contains('not found')) {
            print('[CHAT] 🚨 ERROR: Bucket "${Constants.bucketAvatar}" no existe o no es accesible');
          } else if (errorStr.contains('permission') || errorStr.contains('unauthorized')) {
            print('[CHAT] 🚨 ERROR: Sin permisos para subir al bucket');
          } else if (errorStr.contains('size') || errorStr.contains('large')) {
            print('[CHAT] 🚨 ERROR: Archivo demasiado grande');
          }
        }
      }
      
      print('[CHAT] 📊 Resumen: ${uploaded.length}/${files.length} archivos subidos');
      return uploaded.isNotEmpty ? uploaded : null;
      
    } catch (e) {
      print('[CHAT] ❌ Error general en uploadFiles: $e');
      return null;
    }
  }

  // ✨ MÉTODO MEJORADO PARA DETERMINAR TIPO DE ARCHIVO
  String _getFileTypeByExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      default:
        return 'application/octet-stream';
    }
  }

  String _getFileTypeFromName(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return 'image';
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        return 'video';
      case 'pdf':
        return 'pdf';
      case 'doc':
      case 'docx':
      case 'xls':
      case 'xlsx':
      case 'ppt':
      case 'pptx':
        return 'document';
      case 'mp3':
      case 'wav':
      case 'flac':
        return 'audio';
      default:
        return 'file';
    }
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _lastCreatedAt = null;
  }

  void dispose() {
    stopPolling();
  }
}
