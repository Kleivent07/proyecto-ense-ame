import 'package:flutter/material.dart';
import 'package:my_app/src/models/profesores_model.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/models/solicitud_model.dart';
import 'package:my_app/src/BackEnd/custom/solicitud_data.dart';
import 'package:my_app/src/BackEnd/custom/no_teclado.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PerfilTutorPage extends StatefulWidget {
  final String tutorId;

  const PerfilTutorPage({super.key, required this.tutorId});

  @override
  State<PerfilTutorPage> createState() => _PerfilTutorPageState();
}

class _PerfilTutorPageState extends State<PerfilTutorPage> with TickerProviderStateMixin {
  Map<String, dynamic>? tutor;
  bool isLoading = true;
  final solicitudModel = SolicitudModel();
  String estadoSolicitud = 'none';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    cargarTutor();
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
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> cargarTutor() async {
    final profService = ProfesorService();
    final data = await profService.obtenerTutor(widget.tutorId);

    setState(() {
      tutor = data;
      isLoading = false;
    });

    if (mounted) {
      _animationController.forward();
    }

    final estudianteId = Supabase.instance.client.auth.currentUser?.id;
    if (estudianteId != null) {
      verificarEstadoSolicitud(estudianteId, widget.tutorId);
    }
  }

  Future<void> enviarSolicitud(String profesorId) async {
    final estudianteId = Supabase.instance.client.auth.currentUser?.id;
    if (estudianteId == null) {
      _showSnackBar('No se pudo obtener tu ID de usuario.', isError: true);
      return;
    }

    final TextEditingController messageCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildSolicitudDialog(messageCtrl),
    );

    if (result != true) return;

    try {
      final nuevaSolicitud = SolicitudData(
        estudianteId: estudianteId,
        profesorId: profesorId,
        estado: 'pendiente',
        fechaSolicitud: DateTime.now(),
        mensaje: messageCtrl.text.trim(),
      );

      await solicitudModel.crearSolicitud(nuevaSolicitud);

      setState(() {
        estadoSolicitud = 'pendiente';
      });

      _showSnackBar('Solicitud enviada correctamente');
    } catch (e) {
      _showSnackBar('Error al enviar solicitud: $e', isError: true);
    } finally {
      messageCtrl.dispose();
    }
  }

  Future<void> verificarEstadoSolicitud(String estudianteId, String profesorId) async {
    try {
      final solicitudes = await solicitudModel.obtenerSolicitudesPorEstudiante(estudianteId);

      final existente = solicitudes.firstWhere(
        (s) => s.profesorId == profesorId,
        orElse: () => SolicitudData(
          id: '',
          estudianteId: estudianteId,
          profesorId: profesorId,
          estado: 'none',
          fechaSolicitud: DateTime.now(),
        ),
      );

      setState(() {
        estadoSolicitud = existente.estado;
      });
    } catch (e) {
      print('Error al verificar solicitud: $e');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_rounded : Icons.check_circle_rounded,
              color: Constants.colorBackground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Constants.textStyleBLANCO,
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Constants.colorError : Constants.colorAccent,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return cerrarTecladoAlTocar(
      child: Scaffold(
        backgroundColor: Constants.colorPrimaryDark,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Constants.colorBackground.withOpacity(0.25),
                  Constants.colorBackground.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Constants.colorBackground.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: Constants.colorBackground,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          title: Text(
            'Perfil del Tutor',
            style: Constants.textStyleBLANCOTitle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          toolbarHeight: 60,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Constants.colorPrimary,
                  Constants.colorAccent,
                  Constants.colorPrimaryDark.withOpacity(0.8),
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
                Constants.colorPrimary,
                Constants.colorAccent,
                Constants.colorPrimaryDark,
                Constants.colorPrimaryDark,
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          width: double.infinity,
          height: double.infinity,
          child: SafeArea(
            child: isLoading 
                ? _buildLoadingState() 
                : tutor == null 
                    ? _buildErrorState() 
                    : _buildTutorProfile(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Constants.colorBackground),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando perfil...',
            style: Constants.textStyleBLANCO.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_rounded,
            size: 80,
            color: Constants.colorBackground.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'Tutor no encontrado',
            style: Constants.textStyleBLANCO.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'El perfil solicitado no está disponible',
            style: Constants.textStyleBLANCO.copyWith(
              fontSize: 14,
              color: Constants.colorBackground.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorProfile() {
    final usuario = tutor!['usuarios'] ?? {};
    final nombre = usuario['nombre'] ?? 'Sin nombre';
    final apellido = usuario['apellido'] ?? '';
    final especialidad = tutor!['especialidad'] ?? 'No definida';
    final carrera = tutor!['carrera_profesion'] ?? 'No definida';
    final horario = tutor!['horario'] ?? 'No definido';
    final experiencia = tutor!['experiencia'] ?? 'No especificada';
    final email = usuario['email'] ?? 'Sin correo';
    final biografia = usuario['biografia'] ?? 'Este tutor aún no ha agregado una biografía.';
    final imagenUrl = usuario['imagen_url'];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Card completa unificada
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Constants.colorBackground,
                      Constants.colorBackground.withOpacity(0.98),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Constants.colorPrimaryDark.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header con avatar y nombre
                    _buildProfileHeaderSection(nombre, apellido, especialidad, carrera, imagenUrl),
                    
                    const SizedBox(height: 24),
                    
                    // Divider elegante
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Constants.colorAccent.withOpacity(0.2),
                            Constants.colorAccent.withOpacity(0.05),
                            Constants.colorAccent.withOpacity(0.2),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Información del tutor
                    _buildInfoSectionUnified(horario, experiencia, email),
                    
                    const SizedBox(height: 24),
                    
                    // Divider elegante
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Constants.colorAccent.withOpacity(0.2),
                            Constants.colorAccent.withOpacity(0.05),
                            Constants.colorAccent.withOpacity(0.2),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Biografía
                    _buildBiografiaSectionUnified(biografia),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Botón de solicitud fuera de la card principal
              _buildSolicitudButton(),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeaderSection(String nombre, String apellido, String especialidad, String carrera, String? imagenUrl) {
    return Column(
      children: [
        // Avatar elegante
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Constants.colorAccent.withOpacity(0.2),
                Constants.colorPrimary.withOpacity(0.1),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Constants.colorAccent.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: Container(
              width: 70,
              height: 70,
              child: imagenUrl != null && imagenUrl.isNotEmpty
                  ? Image.network(
                      imagenUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultAvatar();
                      },
                    )
                  : _buildDefaultAvatar(),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Nombre
        Text(
          '$nombre $apellido',
          style: Constants.textStyleFontBold.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Constants.colorPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 8),
        
        // Especialidad
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Constants.colorAccent.withOpacity(0.15),
                Constants.colorPrimary.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            especialidad,
            style: Constants.textStyleAccentBold.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        const SizedBox(height: 6),
        
        // Carrera
        Text(
          carrera,
          style: Constants.textStyleFont.copyWith(
            fontSize: 14,
            color: Constants.colorFont.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInfoSectionUnified(String horario, String experiencia, String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de la sección
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Constants.colorAccent.withOpacity(0.1),
                    Constants.colorPrimary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.info_rounded,
                color: Constants.colorAccent,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Información del Tutor',
              style: Constants.textStyleFontBold.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Constants.colorPrimary,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Información en filas
        _buildUnifiedInfoRow(Icons.access_time_rounded, 'Horario', horario, Constants.colorAccent),
        _buildUnifiedInfoRow(Icons.school_rounded, 'Experiencia', experiencia, Constants.colorButton),
        _buildUnifiedInfoRow(Icons.email_rounded, 'Correo', email, Constants.colorRosa),
      ],
    );
  }

  Widget _buildUnifiedInfoRow(IconData icon, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.05),
            color.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Constants.textStyleFontBold.copyWith(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Constants.textStyleFont.copyWith(
                    fontSize: 14,
                    color: Constants.colorFont.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiografiaSectionUnified(String biografia) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de la sección
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Constants.colorAccent.withOpacity(0.1),
                    Constants.colorPrimary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.person_rounded,
                color: Constants.colorAccent,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Sobre el Tutor',
              style: Constants.textStyleFontBold.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Constants.colorPrimary,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Biografía con fondo sutil
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Constants.colorAccent.withOpacity(0.03),
                Constants.colorPrimary.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Constants.colorAccent.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Text(
            biografia,
            style: Constants.textStyleFont.copyWith(
              fontSize: 15,
              color: Constants.colorFont.withOpacity(0.8),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSolicitudButton() {
    final estadosConfig = {
      'none': {
        'text': 'Enviar solicitud',
        'icon': Icons.send_rounded,
        'colors': [Constants.colorAccent, Constants.colorPrimary],
        'enabled': true,
      },
      'pendiente': {
        'text': 'Solicitud pendiente',
        'icon': Icons.hourglass_top_rounded,
        'colors': [Constants.colorButton, Constants.colorButton.withOpacity(0.8)],
        'enabled': false,
      },
      'aceptada': {
        'text': 'Solicitud aceptada',
        'icon': Icons.check_circle_rounded,
        'colors': [Constants.colorRosa, Constants.colorRosaLight],
        'enabled': false,
      },
      'rechazada': {
        'text': 'Solicitud rechazada',
        'icon': Icons.cancel_rounded,
        'colors': [Constants.colorError, Constants.colorError.withOpacity(0.8)],
        'enabled': false,
      },
    };

    final config = estadosConfig[estadoSolicitud] ?? estadosConfig['none']!;
    final isEnabled = config['enabled'] == true; // Corrección aquí

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: config['colors'] as List<Color>,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isEnabled // Usar la variable corregida
            ? [
                BoxShadow(
                  color: (config['colors'] as List<Color>)[0].withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: ElevatedButton.icon(
        onPressed: isEnabled ? () => enviarSolicitud(widget.tutorId) : null, // Usar la variable corregida
        icon: Icon(
          config['icon'] as IconData,
          color: Constants.colorBackground,
          size: 20,
        ),
        label: Text(
          config['text'] as String,
          style: Constants.textStyleBLANCO.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Constants.colorAccent.withOpacity(0.8),
            Constants.colorPrimary.withOpacity(0.6),
          ],
        ),
      ),
      child: Icon(
        Icons.person_rounded,
        color: Constants.colorBackground,
        size: 35,
      ),
    );
  }

  Widget _buildSolicitudDialog(TextEditingController messageCtrl) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Constants.colorAccent.withOpacity(0.1),
                  Constants.colorPrimary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.message_rounded,
              color: Constants.colorAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Mensaje para la solicitud',
              style: Constants.textStyleFontBold.copyWith(fontSize: 16),
            ),
          ),
        ],
      ),
      content: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Constants.colorAccent.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: messageCtrl,
          maxLines: 4,
          style: Constants.textStyleFont,
          decoration: InputDecoration(
            hintText: 'Ej: Hola, me gustaría tener tutorías para la clase de...',
            hintStyle: Constants.textStyleFontSmall.copyWith(
              color: Constants.colorFont.withOpacity(0.6),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancelar',
            style: Constants.textStyleFont.copyWith(
              color: Constants.colorFont.withOpacity(0.7),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Constants.colorAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            'Enviar',
            style: Constants.textStyleBLANCO.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
