import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/src/BackEnd/custom/notifications_service.dart';
import 'package:my_app/src/BackEnd/custom/zego_keys.dart';
import 'package:my_app/src/BackEnd/custom/no_teclado.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/models/reuniones_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:flutter/services.dart';

class CreateMeetingPage extends StatefulWidget {
  const CreateMeetingPage({Key? key}) : super(key: key);

  @override
  State<CreateMeetingPage> createState() => _CreateMeetingPageState();
}

class _CreateMeetingPageState extends State<CreateMeetingPage> with TickerProviderStateMixin {
  final _tutorCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  DateTime? _selectedDate;
  final MeetingModel _model = MeetingModel();
  bool _saving = false;
  bool _opening = false;
  String? _createdRoomId;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final displayName = user.userMetadata?['full_name']?.toString() ??
          user.email?.split('@').first ??
          '';
      if (displayName.isNotEmpty) {
        _tutorCtrl.text = displayName;
      }
    }
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tutorCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().toLocal(),
      firstDate: DateTime.now().toLocal(),
      lastDate: DateTime(DateTime.now().year + 3),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Constants.colorPrimary,
              onPrimary: Constants.colorBackground,
              surface: Constants.colorBackground,
              onSurface: Constants.colorFont,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context, 
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Constants.colorPrimary,
                onPrimary: Constants.colorBackground,
                surface: Constants.colorBackground,
                onSurface: Constants.colorFont,
              ),
            ),
            child: child!,
          );
        },
      );
      if (time != null) {
        setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
      } else {
        setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day));
      }
    }
  }

  Future<void> _create() async {
    if (_tutorCtrl.text.trim().isEmpty) {
      _showSnackBar('Ingresa el nombre del tutor', isError: true);
      return;
    }
    if (_selectedDate == null) {
      _showSnackBar('Selecciona fecha y hora', isError: true);
      return;
    }

    setState(() => _saving = true);

    final roomId = 'room_${DateTime.now().millisecondsSinceEpoch}_${_tutorCtrl.text.replaceAll(' ', '_')}';
    final tutorId = Supabase.instance.client.auth.currentUser?.id;

    try {
      final created = await _model.createMeeting(
        tutorName: _tutorCtrl.text.trim(),
        roomId: roomId,
        subject: _subjectCtrl.text.trim(),
        scheduledAt: _selectedDate!.toUtc(),
        tutorId: tutorId,
      );

      setState(() {
        _saving = false;
        _createdRoomId = created?['room_id']?.toString() ?? roomId;
      });

      if (created != null) {
        // Programar notificaciones
        final scheduledRaw = created['scheduled_at'] as String?;
        if (scheduledRaw != null) {
          try {
            final scheduledUtc = DateTime.parse(scheduledRaw).toUtc();
            final notifIdStart = (_createdRoomId ?? roomId).hashCode;
            await NotificationsService.scheduleNotification(
              notifIdStart,
              'Reunión iniciada',
              '${_subjectCtrl.text.isEmpty ? 'Tutoría' : _subjectCtrl.text} — ${DateFormat('dd/MM/yyyy – HH:mm').format(scheduledUtc.toLocal())}',
              scheduledUtc,
              payload: _createdRoomId,
            );
            final reminderUtc = scheduledUtc.subtract(const Duration(minutes: 10));
            if (reminderUtc.isAfter(DateTime.now().toUtc())) {
              await NotificationsService.scheduleNotification(
                notifIdStart + 1,
                'Recordatorio: reunión en 10 min',
                '${_subjectCtrl.text.isEmpty ? 'Tutoría' : _subjectCtrl.text}',
                reminderUtc,
                payload: _createdRoomId,
              );
            }
          } catch (e) {
            debugPrint('No se pudo programar notificaciones: $e');
          }
        }
        _showSnackBar('¡Reunión creada exitosamente!', isError: false);
      } else {
        _showSnackBar('Error creando reunión', isError: true);
      }
    } catch (e, st) {
      debugPrint('Error en _create: $e\n$st');
      setState(() => _saving = false);
      _showSnackBar('Ocurrió un error al crear la reunión', isError: true);
    }
  }

  void _openCreatedMeeting() async {
    if (_createdRoomId == null) return;
    setState(() => _opening = true);

    final user = Supabase.instance.client.auth.currentUser;
    final userID = user?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
    final userName = _tutorCtrl.text.trim().isEmpty ? 'Tutor' : _tutorCtrl.text.trim();

    ZegoUIKitPrebuiltCallConfig config = ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ZegoUIKitPrebuiltCall(
          appID: zegoAppID,
          appSign: zegoAppSign,
          userID: userID,
          userName: userName,
          callID: _createdRoomId!,
          config: config,
        ),
      ),
    );

    setState(() => _opening = false);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
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
        backgroundColor: isError ? Constants.colorError : Constants.colorPrimary,
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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Constants.colorBackground.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back, color: Constants.colorBackground, size: 20),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Crear Reunión',
            style: Constants.textStyleBLANCOTitle,
          ),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Constants.colorPrimaryDark,
                  Constants.colorPrimary,
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
                Constants.colorPrimary,
                Constants.colorPrimaryLight.withOpacity(0.1),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ✨ Header elegante con estilo profesor
                      _buildProfessorHeader(),
                      const SizedBox(height: 24),
                      
                      // ✨ Formulario moderno
                      _buildModernForm(),
                      const SizedBox(height: 24),
                      
                      // ✨ Tarjeta de resultado (si existe)
                      if (_createdRoomId != null) ...[
                        _buildSuccessCard(),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfessorHeader() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Constants.colorBackground,
            Constants.colorBackground.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icono principal con estilo profesor
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Constants.colorPrimary,
                  Constants.colorPrimaryDark,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Constants.colorPrimary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              Icons.video_call_rounded,
              size: 40,
              color: Constants.colorBackground,
            ),
          ),
          const SizedBox(height: 20),
          
          // Título y subtítulo
          Text(
            'Crear Nueva Reunión',
            style: Constants.textStyleFontTitle.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Organiza una sesión de tutoría personalizada\npara conectar con tus estudiantes',
            style: Constants.textStyleFont.copyWith(
              color: Constants.colorFont.withOpacity(0.7),
              fontSize: 16,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 20),
          
          // Estadística o info adicional
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Constants.colorPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Constants.colorPrimary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school_rounded,
                  color: Constants.colorPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Panel de Profesor',
                  style: Constants.textStylePrimarySemiBold.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernForm() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Constants.colorBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título de la sección
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Constants.colorPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.edit_rounded,
                  color: Constants.colorPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Detalles de la Reunión',
                style: Constants.textStyleFontTitle.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Campo nombre del tutor
          _buildModernTextField(
            controller: _tutorCtrl,
            label: 'Nombre del Tutor',
            hint: 'Tu nombre como aparecerá en la reunión',
            icon: Icons.person_rounded,
            color: Constants.colorPrimary,
          ),
          const SizedBox(height: 20),
          
          // Campo materia
          _buildModernTextField(
            controller: _subjectCtrl,
            label: 'Materia o Tema',
            hint: 'Ej: Matemáticas, Física, Programación...',
            icon: Icons.subject_rounded,
            color: Constants.colorPrimaryDark,
            isOptional: true,
          ),
          const SizedBox(height: 24),
          
          // Selector de fecha y hora
          _buildDateTimeSelector(),
          const SizedBox(height: 32),
          
          // Botón crear
          _buildCreateButton(),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    bool isOptional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Constants.textStyleFontBold.copyWith(fontSize: 16),
            ),
            if (isOptional) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Constants.colorSecondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'opcional',
                  style: Constants.textStyleFontSmall.copyWith(
                    color: Constants.colorSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: Constants.textStyleFont.copyWith(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Constants.textStyleFont.copyWith(
              color: Constants.colorFont.withOpacity(0.5),
              fontSize: 14,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Constants.colorFont.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Constants.colorFont.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: color, width: 2),
            ),
            filled: true,
            fillColor: Constants.colorFondo2.withOpacity(0.3),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fecha y Hora',
          style: Constants.textStyleFontBold.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: _selectedDate != null
                  ? LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Constants.colorPrimary.withOpacity(0.1),
                        Constants.colorPrimaryLight.withOpacity(0.05),
                      ],
                    )
                  : null,
              color: _selectedDate == null ? Constants.colorFondo2.withOpacity(0.3) : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedDate != null 
                    ? Constants.colorPrimary.withOpacity(0.3)
                    : Constants.colorFont.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Constants.colorPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    color: Constants.colorPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedDate == null ? 'Seleccionar fecha y hora' : 'Reunión programada',
                        style: Constants.textStyleFontBold.copyWith(
                          fontSize: 16,
                          color: _selectedDate != null ? Constants.colorPrimary : Constants.colorFont,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedDate == null
                            ? 'Toca para elegir cuándo será la reunión'
                            : DateFormat('EEEE, dd MMMM yyyy - HH:mm', 'es').format(_selectedDate!.toLocal()),
                        style: Constants.textStyleFont.copyWith(
                          color: Constants.colorFont.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Constants.colorFont.withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: _saving 
              ? [Constants.colorFont.withOpacity(0.3), Constants.colorFont.withOpacity(0.3)]
              : [Constants.colorPrimary, Constants.colorPrimaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Constants.colorPrimary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _saving ? null : _create,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _saving
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Constants.colorBackground),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Creando reunión...',
                    style: Constants.textStyleBLANCOSemiBold.copyWith(fontSize: 16),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_rounded,
                    color: Constants.colorBackground,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Crear Reunión',
                    style: Constants.textStyleBLANCOSemiBold.copyWith(fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Constants.colorRosaLight.withOpacity(0.1),
            Constants.colorRosa.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Constants.colorRosa.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Constants.colorRosa.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header exitoso
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Constants.colorRosa.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Constants.colorRosa,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡Reunión Creada!',
                      style: Constants.textStyleFontTitle.copyWith(
                        fontSize: 20,
                        color: Constants.colorRosa,
                      ),
                    ),
                    Text(
                      'Tu sesión está lista para comenzar',
                      style: Constants.textStyleFont.copyWith(
                        color: Constants.colorFont.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Room ID
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Constants.colorBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Constants.colorFont.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Room ID:',
                  style: Constants.textStyleFontSmall.copyWith(
                    color: Constants.colorFont.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _createdRoomId!,
                  style: Constants.textStyleFontBold.copyWith(
                    fontSize: 16,
                    fontFamily: 'monospace',
                    color: Constants.colorRosa,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Botones de acción
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Constants.colorRosa, Constants.colorRosaDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _opening ? null : _openCreatedMeeting,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _opening 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Constants.colorBackground),
                            ),
                          )
                        : Icon(Icons.videocam_rounded, color: Constants.colorBackground),
                    label: Text(
                      _opening ? 'Iniciando...' : 'Iniciar Ahora',
                      style: Constants.textStyleBLANCOSemiBold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: Constants.colorRosa, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _createdRoomId!));
                    _showSnackBar('Room ID copiado al portapapeles', isError: false);
                  },
                  icon: Icon(Icons.copy_rounded, color: Constants.colorRosa),
                  tooltip: 'Copiar Room ID',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Instrucciones
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Constants.colorBackground.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Constants.colorRosa,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Comparte el Room ID con tus estudiantes para que puedan unirse a la reunión.',
                    style: Constants.textStyleFont.copyWith(
                      fontSize: 14,
                      color: Constants.colorFont.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}