import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/custom/custom_bottom_nav_bar.dart';
import 'package:my_app/src/BackEnd/custom/no_teclado.dart';
import 'package:my_app/src/BackEnd/custom/refrescar.dart';
import 'package:my_app/src/models/usuarios_model.dart';
import 'package:my_app/src/pages/Editar/editar_perfil_page.dart';
import 'package:my_app/src/pages/notificaciones.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';

class HomePROPage extends StatefulWidget {
  const HomePROPage({super.key});

  @override
  State<HomePROPage> createState() => _HomePROPageState();
}

class _HomePROPageState extends State<HomePROPage> {
  int selectedIndex = 2; // Home es el índice 2
  Map<String, dynamic>? perfilActual;
  bool perfilCompleto(Map<String, dynamic> perfil) {
    return (perfil['nombre'] != null &&
            perfil['nombre'].toString().isNotEmpty) &&
        (perfil['apellido'] != null &&
            perfil['apellido'].toString().isNotEmpty) &&
        (perfil['biografia'] != null &&
            perfil['biografia'].toString().isNotEmpty);
  } // Simulación — puedes reemplazar por lógica real

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
    return cerrarTecladoAlTocar(
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 16,
              ),
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
          backgroundColor: Colors.blueGrey[900],
          toolbarHeight: 70,
        ),

        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: RefreshIndicator(
            onRefresh: () async {
              await RefrescarHelper.actualizarDatos(
                context: context,
                onUpdate: () {
                  setState(() {});
                },
              );
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Si el perfil está incompleto, muestra el aviso:
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
                            builder: (context) =>
                                EditarPerfilPage(perfil: perfilActual!),
                          ),
                        );

                        if (result == true) {
                          // Recarga el perfil desde Supabase después de guardar cambios
                          perfilActual = await Usuario().obtenerPerfil();
                          setState(
                            () {},
                          ); // esto ocultará el botón si el perfil ahora está completo
                        }
                      },
                    ),
                  const SizedBox(height: 12),

                  // Reunión actual o bienvenida
                  Text(
                    'Bienvenido, Profesor 👋',
                    style: TextStyle(
                      color: Colors.blueGrey[900],
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildFeatureButton(Icons.group, 'Reuniones', () {}),
                  const SizedBox(height: 20),
                  _buildFeatureButton(Icons.description, 'Documentos', () {}),
                  const SizedBox(height: 20),
                  _buildFeatureButton(Icons.school, 'Clases', () {}),
                  const SizedBox(height: 20),
                  _buildFeatureButton(
                    Icons.bar_chart,
                    'Historial de Tutorías',
                    () {},
                  ),
                ],
              ),
            ),
          ),
        ),

        bottomNavigationBar: CustomBottomNavBar(
          selectedIndex: selectedIndex,
          isEstudiante: false,
          onReloadHome: () {
            RefrescarHelper.actualizarDatos(
              context: context,
              onUpdate: () {
                setState(() {});
              },
            );
          },
        ),
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
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade400,
              blurRadius: 4,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Colors.blueGrey[900]),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                color: Colors.blueGrey[900],
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: Colors.blueGrey[900]),
          ],
        ),
      ),
    );
  }
}

