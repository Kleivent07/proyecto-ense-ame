import 'package:flutter/material.dart';
import 'package:my_app/src/util/constants.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_app/src/custom/CustomBottomNavBar.dart';
import 'package:my_app/src/custom/refrescar.dart';
import 'package:my_app/src/custom/library.dart';

import 'package:my_app/src/models/usuarios_model.dart';
import 'package:my_app/src/models/estudiantes_model.dart';
import 'package:my_app/src/models/profesores_model.dart';
import 'package:my_app/src/pages/editar_perfil_page.dart';


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
    backgroundColor: Constants.colorFondo2,
    appBar: AppBar(
      foregroundColor: Colors.white, 
      backgroundColor: Constants.colorPrimary,
      title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: 'Editar perfil',
          style: ElevatedButton.styleFrom(
            backgroundColor: Constants.colorButton,
            foregroundColor: Colors.white,
          ),
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
    body: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
      child: ListView(
        children: [
          // === Avatar y nombre ===
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(2), // grosor del borde
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Constants.colorFont, // color del borde
                    width: 3, // grosor del borde
                  ),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: perfil!['imagen_url'] != null
                      ? NetworkImage(perfil!['imagen_url'])
                      : const AssetImage('assets/default_avatar.jpg') as ImageProvider,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${perfil!['nombre'] ?? ''} ${perfil!['apellido'] ?? ''}'.trim().isEmpty
                    ? 'Sin nombre'
                    : '${perfil!['nombre']} ${perfil!['apellido']}',
                style: Constants.textStyleFontTitle,
              ),
              const SizedBox(height: 4),
              Text(
                perfil!['email'] ?? 'Sin email',
                style: Constants.textStyleFont,
              ),
            ],
          ),
        ),

          const SizedBox(height: 24),

          // === Información general ===
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            color: Constants.colorBackground,
            shadowColor: Constants.colorShadow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Clase: ${perfil!['clase'] ?? 'No definida'}', style: Constants.textStyleFontSemiBold),
                  const SizedBox(height: 8),
                  Text('Bio: ${perfil!['biografia'] ?? 'Pronto podrás agregar tu descripción...'}', style: Constants.textStyleFont),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // === Campos específicos según tipo ===
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            color: Constants.colorBackground,
            shadowColor: Constants.colorShadow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: esProfesor
                    ? [
                        Text('Especialidad: ${perfil!['especialidad'] ?? 'No definida'}', style: Constants.textStyleFontSemiBold),
                        const SizedBox(height: 8),
                        Text('Carrera/Profesión: ${perfil!['carrera_profesion'] ?? 'No definida'}', style: Constants.textStyleFont),
                        const SizedBox(height: 8),
                        Text('Experiencia: ${perfil!['experiencia'] ?? 'No definida'}', style: Constants.textStyleFont),
                        const SizedBox(height: 8),
                        Text('Horario: ${perfil!['horario'] ?? 'No definida'}', style: Constants.textStyleFont),
                      ]
                    : [
                        Text('Carrera: ${perfil!['carrera'] ?? 'No definida'}', style: Constants.textStyleFontSemiBold),
                        const SizedBox(height: 8),
                        Text('Semestre: ${perfil!['semestre'] ?? 'No definido'}', style: Constants.textStyleFont),
                        const SizedBox(height: 8),
                        Text('Intereses: ${perfil!['intereses'] ?? 'No definidos'}', style: Constants.textStyleFont),
                        const SizedBox(height: 8),
                        Text('Disponibilidad: ${perfil!['disponibilidad'] ?? 'No definida'}', style: Constants.textStyleFont),
                      ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // === Botones según tipo ===
          if (esProfesor) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.star),
              label: const Text("Ver valoraciones"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.colorButton,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.supervised_user_circle),
              label: const Text("Mis Estudiantes"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.colorButton,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {},
            ),
            const SizedBox(height: 12),
          ] else ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.star_half),
              label: const Text("Mis Valoraciones"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.colorButton,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {},
            ),
            const SizedBox(height: 12),
          ],

          // === Cambiar contraseña ===
          ElevatedButton.icon(
            icon: const Icon(Icons.lock),
            label: const Text("Cambiar contraseña"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.colorButton,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {},
          ),

          const SizedBox(height: 12),

          // === Cerrar sesión ===
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text("Cerrar sesión"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.colorError,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _logout,
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