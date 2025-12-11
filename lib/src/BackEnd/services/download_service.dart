import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_filex/open_filex.dart';

class DownloadService {
  final Dio _dio = Dio();
  
  // 🎯 Descargar archivo con Dio (más control)
  Future<String?> downloadFile({
    required String url,
    required String fileName,
    Function(double)? onProgress,
    VoidCallback? onComplete,
    Function(String)? onError,
  }) async {
    try {
      debugPrint('[DownloadService] 📥 Iniciando descarga: $fileName');
      
      // Obtener directorio de descarga (sin permisos complejos)
      final directory = await _getDownloadDirectory();
      
      // Generar nombre único si existe
      final finalFileName = await _getUniqueFileName(directory, fileName);
      final filePath = '${directory.path}/$finalFileName';
      
      debugPrint('[DownloadService] 💾 Guardando en: $filePath');
      
      // Configurar opciones de descarga (header sin caracteres especiales)
      final options = Options(
        headers: {
          'User-Agent': 'EnsenameApp/1.0', // ✅ SIN Ñ
          'Accept': '*/*',
          'Accept-Encoding': 'gzip, deflate, br',
          'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        },
        receiveTimeout: const Duration(minutes: 15),
        sendTimeout: const Duration(minutes: 5),
        followRedirects: true,
        maxRedirects: 5,
      );
      
      // Realizar descarga
      final response = await _dio.download(
        url,
        filePath,
        options: options,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onProgress?.call(progress);
            debugPrint('[DownloadService] 📊 Progreso: ${(progress * 100).toInt()}%');
          }
        },
      );
      
      if (response.statusCode == 200) {
        debugPrint('[DownloadService] ✅ Descarga exitosa: $filePath');
        onComplete?.call();
        return filePath;
      } else {
        throw Exception('Error HTTP: ${response.statusCode}');
      }
      
    } catch (e) {
      debugPrint('[DownloadService] ❌ Error: $e');
      onError?.call(e.toString());
      return null;
    }
  }
  
  // 🎯 Descargar con FlutterDownloader (background)
  Future<String?> downloadInBackground({
    required String url,
    required String fileName,
  }) async {
    try {
      final directory = await _getDownloadDirectory();
      
      final taskId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: directory.path,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: false, // ✅ Siempre false para evitar permisos
      );
      
      debugPrint('[DownloadService] 🚀 Descarga en background iniciada: $taskId');
      return taskId;
      
    } catch (e) {
      debugPrint('[DownloadService] ❌ Error en background: $e');
      return null;
    }
  }
  
  // 🎯 Abrir archivo descargado
  Future<bool> openDownloadedFile(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('[DownloadService] ❌ Error abriendo archivo: $e');
      return false;
    }
  }
  
  // 🎯 Obtener directorio de descarga (simplificado)
  Future<Directory> _getDownloadDirectory() async {
    Directory? directory;
    
    try {
      if (Platform.isAndroid) {
        // ✅ USAR SOLO DIRECTORIO DE LA APP (no requiere permisos)
        final appDir = await getApplicationDocumentsDirectory();
        directory = Directory('${appDir.path}/Downloads');
        
        debugPrint('[DownloadService] 📁 Directorio de app: ${directory.path}');
        
      } else if (Platform.isIOS) {
        // iOS
        final appDir = await getApplicationDocumentsDirectory();
        directory = Directory('${appDir.path}/Downloads');
        
      } else {
        // Otros (Windows, Linux, macOS)
        final appDir = await getApplicationDocumentsDirectory();
        directory = Directory('${appDir.path}/Downloads');
      }
      
      // Crear directorio si no existe
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        debugPrint('[DownloadService] 📁 Directorio creado: ${directory.path}');
      }
      
      // Verificar que podemos escribir
      final testFile = File('${directory.path}/.test_write');
      try {
        await testFile.writeAsString('test');
        await testFile.delete();
        debugPrint('[DownloadService] ✅ Directorio escribible');
      } catch (e) {
        debugPrint('[DownloadService] ⚠️ Problema de escritura: $e');
        // Fallback al temporal
        final tempDir = await getTemporaryDirectory();
        directory = Directory('${tempDir.path}/Downloads');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      }
      
      return directory;
      
    } catch (e) {
      debugPrint('[DownloadService] ❌ Error obteniendo directorio: $e');
      
      // Fallback absoluto al directorio temporal
      final tempDir = await getTemporaryDirectory();
      directory = Directory('${tempDir.path}/Downloads');
      
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      debugPrint('[DownloadService] 📁 Usando directorio temporal: ${directory.path}');
      return directory;
    }
  }
  
  // 🎯 Generar nombre único
  Future<String> _getUniqueFileName(Directory directory, String fileName) async {
    String finalName = fileName;
    int counter = 1;
    
    while (await File('${directory.path}/$finalName').exists()) {
      final parts = fileName.split('.');
      if (parts.length > 1) {
        final nameWithoutExt = parts.sublist(0, parts.length - 1).join('.');
        final extension = parts.last;
        finalName = '${nameWithoutExt}_$counter.$extension';
      } else {
        finalName = '${fileName}_$counter';
      }
      counter++;
    }
    
    if (counter > 1) {
      debugPrint('[DownloadService] 📝 Nombre único generado: $finalName');
    }
    
    return finalName;
  }
  
  // 🎯 Obtener archivos descargados
  Future<List<FileSystemEntity>> getDownloadedFiles() async {
    try {
      final directory = await _getDownloadDirectory();
      if (await directory.exists()) {
        return directory.listSync();
      }
      return [];
    } catch (e) {
      debugPrint('[DownloadService] ❌ Error listando archivos: $e');
      return [];
    }
  }
  
  // 🎯 Eliminar archivo descargado
  Future<bool> deleteDownloadedFile(String fileName) async {
    try {
      final directory = await _getDownloadDirectory();
      final file = File('${directory.path}/$fileName');
      
      if (await file.exists()) {
        await file.delete();
        debugPrint('[DownloadService] 🗑️ Archivo eliminado: $fileName');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('[DownloadService] ❌ Error eliminando archivo: $e');
      return false;
    }
  }
  
  // 🎯 Obtener tamaño de archivo
  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      debugPrint('[DownloadService] ❌ Error obteniendo tamaño: $e');
      return 0;
    }
  }
  
  // 🎯 Formatear tamaño de archivo
  String formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    int suffixIndex = 0;
    double size = bytes.toDouble();
    
    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }
    
    return "${size.toStringAsFixed(suffixIndex == 0 ? 0 : 1)} ${suffixes[suffixIndex]}";
  }
  
  // 🎯 Limpiar archivos antiguos (opcional)
  Future<void> cleanOldFiles({int daysOld = 7}) async {
    try {
      final directory = await _getDownloadDirectory();
      if (!await directory.exists()) return;
      
      final now = DateTime.now();
      final files = directory.listSync();
      int deletedCount = 0;
      
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          final age = now.difference(stat.modified).inDays;
          
          if (age > daysOld) {
            try {
              await file.delete();
              deletedCount++;
            } catch (e) {
              debugPrint('[DownloadService] ⚠️ No se pudo eliminar: ${file.path}');
            }
          }
        }
      }
      
      if (deletedCount > 0) {
        debugPrint('[DownloadService] 🧹 Archivos antiguos eliminados: $deletedCount');
      }
    } catch (e) {
      debugPrint('[DownloadService] ❌ Error limpiando archivos: $e');
    }
  }
}