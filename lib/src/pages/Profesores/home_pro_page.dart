import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/custom/custom_bottom_nav_bar.dart';
import 'package:my_app/src/BackEnd/custom/no_teclado.dart';
import 'package:my_app/src/BackEnd/custom/refrescar.dart';
import 'package:my_app/src/BackEnd/custom/auth_guard.dart'; // ✨ AÑADIR IMPORT
import 'package:my_app/src/models/usuarios_model.dart';
import 'package:my_app/src/pages/Editar/editar_perfil_page.dart';
import 'package:my_app/src/pages/notificaciones.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';

class HomePROPage extends StatefulWidget {
  const HomePROPage({super.key});

  @override
  State<HomePROPage> createState() => _HomePROPageState();
}

class _HomePROPageState extends State<HomePROPage> with TickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    // ✨ ENVOLVER TODO CON AUTH GUARD
    return AuthGuard(
      pageName: 'Home Profesor',
      shouldCheck: true, // ✨ ACTIVAR VERIFICACIÓN
      child: Scaffold(
        backgroundColor: Constants.colorBackground,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Constants.colorBackground.withOpacity(0.2),
                    Constants.colorBackground.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Constants.colorBackground.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.notifications_rounded,
                  color: Constants.colorBackground,
                  size: 20,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificacionesPage()),
                  );
                },
              ),
            ),
          ],
          toolbarHeight: 60,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Constants.colorPrimaryDark,
                  Constants.colorButton,
                ],
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
                Constants.colorPrimaryDark,
                Constants.colorButton,
                Constants.colorOnPrimary.withOpacity(0.1),
              ],
              stops: const [0.0, 0.7, 1.0],
            ),
          ),
          child: SafeArea(
            child: RefreshIndicator(
              color: Constants.colorBackground,
              backgroundColor: Constants.colorButton,
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
                child: _buildAnimatedContent(),
              ),
            ),
          ),
        ),

        bottomNavigationBar: CustomBottomNavBar(
          selectedIndex: selectedIndex,
          isEstudiante: false,
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
        // Header de bienvenida (más pequeño)
        _buildWelcomeHeader(),
        
        const SizedBox(height: 16),
        
        // Aviso de perfil incompleto (si aplica)
        if (perfilActual != null && !perfilCompleto(perfilActual!))
          _buildProfileNotice(),
        
        if (perfilActual != null && !perfilCompleto(perfilActual!))
          const SizedBox(height: 16),
        
        const SizedBox(height: 8),
        
        // Lista de funciones principales (columnas verticales)
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
                  Constants.colorButton.withOpacity(0.1),
                  Constants.colorOnPrimary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.school_rounded,
              color: Constants.colorButton,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido, Profesor 👋',
                  style: Constants.textStyleFontBold.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Gestiona tu experiencia educativa',
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
              color: Constants.colorButton.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.verified_rounded,
              color: Constants.colorButton,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Constants.colorRosa.withOpacity(0.1),
            Constants.colorRosaLight.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Constants.colorRosa.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Constants.colorRosa.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Constants.colorRosa.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_add_rounded,
                  color: Constants.colorRosa,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perfil Incompleto',
                      style: Constants.textStyleFontBold.copyWith(
                        color: Constants.colorRosa,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Completa tu perfil para una mejor experiencia',
                      style: Constants.textStyleFontSmall.copyWith(
                        color: Constants.colorFont.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Constants.colorRosa,
                    Constants.colorRosaLight,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Constants.colorRosa.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: Text(
                  'Mejorar Perfil',
                  style: Constants.textStyleBLANCOSemiBold.copyWith(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureList() {
    final features = [
      {
        'icon': Icons.group_rounded,
        'title': 'Reuniones',
        'subtitle': 'Crear y gestionar reuniones con estudiantes. Programa sesiones de tutoría individuales o grupales.',
        'color': Constants.colorButton,
        'gradient': [Constants.colorButton, Constants.colorOnPrimary],
      },
      {
        'icon': Icons.description_rounded,
        'title': 'Documentos',
        'subtitle': 'Administrar recursos y material educativo. Comparte archivos, presentaciones y guías de estudio.',
        'color': Constants.colorAccent,
        'gradient': [Constants.colorAccent, Constants.colorPrimary],
      },
      {
        'icon': Icons.people_rounded,
        'title': 'Estudiantes',
        'subtitle': 'Gestionar estudiantes asignados',
        'color': Constants.colorRosa,
        'gradient': [Constants.colorRosa, Constants.colorRosaLight],
        'onTap': () => _showComingSoon('Gestión de Estudiantes'), // Cambiar esta línea
      },
      {
        'icon': Icons.settings_rounded,
        'title': 'Configuración',
        'subtitle': 'Personalizar preferencias, horarios disponibles y configuración de la cuenta.',
        'color': Constants.colorOnPrimary,
        'gradient': [Constants.colorOnPrimary, Constants.colorSurface],
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
            onTap: () {
              // Ejecutar la función onTap si está definida, de lo contrario, no hacer nada
              if (feature['onTap'] != null) {
                (feature['onTap'] as VoidCallback).call();
              }
            },
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
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Icono con gradiente
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          gradientColors[0].withOpacity(0.15),
                          gradientColors[1].withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      color: gradientColors[0],
                      size: 28,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Contenido
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título
                        Text(
                          title,
                          style: Constants.textStyleFontBold.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        
                        const SizedBox(height: 6),
                        
                        // Subtítulo
                        Text(
                          subtitle,
                          style: Constants.textStyleFontSmall.copyWith(
                            color: Constants.colorFont.withOpacity(0.7),
                            fontSize: 13,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Flecha indicadora
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          gradientColors[0].withOpacity(0.15),
                          gradientColors[1].withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: gradientColors[0],
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

  void _showComingSoon(String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Constants.colorBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Constants.colorButton,
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  'Funcionalidad en Desarrollo',
                  style: Constants.textStyleFontBold.copyWith(
                    fontSize: 18,
                    color: Constants.colorFont,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'La $feature estará disponible pronto. ¡Esté atento a las actualizaciones!',
                  style: Constants.textStyleFontSmall.copyWith(
                    color: Constants.colorFont.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Constants.colorButton,
                    foregroundColor: Constants.colorBackground,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Aceptar',
                    style: Constants.textStyleBLANCOSemiBold.copyWith(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

