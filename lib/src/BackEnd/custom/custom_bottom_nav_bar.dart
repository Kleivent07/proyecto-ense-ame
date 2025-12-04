import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/pages/Reuniones/reuniones_home_page.dart';
import 'package:my_app/src/pages/Documentos/documentos_whatsapp_page.dart'; // ✨ CAMBIO AQUÍ
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // ✅ Cache estático para evitar consultas repetidas
  static String? _cachedUserId;
  static bool? _cachedIsStudent;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5); // Cache por 5 minutos

  /// Verifica el rol del usuario actual con caché optimizado
  Future<bool> _getUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('[NAVBAR] No hay usuario logueado');
        return true; // Por defecto estudiante
      }

      // ✅ Verificar caché primero
      final now = DateTime.now();
      if (_cachedUserId == user.id && 
          _cachedIsStudent != null && 
          _cacheTimestamp != null &&
          now.difference(_cacheTimestamp!).compareTo(_cacheDuration) < 0) {
        debugPrint('[NAVBAR] Usando caché - Es estudiante: $_cachedIsStudent');
        return _cachedIsStudent!;
      }

      debugPrint('[NAVBAR] Cache expirado o no existe - Consultando DB...');
      
      try {
        // ✅ Consulta optimizada: Una sola query con JOIN
        final result = await Supabase.instance.client
            .from('usuarios')
            .select('clase, profesores(id)')
            .eq('id', user.id)
            .maybeSingle();
        
        debugPrint('[NAVBAR] Resultado DB: $result');
        
        if (result != null) {
          // Determinar rol con lógica simple y rápida
          bool isProfesor = false;
          
          // Si existe en tabla profesores O clase es Tutor/Profesor = es profesor
          if (result['profesores'] != null) {
            isProfesor = true;
          } else if (result['clase']?.toString().toLowerCase() == 'tutor' ||
                     result['clase']?.toString().toLowerCase() == 'profesor') {
            isProfesor = true;
          }
          
          final isStudent = !isProfesor;
          
          // ✅ Guardar en caché
          _cachedUserId = user.id;
          _cachedIsStudent = isStudent;
          _cacheTimestamp = now;
          
          debugPrint('[NAVBAR] Rol detectado y cacheado - Es estudiante: $isStudent');
          return isStudent;
        }
      } catch (dbError) {
        debugPrint('[NAVBAR] Error DB: $dbError');
        // Si falla DB, usar el parámetro como fallback
        return isEstudiante;
      }

      // Fallback final
      debugPrint('[NAVBAR] Sin datos, usando parámetro: $isEstudiante');
      return isEstudiante;
      
    } catch (e) {
      debugPrint('[NAVBAR] Error general: $e');
      return isEstudiante; // Usar parámetro como fallback
    }
  }

  /// Limpia el caché (útil al cambiar usuario o forzar actualización)
  static void clearCache() {
    _cachedUserId = null;
    _cachedIsStudent = null;
    _cacheTimestamp = null;
    debugPrint('[NAVBAR] Cache limpiado');
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Constants.colorButtonOnPress,
      currentIndex: selectedIndex,
      selectedItemColor: Constants.colorError,
      unselectedItemColor: Constants.colorFondo2,
      onTap: (index) async {
        switch (index) {
          case 0:
            // Abrir Reuniones - navegación directa sin verificación
            debugPrint('[NAVBAR] Navegando a Reuniones');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReunionesHomePage()),
            );
            break;
            
          case 1:
            // ✨ DOCUMENTOS - Nueva página tipo WhatsApp
            debugPrint('[NAVBAR] Navegando a Documentos WhatsApp');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DocumentosWhatsappPage()),
            );
            break;
            
          case 2:
            debugPrint('[NAVBAR] Home button pressed');
            
            if (selectedIndex == 2 && onReloadHome != null) {
              debugPrint('[NAVBAR] Recargando página home actual');
              onReloadHome!();
            } else {
              // ✅ Solo verificar rol real para navegación Home
              final isActuallyStudent = await _getUserRole();
              final targetPage = isActuallyStudent ? CustomPages.homeEsPage : CustomPages.homeProPage;
              
              debugPrint('[NAVBAR] Navegando a: $targetPage');
              navigate(context, targetPage, finishCurrent: true);
            }
            break;
            
          case 3:
            debugPrint('[NAVBAR] Chat pressed');
            navigate(context, CustomPages.chatListPage);
            break;
            
          case 4:
            debugPrint('[NAVBAR] Profile pressed');
            navigate(context, CustomPages.perfilPage);
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

