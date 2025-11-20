import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/custom/custom_bottom_nav_bar.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/pages/Reuniones/crear_reunion_page.dart';
import 'package:my_app/src/pages/Reuniones/unir_reunion_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReunionesHomePage extends StatefulWidget {
  const ReunionesHomePage({super.key});

  @override
  State<ReunionesHomePage> createState() => _ReunionesHomePageState();
}

class _ReunionesHomePageState extends State<ReunionesHomePage> {
  bool? _isEstudiante;
  bool _isLoading = true;
  String? _userRole;
  String? _userEmail;
  String? _userName;
  bool? _isProfesorInDB;

  // ✅ Cache estático para evitar consultas repetidas
  static String? _cachedUserId;
  static bool? _cachedIsStudent;
  static String? _cachedUserRole;
  static String? _cachedUserName;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 10); // Cache por 10 minutos

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _isEstudiante = true;
          _isLoading = false;
        });
        return;
      }

      _userEmail = user.email;

      // ✅ Verificar caché primero
      final now = DateTime.now();
      if (_cachedUserId == user.id && 
          _cachedIsStudent != null && 
          _cacheTimestamp != null &&
          now.difference(_cacheTimestamp!).compareTo(_cacheDuration) < 0) {
        
        debugPrint('[REUNIONES] 🚀 Usando caché - Carga rápida');
        setState(() {
          _isEstudiante = _cachedIsStudent;
          _userRole = _cachedUserRole;
          _userName = _cachedUserName ?? user.email?.split('@').first ?? 'Usuario';
          _isLoading = false;
        });
        return;
      }

      // ✅ Consulta optimizada: Una sola query con datos necesarios
      debugPrint('[REUNIONES] 📡 Cache expirado - Consultando DB...');
      
      try {
        // Query optimizada que trae todo en una sola consulta
        final result = await Supabase.instance.client
            .from('usuarios')
            .select('clase, nombre, apellido, profesores(id)')
            .eq('id', user.id)
            .maybeSingle();
        
        debugPrint('[REUNIONES] ✅ Datos obtenidos: ${result != null ? "Sí" : "No"}');
        
        if (result != null) {
          // ✅ Determinar rol de forma eficiente
          bool isProfesor = false;
          String rolDetectado = "Estudiante";
          
          // Lógica optimizada de detección
          if (result['profesores'] != null) {
            isProfesor = true;
            rolDetectado = "Profesor (verificado)";
            _isProfesorInDB = true;
          } else {
            final clase = result['clase']?.toString().toLowerCase();
            if (clase == 'tutor' || clase == 'profesor') {
              isProfesor = true;
              rolDetectado = clase == 'tutor' ? "Tutor" : "Profesor";
              _isProfesorInDB = false;
            }
          }

          // ✅ Construir nombre completo
          String userName = 'Usuario';
          if (result['nombre'] != null) {
            userName = result['nombre'].toString();
            if (result['apellido'] != null && result['apellido'].toString().isNotEmpty) {
              userName = '$userName ${result['apellido']}';
            }
          } else {
            userName = user.email?.split('@').first ?? 'Usuario';
          }

          // ✅ Guardar en caché para próximas cargas
          _cachedUserId = user.id;
          _cachedIsStudent = !isProfesor;
          _cachedUserRole = rolDetectado;
          _cachedUserName = userName;
          _cacheTimestamp = now;

          // ✅ Actualizar UI una sola vez
          setState(() {
            _isEstudiante = !isProfesor;
            _userRole = rolDetectado;
            _userName = userName;
            _isLoading = false;
          });

          debugPrint('[REUNIONES] 🎯 Rol: $rolDetectado | Profesor: $isProfesor');
          return;
        }
      } catch (dbError) {
        debugPrint('[REUNIONES] ❌ Error DB: $dbError');
      }

      // ✅ Fallback rápido sin más consultas
      setState(() {
        _isEstudiante = true;
        _userRole = "Estudiante (fallback)";
        _userName = user.email?.split('@').first ?? 'Usuario';
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('[REUNIONES] ❌ Error general: $e');
      setState(() {
        _isEstudiante = true;
        _isLoading = false;
      });
    }
  }

  /// ✅ Método para limpiar caché si es necesario
  static void clearCache() {
    _cachedUserId = null;
    _cachedIsStudent = null;
    _cachedUserRole = null;
    _cachedUserName = null;
    _cacheTimestamp = null;
    debugPrint('[REUNIONES] 🗑️ Cache limpiado');
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Mostrar UI optimizada durante carga
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Constants.colorPrimaryDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Constants.colorAccent),
              ),
              const SizedBox(height: 20),
              Text(
                'Cargando reuniones...',
                style: TextStyle(
                  color: Constants.colorBackground.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Constants.colorPrimaryDark,
      appBar: AppBar(
        backgroundColor: Constants.colorPrimaryDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Constants.colorBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Reuniones',
          style: TextStyle(
            color: Constants.colorBackground,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
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
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ✅ Header optimizado
                _buildUserHeader(),
                const SizedBox(height: 30),
                
                // Título principal
                Text(
                  'Sistema de Reuniones',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Constants.colorBackground,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Gestiona tus sesiones de tutoría de forma fácil y segura',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Constants.colorBackground.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),

                // ✅ Opciones optimizadas
                Expanded(
                  child: Column(
                    children: [
                      // Opción Crear Reunión (solo para profesores)
                      if (!_isEstudiante!) ...[
                        _buildOptionCard(
                          icon: Icons.add_circle_outline,
                          title: 'Crear Reunión',
                          subtitle: 'Programa una nueva sesión con horario personalizado',
                          color: Constants.colorAccent,
                          onTap: () => _navigateToCreateMeeting(),
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      // Opción Unirse a Reunión
                      _buildOptionCard(
                        icon: Icons.videocam,
                        title: 'Unirse a Reunión',
                        subtitle: 'Accede a reuniones programadas o mediante ID',
                        color: Constants.colorError,
                        onTap: () => _navigateToJoinMeeting(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 0,
        isEstudiante: _isEstudiante!,
      ),
    );
  }

  // ✅ Widgets optimizados como métodos separados
  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Constants.colorBackground.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Constants.colorBackground.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bienvenido, $_userName',
                style: TextStyle(
                  color: Constants.colorBackground,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '¡Listo para tu próxima reunión!',
                style: TextStyle(
                  color: Constants.colorBackground.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          // Botón de información para debug (solo en desarrollo)
          if (const bool.fromEnvironment('dart.vm.product') == false)
            IconButton(
              onPressed: _showUserInfo,
              icon: Icon(
                Icons.info_outline,
                color: Constants.colorBackground.withOpacity(0.7),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ Navegación optimizada
  void _navigateToCreateMeeting() {
    debugPrint('[REUNIONES] 🚀 Navegando a crear reunión');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateMeetingPage(),
      ),
    );
  }

  void _navigateToJoinMeeting() {
    debugPrint('[REUNIONES] 🚀 Navegando a unirse a reunión');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JoinMeetingPage(),
      ),
    );
  }

  // ✅ Diálogo de información optimizado
  void _showUserInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información de Usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: $_userEmail'),
            Text('Rol: $_userRole'),
            Text('Tipo: ${_isEstudiante! ? "👨‍🎓 Estudiante" : "👨‍🏫 Profesor"}'),
            const SizedBox(height: 10),
            Text('Cache: ${_cachedUserId != null ? "✅ Activo" : "❌ No"}', 
                 style: TextStyle(fontSize: 12)),
            Text('Profesor DB: ${_isProfesorInDB == true ? "✅ Sí" : "❌ No"}', 
                 style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () {
              clearCache();
              Navigator.pop(context);
              _checkUserRole(); // Recargar sin caché
            },
            child: const Text('Limpiar Cache'),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Constants.colorBackground,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 30,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Constants.colorFont,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Constants.colorFont.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Constants.colorFont.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}