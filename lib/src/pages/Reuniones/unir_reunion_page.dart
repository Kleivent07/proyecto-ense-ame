import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:my_app/src/BackEnd/custom/no_teclado.dart';
import 'package:my_app/src/BackEnd/services/reuniones_service.dart';
import 'package:my_app/src/pages/Reuniones/meeting_completion_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/models/reuniones_model.dart';
import 'package:my_app/src/BackEnd/custom/zego_keys.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';


class JoinMeetingPage extends StatefulWidget {
  const JoinMeetingPage({Key? key}) : super(key: key);

  @override
  State<JoinMeetingPage> createState() => _JoinMeetingPageState();
}

class _JoinMeetingPageState extends State<JoinMeetingPage> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final MeetingModel _model = MeetingModel();
  final MeetingService _meetingService = MeetingService();
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  
  List<Map<String, dynamic>> _upcomingMeetings = [];
  bool _loadingMeetings = true;
  bool _joiningMeeting = false;
  bool? _isEstudiante;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    
    _initializeUserName();

    // Espera a que se determine el rol antes de cargar reuniones
    _initWithRole();
  }

  Future<void> _initWithRole() async {
    await _checkUserRole();
    await _loadUpcomingMeetings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    _roomIdController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _isEstudiante = true;
          _userRole = 'Estudiante';
        });
        return;
      }

      final result = await Supabase.instance.client
          .from('usuarios')
          .select('clase, profesores(id)')
          .eq('id', user.id)
          .maybeSingle();
      
      if (result != null) {
        bool isProfesor = false;
        if (result['profesores'] != null) {
          isProfesor = true;
          _userRole = "Profesor";
        } else {
          final clase = result['clase']?.toString().toLowerCase();
          if (clase == 'tutor' || clase == 'profesor') {
            isProfesor = true;
            _userRole = clase == 'tutor' ? "Tutor" : "Profesor";
          }
        }

        setState(() {
          _isEstudiante = !isProfesor;
          _userRole = _userRole ?? "Estudiante";
        });
      } else {
        setState(() {
          _isEstudiante = true;
          _userRole = "Estudiante";
        });
      }
    } catch (e) {
      debugPrint('[JOIN] Error checking user role: $e');
      setState(() {
        _isEstudiante = true;
        _userRole = "Estudiante";
      });
    }
  }

  void _initializeUserName() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final displayName = user.userMetadata?['full_name']?.toString() ??
          user.email?.split('@').first ??
          (_isEstudiante == false ? 'Profesor' : 'Estudiante');
      _nameController.text = displayName;
    }
  }

  Future<void> _loadUpcomingMeetings() async {
    setState(() {
      _loadingMeetings = true;
    });

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _upcomingMeetings = [];
        _loadingMeetings = false;
      });
      return;
    }

    List<Map<String, dynamic>> meetings = [];
    if (_isEstudiante == true) {
      meetings = await _model.reunionesAgendadasPorEstudiante(userId);
    } else {
      meetings = await _model.listMeetingsByTutor(userId);
    }

    setState(() {
      _upcomingMeetings = meetings;
      _loadingMeetings = false;
    });
  }

  Future<void> _joinMeeting(String roomId) async {
    final inicio = DateTime.now(); // ⏱️ INICIO

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final esEstudiante = _isEstudiante ?? true;

      final puedeUnirse = await _meetingService.puedeUnirseAReunion(
        userId: userId,
        meetingId: roomId,
        esEstudiante: esEstudiante,
      );

      if (!puedeUnirse) {
        _showSnackBar('No tienes acceso a esta reunión', isError: true);
        return;
      }

      if (_nameController.text.trim().isEmpty) {
        _showSnackBar('Ingresa tu nombre', isError: true);
        return;
      }

      setState(() => _joiningMeeting = true);

      try {
        final userID = Supabase.instance.client.auth.currentUser?.id ?? 
                     'user_${DateTime.now().millisecondsSinceEpoch}';
        final userName = _nameController.text.trim();

        debugPrint('[JOIN] 🚀 Iniciando reunión: $roomId');

        await MeetingCompletionHandler.markParticipantJoined(roomId, userID, isStudent: _isEstudiante ?? true);

        ZegoUIKitPrebuiltCallConfig config = ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall();

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ZegoUIKitPrebuiltCall(
              appID: zegoAppID,
              appSign: zegoAppSign,
              userID: userID,
              userName: userName,
              callID: roomId,
              config: config,
              events: ZegoUIKitPrebuiltCallEvents(
                onCallEnd: (ZegoCallEndEvent event, VoidCallback defaultAction) {
                  defaultAction();
                  _onCallEnd(roomId);
                },
              ),
            ),
          ),
        );

        await _onCallEnd(roomId);

      } catch (e) {
        debugPrint('[JOIN] ❌ Error en la reunión: $e');
        
        try {
          await _onCallEnd(roomId);
        } catch (completionError) {
          debugPrint('[JOIN] ⚠️ Error adicional: $completionError');
        }
        
        _showSnackBar('Error al unirse: $e', isError: true);
      } finally {
        setState(() => _joiningMeeting = false);
      }
    } catch (e) {
      debugPrint('[JOIN] Error en la lógica de unión: $e');
      setState(() => _joiningMeeting = false);
    } finally {
      final fin = DateTime.now();
      final duracion = fin.difference(inicio).inMilliseconds;
      print('⏱️ Tiempo de respuesta al entrar a la reunión: $duracion ms');
    }
  }

  Future<void> _onCallEnd(String roomId) async {
    try {
      debugPrint('[JOIN] 🏁 Procesando fin de reunión: $roomId');
      
      final meeting = await _model.findByRoom(roomId);
      if (meeting != null) {
        final studentName = meeting['student_name']?.toString() ?? '';
        if (studentName.startsWith('COMPLETED_')) {
          debugPrint('[JOIN] ⚠️ Reunión ya completada');
          return;
        }
      }
      
      final success = await MeetingModel().completeMeeting(roomId);
      
      if (success != null) {
        debugPrint('[JOIN] ✅ Reunión marcada como completada');
        
        if (mounted) {
          _showSnackBar('Reunión completada exitosamente', isError: false, icon: Icons.check_circle);
        }

        await Future.delayed(const Duration(seconds: 2));
        
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null && _isEstudiante == true) {
          final ratableMeetings = await MeetingCompletionHandler.checkCompletedMeetings(currentUser.id);
          final thisRoomMeeting = ratableMeetings.where((m) => m['room_id'] == roomId).toList();
          
          if (thisRoomMeeting.isNotEmpty && mounted) {
            _showSnackBar('El diálogo de calificación aparecerá en breve', 
                          isError: false, icon: Icons.star, color: Constants.colorRosa);
          }
        }
      }
    } catch (e) {
      debugPrint('[JOIN] ❌ Error al completar reunión: $e');
    }
  }

  void _showSnackBar(String message, {bool isError = false, IconData? icon, Color? color}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon ?? (isError ? Icons.error_outline : Icons.check_circle_outline),
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
        backgroundColor: color ?? (isError ? Constants.colorError : Constants.colorAccent),
        duration: Duration(seconds: isError ? 4 : 2),
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
        backgroundColor: _getBackgroundColor(),
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
            'Unirse a Reunión',
            style: Constants.textStyleBLANCOTitle,
          ),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _getGradientColors(),
              ),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _getGradientColors(),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Constants.colorBackground,
                unselectedLabelColor: Constants.colorBackground.withOpacity(0.7),
                indicatorColor: Constants.colorBackground,
                indicatorWeight: 3,
                labelStyle: Constants.textStyleBLANCOSemiBold,
                unselectedLabelStyle: Constants.textStyleBLANCO,
                tabs: [
                  Tab(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Constants.colorBackground.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.schedule, size: 20),
                    ),
                    text: 'Programadas',
                  ),
                  Tab(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Constants.colorBackground.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.keyboard, size: 20),
                    ),
                    text: 'ID Manual',
                  ),
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
                _getBackgroundColor(),
                _getSecondaryColor(),
                _getAccentColor().withOpacity(0.1),
              ],
              stops: const [0.0, 0.7, 1.0],
            ),
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUpcomingMeetingsTab(),
                  _buildManualJoinTab(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    return _isEstudiante == false ? Constants.colorPrimaryDark : Constants.colorPrimaryDark;
  }

  Color _getSecondaryColor() {
    return _isEstudiante == false ? Constants.colorButton : Constants.colorPrimary;
  }

  Color _getAccentColor() {
    return _isEstudiante == false ? Constants.colorOnPrimary : Constants.colorAccent;
  }

  List<Color> _getGradientColors() {
    return _isEstudiante == false 
        ? [Constants.colorPrimaryDark, Constants.colorButton]
        : [Constants.colorPrimaryDark, Constants.colorPrimary];
  }

  Widget _buildUpcomingMeetingsTab() {
    if (_loadingMeetings) {
      return _buildLoadingState();
    }

    if (_upcomingMeetings.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Header con información del usuario
        _buildUserHeader(),
        
        // Lista de reuniones
        Expanded(
          child: RefreshIndicator(
            color: _getAccentColor(),
            backgroundColor: Constants.colorBackground,
            onRefresh: _loadUpcomingMeetings,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _upcomingMeetings.length,
              itemBuilder: (context, index) {
                return _buildElegantMeetingCard(_upcomingMeetings[index], index);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Constants.colorBackground.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_getAccentColor()),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Cargando reuniones...',
            style: Constants.textStyleBLANCO.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Constants.colorBackground.withOpacity(0.15),
                    Constants.colorBackground.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.event_busy_rounded,
                size: 80,
                color: Constants.colorBackground.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No hay reuniones programadas',
              style: Constants.textStyleBLANCOTitle.copyWith(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _isEstudiante == false 
                  ? 'Las reuniones que crees aparecerán aquí\nTambién puedes unirte con un ID manual'
                  : 'Las reuniones programadas aparecerán aquí\nTambién puedes unirte con un ID manual',
              style: Constants.textStyleBLANCO.copyWith(
                fontSize: 16,
                color: Constants.colorBackground.withOpacity(0.8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _getAccentColor().withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getAccentColor().withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: _getAccentColor(),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Usa la pestaña "ID Manual" para unirte directamente',
                      style: Constants.textStyleBLANCOSmall.copyWith(
                        color: _getAccentColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Constants.colorBackground,
            Constants.colorBackground.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getAccentColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _isEstudiante == false ? Icons.school_rounded : Icons.person_rounded,
                  color: _getAccentColor(),
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEstudiante == false ? 'Panel de Profesor' : 'Panel de Estudiante',
                      style: Constants.textStyleFontTitle.copyWith(fontSize: 18),
                    ),
                    Text(
                      _userRole ?? 'Usuario',
                      style: Constants.textStyleFont.copyWith(
                        color: _getAccentColor(),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getAccentColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_upcomingMeetings.length}',
                  style: Constants.textStyleFontSmall.copyWith(
                    color: _getAccentColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            style: Constants.textStyleFont,
            decoration: InputDecoration(
              labelText: _isEstudiante == false ? 'Tu nombre (profesor)' : 'Tu nombre (estudiante)',
              labelStyle: Constants.textStyleFontSemiBold.copyWith(
                color: Constants.colorFont.withOpacity(0.7),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                _isEstudiante == false ? Icons.school : Icons.person, 
                color: _getAccentColor(),
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
                borderSide: BorderSide(
                  color: _getAccentColor(),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Constants.colorFondo2.withOpacity(0.3),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElegantMeetingCard(Map<String, dynamic> meeting, int index) {
    final scheduledAt = DateTime.parse(meeting['scheduled_at']).toLocal();
    final createdAt = DateTime.parse(meeting['created_at'] ?? meeting['scheduled_at']).toLocal();
    final now = DateTime.now();
    final diffMinutes = scheduledAt.difference(now).inMinutes;
    final hoursCreated = now.difference(createdAt).inHours;
    
    // Determinar el estado de la reunión
    String status;
    Color statusColor;
    String emoji;
    bool isNew = hoursCreated < 1;
    
    if (diffMinutes > 15) {
      status = isNew ? 'Nueva' : 'Programada';
      statusColor = isNew ? Constants.colorRosa : _getAccentColor();
      emoji = isNew ? '🆕' : '📅';
    } else if (diffMinutes >= -15) {
      status = 'En vivo';
      statusColor = Constants.colorRosa;
      emoji = '🔴';
    } else {
      status = 'Atrasada';
      statusColor = Constants.colorError;
      emoji = '⏰';
    }

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      margin: const EdgeInsets.only(bottom: 20),
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
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: isNew 
              ? Border.all(color: Constants.colorRosa.withOpacity(0.3), width: 1.5)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header con status y título - ✅ ARREGLADO
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    meeting['subject']?.isNotEmpty == true 
                                        ? meeting['subject'] 
                                        : 'Tutoría con ${meeting['tutor_name']}',
                                    style: Constants.textStyleFontBold.copyWith(fontSize: 18),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // ✅ ARREGLADO: Información del participante con layout flexible
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getAccentColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isEstudiante == false ? Icons.person : Icons.school,
                                    color: _getAccentColor(),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _isEstudiante == false 
                                          ? 'Estudiante: ${meeting['student_name'] ?? 'Sin asignar'}'
                                          : 'Tutor: ${meeting['tutor_name']}',
                                      style: Constants.textStyleFont.copyWith(
                                        color: _getAccentColor(),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          status,
                          style: Constants.textStyleFontBold.copyWith(
                            color: statusColor,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Información de fecha y hora
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Constants.colorFondo2.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 20, color: Constants.colorFont.withOpacity(0.7)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat('EEEE, dd MMM yyyy • HH:mm', 'es').format(scheduledAt),
                                style: Constants.textStyleFontSemiBold.copyWith(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        if (diffMinutes > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.timer_rounded, size: 20, color: _getAccentColor()),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  diffMinutes < 60 
                                      ? 'Comienza en $diffMinutes min'
                                      : 'Comienza en ${(diffMinutes / 60).floor()}h ${diffMinutes % 60}min',
                                  style: Constants.textStyleFont.copyWith(
                                    color: _getAccentColor(),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (diffMinutes >= -15) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.live_tv_rounded, size: 20, color: Constants.colorRosa),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '¡Disponible ahora!',
                                  style: Constants.textStyleFontBold.copyWith(
                                    color: Constants.colorRosa,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.warning_rounded, size: 20, color: Constants.colorError),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Comenzó hace ${(-diffMinutes)} min',
                                  style: Constants.textStyleFontBold.copyWith(
                                    color: Constants.colorError,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Room ID con botón de copiar - ✅ ARREGLADO
                  Row(
                    children: [
                      Icon(Icons.meeting_room_rounded, size: 20, color: Constants.colorFont.withOpacity(0.7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Constants.colorFont.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Constants.colorFont.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'ID: ${meeting['room_id']}',
                            style: Constants.textStyleFontSmall.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: meeting['room_id']));
                            _showSnackBar('ID copiado', icon: Icons.copy);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _getAccentColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 18,
                              color: _getAccentColor(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Botón de unirse
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: status == 'En vivo' 
                              ? [Constants.colorRosa, Constants.colorRosaLight]
                              : [_getAccentColor(), _getSecondaryColor()],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (status == 'En vivo' ? Constants.colorRosa : _getAccentColor()).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _joiningMeeting ? null : () => _joinMeeting(meeting['room_id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _joiningMeeting 
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Constants.colorBackground),
                                ),
                              )
                            : Icon(
                                Icons.videocam_rounded,
                                color: Constants.colorBackground,
                                size: 24,
                              ),
                        label: Text(
                          _joiningMeeting ? 'Conectando...' : 'Unirse',
                          style: Constants.textStyleBLANCOSemiBold.copyWith(fontSize: 16),
                        ),
                      ),
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

  Widget _buildManualJoinTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header informativo
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Constants.colorBackground,
                  Constants.colorBackground.withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getAccentColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.keyboard_rounded,
                        color: _getAccentColor(),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unirse con ID Manual',
                            style: Constants.textStyleFontTitle.copyWith(fontSize: 18),
                          ),
                          Text(
                            'Ingresa el ID compartido',
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getAccentColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getAccentColor().withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: _getAccentColor(),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isEstudiante == false 
                              ? 'Como profesor, puedes unirte a cualquier reunión'
                              : 'Pide al organizador el Room ID',
                          style: Constants.textStyleFontSmall.copyWith(
                            color: _getAccentColor(),
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Campo de Room ID
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Constants.colorBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ID de la Reunión',
                  style: Constants.textStyleFontBold.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _roomIdController,
                  style: Constants.textStyleFont,
                  decoration: InputDecoration(
                    hintText: 'room_1234567890_NombreTutor',
                    hintStyle: Constants.textStyleFont.copyWith(
                      color: Constants.colorFont.withOpacity(0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.meeting_room_rounded,
                      color: _getAccentColor(),
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
                      borderSide: BorderSide(
                        color: _getAccentColor(),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Constants.colorFondo2.withOpacity(0.3),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  onSubmitted: (_) => _joinManualMeeting(),
                ),
                const SizedBox(height: 8),
                Text(
                  'El ID suele comenzar con "room_" seguido de números',
                  style: Constants.textStyleFontSmall.copyWith(
                    color: Constants.colorFont.withOpacity(0.6),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Botón de unirse
          SizedBox(
            height: 60,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: _joiningMeeting 
                      ? [Constants.colorFont.withOpacity(0.3), Constants.colorFont.withOpacity(0.3)]
                      : [_getAccentColor(), _getSecondaryColor()],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _getAccentColor().withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _joiningMeeting ? null : _joinManualMeeting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: _joiningMeeting 
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Constants.colorBackground),
                        ),
                      )
                    : Icon(
                        Icons.videocam_rounded,
                        color: Constants.colorBackground,
                        size: 24,
                      ),
                label: Text(
                  _joiningMeeting ? 'Conectando...' : 'Unirse',
                  style: Constants.textStyleBLANCOSemiBold.copyWith(fontSize: 16),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Tips adicionales
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Constants.colorBackground.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Constants.colorBackground.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_rounded,
                      color: Constants.colorBackground.withOpacity(0.8),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Consejos útiles',
                      style: Constants.textStyleBLANCOSemiBold.copyWith(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...[
                  '• Verifica que el ID esté completo',
                  '• El ID es único para cada reunión',
                  if (_isEstudiante == false) 
                    '• Puedes crear y unirte a reuniones'
                  else 
                    '• Guarda IDs frecuentes en notas',
                ].map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    tip,
                    style: Constants.textStyleBLANCO.copyWith(
                      fontSize: 12,
                      color: Constants.colorBackground.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                )).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _joinManualMeeting() {
    if (_roomIdController.text.trim().isEmpty) {
      _showSnackBar('Ingresa el ID de la reunión', isError: true);
      return;
    }
    
    _joinMeeting(_roomIdController.text.trim());
  }
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