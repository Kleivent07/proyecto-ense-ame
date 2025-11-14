import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/BackEnd/custom/library.dart';
import 'package:my_app/src/models/usuarios_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _navigated = false;
  final Usuario usuario = Usuario();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    if (_navigated) return;
    _navigated = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final String? tipoUsuario = prefs.getString('tipoUsuario');

      // Espera 2 segundos para mostrar la splash
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      if (isLoggedIn && tipoUsuario != null) {
        switch (tipoUsuario.toLowerCase()) {
          case 'profesor':
            navigate(context, CustomPages.homeProPage);
            break;
          case 'estudiante':
            navigate(context, CustomPages.homeEsPage);
            break;
          default:
            navigate(context, CustomPages.loginPage);
        }
      } else {
        usuario.logout();
        navigate(context, CustomPages.loginPage);
      }
    } catch (error) {
      // En caso de error, siempre redirige al login
      usuario.logout();
      if (mounted) navigate(context, CustomPages.loginPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Puedes reemplazar este texto por un logo o animación
            const Icon(Icons.school, size: 80, color: Colors.white),
            const SizedBox(height: 20),
            Text(
              '¡Enséñame!',
              style: TextStyle(
                color: Constants.colorFont,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

