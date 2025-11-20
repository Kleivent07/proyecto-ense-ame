import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

import 'file_service.dart';
import 'download_service.dart';
import '../util/constants.dart';

class ViewerService {
  final FileService _fileService = GetIt.instance<FileService>();
  final DownloadService _downloadService = GetIt.instance<DownloadService>();
  
  // 🎯 Abrir archivo - todo con apps externas
  Future<void> openFile(BuildContext context, String url, String fileName) async {
    try {
      debugPrint('[ViewerService] Abriendo archivo externo: $fileName');
      
      // Mostrar progreso con más detalles
      double progress = 0.0;
      late StateSetter dialogSetState;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) {
            dialogSetState = setState;
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          value: progress > 0 ? progress : null,
                          color: Constants.colorPrimary,
                          strokeWidth: 3,
                        ),
                      ),
                      if (progress > 0)
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: Constants.textStyleFont.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Descargando $fileName...',
                    textAlign: TextAlign.center,
                    style: Constants.textStyleFont.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Se abrirá automáticamente',
                    style: Constants.textStyleFont.copyWith(
                      fontSize: 12,
                      color: Constants.colorFont.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
      
      // Descargar archivo con progreso
      final filePath = await _downloadService.downloadFile(
        url: url,
        fileName: fileName,
        onProgress: (progressValue) {
          dialogSetState(() {
            progress = progressValue;
          });
        },
        onComplete: () {
          debugPrint('[ViewerService] ✅ Descarga completada, abriendo...');
        },
        onError: (error) {
          debugPrint('[ViewerService] ❌ Error en descarga: $error');
        },
      );
      
      // Cerrar diálogo de progreso
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (filePath != null) {
        // Intentar abrir con app externa
        debugPrint('[ViewerService] 🚀 Abriendo archivo: $filePath');
        final result = await OpenFilex.open(filePath);
        
        if (context.mounted) {
          if (result.type == ResultType.done) {
            // Éxito
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Archivo abierto',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            fileName,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                backgroundColor: Constants.colorRosa,
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            // No se pudo abrir, pero el archivo está descargado
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Archivo descargado'),
                    Text(
                      'No se encontró una app para abrir este tipo de archivo',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                backgroundColor: Constants.colorAccent,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Ver ubicación',
                  textColor: Colors.white,
                  onPressed: () => _showFileLocation(context, filePath),
                ),
              ),
            );
          }
        }
      } else {
        throw Exception('Error descargando archivo');
      }
    } catch (e) {
      // Cerrar cualquier diálogo abierto
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }
      
      debugPrint('[ViewerService] ❌ Error: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Error abriendo archivo'),
                      Text(
                        fileName,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Constants.colorError,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  // 🎯 Solo descargar archivo
  Future<void> downloadFile(BuildContext context, String url, String fileName) async {
    try {
      debugPrint('[ViewerService] 📥 Descargando: $fileName');
      
      double progress = 0.0;
      late StateSetter dialogSetState;
      
      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) {
            dialogSetState = setState;
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          value: progress > 0 ? progress : null,
                          color: Constants.colorPrimary,
                          strokeWidth: 3,
                        ),
                      ),
                      if (progress > 0)
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: Constants.textStyleFont.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Descargando $fileName...'),
                ],
              ),
            );
          },
        ),
      );
      
      // Descargar con progreso
      final filePath = await _downloadService.downloadFile(
        url: url,
        fileName: fileName,
        onProgress: (progressValue) {
          dialogSetState(() {
            progress = progressValue;
          });
        },
      );
      
      // Cerrar diálogo
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (filePath != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Descarga completada',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        fileName,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Constants.colorRosa,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Abrir',
              textColor: Colors.white,
              onPressed: () => OpenFilex.open(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error descargando $fileName'),
            backgroundColor: Constants.colorError,
          ),
        );
      }
    }
  }
  
  // 🎯 Compartir archivo
  Future<void> shareFile(String url, String fileName) async {
    try {
      await Share.share(url, subject: 'Compartir $fileName');
    } catch (e) {
      debugPrint('[ViewerService] Error compartiendo: $e');
    }
  }
  
  // 🎯 Mostrar ubicación del archivo
  void _showFileLocation(BuildContext context, String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.folder, color: Constants.colorPrimary),
            const SizedBox(width: 8),
            const Text('Archivo guardado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('El archivo se guardó en:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Constants.colorFondo2.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Constants.colorFondo2.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.description, 
                       color: Constants.colorAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      filePath,
                      style: Constants.textStyleFont.copyWith(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Puedes acceder al archivo desde el administrador de archivos de tu dispositivo.',
              style: Constants.textStyleFont.copyWith(
                fontSize: 12,
                color: Constants.colorFont.withOpacity(0.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              OpenFilex.open(filePath);
            },
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
  }
}