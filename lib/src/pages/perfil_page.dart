
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_app/src/models/perfil_usuario.dart'; // archivo donde tienes cargarPerfil() y guardarPerfil()

class PerfilPage extends StatefulWidget {
  const PerfilPage({Key? key}) : super(key: key);

  @override
  _PerfilPageState createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? perfil;
  String? imagenUrl; // URL de la imagen de perfil
  TextEditingController nombreController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  String claseController = 'Estudiante';
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  void _cargarDatos() async {
    final datos = await cargarPerfil(); // tu función backend
    if (datos != null) {
      setState(() {
        perfil = datos;
        nombreController.text = datos['nombre'] ?? '';
        emailController.text = datos['email'] ?? '';
        claseController = datos['clase'] ?? 'Estudiante';
        imagenUrl = datos['imagen_url']; // puede ser null
      });
    }
    setState(() => cargando = false);
  }

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final path = 'avatars/$userId.png';

      // Subir imagen a Supabase Storage (se sobreescribe si ya existe)
      await Supabase.instance.client.storage
          .from('perfiles')
          .uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true));

      // Obtener URL pública (ya es String)
      final url = Supabase.instance.client.storage
          .from('perfiles')
          .getPublicUrl(path);

      setState(() {
        imagenUrl = url;
      });
    }
  }


  void _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final exito = await guardarPerfil({
      'nombre': nombreController.text,
      'email': emailController.text,
      'clase': claseController,
      'imagen_url': imagenUrl, // opcional
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          exito ? 'Perfil actualizado correctamente' : 'Error al guardar perfil',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: imagenUrl != null
                          ? NetworkImage(imagenUrl!)
                          : AssetImage('assets/default_avatar.png') as ImageProvider,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt),
                        onPressed: _seleccionarImagen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) => value!.isEmpty ? 'Ingrese un email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value!.isEmpty ? 'Ingrese un nombre' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: claseController,
                decoration: const InputDecoration(labelText: 'Clase'),
                items: ['Estudiante', 'Tutor (profesor)']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) => setState(() => claseController = value!),
                validator: (value) => value == null ? 'Seleccione una clase' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _guardar, child: const Text('Guardar')),
            ],
          ),
        ),
      ),
    );
  }
}
