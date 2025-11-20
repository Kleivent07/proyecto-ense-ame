import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/src/BackEnd/custom/library.dart';

class AuthGuard extends StatefulWidget {
  final Widget child;
  final bool shouldCheck;
  final String pageName;

  const AuthGuard({
    Key? key,
    required this.child,
    this.shouldCheck = true,
    this.pageName = 'Página',
  }) : super(key: key);

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  Timer? _authTimer;
  bool _isChecking = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.shouldCheck) {
      _initAuthGuard();
    }
  }

  @override
  void dispose() {
    _authTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _initAuthGuard() {
    // ✨ VERIFICACIÓN INMEDIATA
    _checkAuthStatus();

    // ✨ LISTENER PARA CAMBIOS DE AUTENTICACIÓN
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      print('[AUTH_GUARD] Estado cambió en ${widget.pageName}: ${data.event}');
      
      if (data.event == AuthChangeEvent.signedOut || data.session == null) {
        _handleAuthFailureImmediate('Usuario cerró sesión');
      }
    });

    // ✨ VERIFICACIÓN PERIÓDICA CADA 15 SEGUNDOS (MÁS FRECUENTE)
    _authTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && !_isChecking) {
        _checkAuthStatus();
      }
    });
  }

  Future<void> _checkAuthStatus() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      final user = client.auth.currentUser;

      // ✨ VERIFICACIONES MÚLTIPLES
      if (session == null || user == null) {
        _handleAuthFailureImmediate('No hay sesión o usuario');
        return;
      }

      // ✨ VERIFICAR EXPIRACIÓN DEL TOKEN
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
      final now = DateTime.now();
      
      if (now.isAfter(expiresAt)) {
        print('[AUTH_GUARD] ❌ Token ya expiró');
        _handleAuthFailureImmediate('Token expirado');
        return;
      }
      
      if (now.isAfter(expiresAt.subtract(const Duration(minutes: 2)))) {
        print('[AUTH_GUARD] Sesión por expirar pronto, intentando renovar...');
        
        try {
          await client.auth.refreshSession();
          print('[AUTH_GUARD] ✅ Sesión renovada exitosamente');
        } catch (e) {
          print('[AUTH_GUARD] ❌ Error renovando sesión: $e');
          _handleAuthFailureImmediate('No se pudo renovar la sesión');
          return;
        }
      }

      // ✨ VERIFICAR CONSISTENCIA CON SHARED PREFERENCES
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      
      if (!isLoggedIn) {
        _handleAuthFailureImmediate('Estado inconsistente en SharedPreferences');
        return;
      }

      // ✨ VERIFICAR QUE EL USUARIO EXISTE EN LA BASE DE DATOS (CON TIMEOUT CORTO)
      try {
        final userResponse = await client
            .from('usuarios')
            .select('id')
            .eq('id', user.id)
            .timeout(const Duration(seconds: 3)); // ✨ TIMEOUT CORTO

        // Si la respuesta es una lista, obtener el primer elemento
        final userData = (userResponse is List && userResponse.isNotEmpty)
            ? userResponse.first
            : userResponse;

        if (userData == null) {
          _handleAuthFailureImmediate('Usuario no existe en la base de datos');
          return;
        }
      } catch (e) {
        print('[AUTH_GUARD] ⚠️ Error verificando usuario en DB: $e');
        
        // ✨ DETECTAR ERRORES 401 (JWT EXPIRED) Y OTROS ERRORES CRÍTICOS
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('jwt expired') || 
            errorString.contains('401') || 
            errorString.contains('unauthorized') ||
            errorString.contains('pgrst303')) {
          print('[AUTH_GUARD] 🚨 ERROR CRÍTICO: JWT expirado - CERRANDO APP');
          _handleAuthFailureImmediate('Token JWT expirado');
          return;
        }
        
        // ✨ TIMEOUT O ERROR DE RED
        if (errorString.contains('timeout') || errorString.contains('network')) {
          print('[AUTH_GUARD] ⚠️ Error de red, verificando nuevamente en 5 segundos');
          // Programar verificación más rápida
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _checkAuthStatus();
          });
          return;
        }
        
        // ✨ CUALQUIER OTRO ERROR - SER PRECAVIDO
        print('[AUTH_GUARD] ❌ Error desconocido - CERRANDO APP por seguridad');
        _handleAuthFailureImmediate('Error crítico de autenticación');
        return;
      }

      print('[AUTH_GUARD] ✅ Verificación completa exitosa en ${widget.pageName}');
      
    } catch (e) {
      print('[AUTH_GUARD] ❌ Error general en verificación: $e');
      _handleAuthFailureImmediate('Error en verificación de autenticación');
    } finally {
      _isChecking = false;
    }
  }

  void _handleAuthFailureImmediate(String reason) {
    print('[AUTH_GUARD] 🚨 FALLA CRÍTICA - CERRANDO APP: $reason');
    
    if (!mounted) return;

    // ✨ LIMPIAR Y REDIRIGIR INMEDIATAMENTE SIN MENSAJES
    _clearAuthData().then((_) {
      if (mounted) {
        // ✨ REDIRIGIR INMEDIATAMENTE SIN ESPERAR
        _redirectToLogin();
      }
    });
  }

  void _redirectToLogin() {
    try {
      // ✨ MÚLTIPLES MÉTODOS DE REDIRECCIÓN PARA ASEGURAR QUE FUNCIONE
      
      // Método 1: Navigator con ruta nombrada
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } catch (e1) {
      print('[AUTH_GUARD] Error método 1: $e1');
      
      try {
        // Método 2: Biblioteca personalizada
        navigate(context, CustomPages.loginPage);
      } catch (e2) {
        print('[AUTH_GUARD] Error método 2: $e2');
        
        try {
          // Método 3: Navigator básico - forzar reemplazo completo
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => _buildLoginRedirect(),
              settings: const RouteSettings(name: '/login'),
            ),
            (route) => false,
          );
        } catch (e3) {
          print('[AUTH_GUARD] Error método 3: $e3 - Usando último recurso');
          
          // Método 4: Último recurso - reemplazar toda la pila
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => _buildLoginRedirect(),
            ),
            (route) => false,
          );
        }
      }
    }
  }

  Widget _buildLoginRedirect() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Redirigiendo al login...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearAuthData() async {
    try {
      // ✨ LIMPIAR DATOS EN PARALELO PARA SER MÁS RÁPIDO
      final futures = [
        Supabase.instance.client.auth.signOut(),
        SharedPreferences.getInstance().then((prefs) => prefs.clear()),
      ];
      
      await Future.wait(futures, eagerError: false);
      
      print('[AUTH_GUARD] ✅ Datos limpiados rápidamente');
    } catch (e) {
      print('[AUTH_GUARD] ⚠️ Error limpiando datos (continuando): $e');
      // No importa si falla, continuamos con la redirección
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// ✨ EXTENSION PARA FÁCIL USO
extension AuthGuardExtension on Widget {
  Widget withAuthGuard({String pageName = 'Página'}) {
    return AuthGuard(
      pageName: pageName,
      child: this,
    );
  }
}