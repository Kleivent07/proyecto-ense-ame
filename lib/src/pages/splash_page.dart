import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/BackEnd/custom/library.dart';
import 'package:my_app/src/models/usuarios_model.dart';
import 'package:my_app/src/pages/debug/debug_reset_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// ✅ Reset completo de la aplicación
  Future<void> _resetAppCompletely() async {
    try {
      debugPrint('[SPLASH] 🔄 Iniciando reset completo de la app...');
      
      // 1. Cerrar sesión en Supabase
      await Supabase.instance.client.auth.signOut();
      
      // 2. Limpiar todas las SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // 3. Limpiar cualquier caché en memoria (si existe)
      // Aquí puedes agregar más limpieza si tienes otros cachés
      
      debugPrint('[SPLASH] ✅ Reset completo finalizado');
    } catch (e) {
      debugPrint('[SPLASH] ❌ Error en reset completo: $e');
    }
  }

  Future<void> _checkLoginStatus() async {
    if (_navigated) return;
    _navigated = true;

    try {
      // ✅ Verificar primero si hay una sesión válida en Supabase
      final session = Supabase.instance.client.auth.currentSession;
      
      if (session != null) {
        // Verificar si la sesión ha expirado
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
        final now = DateTime.now();
        
        if (now.isAfter(expiresAt)) {
          debugPrint('[SPLASH] ⚠️ Sesión expirada, haciendo reset...');
          await _resetAppCompletely();
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) navigate(context, CustomPages.loginPage);
          return;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final String? tipoUsuario = prefs.getString('tipoUsuario');

      // Espera 2 segundos para mostrar la splash
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      if (isLoggedIn && tipoUsuario != null && session != null) {
        switch (tipoUsuario.toLowerCase()) {
          case 'profesor':
          case 'tutor':
            navigate(context, CustomPages.homeProPage);
            break;
          case 'estudiante':
            navigate(context, CustomPages.homeEsPage);
            break;
          default:
            await _resetAppCompletely();
            navigate(context, CustomPages.loginPage);
        }
      } else {
        // Si no hay sesión válida o datos inconsistentes, hacer reset
        await _resetAppCompletely();
        navigate(context, CustomPages.loginPage);
      }
    } catch (error) {
      debugPrint('[SPLASH] ❌ Error verificando login: $error');
      // En caso de cualquier error, hacer reset completo
      await _resetAppCompletely();
      if (mounted) navigate(context, CustomPages.loginPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorPrimaryDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Constants.colorPrimaryDark,
              Constants.colorPrimary,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo o icono
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Constants.colorBackground.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Constants.colorBackground.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.school,
                  size: 80,
                  color: Constants.colorBackground,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                '¡Enséñame!',
                style: TextStyle(
                  color: Constants.colorBackground,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Conectando estudiantes y tutores',
                style: TextStyle(
                  color: Constants.colorBackground.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 40),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Constants.colorBackground),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                'Cargando...',
                style: TextStyle(
                  color: Constants.colorBackground.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onLongPress: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DebugResetPage(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Mantén presionado para opciones de debug',
                    style: TextStyle(
                      color: Constants.colorBackground.withOpacity(0.3),
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

