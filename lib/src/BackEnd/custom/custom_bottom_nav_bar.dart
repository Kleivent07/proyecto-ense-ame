import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/pages/Reuniones/reuniones_home_page.dart';

import 'library.dart';


class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final bool isEstudiante;
  final VoidCallback? onReloadHome;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.isEstudiante,
    this.onReloadHome,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Constants.colorButtonOnPress,
      currentIndex: selectedIndex,
      selectedItemColor: Constants.colorError,
      unselectedItemColor: Constants.colorFondo2,
      onTap: (index) {
        switch (index) {
          case 0:
            // Abrir Reuniones desde el primer botón
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReunionesHomePage()),
            );
            break;
          case 1:
            // navegar a Documentos (ajusta si necesitas)
            // navigate(context, isEstudiante ? CustomPages.documentosPage : CustomPages.documentosProPage);
            break;
          case 2:
            if (selectedIndex == 2 && onReloadHome != null) {
              onReloadHome!();
            } else {
              navigate(
                context,
                isEstudiante ? CustomPages.homeEsPage : CustomPages.homeProPage,
                finishCurrent: true,
              );
            }
            break;
          case 3:
            print('[NAVBAR] Chat pressed');
            navigate(context, CustomPages.chatListPage);
            break;
          case 4:
            navigate(
              context,
              CustomPages.perfilPage,
            );
            break;
        }
      },
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.video_call), label: 'Reuniones'),
        BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Documentos'),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ],
    );
  }
}

