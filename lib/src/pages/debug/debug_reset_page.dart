import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/BackEnd/custom/library.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DebugResetPage extends StatelessWidget {
  const DebugResetPage({Key? key}) : super(key: key);

  /// Reset completo de la aplicación
  Future<void> _resetAppCompletely(BuildContext context) async {
    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Reset Completo'),
        content: const Text(
          'Esto eliminará TODOS los datos de la aplicación:\n\n'
          '• Cerrará la sesión actual\n'
          '• Borrará todas las preferencias\n'
          '• Limpiará el caché\n'
          '• Te llevará al login\n\n'
          '¿Estás seguro?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.colorError,
            ),
            child: const Text('SÍ, RESETEAR TODO'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      debugPrint('[RESET] 🔄 Iniciando reset completo...');
      
      // 1. Cerrar sesión en Supabase
      try {
        await Supabase.instance.client.auth.signOut();
        debugPrint('[RESET] ✅ Sesión Supabase cerrada');
      } catch (e) {
        debugPrint('[RESET] ⚠️ Error cerrando sesión Supabase: $e');
      }
      
      // 2. Limpiar todas las SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) { await prefs.remove('onboarding_visto_$userId'); }
        await prefs.clear();
        debugPrint('[RESET] ✅ SharedPreferences limpiadas');
      } catch (e) {
        debugPrint('[RESET] ⚠️ Error limpiando SharedPreferences: $e');
      }
      
      // 3. Esperar un momento para asegurar que todo se limpie
      await Future.delayed(const Duration(seconds: 1));
      
      debugPrint('[RESET] ✅ Reset completo finalizado');
      
      // Cerrar el diálogo de carga
      if (context.mounted) {
        Navigator.pop(context);
        
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Reset completo exitoso. Redirigiendo al login...'),
            backgroundColor: Constants.colorAccent,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Esperar un momento y navegar al login
        await Future.delayed(const Duration(seconds: 2));
        
        if (context.mounted) {
          // Navegar al login y limpiar toda la pila de navegación
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/',
            (route) => false,
          );
        }
      }
      
    } catch (e) {
      debugPrint('[RESET] ❌ Error en reset completo: $e');
      
      if (context.mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error en reset: $e'),
            backgroundColor: Constants.colorError,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorPrimaryDark,
      appBar: AppBar(
        backgroundColor: Constants.colorPrimaryDark,
        elevation: 0,
        title: Text(
          'Debug & Reset',
          style: TextStyle(
            color: Constants.colorBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Constants.colorBackground),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Constants.colorBackground,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 60,
                          color: Constants.colorError,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Reset Completo de la App',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Constants.colorPrimaryDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Si tienes problemas con JWT expirado, sesiones corruptas, o errores persistentes, puedes hacer un reset completo.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Constants.colorPrimaryDark.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Card(
                  color: Constants.colorBackground.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Esto hará:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Constants.colorBackground,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildResetItem('🚪 Cerrar sesión actual'),
                        _buildResetItem('🗑️ Borrar todas las preferencias'),
                        _buildResetItem('🧹 Limpiar caché de la app'),
                        _buildResetItem('🔄 Reiniciar completamente'),
                        _buildResetItem('📱 Llevarte al login'),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _resetAppCompletely(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Constants.colorError,
                    foregroundColor: Constants.colorBackground,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '🔄 RESETEAR APP COMPLETA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Constants.colorBackground.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResetItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              color: Constants.colorBackground.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}