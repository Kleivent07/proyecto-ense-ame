import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../BackEnd/custom/configuration.dart';
import '../BackEnd/util/constants.dart';
import 'package:image/image.dart' as img;
import 'package:my_app/src/BackEnd/services/notifications_service.dart';
import 'package:my_app/src/models/profesores_model.dart';
import 'package:my_app/src/models/estudiantes_model.dart';

class ChatModel {
  final SupabaseClient _client = Supabase.instance.client;
  Timer? _pollTimer;
  String? _lastCreatedAt;
  String? _currentSolicitudId;
  DateTime? _lastNotifyAt;
  String? _lastNotifiedMessageId;
  bool _isForeground = true;

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

  // ✨ MÉTODO DISPOSE MEJORADO
  void dispose() {
    try {
      _pollTimer?.cancel();
      _pollTimer = null;
      _currentSolicitudId = null;
      print('[CHAT] 🧹 Recursos limpiados correctamente');
    } catch (e) {
      print('[CHAT] ⚠️ Error limpiando recursos: $e');
    }
  }

  // ✨ MÉTODO FALTANTE: Establecer solicitud actual
  void setSolicitudActual(String solicitudId) {
    _currentSolicitudId = solicitudId;
    print('[CHAT] 📝 Solicitud actual establecida: $solicitudId');
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
        'created_at': solicitudData['fecha_solicitud'],
        'is_initial': true, // ← nuevo
      };

      await _client.from('chat_messages').insert(messageData);
          
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
  Future<void> startPolling(
  String solicitudId,
  void Function(Map<String, dynamic>) onNewMessage,
  {Duration interval = const Duration(seconds: 3)}
) async {
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

      // Emitir solo mensajes nuevos con nombres y mostrar notificación
      for (var messageData in messages.reversed) {
        final message = _safeMap(messageData);
        final created = message['created_at']?.toString();
        if (created != null && _lastCreatedAt != null && created.compareTo(_lastCreatedAt!) > 0) {
          final senderId = message['sender_id']?.toString();
          final currentUserId = _client.auth.currentUser?.id;
          if (senderId != null && senderId.isNotEmpty) {
            message['sender_name'] = await _getUserName(senderId);

            // Solo mostrar notificación si el mensaje NO lo envió el usuario actual
            if (currentUserId != null && senderId != currentUserId) {
              String tipoRemitente = 'estudiante'; // Por defecto
              final solicitudData = await loadSolicitudData(solicitudId);
              if (solicitudData != null) {
                if (senderId == solicitudData['profesor_id']?.toString()) {
                  tipoRemitente = 'profesor';
                } else if (senderId == solicitudData['estudiante_id']?.toString()) {
                  tipoRemitente = 'estudiante';
                }
              }

              final id = message['id']?.toString();
              final isInitial = message['is_initial'] == true;
              final now = DateTime.now();
              final inCooldown = _lastNotifyAt != null && now.difference(_lastNotifyAt!) < const Duration(seconds: 10);

              if (id == null || isInitial || senderId == currentUserId || inCooldown || id == _lastNotifiedMessageId) {
                // no notificar
              } else if (!_isForeground) {
                // Determinar tipoRemitente como ya haces y avisar
                await mostrarNotificacionMensajeNuevo(senderId, tipoRemitente);
                _lastNotifiedMessageId = id;
                _lastNotifyAt = now;
              }
            }
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

  // Subir archivos y guardarlos también en documentos - VERSIÓN OPTIMIZADA
  Future<List<Map<String, dynamic>>?> uploadFiles(
    List<PlatformFile> files, {
    Function(int current, int total, String fileName)? onProgress,
  }) async {
    try {
      print('[CHAT] 🚀 Iniciando subida OPTIMIZADA de ${files.length} archivo(s)');
      
      // ✨ 1. VALIDACIÓN RÁPIDA PRIMERO
      final validFiles = files.where((f) => 
        f.bytes != null || f.path != null).toList();
      
      if (validFiles.isEmpty) {
        throw Exception('No hay archivos válidos para subir');
      }
      
      // ✨ 2. OBTENER INFO DE SOLICITUD UNA SOLA VEZ
      String? profesorId;
      String? estudianteId;
      
      if (_currentSolicitudId != null) {
        try {
          final solicitudInfo = await _client
              .from('solicitudes_tutorias')
              .select('profesor_id, estudiante_id')
              .eq('id', _currentSolicitudId!)
              .single();
          
          profesorId = solicitudInfo['profesor_id'];
          estudianteId = solicitudInfo['estudiante_id'];
          print('[CHAT] 📋 Info solicitud - Profesor: $profesorId, Estudiante: $estudianteId');
        } catch (e) {
          print('[CHAT] ⚠️ Error obteniendo info de solicitud: $e');
        }
      }
      
      // ✨ 3. SUBIDA EN LOTES (PARALELA)
      const batchSize = 3; // Subir máximo 3 archivos en paralelo
      final List<Map<String, dynamic>> allUploaded = [];
      
      for (int i = 0; i < validFiles.length; i += batchSize) {
        final batch = validFiles.skip(i).take(batchSize).toList();
        
        // Subir lote en paralelo
        final futures = batch.asMap().entries.map((entry) async {
          final index = i + entry.key;
          final file = entry.value;
          
          // ✨ CALLBACK DE PROGRESO
          onProgress?.call(index + 1, validFiles.length, file.name);
          
          return await _uploadSingleFileOptimized(
            file, 
            profesorId, 
            estudianteId,
          );
        });
        
        final batchResults = await Future.wait(futures);
        allUploaded.addAll(batchResults.where((r) => r != null).cast<Map<String, dynamic>>());
      }
      
      print('[CHAT] ✅ Subida completada: ${allUploaded.length}/${validFiles.length} archivos');
      return allUploaded.isNotEmpty ? allUploaded : null;
      
    } catch (e) {
      print('[CHAT] ❌ Error en subida optimizada: $e');
      rethrow;
    }
  }

  // ✨ MÉTODO AUXILIAR NUEVO: Subir archivo individual optimizado
  Future<Map<String, dynamic>?> _uploadSingleFileOptimized(
    PlatformFile file,
    String? profesorId,
    String? estudianteId,
  ) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // 1. Obtener bytes del archivo
      final Uint8List bytes = file.bytes ?? await File(file.path!).readAsBytes();
      
      // 2. Comprimir si es necesario (imágenes)
      final compressedBytes = await _compressFileIfNeeded(file, bytes);
      
      // 3. Generar nombre único optimizado
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final userId = _client.auth.currentUser?.id ?? 'anonymous';
      final extension = file.name.split('.').last.toLowerCase();
      final baseName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final uniqueName = '${timestamp}_${baseName}';
      final storagePath = 'chat_files/${userId}/$uniqueName';
      
      // 4. Subir con configuración optimizada
      await _client.storage
          .from(Constants.bucketAvatar) // Usar bucket existente por ahora
          .uploadBinary(
            storagePath, 
            compressedBytes, 
            fileOptions: FileOptions(
              contentType: _getFileTypeByExtension(extension),
              cacheControl: '31536000', // Cache 1 año
              upsert: false, // No sobrescribir (más rápido)
            )
          );

      // 5. Generar URL pública
      final publicUrl = _client.storage
          .from(Constants.bucketAvatar)
          .getPublicUrl(storagePath);
    
      final fileData = {
        'name': file.name,
        'url': publicUrl,
        'size': compressedBytes.length,
        'type': extension,
        'storage_path': storagePath,
        'original_size': file.size,
        'upload_time_ms': stopwatch.elapsedMilliseconds,
      };
    
      // 6. Guardar en documentos (en background)
      if (profesorId != null && estudianteId != null) {
        // ✨ NO ESPERAR - EJECUTAR EN BACKGROUND
        _guardarArchivoComoDocumento(
          profesorId: profesorId,
          estudianteId: estudianteId,
          nombreArchivo: file.name,
          urlArchivo: publicUrl,
          tipoArchivo: extension,
          tamano: compressedBytes.length,
        ).catchError((error) {
          print('[CHAT] ⚠️ Error guardando en documentos (background): $error');
        });
      }
      
      stopwatch.stop();
      print('[CHAT] ⚡ Archivo ${file.name} subido en ${stopwatch.elapsedMilliseconds}ms');
      
      return fileData;
      
    } catch (e) {
      print('[CHAT] ❌ Error subiendo ${file.name}: $e');
      return null;
    }
  }

  // ✨ NUEVA FUNCIÓN: Comprimir archivos si es necesario - MEJORADA
  Future<Uint8List> _compressFileIfNeeded(PlatformFile file, Uint8List originalBytes) async {
    final extension = file.name.split('.').last.toLowerCase();
    final originalSizeMB = originalBytes.length / (1024 * 1024);
    
    print('[CHAT] 📏 Archivo: ${file.name}');
    print('[CHAT] 📊 Tamaño: ${originalSizeMB.toStringAsFixed(2)} MB');
    
    // ✨ LÍMITES MEJORADOS Y MÁS REALISTAS
    const maxPdfSizeMB = 25; // 25MB para PDFs (más realista)
    const maxImageSizeMB = 15; // 15MB para imágenes  
    const maxVideoSizeMB = 50; // 50MB para videos
    const maxOtherSizeMB = 20; // 20MB para otros archivos
    
    // Validar límites según tipo de archivo
    switch (extension.toLowerCase()) {
      case 'pdf':
        if (originalSizeMB > maxPdfSizeMB) {
          throw Exception('Archivo PDF muy grande (máximo ${maxPdfSizeMB}MB, actual: ${originalSizeMB.toStringAsFixed(1)}MB)');
        }
        break;
        
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'bmp':
      case 'gif':
      case 'webp':
        if (originalSizeMB > maxImageSizeMB) {
          // ✨ INTENTAR COMPRIMIR IMÁGENES GRANDES
          try {
            print('[CHAT] 🖼️ Comprimiendo imagen grande...');
            final compressedBytes = await _compressImage(originalBytes, extension);
            final compressedSizeMB = compressedBytes.length / (1024 * 1024);
            
            if (compressedSizeMB <= maxImageSizeMB) {
              print('[CHAT] ✅ Imagen comprimida: ${originalSizeMB.toStringAsFixed(2)}MB → ${compressedSizeMB.toStringAsFixed(2)}MB');
              return compressedBytes;
            } else {
              throw Exception('Imagen muy grande incluso después de comprimir (máximo ${maxImageSizeMB}MB)');
            }
          } catch (e) {
            print('[CHAT] ⚠️ Error comprimiendo imagen: $e');
            throw Exception('Imagen muy grande (máximo ${maxImageSizeMB}MB, actual: ${originalSizeMB.toStringAsFixed(1)}MB)');
          }
        }
        break;
        
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        if (originalSizeMB > maxVideoSizeMB) {
          throw Exception('Video muy grande (máximo ${maxVideoSizeMB}MB, actual: ${originalSizeMB.toStringAsFixed(1)}MB)');
        }
        break;
        
      default:
        if (originalSizeMB > maxOtherSizeMB) {
          throw Exception('Archivo muy grande (máximo ${maxOtherSizeMB}MB, actual: ${originalSizeMB.toStringAsFixed(1)}MB)');
        }
        break;
    }
    
    return originalBytes;
  }

  // ✨ NUEVA FUNCIÓN: Comprimir imágenes usando la librería image
  Future<Uint8List> _compressImage(Uint8List originalBytes, String extension) async {
    try {
      final image = img.decodeImage(originalBytes);
      if (image == null) {
        throw Exception('No se puede decodificar la imagen');
      }
      
      // Calcular nuevo tamaño manteniendo proporción
      int newWidth = image.width;
      int newHeight = image.height;
      
      // Si es muy grande, redimensionar
      const maxDimension = 1920;
      if (image.width > maxDimension || image.height > maxDimension) {
        if (image.width > image.height) {
          newWidth = maxDimension;
          newHeight = (image.height * maxDimension / image.width).round();
        } else {
          newHeight = maxDimension;
          newWidth = (image.width * maxDimension / image.height).round();
        }
      }
      
      // Redimensionar si es necesario
      img.Image resizedImage = image;
      if (newWidth != image.width || newHeight != image.height) {
        resizedImage = img.copyResize(image, width: newWidth, height: newHeight);
        print('[CHAT] 📐 Redimensionado: ${image.width}x${image.height} → ${newWidth}x${newHeight}');
      }
      
      // Comprimir con diferentes calidades según el tamaño original
      int quality = 85;
      final originalSizeMB = originalBytes.length / (1024 * 1024);
      
      if (originalSizeMB > 10) quality = 70;
      if (originalSizeMB > 15) quality = 60;
      if (originalSizeMB > 20) quality = 50;
      
      // Comprimir a JPEG (más eficiente)
      final compressedBytes = img.encodeJpg(resizedImage, quality: quality);
      
      print('[CHAT] 🗜️ Compresión aplicada con calidad: $quality%');
      return Uint8List.fromList(compressedBytes);
      
    } catch (e) {
      print('[CHAT] ❌ Error en compresión de imagen: $e');
      rethrow;
    }
  }

  // ✨ MÉTODO FALTANTE: Obtener tipo MIME por extensión
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
      case 'bmp':
        return 'image/bmp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      default:
        return 'application/octet-stream';
    }
  }

  // ✨ MÉTODO FALTANTE: Guardar archivo como documento
  Future<void> _guardarArchivoComoDocumento({
    required String profesorId,
    required String estudianteId,
    required String nombreArchivo,
    required String urlArchivo,
    required String tipoArchivo,
    required int tamano,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        print('[CHAT] ❌ No hay usuario autenticado para guardar documento');
        return;
      }

      // Determinar emisor y receptor
      String emisorId = userId;
      String receptorId = userId == estudianteId ? profesorId : estudianteId;

      print('[CHAT] 💾 Guardando documento: $nombreArchivo');
      print('[CHAT] 📤 Emisor: $emisorId, Receptor: $receptorId');

      // Insertar en la tabla documentos_compartidos
      await _client.from('documentos_compartidos').insert({
        'emisor_id': emisorId,
        'receptor_id': receptorId,
        'solicitud_id': _currentSolicitudId,
        'nombre_archivo': nombreArchivo,
        'url_archivo': urlArchivo,
        'descripcion': 'Archivo enviado desde el chat',
        'tipo_archivo': tipoArchivo,
        'tamano': tamano,
        'visto': false,
        'fecha_subida': DateTime.now().toIso8601String(),
      });

      print('[CHAT] ✅ Documento guardado exitosamente');
    } catch (e) {
      print('[CHAT] ❌ Error guardando documento: $e');
    }
  }

  // Ejemplo en chat_page.dart o donde recibes el mensaje
  Future<void> mostrarNotificacionMensajeNuevo(String remitenteId, String tipoRemitente) async {
  String nombre = 'Usuario';

  if (tipoRemitente == 'profesor' || tipoRemitente == 'tutor') {
    final perfil = await ProfesorService().obtenerProfesor(remitenteId);
    if (perfil != null) {
      nombre = '${perfil['nombre'] ?? ''} ${perfil['apellido'] ?? ''}'.trim();
    }
  } else if (tipoRemitente == 'estudiante') {
    final perfil = await EstudianteService().obtenerEstudiante(remitenteId);
    if (perfil != null) {
      nombre = '${perfil['nombre'] ?? ''} ${perfil['apellido'] ?? ''}'.trim();
    }
  }

  // Notificación con tipo y referencia
  await NotificationsService.showNotification(
    title: 'Mensaje nuevo',
    body: 'Mensaje nuevo de $nombre',
    userId: _client.auth.currentUser?.id, // ← destinatario: el usuario actual (receptor)
    tipo: 'chat',
    referenciaId: _currentSolicitudId,
  );
}
}
