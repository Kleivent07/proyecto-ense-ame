import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class FileService {
  
  // 🎯 Seleccionar archivos
  Future<List<PlatformFile>> pickFiles({
    FileType type = FileType.any,
    bool allowMultiple = true,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        type: type,
        allowCompression: true,
      );
      
      return result?.files ?? [];
    } catch (e) {
      throw Exception('Error seleccionando archivos: $e');
    }
  }
  
  // 🎯 Abrir archivo con app nativa
  Future<bool> openFile(String path) async {
    try {
      final result = await OpenFilex.open(path);
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('[FileService] Error abriendo archivo: $e');
      return false;
    }
  }
  
  // 🎯 Compartir archivo
  Future<void> shareFile(String path, {String? text}) async {
    try {
      await Share.shareXFiles([XFile(path)], text: text);
    } catch (e) {
      debugPrint('[FileService] Error compartiendo archivo: $e');
      throw Exception('No se pudo compartir el archivo');
    }
  }
  
  // 🎯 Compartir URL
  Future<void> shareUrl(String url, String fileName) async {
    try {
      await Share.share('$fileName: $url');
    } catch (e) {
      debugPrint('[FileService] Error compartiendo URL: $e');
      throw Exception('No se pudo compartir el enlace');
    }
  }
  
  // 🎯 Obtener tipo de archivo
  String getFileType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'];
    const videoExtensions = ['mp4', 'avi', 'mov', 'webm', 'mkv', 'flv', '3gp'];
    const audioExtensions = ['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a'];
    const documentExtensions = ['pdf', 'doc', 'docx', 'txt', 'rtf', 'odt'];
    const codeExtensions = ['html', 'css', 'js', 'json', 'xml', 'dart', 'java', 'py'];
    
    if (imageExtensions.contains(extension)) return 'image';
    if (videoExtensions.contains(extension)) return 'video';
    if (audioExtensions.contains(extension)) return 'audio';
    if (documentExtensions.contains(extension)) return 'document';
    if (codeExtensions.contains(extension)) return 'code';
    
    return 'file';
  }
  
  // 🎯 Obtener icono según tipo
  IconData getFileIcon(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    
    const iconMap = {
      // Documentos
      'pdf': Icons.picture_as_pdf,
      'doc': Icons.description,
      'docx': Icons.description,
      'txt': Icons.text_snippet,
      'rtf': Icons.text_fields,
      
      // Hojas de cálculo
      'xls': Icons.table_chart,
      'xlsx': Icons.table_chart,
      'csv': Icons.table_view,
      
      // Presentaciones
      'ppt': Icons.slideshow,
      'pptx': Icons.slideshow,
      
      // Archivos comprimidos
      'zip': Icons.archive,
      'rar': Icons.archive,
      '7z': Icons.archive,
      
      // Audio
      'mp3': Icons.audio_file,
      'wav': Icons.audio_file,
      'aac': Icons.audio_file,
      'flac': Icons.audio_file,
      'ogg': Icons.audio_file,
      
      // Video
      'mp4': Icons.video_file,
      'avi': Icons.video_file,
      'mov': Icons.video_file,
      'webm': Icons.video_file,
      'mkv': Icons.video_file,
      
      // Imágenes
      'jpg': Icons.image,
      'jpeg': Icons.image,
      'png': Icons.image,
      'gif': Icons.image,
      'webp': Icons.image,
      'bmp': Icons.image,
      
      // Código
      'html': Icons.web,
      'css': Icons.style,
      'js': Icons.javascript,
      'json': Icons.data_object,
      'xml': Icons.code,
      'dart': Icons.flutter_dash,
      'java': Icons.code,
      'py': Icons.code,
      
      // Otros
      'apk': Icons.android,
      'exe': Icons.computer,
      'dmg': Icons.folder_zip,
    };
    
    return iconMap[extension] ?? Icons.insert_drive_file;
  }
  
  // 🎯 Obtener color según tipo
  Color getFileIconColor(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    
    const colorMap = {
      'pdf': Colors.red,
      'doc': Colors.blue,
      'docx': Colors.blue,
      'xls': Colors.green,
      'xlsx': Colors.green,
      'ppt': Colors.orange,
      'pptx': Colors.orange,
      'zip': Colors.purple,
      'rar': Colors.purple,
      'mp3': Colors.pink,
      'wav': Colors.pink,
      'mp4': Colors.indigo,
      'avi': Colors.indigo,
      'jpg': Colors.teal,
      'jpeg': Colors.teal,
      'png': Colors.teal,
      'gif': Colors.teal,
      'txt': Colors.grey,
      'html': Colors.orange,
      'css': Colors.blue,
      'js': Colors.yellow,
      'dart': Colors.cyan,
    };
    
    return colorMap[extension] ?? Colors.blueGrey;
  }
  
  // 🎯 Formatear tamaño de archivo
  String formatFileSize(int bytes) {
    if (bytes == 0) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double size = bytes.toDouble();
    
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }
  
  // 🎯 Verificar si es imagen
  bool isImageFile(String fileName) {
    return getFileType(fileName) == 'image';
  }
  
  // 🎯 Verificar si es video
  bool isVideoFile(String fileName) {
    return getFileType(fileName) == 'video';
  }
  
  // 🎯 Verificar si es documento de texto
  bool isTextFile(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    const textExtensions = ['txt', 'json', 'xml', 'html', 'css', 'js', 'dart', 'md'];
    return textExtensions.contains(extension);
  }
}