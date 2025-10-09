import 'package:flutter/material.dart';
import 'package:my_app/src/custom/CustomBottomNavBar.dart';
import 'package:my_app/src/custom/refrescar.dart';
import 'package:my_app/src/models/estudiantes_model.dart';
import 'package:my_app/src/models/profesores_model.dart';
import 'package:my_app/src/pages/editar_perfil_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_app/src/custom/library.dart';
import 'package:my_app/src/models/usuarios_model.dart';



class PerfilPage extends StatefulWidget {
  const PerfilPage({Key? key}) : super(key: key);

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  int selectedIndex = 4;
  bool? esProfesor;
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

    // Primero obtén el perfil general
    final perfilGeneral = await Usuario().obtenerPerfil();

    // Detecta el tipo de usuario
    final esProf = perfilGeneral?['clase'] == 'Tutor';

    // Obtén datos específicos según el tipo
    Map<String, dynamic>? perfilCompleto;
    if (esProf) {
      perfilCompleto = await ProfesorService().obtenerProfesor(userId);
    } else {
      perfilCompleto = await EstudianteService().obtenerEstudiante(userId);
    }
    setState(() {
      cargando = false;
      esProfesor = esProf;
      perfil = {
        ...?perfilGeneral,
        ...?perfilCompleto, // Combina los datos generales y específicos
      };
    });
  } catch (e) {
    debugPrint('Error cargando perfil: $e');
    setState(() => cargando = false);
  }
}
Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ Cerrar sesión en Supabase
      await Supabase.instance.client.auth.signOut();

      // ✅ Eliminar datos locales
      await prefs.clear();

      // ✅ Redirigir al login
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          navigate(context, CustomPages.loginPage),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
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

    final esProfesor = perfil!['clase'] == 'Tutor';

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

            // ===== BOTONES COMUNES =====
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text("Editar perfil"),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditarPerfilPage(perfil: perfil!)),
                );
                _cargarPerfil(); // Recarga el perfil al volver
              },
            ),
            const SizedBox(height: 12),

            // ===== BOTONES SOLO PARA PROFESORES =====
            if (esProfesor) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.star),
                label: const Text("Ver valoraciones"),
                onPressed: () {
                  // Navega a valoraciones
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.school),
                label: const Text("Mis clases"),
                onPressed: () {
                  // Navega a clases del profesor
                },
              ),
              const SizedBox(height: 12),
            ],

            // ===== BOTONES SOLO PARA ESTUDIANTES =====
            if (!esProfesor) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.assignment),
                label: const Text("Mis tareas"),
                onPressed: () {
                  // Navega a tareas del estudiante
                },
              ),
              const SizedBox(height: 12),
            ],

            // ===== BOTÓN COMÚN =====
            ElevatedButton.icon(
              icon: const Icon(Icons.lock),
              label: const Text("Cambiar contraseña"),
              onPressed: () {
                // Navega a cambiar contraseña
              },
            ),
            // ===== BOTÓN DE CERRAR SESIÓN =====
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text("Cerrar sesión"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: _logout,
            ),
          ],
          
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: selectedIndex,
        isEstudiante: !esProfesor, // true si NO es profesor
        onReloadHome: () {
          RefrescarHelper.actualizarDatos(
            context: context,
            onUpdate: () {
              setState(() {
                _cargarPerfil(); // Recarga los datos del perfil
              });
            },
          );
        },
      ),
    );
  }
}