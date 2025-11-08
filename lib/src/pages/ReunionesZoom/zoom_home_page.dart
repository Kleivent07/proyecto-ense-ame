import 'package:flutter/material.dart';
import 'crear_reunion_page.dart';
import 'unirse_reunion_page.dart';
import 'grabaciones_page.dart';

class ZoomHomePage extends StatelessWidget {
  const ZoomHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reuniones Zoom")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Crear reunión"),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CrearReunionPage()),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              icon: const Icon(Icons.video_call),
              label: const Text("Unirse a reunión"),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UnirseReunionPage()),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text("Ver grabaciones"),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GrabacionesPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}