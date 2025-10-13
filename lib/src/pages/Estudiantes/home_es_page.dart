import 'package:flutter/material.dart';
import 'package:my_app/src/custom/CustomBottomNavBar.dart';
import 'package:my_app/src/custom/library.dart';
import 'package:my_app/src/custom/refrescar.dart';
import 'package:my_app/src/models/usuarios_model.dart';
import 'package:my_app/src/pages/Estudiantes/buscar_profesores_page.dart';
import 'package:my_app/src/pages/editar_perfil_page.dart';
import 'package:my_app/src/pages/notificaciones.dart';
import 'package:my_app/src/util/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeESPage extends StatefulWidget {
  const HomeESPage({super.key});

  @override
  State<HomeESPage> createState() => _HomeESPageState();
}

class _HomeESPageState extends State<HomeESPage> {
  int selectedIndex = 2; // Home es el índice 2
  Map<String, dynamic>? perfilActual;

bool perfilCompleto(Map<String, dynamic> perfil) {
    return (perfil['nombre'] != null && perfil['nombre'].toString().isNotEmpty) &&
          (perfil['apellido'] != null && perfil['apellido'].toString().isNotEmpty) &&
          (perfil['biografia'] != null && perfil['biografia'].toString().isNotEmpty);
  }
  bool cargando = true;

    @override
  void initState() {
    super.initState();
    _cargarPerfilActual();
  }
  Future<void> _cargarPerfilActual() async {
  perfilActual = await Usuario().obtenerPerfil();
  setState(() {});
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: TextField(
          onTap: () {
              // Navega a la pantalla de búsqueda de profesores
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuscarProfesoresPage()),
              );
          },
          decoration: InputDecoration(
            hintText: 'Buscar...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificacionesPage()),
              );
            },
          ),
        ],
        backgroundColor: Constants.colorPrimary,
        toolbarHeight: 70,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: RefreshIndicator(
          onRefresh: () async {
            await RefrescarHelper.actualizarDatos(
              context: context,
              onUpdate: () {
                setState(() {
                  // Aquí actualizas los datos del Home
                });
              },
            );// Tu función de recarga
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido a Enseñame',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900],
                  ),
                ),
                SizedBox(height: 12),
                if (perfilActual != null && !perfilCompleto(perfilActual!))
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person),
                    label: const Text('¿Te gustaría mejorar tu perfil?'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Constants.colorButtonOnPress,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditarPerfilPage(perfil: perfilActual!),
                        ),
                      );

                      if (result == true) {
                        // Recarga el perfil desde Supabase después de guardar cambios
                        perfilActual = await Usuario().obtenerPerfil();
                        setState(() {}); // esto ocultará el botón si el perfil ahora está completo
                      }
                    },
                  ),

                SizedBox(height: 24),
                // Botón destacado para la reunión actual
                Card(
                  color: Colors.green[100],
                  child: ListTile(
                    leading: Icon(Icons.video_call, color: Colors.green[800]),
                    title: Text('Ir a la reunión actual'),
                    subtitle: Text('Reunión con el tutor Juan Pérez'),
                    trailing: Icon(Icons.arrow_forward_ios, color: Colors.green[800]),
                    onTap: () {
                      // Navega a la reunión actual
                    },
                  ),
                ),
                SizedBox(height: 24),
                // Botones específicos para estudiantes
                _buildFeatureButton(Icons.group, 'Reuniones', () {}),
                SizedBox(height: 20),
                _buildFeatureButton(Icons.school, 'Clases', () {}),
                SizedBox(height: 20),
                _buildFeatureButton(Icons.chat, 'Chat con tutores', () {}),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: selectedIndex,
        isEstudiante: true,
        onReloadHome: () {
          RefrescarHelper.actualizarDatos(
            context: context,
            onUpdate: () {
              setState(() {
                // Aquí actualizas los datos del Home
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildFeatureButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blueGrey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Colors.blueGrey[900]),
            SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                color: Colors.blueGrey[900],
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            Icon(Icons.arrow_forward_ios, color: Colors.blueGrey[900]),
          ],
        ),
      ),
    );
  }
}