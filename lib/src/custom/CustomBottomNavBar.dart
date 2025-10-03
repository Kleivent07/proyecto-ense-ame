import 'package:flutter/material.dart';
import 'package:my_app/src/custom/library.dart';

class CustomBottomNavBarES extends StatelessWidget {
  final int selectedIndex;

  const CustomBottomNavBarES({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      selectedItemColor: Colors.blueGrey[900],
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        switch (index) {
          case 0:
            //navigate(context, CustomPages.reunionesPage);
            break;
          case 1:
            //navigate(context, CustomPages.documentosPage);
            break;
          case 2:
            //navigate(context, CustomPages.homeProPage, finishCurrent: true);
            break;
          case 3:
            //navigate(context, CustomPages.chatPage);
            break;
          case 4:
            navigate(context, CustomPages.perfilPage);
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
