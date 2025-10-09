import 'package:flutter/material.dart';
import 'package:my_app/src/custom/CustomBottomNavBar.dart';
import 'package:my_app/src/pages/notificaciones.dart';

class HomeESPage extends StatefulWidget {
  const HomeESPage({super.key});

  @override
  State<HomeESPage> createState() => _HomeESPageState();
}

class _HomeESPageState extends State<HomeESPage> {
  int _selectedIndex = 2; // Home es el índice 2
  bool perfilMejorado = false; // Simulación, cámbialo según tu lógica

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
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
        backgroundColor: Colors.blueGrey[900],
        toolbarHeight: 70,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
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
            if (!perfilMejorado)
              ElevatedButton.icon(
                icon: Icon(Icons.person),
                label: Text('¿Te gustaría mejorar tu perfil?'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () async {
                  // Aquí navegas a la pantalla de edición de perfil
                  // await Navigator.push(...);
                  setState(() {
                    perfilMejorado = true;
                  });
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
            _buildFeatureButton(Icons.description, 'Documentos', () {}),
            SizedBox(height: 20),
            _buildFeatureButton(Icons.school, 'Clases', () {}),
            SizedBox(height: 20),
            _buildFeatureButton(Icons.chat, 'Chat con tutores', () {}),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(selectedIndex: 2, isEstudiante: true), // Cambiado a isEstudiante: true
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
