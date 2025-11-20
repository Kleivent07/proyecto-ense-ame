import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/models/reuniones_model.dart';
import 'package:my_app/src/models/tutor_rating_model.dart';
import 'package:my_app/src/pages/Estudiantes/calificar_tutor_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MeetingCompletionHandler extends StatefulWidget {
  final Widget child;
  
  const MeetingCompletionHandler({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<MeetingCompletionHandler> createState() => _MeetingCompletionHandlerState();

  /// ✅ Método estático para marcar una reunión como completada
  static Future<bool> completeMeeting(String roomId) async {
    try {
      final meetingModel = MeetingModel();
      final result = await meetingModel.completeMeeting(roomId);
      if (result != null) {
        debugPrint('[COMPLETION] ✅ Reunión $roomId marcada como completada');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[COMPLETION] ❌ Error completando reunión: $e');
      return false;
    }
  }

  /// ✅ Método estático para marcar que un participante se unió
  static Future<bool> markParticipantJoined(String roomId, String userId, {bool isStudent = true}) async {
    try {
      final meetingModel = MeetingModel();
      final success = await meetingModel.markParticipantJoined(roomId, userId, isStudent: isStudent);
      if (success) {
        debugPrint('[COMPLETION] ✅ Participante $userId marcado como unido a $roomId');
      }
      return success;
    } catch (e) {
      debugPrint('[COMPLETION] ❌ Error marcando participante: $e');
      return false;
    }
  }

  /// ✅ Método estático para forzar verificación de reuniones completadas
  static Future<List<Map<String, dynamic>>> checkCompletedMeetings(String studentId) async {
    try {
      final ratingModel = TutorRatingModel();
      return await ratingModel.getRatableCompletedMeetings(studentId);
    } catch (e) {
      debugPrint('[COMPLETION] ❌ Error verificando reuniones: $e');
      return [];
    }
  }
}

class _MeetingCompletionHandlerState extends State<MeetingCompletionHandler> with WidgetsBindingObserver {
  final MeetingModel _meetingModel = MeetingModel();
  final TutorRatingModel _ratingModel = TutorRatingModel();
  
  // ✅ Tracking per reunión para evitar duplicados
  final Set<String> _dialogsShownForMeetings = <String>{};
  final Set<String> _processedMeetings = <String>{}; // ✅ NUEVO: Reuniones ya procesadas
  bool _isCheckingMeetings = false;
  DateTime? _lastCheckTime; // ✅ NUEVO: Control de tiempo

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ❌ REMOVIDO: NO verificar automáticamente al inicializar
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _checkForCompletedMeetings();
    // });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // ❌ REMOVIDO: NO verificar automáticamente cuando la app se reanuda
    // Solo mantener esto comentado para pruebas
    /*
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastCheckTime == null || now.difference(_lastCheckTime!).inSeconds > 30) {
        debugPrint('[COMPLETION] 📱 App resumed después de 30s, verificando reuniones...');
        _checkForCompletedMeetings();
      } else {
        debugPrint('[COMPLETION] 📱 App resumed muy pronto, saltando verificación');
      }
    }
    */
  }

  /// ✅ Verificar si hay reuniones completadas - ANTI BUCLE
  Future<void> _checkForCompletedMeetings() async {
    if (_isCheckingMeetings) {
      debugPrint('[COMPLETION] ⏳ Ya verificando reuniones, saltando para evitar bucle...');
      return;
    }

    // ✅ Control de tiempo para evitar verificaciones muy frecuentes
    final now = DateTime.now();
    if (_lastCheckTime != null && now.difference(_lastCheckTime!).inSeconds < 5) {
      debugPrint('[COMPLETION] ⏰ Verificación muy reciente, esperando...');
      return;
    }

    _isCheckingMeetings = true;
    _lastCheckTime = now;

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('[COMPLETION] ❌ Usuario no autenticado');
        return;
      }

      debugPrint('[COMPLETION] 🔍 Verificando reuniones completadas para: ${currentUser.id}');

      final meetingsNeedingRating = await _ratingModel.getRatableCompletedMeetings(currentUser.id);
      
      debugPrint('[COMPLETION] 📋 Reuniones que necesitan calificación: ${meetingsNeedingRating.length}');

      if (meetingsNeedingRating.isNotEmpty) {
        // ✅ Buscar una reunión que NO haya sido procesada
        Map<String, dynamic>? meetingToShow;
        
        for (final meeting in meetingsNeedingRating) {
          final meetingId = meeting['id']?.toString() ?? '';
          final roomId = meeting['room_id']?.toString() ?? '';
          final meetingKey = '$meetingId-$roomId';
          
          // ✅ Solo mostrar si no ha sido procesada en esta sesión
          if (!_dialogsShownForMeetings.contains(meetingId) && 
              !_dialogsShownForMeetings.contains(roomId) &&
              !_processedMeetings.contains(meetingKey)) {
            meetingToShow = meeting;
            break;
          }
        }
        
        if (meetingToShow != null) {
          final meetingId = meetingToShow['id']?.toString() ?? '';
          final roomId = meetingToShow['room_id']?.toString() ?? '';
          final meetingKey = '$meetingId-$roomId';
          
          debugPrint('[COMPLETION] 🌟 Mostrando diálogo para reunión: ${meetingToShow['subject']} con ${meetingToShow['tutor_name']}');
          
          // ✅ Marcar como procesada ANTES de mostrar
          _dialogsShownForMeetings.add(meetingId);
          _dialogsShownForMeetings.add(roomId);
          _processedMeetings.add(meetingKey);
          
          // ✅ Esperar un poco para asegurar que el contexto esté listo
          await Future.delayed(const Duration(milliseconds: 1000));
          
          if (mounted) {
            _showRatingDialog(meetingToShow);
          }
        } else {
          debugPrint('[COMPLETION] ⏭️ Todas las reuniones ya fueron procesadas en esta sesión');
        }
      } else {
        debugPrint('[COMPLETION] ✅ No hay reuniones pendientes de calificar');
      }
    } catch (e) {
      debugPrint('[COMPLETION] ❌ Error verificando reuniones completadas: $e');
    } finally {
      _isCheckingMeetings = false;
    }
  }

  /// ✅ Mostrar diálogo automático de calificación - MEJORADO
  void _showRatingDialog(Map<String, dynamic> meeting) {
    if (!mounted) return;
    
    final meetingId = meeting['id']?.toString() ?? '';
    final roomId = meeting['room_id']?.toString() ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: Constants.colorAccent, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '¡Reunión Completada!',
                style: TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Te gustaría calificar tu tutoría con ${meeting['tutor_name']}?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 15),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Constants.colorAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Materia: ${meeting['subject'] ?? 'Tutoría General'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tu calificación ayuda a otros estudiantes',
                      style: TextStyle(
                        color: Constants.colorFont.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _skipRating(meeting);
                  },
                  child: const Text(
                    'Ahora no',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToRating(meeting);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Constants.colorAccent,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text(
                    'Calificar',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );

    debugPrint('[COMPLETION] 📱 Diálogo mostrado para reunión ID: $meetingId');
  }

  /// ✅ Navegar a la página de calificación - SIN BUCLE
  void _navigateToRating(Map<String, dynamic> meeting) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CalificarTutorPage(
          meetingId: meeting['id'],
          tutorId: meeting['tutor_id'] ?? '',
          tutorName: meeting['tutor_name'] ?? 'Tutor',
          subject: meeting['subject'] ?? 'Tutoría General',
        ),
      ),
    );

    // ✅ Marcar como mostrada en BD
    await _meetingModel.markRatingShown(meeting['room_id']);
    
    // ✅ SOLO verificar más reuniones si se guardó exitosamente Y han pasado al menos 2 segundos
    if (result == true) {
      debugPrint('[COMPLETION] ✅ Calificación guardada exitosamente');
      await Future.delayed(const Duration(seconds: 2));
      
      // ✅ Solo continuar si no hay otros diálogos activos
      if (mounted && !_isCheckingMeetings) {
        debugPrint('[COMPLETION] 🔄 Verificando si hay más reuniones...');
        _checkForCompletedMeetings();
      }
    } else {
      debugPrint('[COMPLETION] ⏭️ Usuario canceló calificación - NO verificar más');
    }
  }

  /// ✅ Saltar la calificación - SIN BUCLE
  void _skipRating(Map<String, dynamic> meeting) async {
    try {
      // ✅ Marcar en base de datos que ya se mostró
      await _meetingModel.markRatingShown(meeting['room_id']);
      
      debugPrint('[COMPLETION] ⏭️ Usuario saltó calificación para ${meeting['room_id']} - NO verificar más');
      
      // ✅ NO verificar más reuniones si el usuario saltó
      // El usuario no quiere calificar ahora, respetamos su decisión
      
    } catch (e) {
      debugPrint('[COMPLETION] ❌ Error saltando calificación: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}