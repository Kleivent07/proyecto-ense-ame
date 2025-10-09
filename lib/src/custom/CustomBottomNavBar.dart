import 'package:flutter/material.dart';
import 'package:my_app/src/custom/library.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final bool isEstudiante;
  final VoidCallback? onReloadHome; // Nuevo parámetro

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.isEstudiante,
    this.onReloadHome,
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
            if (selectedIndex == 2 && onReloadHome != null) {
              // Si ya está en Home, recarga
              onReloadHome!();
            } else {
              // Si no está en Home, navega
              navigate(
                context,
                isEstudiante ? CustomPages.homeEsPage : CustomPages.homeProPage,
                finishCurrent: true,
              );
            }
            break;
          case 3:
            //navigate(context, isEstudiante ? CustomPages.chatPage : CustomPages.chatProPage);
            break;
          case 4:
            navigate(context, isEstudiante ? CustomPages.perfilPage : CustomPages.perfilPage);
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