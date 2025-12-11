import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/custom/custom_bottom_nav_bar.dart';
import 'package:my_app/src/BackEnd/services/notifications_service.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/models/reuniones_model.dart';
import 'package:my_app/src/pages/Reuniones/crear_reunion_page.dart';
import 'package:my_app/src/pages/Reuniones/unir_es_page.dart';
import 'package:my_app/src/pages/Reuniones/unir_pro_page.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

 // Asegúrate de que la ruta sea correcta

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

    // Si es estudiante, solo muestra el widget de agendar
    if (_isEstudiante == true) {
      return Scaffold(
        backgroundColor: Constants.colorPrimaryDark,
        appBar: AppBar(
          title: const Text('Reuniones'),
          backgroundColor: Constants.colorPrimaryDark,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Constants.colorBackground),
          titleTextStyle: TextStyle(
            color: Constants.colorBackground,
            fontWeight: FontWeight.bold,
            fontSize: 22,
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildStudentJoinMeeting(),
          ),
        ),
        bottomNavigationBar: CustomBottomNavBar(
          selectedIndex: 0,
          isEstudiante: _isEstudiante!,
        ),
      );
    }

    // Si es profesor, muestra la lista de reuniones
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
                
                // ✅ Sección adicional para estudiantes
                if (_isEstudiante!) ...[
                  const SizedBox(height: 24),
                  Text('Tus reuniones agendadas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  _buildStudentMeetingsList(),
                ],
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
    if (_isEstudiante == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UnirESPage(),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UnirPROPage(),
        ),
      );
    }
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

  void _enviarNotificacionPrueba() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await NotificationsService.showNotification(
      title: '¡Hola!',
      body: 'Esta es una notificación solo para ti.',
      userId: userId,
      tipo: 'prueba',
      referenciaId: null,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notificación enviada')),
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

  Widget _buildStudentJoinMeeting() {
    final TextEditingController _codeController = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card para agendar reunión (más bonita y moderna)
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Constants.colorBackground,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Constants.colorPrimaryDark.withOpacity(0.13),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Constants.colorPrimary.withOpacity(0.18),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Constants.colorAccent.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Icon(Icons.event_available, color: Constants.colorAccent, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Agendar reunión',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                        color: Constants.colorAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Si tienes un código de reunión, ingrésalo aquí para agendarla en tu perfil.',
                  style: TextStyle(fontSize: 14, color: Constants.colorFont.withOpacity(0.7)),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          hintText: 'Código de reunión',
                          filled: true,
                          fillColor: Constants.colorBackground.withOpacity(0.97),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Constants.colorPrimary, width: 1.2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        style: TextStyle(fontSize: 15, color: Constants.colorFont),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save_alt, size: 18),
                      label: const Text('Agendar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Constants.colorAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final code = _codeController.text.trim();
                        if (code.isEmpty) return;

                        final meeting = await MeetingModel().findByRoom(code);
                        if (meeting != null) {
                          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                          try {
                            await Supabase.instance.client.from('student_meetings').insert({
                              'student_id': currentUserId,
                              'meeting_id': meeting['id'],
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('¡Reunión agendada exitosamente!')),
                            );
                            // Notificación para nueva reunión agendada
                            final fecha = meeting['fecha_hora'] != null
                                ? DateTime.tryParse(meeting['fecha_hora'])
                                : (meeting['scheduled_at'] != null
                                    ? DateTime.tryParse(meeting['scheduled_at'])
                                    : null);

                            final roomId = meeting['room_id'] ?? '';

                            // Notificación inmediata en BD para que el badge se actualice ya
                            await NotificationsService.showNotification(
                              title: 'Reunión agendada',
                              body: 'Tu reunión ha sido agendada para ${fecha != null ? DateFormat('dd/MM/yyyy • HH:mm').format(fecha.toLocal()) : 'fecha desconocida'}.',
                              userId: currentUserId!,
                              tipo: 'reunion_agendada',
                              referenciaId: roomId.isNotEmpty ? roomId : meeting['id']?.toString(),
                            );
                            setState(() {});
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('No tienes autorización para agendar esta reunión. (ID inválida o sin permisos)')),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Código inválido o reunión no encontrada')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Card para unirse a reunión (mantén el estilo moderno de opción)
        _buildOptionCard(
          icon: Icons.video_call,
          title: 'Unirse a reunión',
          subtitle: 'Accede directamente a la videollamada si ya tienes agendada la reunión.',
          color: Constants.colorPrimary,
          onTap: () {
            _navigateToJoinMeeting();
          },
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> obtenerReunionesAgendadas() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    final relaciones = await Supabase.instance.client
        .from('student_meetings')
        .select('meeting_id')
        .eq('student_id', userId);

    if (relaciones == null || relaciones.isEmpty) return [];

    final ids = relaciones.map((r) => r['meeting_id']).toList();
    if (ids.isEmpty) return [];

    final reuniones = await Supabase.instance.client
        .from('meetings')
        .select()
        .inFilter('id', ids);

    return List<Map<String, dynamic>>.from(reuniones);
  }

  Widget _buildStudentMeetingsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: obtenerReunionesAgendadas(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Constants.colorAccent),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error al cargar reuniones',
              style: TextStyle(color: Constants.colorError),
            ),
          );
        }

        final reuniones = snapshot.data;
        if (reuniones == null || reuniones.isEmpty) {
          return Center(
            child: Text(
              'No tienes reuniones agendadas',
              style: TextStyle(color: Constants.colorFont.withOpacity(0.7)),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: reuniones.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final reunion = reuniones[index];
            // <-- cambio: usar scheduled_at con fallback y parse seguro
            final fechaIso = reunion['scheduled_at'] ?? reunion['fecha_hora'] ?? '';
            final fechaHora = DateTime.tryParse(fechaIso)?.toLocal();
            final fechaFormateada = fechaHora != null
                ? '${fechaHora.day}/${fechaHora.month}/${fechaHora.year}'
                : 'Fecha desconocida';
            final horaFormateada = fechaHora != null
                ? '${fechaHora.hour.toString().padLeft(2,'0')}:${fechaHora.minute.toString().padLeft(2,'0')}'
                : '--:--';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Constants.colorPrimaryDark.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Constants.colorPrimaryDark,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reunion['titulo'] ?? 'Reunión sin título',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Constants.colorFont,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fecha: $fechaFormateada',
                    style: TextStyle(
                      fontSize: 14,
                      color: Constants.colorFont.withOpacity(0.8),
                    ),
                  ),
                  Text(
                    'Hora: $horaFormateada',
                    style: TextStyle(
                      fontSize: 14,
                      color: Constants.colorFont.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // Acción para unirse a la reunión
                          _joinMeeting(reunion['id']);
                        },
                        icon: Icon(Icons.video_call),
                        label: Text('Unirse'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Constants.colorPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Acción para cancelar la reunión
                          _cancelMeeting(reunion['id']);
                        },
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Constants.colorError,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _joinMeeting(String meetingId) {
    // Lógica para unirse a la reunión
    debugPrint('Unirse a la reunión con ID: $meetingId');
    // Aquí puedes navegar a la página de reunión o abrir el enlace de la videollamada
  }

  void _cancelMeeting(String meetingId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Eliminar la relación de la reunión agendada
    await Supabase.instance.client
        .from('student_meetings')
        .delete()
        .eq('student_id', userId)
        .eq('meeting_id', meetingId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reunión cancelada')),
    );

    setState(() {}); // Refrescar la lista de reuniones agendadas
  }
}