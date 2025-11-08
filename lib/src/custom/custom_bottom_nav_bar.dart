import 'package:flutter/material.dart';
import '../custom/library.dart';
import '../util/constants.dart';

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
            // El botón 0 anteriormente abría Reuniones; ahora navegamos al Home.
            navigate(
              context,
              isEstudiante ? CustomPages.homeEsPage : CustomPages.homeProPage,
              finishCurrent: true,
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
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
        BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Documentos'),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
      ],
    );
  }
}

