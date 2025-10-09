// ignore: file_names
import 'package:flutter/material.dart';
import 'package:my_app/src/custom/library.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final bool isEstudiante; // true = estudiante, false = profesor

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.isEstudiante,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      selectedItemColor: Colors.blueGrey[900],
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        switch (index) {
          case 0:
            //navigate(context, isEstudiante ? CustomPages.reunionesPage : CustomPages.reunionesProPage);
            break;
          case 1:
            //navigate(context, isEstudiante ? CustomPages.documentosPage : CustomPages.documentosProPage);
            break;
          case 2:
            navigate(
              context,
              isEstudiante ? CustomPages.homeEsPage : CustomPages.homeProPage,
              finishCurrent: true,
            );
            break;
          case 3:
            navigate(context, isEstudiante ? CustomPages.chatPage : CustomPages.chatProPage);
            break;
          case 4:
            navigate(context, isEstudiante ? CustomPages.perfilPage : CustomPages.perfilProPage);
            break;
        }
      },
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Reuniones'),
        BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Documentos'),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ],
    );
  }
}

// Ejemplo de uso
CustomBottomNavBar(selectedIndex: 2, isEstudiante: true); // Para estudiantes
CustomBottomNavBar(selectedIndex: 2, isEstudiante: false); // Para profesores
