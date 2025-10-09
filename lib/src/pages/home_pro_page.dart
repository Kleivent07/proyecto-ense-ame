import 'package:flutter/material.dart';
import 'package:my_app/src/custom/CustomBottomNavBar.dart';
import 'package:my_app/src/pages/notificaciones.dart';


class HomePROPage extends StatefulWidget {
  const HomePROPage({super.key});

  @override
  State<HomePROPage> createState() => _HomePROPageState();
}

class _HomePROPageState extends State<HomePROPage> {
  // ignore: prefer_final_fields
  int _selectedIndex = 2; // Home es el índice 2

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
          children: [
            // Widgets tipo botón
            _buildFeatureButton(Icons.group, 'Reuniones', () {}),
            SizedBox(height: 20),
            _buildFeatureButton(Icons.description, 'Documentos', () {}),
            SizedBox(height: 20),
            _buildFeatureButton(Icons.school, 'Clases', () {}),
            // Puedes agregar más aquí
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(selectedIndex: _selectedIndex),
    );
  }

  Widget _buildFeatureButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap, // No funcional aún
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