import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_app/src/models/reuniones_model.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';

class AutoRecordingService {
  final MeetingModel _meetingModel = MeetingModel();
  bool _isRecording = false;
  String? _recordingPath;

  /// Verificar permisos antes de grabar
  Future<bool> _checkPermissions(BuildContext context) async {
    try {
      // Verificar permisos específicos según la plataforma
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
        Permission.storage,
        Permission.photos, // Para iOS
      ].request();

      // No es necesario verificar permisos de grabación de pantalla aquí, ya que permission_handler los cubre.

      bool basicPermissionsGranted = statuses.values.any((status) => status.isGranted);
      
      if (!basicPermissionsGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Se requieren permisos de audio y almacenamiento'),
            backgroundColor: Colors.orange,
          )
        );
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      return false;
    }
  }

  /// Mostrar diálogo de preparación y iniciar grabación
  Future<bool> startAutoRecording(BuildContext context, String roomId) async {
    // Primero verificar permisos
    final hasPermissions = await _checkPermissions(context);
    if (!hasPermissions) return false;

    // Mostrar diálogo de preparación
    final shouldStart = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.videocam, color: Colors.red),
            SizedBox(width: 8),
            Text('Grabación automática'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔴 Se iniciará la grabación de pantalla automáticamente',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            Text('La grabación incluirá:'),
            Text('• Video de la pantalla completa'),
            Text('• Audio del micrófono'),
            Text('• Audio de la videollamada'),
            SizedBox(height: 16),
            Text(
              '💡 El video se guardará en tu dispositivo',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text(
              'ℹ️ Es posible que aparezca una notificación del sistema para confirmar',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.fiber_manual_record, color: Colors.white),
            label: const Text('Iniciar grabación'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (shouldStart != true) return false;

    // Intentar iniciar grabación
    try {
      // Verificar permisos una vez más antes de iniciar
      // Ya se verificaron los permisos previamente, así que continuamos

      // Iniciar grabación con la API correcta
      await FlutterScreenRecording.startRecordScreen("GrabacionAutomatica");
      _isRecording = true;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.fiber_manual_record, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('🔴 Grabación en curso...'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        )
      );

      return true;
    } catch (e) {
      debugPrint('Error starting screen recording: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error iniciando grabación: $e'),
          backgroundColor: Colors.red,
        )
      );
      
      return false;
    }
  }

  /// Detener grabación y mostrar resultado
  Future<void> stopAutoRecording(BuildContext context, String roomId) async {
    if (!_isRecording) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏹️ Finalizando grabación...'),
          duration: Duration(seconds: 3),
        )
      );

      // Detener grabación
      final path = await FlutterScreenRecording.stopRecordScreen;
      _isRecording = false;
      _recordingPath = path;

      if (path != null && path.isNotEmpty) {
        // Grabación exitosa
        await _showSuccessDialog(context, roomId, path);
      } else {
        // Error en la grabación
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No se pudo obtener el archivo de grabación'),
            backgroundColor: Colors.orange,
          )
        );
      }
    } catch (e) {
      _isRecording = false;
      debugPrint('Error stopping recording: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error deteniendo grabación: $e'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  /// Mostrar diálogo de éxito con opciones
  Future<void> _showSuccessDialog(BuildContext context, String roomId, String filePath) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Grabación completada'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✅ Video guardado exitosamente',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ubicación: $filePath',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              const Text(
                'Para compartir la grabación:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('1. Sube el video a YouTube (No listado)'),
              const Text('2. O súbelo a Google Drive'),
              const Text('3. Copia la URL y pégala aquí:'),
              
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'URL del video (opcional)',
                  hintText: 'https://youtube.com/watch?v=...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                maxLines: 2,
              ),
              
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ℹ️ También puedes agregar la URL después desde "Reuniones Pasadas"',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Después'),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                try {
                  await _meetingModel.updateMeetingByRoom(roomId, recordingUrl: url);
                  Navigator.of(ctx).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ URL guardada correctamente'),
                      backgroundColor: Colors.green,
                    )
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error guardando URL'))
                  );
                }
              } else {
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Guardar URL'),
          ),
        ],
      ),
    );
  }

  /// Verificar si está grabando
  bool get isRecording => _isRecording;

  /// Obtener la ruta del último archivo grabado
  String? get lastRecordingPath => _recordingPath;
}