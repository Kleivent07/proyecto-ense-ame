import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatModel {
  final SupabaseClient _client = Supabase.instance.client;
  Timer? _pollTimer;
  String? _lastCreatedAt;
  String? _currentRoomId;

  dynamic _unwrap(dynamic res) {
    if (res == null) return null;
    try {
      final dyn = (res as dynamic).data;
      if (dyn != null) return dyn;
    } catch (_) {}
    return res;
  }

  // Extrae una URL desde respuestas variadas de Storage (String, Map, etc.)
  String? _extractUrlFromResponse(dynamic resp) {
    if (resp == null) return null;
    if (resp is String) return resp;
    try {
      if (resp is Map) {
        if (resp.containsKey('signedURL')) return resp['signedURL']?.toString();
        if (resp.containsKey('signed_url')) return resp['signed_url']?.toString();
        if (resp.containsKey('signedUrl')) return resp['signedUrl']?.toString();
        if (resp.containsKey('url')) return resp['url']?.toString();
        if (resp.containsKey('data') && resp['data'] is Map) {
          final d = resp['data'] as Map;
          if (d.containsKey('signedURL')) return d['signedURL']?.toString();
          if (d.containsKey('url')) return d['url']?.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  // Devuelve room.id si ya existe (no crea)
  Future<String?> getRoomIfExists(String solicitudId) async {
    try {
      final raw = await _client.from('rooms').select('id').eq('solicitud_id', solicitudId).maybeSingle();
      final data = _unwrap(raw);
      if (data == null) return null;
      if (data is Map && data['id'] != null) return data['id'] as String;
      if (data is List && data.isNotEmpty && data.first['id'] != null) return data.first['id'] as String;
      return null;
    } catch (e, st) {
      print('[CHAT] getRoomIfExists ERROR: $e');
      print(st);
      return null;
    }
  }

  // Crea room para la solicitud (intenta insertar y devuelve id)
  Future<String?> createRoomForSolicitud(String solicitudId) async {
    try {
      final raw = await _client.from('rooms').insert({'solicitud_id': solicitudId}).select();
      final data = _unwrap(raw);
      if (data is List && data.isNotEmpty) {
        final created = Map<String, dynamic>.from(data.first);
        return created['id'] as String?;
      }
      if (data is Map && data['id'] != null) return data['id'] as String?;
      return null;
    } catch (e, st) {
      print('[CHAT] createRoom ERROR: $e');
      print(st);
      rethrow;
    }
  }

  // Verifica acceso y devuelve roomId (crea room si hace falta)
  Future<String?> ensureAccessAndGetRoom(String solicitudId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      print('[CHAT] ensureAccessAndGetRoom: usuario no autenticado');
      return null;
    }

    try {
      final solRaw = await _client
          .from('solicitudes_tutorias')
          .select('id, estado, estudiante_id, profesor_id')
          .eq('id', solicitudId)
          .maybeSingle();

      final solData = _unwrap(solRaw);
      final sol = (solData is Map) ? Map<String, dynamic>.from(solData) : null;
      if (sol == null) {
        print('[CHAT] ensureAccessAndGetRoom: solicitud no encontrada $solicitudId');
        return null;
      }

      final estado = sol['estado'];
      final estudianteId = sol['estudiante_id'];
      final profesorId = sol['profesor_id'];

      final isParticipant = (user.id == estudianteId || user.id == profesorId);
      final isAccepted = (estado == 'aceptada');

      print('[CHAT] ensureAccessAndGetRoom: user=${user.id} estudiante=$estudianteId profesor=$profesorId estado=$estado isParticipant=$isParticipant isAccepted=$isAccepted');

      if (!(isParticipant && isAccepted)) {
        print('[CHAT] ensureAccessAndGetRoom: acceso denegado por rol o estado');
        return null;
      }

      // Buscar room existente
      final roomRaw = await _client.from('rooms').select('id').eq('solicitud_id', solicitudId).maybeSingle();
      final roomData = _unwrap(roomRaw);
      if (roomData != null) {
        if (roomData is Map && roomData['id'] != null) {
          return roomData['id'] as String;
        }
        if (roomData is List && roomData.isNotEmpty && roomData.first['id'] != null) {
          return roomData.first['id'] as String;
        }
      }

      // Crear room si no existe (pedimos la fila creada con .select())
      final insertRaw = await _client.from('rooms').insert({'solicitud_id': solicitudId}).select();
      final insertData = _unwrap(insertRaw);
      if (insertData is List && insertData.isNotEmpty) {
        final created = Map<String, dynamic>.from(insertData.first);
        return created['id'] as String?;
      }
      if (insertData is Map && insertData['id'] != null) {
        return insertData['id'] as String;
      }
    } catch (e, st) {
      print('[CHAT] ensureAccessAndGetRoom ERROR: $e');
      print(st);
      return null;
    }
    return null;
  }

  // Carga mensajes (orden cronológico)
  Future<List<Map<String, dynamic>>> loadMessages(String roomId, {int limit = 50}) async {
    try {
      final raw = await _client
          .from('messages')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(limit);

      final data = _unwrap(raw);
      if (data == null) return [];
      final list = (data is List)
          ? (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : (data is Map ? [Map<String, dynamic>.from(data)] : <Map<String, dynamic>>[]);
      return list.reversed.toList();
    } catch (e, st) {
      print('[CHAT] loadMessages ERROR: $e');
      print(st);
      return [];
    }
  }

  // Start polling: NO emite el backlog (porque loadMessages ya cargó inicialmente)
  Future<void> startPollingBySolicitud(String solicitudId, void Function(Map<String, dynamic>) onNewMessage,
      {Duration interval = const Duration(seconds: 3)}) async {
    final roomId = await ensureAccessAndGetRoom(solicitudId);
    if (roomId == null) return;
    _currentRoomId = roomId;
    _lastCreatedAt = null;
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(interval, (_) async {
      try {
        final raw = await _client
            .from('messages')
            .select()
            .eq('room_id', roomId)
            .order('created_at', ascending: false)
            .limit(20);

        final data = _unwrap(raw);
        if (data == null) return;
        final list = (data is List)
            ? (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : (data is Map ? [Map<String, dynamic>.from(data)] : <Map<String, dynamic>>[]);

        if (list.isEmpty) return;
        final newest = list.first['created_at']?.toString();

        // Si es la primera vez del polling, sólo establecemos _lastCreatedAt para evitar emitir backlog
        if (_lastCreatedAt == null) {
          _lastCreatedAt = newest;
          return;
        }

        // Iterar en orden cronológico y emitir sólo los nuevos
        for (var item in list.reversed) {
          final created = item['created_at']?.toString();
          if (created != null && _lastCreatedAt != null && created.compareTo(_lastCreatedAt!) > 0) {
            onNewMessage(Map<String, dynamic>.from(item));
          }
        }

        // Actualizar último timestamp conocido
        _lastCreatedAt = newest ?? _lastCreatedAt;
      } catch (e, st) {
        print('[CHAT] polling ERROR: $e');
        print(st);
        // ignorar errores de red temporales
      }
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _lastCreatedAt = null;
    _currentRoomId = null;
  }

  void dispose() {
    stopPolling();
  }

  // Enviar mensaje (ahora soporta attachments opcionales)
  Future<bool> sendMessage(String roomId, String content, {List<Map<String, dynamic>>? attachments}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      print('[CHAT] sendMessage: usuario no autenticado');
      return false;
    }
    try {
      final payload = {
        'room_id': roomId,
        'user_id': user.id,
        'content': content,
        'attachments': attachments ?? [],
      };
      final raw = await _client.from('messages').insert(payload).select();
      final data = _unwrap(raw);
      return data != null;
    } catch (e, st) {
      print('[CHAT] sendMessage ERROR: $e');
      print(st);
      return false;
    }
  }

  // Cargar datos de la solicitud (ej. asunto, descripcion, estado, ids)
  Future<Map<String, dynamic>?> loadSolicitudData(String solicitudId) async {
    try {
      final raw = await _client
          .from('solicitudes_tutorias')
          .select('id, estado, estudiante_id, profesor_id, asunto, descripcion, created_at')
          .eq('id', solicitudId)
          .maybeSingle();

      final data = _unwrap(raw);
      if (data == null) return null;
      return Map<String, dynamic>.from(data as Map);
    } catch (e, st) {
      print('[CHAT] loadSolicitudData ERROR: $e');
      print(st);
      return null;
    }
  }

  /// Lista solicitudes en las que participa el usuario. Cada item incluye:
  /// { 'solicitud': Map, 'room_id': String? }
  Future<List<Map<String, dynamic>>> listConversations() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    try {
      // Pedimos todos los campos para evitar fallos por columnas que no existan
      dynamic raw;
      try {
        raw = await _client
            .from('solicitudes_tutorias')
            .select('*') // <- pedir todo en lugar de campos explícitos
            .or('estudiante_id.eq.${user.id},profesor_id.eq.${user.id}');
      } catch (e) {
        print('[CHAT] listConversations: error al pedir *, fallback: $e');
        raw = null;
      }

      final data = _unwrap(raw);
      if (data == null) return [];

      final rows = (data is List) ? data as List : [data];

      // Debug: mostrar keys/columnas que devolvió la consulta (muestra solo la primera fila)
      if (rows.isNotEmpty && rows.first is Map) {
        final keys = (rows.first as Map).keys.toList();
        print('[CHAT] listConversations: columnas recibidas: $keys');
      } else {
        print('[CHAT] listConversations: no hay filas o formato inesperado');
      }

      // Si no vinieron relations anidadas, consultamos rooms por solicitud_id (fallback)
      bool anyHasRooms = rows.any((r) => r is Map && r.containsKey('rooms'));
      Map<String, String> roomMap = {};
      if (!anyHasRooms) {
        final solicitudIds = rows.whereType<Map>().map((r) => r['id']?.toString()).where((id) => id != null).toSet().toList();
        if (solicitudIds.isNotEmpty) {
          final idsString = '(${solicitudIds.map((e) => "'$e'").join(',')})';
          try {
            final roomsRaw = await _client
                .from('rooms')
                .select('id, solicitud_id')
                .filter('solicitud_id', 'in', idsString);
            final roomsData = _unwrap(roomsRaw);
            if (roomsData is List) {
              for (var r in roomsData) {
                try {
                  final Map m = r as Map;
                  final sid = m['solicitud_id']?.toString();
                  final rid = m['id']?.toString();
                  if (sid != null && rid != null) roomMap[sid] = rid;
                } catch (_) {}
              }
            }
          } catch (e) {
            print('[CHAT] listConversations: fallback rooms query falló: $e');
          }
        }
      }

      final List<Map<String, dynamic>> out = [];
      for (var r in rows) {
        if (r is Map) {
          final Map<String, dynamic> sol = Map<String, dynamic>.from(r);
          String? roomId;
          try {
            final rooms = sol['rooms'];
            if (rooms is List && rooms.isNotEmpty && rooms.first != null && rooms.first['id'] != null) {
              roomId = rooms.first['id']?.toString();
            } else if (rooms is Map && rooms['id'] != null) {
              roomId = rooms['id']?.toString();
            } else {
              final sid = sol['id']?.toString();
              if (sid != null && roomMap.containsKey(sid)) roomId = roomMap[sid];
            }
          } catch (_) {
            final sid = sol['id']?.toString();
            if (sid != null && roomMap.containsKey(sid)) roomId = roomMap[sid];
          }
          out.add({'solicitud': sol, 'room_id': roomId});
        }
      }
      print('[CHAT] listConversations: items=${out.length}');
      return out;
    } catch (e, st) {
      print('[CHAT] listConversations ERROR: $e');
      print(st);
      return [];
    }
  }

  /// Sube archivos al bucket 'chat_files' y devuelve lista con { name, url, path } o null si falla.
  Future<List<Map<String, dynamic>>?> uploadFiles(List<PlatformFile> files) async {
    if (files.isEmpty) return [];
    final bucket = _client.storage.from('chat_files');
    final List<Map<String, dynamic>> uploaded = [];
    try {
      for (final f in files) {
        // obtener bytes: preferimos PlatformFile.bytes por compatibilidad con web/móvil
        final bytesList = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
        if (bytesList == null) {
          print('[CHAT] no hay bytes para ${f.name}');
          continue;
        }
        final Uint8List bytes = Uint8List.fromList(bytesList);
        final path = 'chats/${DateTime.now().millisecondsSinceEpoch}_${f.name}';

        var uploadOk = false;
        try {
          // 1) intento preferido: uploadBinary(path, Uint8List)
          final maybe = _client.storage.from('chat_files').uploadBinary(path, bytes);
          final res = await Future.value(maybe);
          print('[CHAT] uploadBinary response for $path: $res');
          uploadOk = true;
        } catch (e) {
          print('[CHAT] uploadBinary failed for $path: $e');
          // 2) fallback: upload with File (if we have a file path)
          if (f.path != null) {
            try {
              final maybe2 = _client.storage.from('chat_files').upload(path, File(f.path!));
              final res2 = await Future.value(maybe2);
              print('[CHAT] upload(File) response for $path: $res2');
              uploadOk = true;
            } catch (e2) {
              print('[CHAT] upload(File) failed for $path: $e2');
              uploadOk = false;
            }
          }
        }

        if (!uploadOk) {
          print('[CHAT] No se pudo subir ${f.name}');
          continue;
        }

        // Intentar crear signed URL — ojo: este SDK espera un int "days"
        dynamic maybeSigned;
        try {
          maybeSigned = bucket.createSignedUrl(path, 7); // <-- pasar int días (ej. 7)
        } catch (e) {
          print('[CHAT] createSignedUrl no disponible o falló para $path: $e');
          maybeSigned = null;
        }

        final signedResp = maybeSigned != null ? await Future.value(maybeSigned) : null;
        String? url = _extractUrlFromResponse(signedResp);

        // fallback público si no hay signed url
        if (url == null) {
          try {
            dynamic maybePub = bucket.getPublicUrl(path);
            final pubResp = await Future.value(maybePub);
            url = _extractUrlFromResponse(pubResp);
          } catch (e) {
            print('[CHAT] getPublicUrl falló para $path: $e');
          }
        }

        if (url != null && url.isNotEmpty) {
          uploaded.add({'name': f.name, 'url': url, 'path': path});
        } else {
          // si falla extraer url, igualmente guardamos path (útil para server-side signing)
          uploaded.add({'name': f.name, 'url': '', 'path': path});
        }
      }
      return uploaded;
    } catch (e, st) {
      print('[CHAT] uploadFiles ERROR: $e');
      print(st);
      return null;
    }
  }

  /// Intenta subir bytes al bucket 'chat_files', intentando varias firmas
  /// para incluir metadata {'user_id': <uid>} si la SDK lo soporta.
  /// Devuelve true si la subida fue aparentemente exitosa.
  Future<bool> _tryUploadWithMetadata(String path, Uint8List bytes, String fileName) async {
    final bucket = _client.storage.from('chat_files');
    final user = _client.auth.currentUser;
    final userId = user?.id ?? '';

    try {
      // 1) Intento: uploadBinary con FileOptions (metadata si la SDK lo soporta)
      try {
        print('[CHAT] intentando uploadBinary con FileOptions (firma1)');
        final maybe = bucket.uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'application/octet-stream',
            // metadata puede no estar disponible en todas las versiones de la SDK.
            // Si da error de parámetro desconocido, eliminar la línea `metadata: {...}`.
            metadata: {'user_id': userId},
          ),
        );
        final res = await Future.value(maybe);
        print('[CHAT] uploadBinary respuesta: $res');
        return true;
      } catch (e1) {
        print('[CHAT] uploadBinary firma1 falló: $e1');
      }

      // 2) Intento alternativo (misma idea, prueba otra firma si existe)
      try {
        print('[CHAT] intentando uploadBinary con FileOptions (firma2)');
        final maybe = bucket.uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'application/octet-stream',
            metadata: {'user_id': userId},
          ),
        );
        final res = await Future.value(maybe);
        print('[CHAT] uploadBinary respuesta firma2: $res');
        return true;
      } catch (e2) {
        print('[CHAT] uploadBinary firma2 falló: $e2');
      }

      // 3) Intento: upload(path, bytes, fileOptions: ...)
      try {
        print('[CHAT] intentando bucket.upload(path, bytes, fileOptions)');
        // Save bytes to a temporary file and upload as File
        final tempDir = Directory.systemTemp;
        final tempFile = await File('${tempDir.path}/$fileName').writeAsBytes(bytes);
        final maybe = bucket.upload(
          path,
          tempFile,
          fileOptions: FileOptions(
            contentType: 'application/octet-stream',
            metadata: {'user_id': userId},
          ),
        );
        final res = await Future.value(maybe);
        print('[CHAT] upload (bytes) respuesta: $res');
        return true;
      } catch (e3) {
        print('[CHAT] upload(path, bytes, fileOptions) falló: $e3');
      }

      // 4) Intento: subir File (si tienes path en disco) con fileOptions
      try {
        // si entramos aquí, creamos un archivo temporal con los bytes para usar la sobrecarga que recibe File
        final tempDir = await Directory.systemTemp.createTemp('chat_upload_');
        final tempFilePath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName';
        final tempFile = File(tempFilePath);
        await tempFile.writeAsBytes(bytes);

        try {
          print('[CHAT] intentando bucket.upload(path, File, fileOptions) usando tempFile: $tempFilePath');
          final maybe = bucket.upload(
            path,
            tempFile,
            // use FileOptions si tu SDK lo soporta; quita `metadata:` si tu versión arroja error
            fileOptions: FileOptions(
              contentType: 'application/octet-stream',
              metadata: {'user_id': userId},
            ),
          );
          final res = await Future.value(maybe);
          print('[CHAT] upload(file) respuesta: $res');
          return true;
        } catch (e4) {
          print('[CHAT] upload(path, File, fileOptions) falló: $e4');
        } finally {
          // limpiar archivo y carpeta temporal
          try {
            if (await tempFile.exists()) await tempFile.delete();
            if (await tempDir.exists()) await tempDir.delete();
          } catch (_) {}
        }
      } catch (eTemp) {
        print('[CHAT] error creando temp file para upload: $eTemp');
      }

      // 5) Fallback: intentar sin metadata (asegurarnos de que la subida funciona)
      try {
        print('[CHAT] Intentando upload sin metadata (fallback)');
        try {
          final maybe = bucket.uploadBinary(path, bytes);
          final res = await Future.value(maybe);
          print('[CHAT] uploadBinary fallback ok: $res');
          return true;
        } catch (_) {
          try {
            // Save bytes to a temporary file and upload as File
            final tempDir = Directory.systemTemp;
            final tempFile = await File('${tempDir.path}/temp_upload_${DateTime.now().millisecondsSinceEpoch}').writeAsBytes(bytes);
            final maybe2 = bucket.upload(path, tempFile);
            final res2 = await Future.value(maybe2);
            print('[CHAT] upload fallback bytes ok: $res2');
            return true;
          } catch (e5) {
            print('[CHAT] upload fallback bytes falló: $e5');
          }
        }
      } catch (ef) {
        print('[CHAT] fallback global falló: $ef');
      }
    } catch (finalOuter) {
      print('[CHAT] error inesperado en _tryUploadWithMetadata: $finalOuter');
    }

    // si llegamos aquí, todo falló
    return false;
  }

  /// Después de que uploadBinary/upload haya devuelto OK y tengas `path`
  /// bucket ya definido: final bucket = _client.storage.from('chat_files');
  ///
  /// Intenta obtener una signed URL (7 días) y, si falla, una public URL.
  /// Devuelve true si al menos una URL válida fue obtenida y registrada en el attachment.
  Future<bool> _trySetUrlForAttachment(String path, String fileName) async {
    final bucket = _client.storage.from('chat_files');

    try {
      // 1) intentar signed URL (7 días)
      dynamic maybeSigned = bucket.createSignedUrl(path, 7);
      final signedResp = await Future.value(maybeSigned);
      final signedUrl = _extractUrlFromResponse(signedResp);

      if (signedUrl != null && signedUrl.isNotEmpty) {
        print('[CHAT] signedUrl para $path: $signedUrl');
        // usa signedUrl en el attachment
        return true;
      } else {
        // 2) fallback a public url (si tu bucket es público o getPublicUrl funciona)
        try {
          dynamic maybePub = bucket.getPublicUrl(path);
          final pubResp = await Future.value(maybePub);
          final pubUrl = _extractUrlFromResponse(pubResp);
          if (pubUrl != null && pubUrl.isNotEmpty) {
            print('[CHAT] publicUrl para $path: $pubUrl');
            // usa pubUrl en el attachment
            return true;
          } else {
            print('[CHAT] No se pudo obtener signed ni public url para $path. RESPUESTAS: signed=$signedResp pub=$pubResp');
            // Guarda path y haz signing server-side si necesitas seguridad
          }
        } catch (ePub) {
          print('[CHAT] getPublicUrl falló para $path: $ePub (signedResp=$signedResp)');
        }
      }
    } catch (e) {
      print('[CHAT] Error al obtener signed/public URL para $path: $e');
    }

    return false;
  }

  // --- helper: intenta obtener una URL usable (signed -> public)
  Future<String?> _getUrlForPath(String path, {int days = 7}) async {
    final bucket = _client.storage.from('chat_files');

    try {
      // 1) signed URL (varias SDKs devuelven Map o String)
      try {
        final maybeSigned = bucket.createSignedUrl(path, days);
        final signedResp = await Future.value(maybeSigned);
        final signedUrl = _extractUrlFromResponse(signedResp);
        print('[CHAT] createSignedUrl respuesta para $path: $signedResp -> parsed=$signedUrl');
        if (signedUrl != null && signedUrl.isNotEmpty) return signedUrl;
      } catch (e) {
        print('[CHAT] createSignedUrl falló para $path: $e');
      }

      // 2) public URL fallback (getPublicUrl puede devolver Map o String)
      try {
        final maybePub = bucket.getPublicUrl(path);
        final pubResp = await Future.value(maybePub);
        final pubUrl = _extractUrlFromResponse(pubResp);
        print('[CHAT] getPublicUrl respuesta para $path: $pubResp -> parsed=$pubUrl');
        if (pubUrl != null && pubUrl.isNotEmpty) return pubUrl;
      } catch (e) {
        print('[CHAT] getPublicUrl falló para $path: $e');
      }
    } catch (e) {
      print('[CHAT] _getUrlForPath error inesperado para $path: $e');
    }

    return null;
  }

  /// Descarga la URL y guarda el archivo en la carpeta "Downloads" del dispositivo (si es posible).
  /// Retorna la ruta del archivo guardado o null en caso de error.
  Future<String?> downloadAndSaveFile(String url, String fileName) async {
    try {
      // Pedir permiso en Android (iOS no necesita para app dir; para guardar en Photos requiere más)
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          print('[CHAT] permiso de almacenamiento denegado');
          return null;
        }
      }

      final uri = Uri.parse(url);
      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        print('[CHAT] descarga fallo, status=${resp.statusCode}');
        return null;
      }

      // Intentar obtener carpeta de descargas en Android: getExternalStorageDirectories(StorageDirectory.downloads)
      Directory? saveDir;
      if (Platform.isAndroid) {
        final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (dirs != null && dirs.isNotEmpty) {
          saveDir = dirs.first;
        } else {
          // fallback a app-specific external directory
          saveDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        // iOS: usar app documents (para guardar en Photos se necesita otra integración)
        saveDir = await getApplicationDocumentsDirectory();
      } else {
        // desktop: use downloads dir or temp
        try {
          saveDir = await getDownloadsDirectory();
        } catch (_) {
          saveDir = await getTemporaryDirectory();
        }
      }

      if (saveDir == null) {
        print('[CHAT] no se pudo determinar directorio de guardado');
        return null;
      }

      // Asegurar que exista
      await saveDir.create(recursive: true);

      // Sanear nombre
      final safeName = fileName.replaceAll(RegExp(r'[:\\/]+'), '_');

      final filePath = '${saveDir.path}/$safeName';
      final file = File(filePath);
      await file.writeAsBytes(resp.bodyBytes);
      print('[CHAT] archivo guardado en $filePath');
      return filePath;
    } catch (e, st) {
      print('[CHAT] downloadAndSaveFile ERROR: $e');
      print(st);
      return null;
    }
  }
}
