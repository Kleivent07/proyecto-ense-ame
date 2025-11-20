import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static bool _isInitialized = false;
  static bool _isRefreshing = false;

  /// Inicializar el servicio de autenticación
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final client = Supabase.instance.client;
      
      // Configurar listener para cambios de autenticación
      client.auth.onAuthStateChange.listen((data) async {
        final event = data.event;
        debugPrint('[AUTH] Estado cambió: $event');

        switch (event) {
          case AuthChangeEvent.signedIn:
            await _saveLoginState(true);
            break;
          case AuthChangeEvent.signedOut:
            await _saveLoginState(false);
            break;
          case AuthChangeEvent.tokenRefreshed:
            debugPrint('[AUTH] Token renovado');
            break;
          default:
            break;
        }
      });

      _isInitialized = true;
      debugPrint('[AUTH] Servicio inicializado');
      
    } catch (e) {
      debugPrint('[AUTH] Error inicializando: $e');
    }
  }

  /// Ejecutar operación con manejo de token expirado
  static Future<T?> executeWithTokenCheck<T>(Future<T> Function() operation) async {
    try {
      // Intentar la operación directamente
      return await operation();
      
    } catch (e) {
      // Si es error de JWT expirado, intentar renovar
      if (e.toString().contains('JWT expired') || e.toString().contains('PGRST303')) {
        debugPrint('[AUTH] JWT expirado, renovando...');
        
        try {
          await _refreshToken();
          // Reintentar la operación
          return await operation();
        } catch (refreshError) {
          debugPrint('[AUTH] Error renovando: $refreshError');
          return null;
        }
      }
      
      // Si no es error de JWT, relanzar el error
      rethrow;
    }
  }

  /// Renovar token de autenticación
  static Future<void> _refreshToken() async {
    if (_isRefreshing) return;
    
    try {
      _isRefreshing = true;
      final client = Supabase.instance.client;
      await client.auth.refreshSession();
      debugPrint('[AUTH] Token renovado exitosamente');
    } finally {
      _isRefreshing = false;
    }
  }

  /// Guardar estado de login
  static Future<void> _saveLoginState(bool isLoggedIn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', isLoggedIn);
      
      if (!isLoggedIn) {
        await prefs.remove('tipoUsuario');
      }
    } catch (e) {
      debugPrint('[AUTH] Error guardando estado: $e');
    }
  }

  /// Verificar si está logueado
  static Future<bool> isLoggedIn() async {
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      return session != null;
    } catch (e) {
      debugPrint('[AUTH] Error verificando login: $e');
      return false;
    }
  }

  /// Forzar renovación de token
  static Future<bool> forceRefreshToken() async {
    try {
      await _refreshToken();
      return true;
    } catch (e) {
      debugPrint('[AUTH] Error forzando renovación: $e');
      return false;
    }
  }
}