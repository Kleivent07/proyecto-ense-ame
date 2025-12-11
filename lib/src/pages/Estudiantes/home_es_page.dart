import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/custom/custom_bottom_nav_bar.dart';
import 'package:my_app/src/BackEnd/custom/no_teclado.dart';
import 'package:my_app/src/BackEnd/custom/refrescar.dart';
import 'package:my_app/src/BackEnd/custom/auth_guard.dart'; // ✨ AÑADIR IMPORT
import 'package:my_app/src/models/usuarios_model.dart';
import 'package:my_app/src/pages/Estudiantes/buscar_profesores_page.dart';
import 'package:my_app/src/pages/Editar/editar_perfil_page.dart';
import 'package:my_app/src/pages/Estudiantes/lista_solicitud_estudiante_page.dart';
import 'package:my_app/src/pages/Reuniones/meeting_completion_handler.dart';
import 'package:my_app/src/pages/notificaciones.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
// Importaciones para las páginas de navegación
import 'package:my_app/src/pages/Reuniones/reuniones_home_page.dart';
import 'package:my_app/src/pages/Chat/chat_list_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeESPage extends StatefulWidget {
  const HomeESPage({super.key});

  @override
  State<HomeESPage> createState() => _HomeESPageState();
}

class _HomeESPageState extends State<HomeESPage> with TickerProviderStateMixin {
  int selectedIndex = 2; // Home es el índice 2
  Map<String, dynamic>? perfilActual;
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  bool perfilCompleto(Map<String, dynamic> perfil) {
    return (perfil['nombre'] != null &&
            perfil['nombre'].toString().isNotEmpty) &&
        (perfil['apellido'] != null &&
            perfil['apellido'].toString().isNotEmpty) &&
        (perfil['biografia'] != null &&
            perfil['biografia'].toString().isNotEmpty);
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _cargarPerfilActual();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfilActual() async {
    try {
      perfilActual = await Usuario().obtenerPerfil();
      if (mounted) {
        setState(() {});
        _animationController?.forward();
      }
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  // Funciones de navegación
  void _navigateToReuniones() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReunionesHomePage()),
    );
  }

  void _navigateToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatListPage()),
    );
  }

  void _navigateToBuscarProfesores() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BuscarProfesoresPage()),
    );
  }

  void _navigateToSolicitudes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListaSolicitudesEstudiantePage(solicitudes: []),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.construction,
              color: Constants.colorBackground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$feature estará disponible pronto',
                style: Constants.textStyleBLANCO,
              ),
            ),
          ],
        ),
        backgroundColor: Constants.colorAccent,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✨ ENVOLVER TODO CON AUTH GUARD
    return MeetingCompletionHandler(
      child: AuthGuard(
        pageName: 'Home Estudiante',
        shouldCheck: true, // ✨ ACTIVAR VERIFICACIÓN
        child: cerrarTecladoAlTocar(
          child: Scaffold(
            backgroundColor: Constants.colorBackground,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                FutureBuilder<int>(
                  future: NotificacionesPage.obtenerCantidadNoLeidas(),
                  builder: (context, snapshot) {
                    return Stack(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.notifications_rounded,
                            color: Constants.colorBackground,
                            size: 20,
                          ),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificacionesPage()),
                            );
                            if (mounted) setState(() {}); // refresca badge al volver
                          },
                        ),
                        if (snapshot.hasData && snapshot.data! > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              child: Text(
                                '${snapshot.data}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
              toolbarHeight: 60,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Constants.colorPrimary,
                      Constants.colorAccent,
                      Constants.colorPrimaryDark.withOpacity(0.8), // Añadir transición al oscuro
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Constants.colorPrimary, // Color base superior
                    Constants.colorAccent, // Transición media
                    Constants.colorPrimaryDark, // Oscuro hacia abajo
                    Constants.colorPrimaryDark, // Mantener oscuro al final (sin opacidad)
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0], // Ajustar para que sea más oscuro más rápido
                ),
              ),
              // Asegurar que ocupe toda la pantalla
              width: double.infinity,
              height: double.infinity,
              child: SafeArea(
                child: RefreshIndicator(
                  color: Constants.colorBackground,
                  backgroundColor: Constants.colorAccent,
                  onRefresh: () async {
                    await RefrescarHelper.actualizarDatos(
                      context: context,
                      onUpdate: () {
                        setState(() {});
                      },
                    );
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      // Contenedor adicional para asegurar que el contenido tenga el fondo correcto
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height - 
                                   MediaQuery.of(context).padding.top - 
                                   MediaQuery.of(context).padding.bottom - 32,
                      ),
                      child: _buildAnimatedContent(),
                    ),
                  ),
                ),
              ),
            ),

            bottomNavigationBar: CustomBottomNavBar(
              selectedIndex: selectedIndex,
              isEstudiante: true,
              onReloadHome: () {
                RefrescarHelper.actualizarDatos(
                  context: context,
                  onUpdate: () {
                    setState(() {});
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedContent() {
    // Si las animaciones no están inicializadas, mostrar contenido sin animación
    if (_fadeAnimation == null || _slideAnimation == null) {
      return _buildContent();
    }

    return FadeTransition(
      opacity: _fadeAnimation!,
      child: SlideTransition(
        position: _slideAnimation!,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header de bienvenida
        _buildWelcomeHeader(),
        
        const SizedBox(height: 16),
        
        // Aviso de perfil incompleto (si aplica)
        if (perfilActual != null && !perfilCompleto(perfilActual!))
          _buildProfileNotice(),
        
        if (perfilActual != null && !perfilCompleto(perfilActual!))
          const SizedBox(height: 16),
        
        const SizedBox(height: 8),
        
        // Lista de funciones principales
        _buildFeatureList(),
      ],
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Constants.colorBackground,
            Constants.colorBackground.withOpacity(0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Constants.colorAccent.withOpacity(0.1),
                  Constants.colorPrimary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.school_rounded,
              color: Constants.colorAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido a Enseñame 🎓',
                  style: Constants.textStyleFontBold.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Encuentra a tu tutor ideal',
                  style: Constants.textStyleFontSmall.copyWith(
                    color: Constants.colorFont.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Constants.colorAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.star_rounded,
              color: Constants.colorAccent,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileNotice() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Constants.colorPrimaryLight, // Rosa vibrante
            Constants.colorPrimaryLight.withOpacity(0.85), // Transición suave
            Constants.colorSecondary.withOpacity(0.7), // Rosa más suave
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Constants.colorBackground.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Constants.colorPrimaryLight.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Constants.colorSecondary.withOpacity(0.15),
            blurRadius: 35,
            offset: const Offset(0, 15),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Información del perfil incompleto (SIN ICONO)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perfil Incompleto',
                  style: Constants.textStyleFontBold.copyWith(
                    color: Constants.colorBackground, // Blanco para contraste
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        color: Constants.colorPrimaryLight.withOpacity(0.3),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Completa tu perfil para una mejor experiencia',
                  style: Constants.textStyleFontSmall.copyWith(
                    color: Constants.colorBackground.withOpacity(0.9), // Blanco semi-transparente
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Botón elegante
          Container(
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Constants.colorBackground, // Fondo blanco
                  Constants.colorBackground.withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Constants.colorBackground.withOpacity(0.7),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Constants.colorBackground.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton(
              child: Text(
                'Mejorar',
                style: Constants.textStyleFontSemiBold.copyWith(
                  fontSize: 11,
                  color: Constants.colorPrimaryLight, // Texto rosa para contraste
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditarPerfilPage(perfil: perfilActual!),
                  ),
                );

                if (result == true) {
                  await _cargarPerfilActual();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureList() {
    final features = [
      {
        'icon': Icons.search_rounded,
        'title': 'Buscar Profesores',
        'subtitle': 'Encuentra tutores expertos en tu materia',
        'gradient': [Constants.colorPrimaryLight, Constants.colorAccent],
        'bgColor': Constants.colorPrimaryLight,
        'onTap': _navigateToBuscarProfesores,
      },
      {
        'icon': Icons.group_rounded,
        'title': 'Mis Reuniones',
        'subtitle': 'Ver y unirse a sesiones programadas',
        'gradient': [Constants.colorButton, Constants.colorPrimary],
        'bgColor': Constants.colorButton,
        'onTap': _navigateToReuniones,
      },
      {
        'icon': Icons.chat_rounded,
        'title': 'Chat con Tutores',
        'subtitle': 'Comunicación directa con profesores',
        'gradient': [Constants.colorRosa, Constants.colorRosaLight],
        'bgColor': Constants.colorRosa,
        'onTap': _navigateToChat,
      },
      {
        'icon': Icons.assignment_rounded,
        'title': 'Solicitudes',
        'subtitle': 'Gestiona tus solicitudes de tutoría',
        'gradient': [Constants.colorSecondary, Constants.colorAccent],
        'bgColor': Constants.colorSecondary,
        'onTap': _navigateToSolicitudes,
      },
    ];

    return Column(
      children: features.asMap().entries.map((entry) {
        final index = entry.key;
        final feature = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: index < features.length - 1 ? 16 : 0),
          child: _buildElegantFeatureCard(
            icon: feature['icon'] as IconData,
            title: feature['title'] as String,
            subtitle: feature['subtitle'] as String,
            gradientColors: feature['gradient'] as List<Color>,
            bgColor: feature['bgColor'] as Color,
            onTap: feature['onTap'] as VoidCallback,
            index: index,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildElegantFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required Color bgColor,
    required VoidCallback onTap,
    required int index,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Constants.colorBackground,
              Constants.colorBackground.withOpacity(0.98),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Constants.colorPrimaryDark.withOpacity(0.2), // Sombra oscura sutil
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
          border: Border.all(
            color: Constants.colorPrimaryDark.withOpacity(0.1), // Borde oscuro sutil
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                // Eliminamos cualquier decoración adicional en la parte inferior
              ),
              child: Row(
                children: [
                  // Icono con gradiente
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: bgColor.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Constants.colorBackground,
                      size: 28,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Contenido
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Título
                        Text(
                          title,
                          style: Constants.textStyleFontBold.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: bgColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 6),
                        
                        // Subtítulo
                        Text(
                          subtitle,
                          style: Constants.textStyleFontSmall.copyWith(
                            color: Constants.colorFont.withOpacity(0.7),
                            fontSize: 13,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Flecha indicadora con estilo más limpio
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Constants.colorPrimaryDark.withOpacity(0.1),
                          Constants.colorPrimaryDark.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: bgColor,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> completeMeeting(String roomId) async {
    final meeting = await Supabase.instance.client
        .from('meetings')
        .select('id')
        .eq('room_id', roomId)
        .maybeSingle();

    if (meeting != null && meeting['id'] != null) {
      final result = await Supabase.instance.client
          .from('meetings')
          .update({'status': 'completada'})
          .eq('id', meeting['id'])
          .select()
          .maybeSingle();
      return result;
    }
    return null;
  }
}

