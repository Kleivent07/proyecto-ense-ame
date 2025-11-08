import 'package:flutter/material.dart';
import '../../custom/zoom_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CrearReunionPage extends StatefulWidget {
  const CrearReunionPage({super.key});

  @override
  State<CrearReunionPage> createState() => _CrearReunionPageState();
}

class _CrearReunionPageState extends State<CrearReunionPage> {
  final _zoomService = ZoomService();
  bool _loading = false;
  String? _joinUrl;
  String? _startUrl;

  Future<void> _crearReunion() async {
    setState(() => _loading = true);

    try {
      // Tomamos token y uid de la sesión Supabase (si existe)
      final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
      print('DEBUG Supabase accessToken: $accessToken');
      final uid = Supabase.instance.client.auth.currentUser?.id ?? 'unknown-host';

      final result = await _zoomService.crearReunion(
        topic: "Tutoría desde app",
        startTime: DateTime.now().add(const Duration(minutes: 5)),
        duration: 45,
        hostId: uid,
        accessToken: accessToken,
      );

      final zoom = result['zoom'] as Map<String, dynamic>?;

      setState(() {
        _joinUrl = zoom?['join_url'] as String?;
        _startUrl = zoom?['start_url'] as String?;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reunión creada correctamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creando reunión: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Crear reunión")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _crearReunion,
                    child: const Text("Crear nueva reunión"),
                  ),
            if (_joinUrl != null) ...[
              const SizedBox(height: 30),
              const Text("📚 Enlace para estudiante:"),
              SelectableText(_joinUrl!),
              const SizedBox(height: 10),
              const Text("🎓 Enlace para tutor:"),
              SelectableText(_startUrl ?? 'No disponible'),
            ],
          ],
        ),
      ),
    );
  }
}