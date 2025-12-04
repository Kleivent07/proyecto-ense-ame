import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/custom/custom_bottom_nav_bar.dart';
import 'package:my_app/src/BackEnd/custom/no_teclado.dart';
import 'package:my_app/src/pages/Estudiantes/lista_solicitud_estudiante_page.dart';
import 'package:my_app/src/pages/Profesores/lista_solicitud_profesor_page.dart';
import 'package:my_app/src/pages/Editar/lista_solicitudes_page.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
// ✅ Imports oficiales para el sistema de calificaciones
import 'package:my_app/src/pages/Estudiantes/mis_calificaciones_page.dart';
import 'package:my_app/src/pages/Estudiantes/calificar_reuniones_page.dart';
// ✨ NUEVO IMPORT para soporte
import 'package:my_app/src/pages/Soporte/soporte_page.dart';

// 🧪 Import para debug (comentar en producción)
// import 'package:my_app/src/pages/debug/debug_reunion_test.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_app/src/BackEnd/custom/refrescar.dart';
import 'package:my_app/src/BackEnd/custom/library.dart';

import 'package:my_app/src/models/usuarios_model.dart';
import 'package:my_app/src/models/estudiantes_model.dart';
import 'package:my_app/src/models/profesores_model.dart' as profesores_model;
import 'package:my_app/src/pages/Editar/editar_perfil_page.dart';
import 'package:my_app/src/models/solicitud_model.dart';
import 'package:my_app/src/BackEnd/custom/solicitud_data.dart';

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

      final perfilGeneral = await Usuario().obtenerPerfil();
      final esProf = perfilGeneral?['clase'] == 'Tutor';

      Map<String, dynamic>? perfilCompleto;
      if (esProf) {
        perfilCompleto = await profesores_model.ProfesorService().obtenerProfesor(userId);
      } else {
        perfilCompleto = await EstudianteService().obtenerEstudiante(userId);
      }

      setState(() {
        cargando = false;
        esProfesor = esProf;
        perfil = {
          ...?perfilGeneral,
          ...?perfilCompleto,
        };
      });
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
      setState(() => cargando = false);
    }
  }
  
  Future<List<SolicitudData>> _obtenerSolicitudes() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final solicitudModel = SolicitudModel();

    if (esProfesor == true) {
      return await solicitudModel.obtenerSolicitudesPorProfesor(userId);
    } else {
      return await solicitudModel.obtenerSolicitudesPorEstudiante(userId);
    }
  }

  Future<void> _irListaSolicitudes() async {
    final solicitudes = await _obtenerSolicitudes();
    if (!mounted) return;

    if (esProfesor == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ListaSolicitudesProfesorPage(solicitudes: solicitudes),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ListaSolicitudesEstudiantePage(solicitudes: solicitudes),
        ),
      );
    }
  }

  // ✨ FUNCIÓN SIMPLE: Abrir página de soporte
  void _abrirSoporte() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SoportePage(),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Supabase.instance.client.auth.signOut();
      await prefs.clear();

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (perfil == null) {
      return const Scaffold(body: Center(child: Text('No hay perfil cargado')));
    }
    final esProfesor = perfil!['clase'] == 'Tutor';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Constants.colorPrimary,
        elevation: 4,
        title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Editar perfil',
            onPressed: () async {
              final guardado = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditarPerfilPage(perfil: perfil!),
                ),
              );
              if (guardado == true) {
                await _cargarPerfil();
                setState(() {});
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Constants.colorPrimaryDark, Constants.colorPrimary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          children: [
            // Avatar destacado
            Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: perfil!['imagen_url'] != null
                      ? NetworkImage(perfil!['imagen_url'])
                      : const AssetImage('assets/default_avatar.jpg') as ImageProvider,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                '${perfil!['nombre'] ?? ''} ${perfil!['apellido'] ?? ''}'.trim().isEmpty
                    ? 'Sin nombre'
                    : '${perfil!['nombre']} ${perfil!['apellido']}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 8)],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                perfil!['email'] ?? 'Sin email',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Información general en tarjeta
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              color: Colors.white.withOpacity(0.95),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Información general', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    Text('Clase: ${perfil!['clase'] ?? 'No definida'}', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Bio: ${perfil!['biografia'] ?? 'Pronto podrás agregar tu descripción...'}', style: TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Campos específicos
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              color: Colors.white.withOpacity(0.95),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(esProfesor ? 'Datos de Tutor' : 'Datos de Estudiante', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    ...(
                      esProfesor
                          ? [
                              Text('Especialidad: ${perfil!['especialidad'] ?? 'No definida'}'),
                              Text('Carrera/Profesión: ${perfil!['carrera_profesion'] ?? 'No definida'}'),
                              Text('Experiencia: ${perfil!['experiencia'] ?? 'No definida'}'),
                              Text('Horario: ${perfil!['horario'] ?? 'No definida'}'),
                            ]
                          : [
                              Text('Carrera: ${perfil!['carrera'] ?? 'No definida'}'),
                              Text('Semestre: ${perfil!['semestre'] ?? 'No definido'}'),
                              Text('Intereses: ${perfil!['intereses'] ?? 'No definidos'}'),
                              Text('Disponibilidad: ${perfil!['disponibilidad'] ?? 'No definida'}'),
                            ]
                    ).map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: e)).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botones principales
            Column(
              children: [
                _PerfilButton(
                  icon: Icons.mail,
                  text: esProfesor ? "Solicitudes Recibidas" : "Mis Solicitudes",
                  color1: const Color.fromARGB(255, 255, 77, 77),
                  color2: const Color.fromARGB(255, 179, 55, 55),
                  onTap: _irListaSolicitudes,
                ),
                if (!esProfesor)
                  _PerfilButton(
                    icon: Icons.rate_review,
                    text: "Calificar Reuniones",
                    color1: const Color.fromARGB(255, 180, 23, 23),
                    color2: const Color.fromARGB(255, 179, 55, 55),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ClasificarReunionesPage()),
                      );
                    },
                  ),
                if (!esProfesor)
                  _PerfilButton(
                    icon: Icons.star,
                    text: "Mis Calificaciones",
                  color1: const Color.fromARGB(255, 131, 21, 21),
                  color2: const Color.fromARGB(255, 179, 55, 55),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MisCalificacionesPage()),
                      );
                    },
                  ),
                _PerfilButton(
                  icon: Icons.support_agent,
                  text: "Centro de Soporte",
                  color1: const Color.fromARGB(255, 77, 9, 9),
                  color2: const Color.fromARGB(255, 179, 55, 55),
                  onTap: _abrirSoporte,
                ),
                _PerfilButton(
                  icon: Icons.lock,
                  text: "Cambiar contraseña",
                  color1: const Color.fromARGB(255, 56, 20, 20),
                  color2: const Color.fromARGB(255, 100, 6, 6),
                  onTap: () {},
                ),
                _PerfilButton(
                  icon: Icons.logout,
                  text: "Cerrar sesión",
                  color1: const Color.fromARGB(255, 255, 0, 0),
                  color2: const Color.fromARGB(255, 255, 26, 26),
                  onTap: _logout,
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: selectedIndex,
        isEstudiante: !esProfesor,
        onReloadHome: () {
          RefrescarHelper.actualizarDatos(
            context: context,
            onUpdate: () {
              setState(() {
                _cargarPerfil();
              });
            },
          );
        },
      ),
    );
  }
}

class _PerfilButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color1;
  final Color color2;
  final VoidCallback onTap;

  const _PerfilButton({
    required this.icon,
    required this.text,
    required this.color1,
    required this.color2,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color2.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 16),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

