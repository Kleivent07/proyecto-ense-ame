import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/src/custom/constants.dart';
import 'package:my_app/src/custom/library.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {

  @override
  void initState() {
    super.initState();
    globalContext = context;
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final tipoUsuario = prefs.getString('tipoUsuario');

    Timer(const Duration(seconds: 2), () {
      if (isLoggedIn) {
        if (tipoUsuario == 'profesor') {
          navigate(context, CustomPages.homeProPage);
        } else if (tipoUsuario == 'estudiante') {
          navigate(context, CustomPages.homeEsPage);
        }
      } else {
        navigate(globalContext!, CustomPages.loginPage);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Constants.colorBackground,
        alignment: Alignment.center,
        child: Text(
          'Icono en proceso',
          style: TextStyle(
            color: Constants.colorFont,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}