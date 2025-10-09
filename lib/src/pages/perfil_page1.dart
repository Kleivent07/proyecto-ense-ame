import 'package:flutter/material.dart';
import 'package:my_app/src/custom/CustomBottomNavBar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_app/src/custom/library.dart';


class PerfilPage extends StatefulWidget {
  const PerfilPage({Key? key}) : super(key: key);

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  bool cargando = true;
  Map<String, dynamic>? perfil;


  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    setState(() => cargando = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;


      setState(() {
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
      setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (perfil == null) {
      return const Scaffold(
        body: Center(child: Text('No hay perfil cargado')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: perfil!['imagen_url'] != null
                    ? NetworkImage(perfil!['imagen_url'])
                    : const AssetImage('assets/default_avatar.jpg') as ImageProvider,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                perfil!['nombre'] ?? 'Sin nombre',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Center(child: Text(perfil!['email'] ?? 'Sin email')),
            const SizedBox(height: 16),
            Text('Clase: ${perfil!['clase'] ?? 'No definida'}'),
            const SizedBox(height: 16),
            Text('Bio: ${perfil!['bio'] ?? 'Pronto podrás agregar tu descripción...'}'),
            const SizedBox(height: 24),

            // ===== BOTONES =====
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text("Editar perfil"),
              onPressed: () async {
                // Navega a la página de edición y recarga perfil al volver
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.star),
              label: const Text("Ver valoraciones"),
              onPressed: () {
                /*Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ValoracionesPage()),
                );*/
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.lock),
              label: const Text("Cambiar contraseña"),
              onPressed: () {
                /*Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CambiarContrasenaPage()),
                );*/
              },
            ),
            
          ],
        ),
      ),
    );
  }
}