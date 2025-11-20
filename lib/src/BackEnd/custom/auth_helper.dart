import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthHelper {
  /// Logout completo y limpieza de datos
  static Future<void> completeLogout() async {
    try {
      debugPrint('[AUTH_HELPER] Iniciando logout completo...');
      
      // 1. Cerrar sesión en Supabase
      final client = Supabase.instance.client;
      await client.auth.signOut();
      debugPrint('[AUTH_HELPER] ✅ Sesión de Supabase cerrada');
      
      // 2. Limpiar SharedPreferences completamente
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('[AUTH_HELPER] ✅ SharedPreferences limpiado');
      
      // 3. Esperar un momento para que se procesen los cambios
      await Future.delayed(const Duration(milliseconds: 500));
      
      debugPrint('[AUTH_HELPER] 🚀 Logout completo exitoso');
      
    } catch (e) {
      debugPrint('[AUTH_HELPER] ❌ Error en logout completo: $e');
      // Incluso si hay error, intentar limpiar SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (_) {}
    }
  }
  
  /// Verificar estado de autenticación actual
  static Future<Map<String, dynamic>> checkAuthStatus() async {
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      final user = client.auth.currentUser;
      
      return {
        'has_session': session != null,
        'has_user': user != null,
        'user_id': user?.id,
        'user_email': user?.email,
        'expires_at': session?.expiresAt,
        'is_expired': session != null ? 
          DateTime.now().millisecondsSinceEpoch > (session.expiresAt ?? 0) * 1000 : 
          true,
      };
    } catch (e) {
      return {
        'has_session': false,
        'has_user': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Forzar renovación de token si es posible
  static Future<bool> forceTokenRefresh() async {
    try {
      debugPrint('[AUTH_HELPER] Intentando renovar token...');
      final client = Supabase.instance.client;
      final response = await client.auth.refreshSession();
      
      if (response.session != null) {
        debugPrint('[AUTH_HELPER] ✅ Token renovado exitosamente');
        return true;
      } else {
        debugPrint('[AUTH_HELPER] ❌ No se pudo renovar token');
        return false;
      }
    } catch (e) {
      debugPrint('[AUTH_HELPER] ❌ Error renovando token: $e');
      return false;
    }
  }
}