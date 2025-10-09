import 'package:flutter/material.dart';

class EditarPerfilPage extends StatefulWidget {
  final Map<String, dynamic> perfil;
  const EditarPerfilPage({required this.perfil, super.key});

  @override
  State<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends State<EditarPerfilPage> {
  late TextEditingController nombreController;
  late TextEditingController bioController;

  @override
  void initState() {
    super.initState();
    nombreController = TextEditingController(text: widget.perfil['nombre']);
    bioController = TextEditingController(text: widget.perfil['bio']);
  }

  Future<void> _guardarCambios() async {
    // Aquí llamas a tu modelo para actualizar el perfil
    // Ejemplo:
    // await UsuariosModel().actualizarPerfil(widget.perfil['id'], nombreController.text, bioController.text);
    Navigator.pop(context); // Vuelve al perfil
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: bioController,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardarCambios,
              child: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}