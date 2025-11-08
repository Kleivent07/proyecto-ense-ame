import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UnirseReunionPage extends StatefulWidget {
  const UnirseReunionPage({super.key});

  @override
  State<UnirseReunionPage> createState() => _UnirseReunionPageState();
}

class _UnirseReunionPageState extends State<UnirseReunionPage> {
  final TextEditingController _urlController = TextEditingController();

  Future<void> _abrirZoom() async {
    final text = _urlController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa una URL de Zoom')));
      return;
    }
    try {
      final url = Uri.parse(text);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir la reunión.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('URL inválida: $e')));
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Unirse a reunión")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Pega el enlace de Zoom para unirte:"),
            const SizedBox(height: 10),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "https://zoom.us/j/...",
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: _abrirZoom,
              child: const Text("Unirse"),
            ),
          ],
        ),
      ),
    );
  }
}