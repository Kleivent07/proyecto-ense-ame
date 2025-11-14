import 'package:flutter/material.dart';
import 'package:my_app/src/models/reuniones_model.dart';

class HybridRecordingService {
  final MeetingModel _meetingModel = MeetingModel();

  /// Mostrar instrucciones antes de la reunión
  Future<void> showPreMeetingDialog(BuildContext context, String roomId) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.videocam, color: Colors.blue),
            SizedBox(width: 8),
            Text('Preparar grabación'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔴 Grabación activada para esta reunión',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Para grabar:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('📱 Móvil: Usa grabación de pantalla'),
            Text('💻 PC: Windows + G (Game Bar)'),
            SizedBox(height: 16),
            Text(
              '💡 Inicia la grabación ANTES de la videollamada',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  /// Mostrar diálogo después de la reunión
  Future<void> showPostMeetingDialog(BuildContext context, String roomId) async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!context.mounted) return;

    final controller = TextEditingController();

    final saved = await showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Tienes la grabación?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Si grabaste la reunión, agrega la URL del video:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'URL del video (opcional)',
                hintText: 'https://youtube.com/watch?v=...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Después'),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                try {
                  await _meetingModel.updateMeetingByRoom(roomId, recordingUrl: url);
                  Navigator.of(ctx).pop(true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error guardando URL'))
                  );
                }
              } else {
                Navigator.of(ctx).pop(false);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Grabación guardada'),
          backgroundColor: Colors.green,
        )
      );
    }
  }
}