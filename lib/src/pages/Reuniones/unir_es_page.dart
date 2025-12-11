import 'package:flutter/material.dart';
import 'package:my_app/src/models/reuniones_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/BackEnd/custom/zego_keys.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:flutter/services.dart';
import 'package:my_app/src/BackEnd/services/notifications_service.dart';
import 'package:permission_handler/permission_handler.dart';

const carmesi = Color(0xFFB71C1C);
const carmesiClaro = Color(0xFFFFCDD2);

class UnirESPage extends StatefulWidget {
  const UnirESPage({Key? key}) : super(key: key);

  @override
  State<UnirESPage> createState() => _UnirESPageState();
}

class _UnirESPageState extends State<UnirESPage> {
  final MeetingModel _model = MeetingModel();
  List<Map<String, dynamic>> _meetings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  Future<void> _loadMeetings() async {
    setState(() => _loading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final meetings = await _model.reunionesAgendadasPorEstudiante(userId);
      // Filtrar reuniones: solo las que no han pasado más de 1 hora
      final now = DateTime.now();
      final filtered = meetings.where((m) {
        final fecha = DateTime.tryParse(m['scheduled_at'] ?? m['fecha_hora'] ?? '');
        if (fecha == null) return false;
        return fecha.isAfter(now.subtract(const Duration(hours: 1)));
      }).toList();

      // Ordenar: primero disponibles ahora (dentro +/-30 min), luego por proximidad ascendente
      filtered.sort((a, b) {
        final fa = DateTime.tryParse(a['scheduled_at'] ?? a['fecha_hora'] ?? '') ?? DateTime.now();
        final fb = DateTime.tryParse(b['scheduled_at'] ?? b['fecha_hora'] ?? '') ?? DateTime.now();

        final now = DateTime.now();
        bool aAvailable = fa.isAfter(now.subtract(const Duration(minutes: 30))) && fa.isBefore(now.add(const Duration(minutes: 60)));
        bool bAvailable = fb.isAfter(now.subtract(const Duration(minutes: 30))) && fb.isBefore(now.add(const Duration(minutes: 60)));

        if (aAvailable && !bAvailable) return -1;
        if (!aAvailable && bAvailable) return 1;

        // Si ambos igual disponibilidad, ordenar por más cercano primero
        return fa.compareTo(fb);
      });

      setState(() {
        _meetings = filtered;
        _loading = false;
      });
    } else {
      setState(() {
        _meetings = [];
        _loading = false;
      });
    }
  }

  Future<void> _unirseComoEstudiante(String roomId) async {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['full_name']?.toString() ?? user?.email?.split('@').first ?? 'Estudiante';
    if (user == null) return;

    // Solicitar permisos de cámara y micrófono
    await Permission.camera.request();
    await Permission.microphone.request();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ZegoUIKitPrebuiltCall(
          appID: zegoAppID,
          appSign: zegoAppSign,
          userID: user.id,
          userName: userName,
          callID: roomId,
          config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall(),
        ),
      ),
    );
  }

  void _copiarCodigo(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado', style: TextStyle(color: Colors.white)),
        backgroundColor: carmesi,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _marcarReunionCompletada(String roomId) async {
    try {
      await MeetingModel().completeMeeting(roomId);
      debugPrint('[MEETINGS] ✅ Reunión $roomId marcada como completada');
      final studentId = Supabase.instance.client.auth.currentUser?.id;
      if (studentId != null) {
        await Supabase.instance.client.from('notificaciones').insert({
          'user_id': studentId,
          'titulo': 'Califica tu reunión',
          'mensaje': 'Ya puedes calificar al profesor de tu última reunión.',
          'tipo': 'calificacion',
          'referencia_id': roomId,
          'fecha': DateTime.now().toIso8601String(),
          'leida': false,
        });
        debugPrint('[NOTIFICATIONS] Notificación de calificación creada para estudiante');
      }
    } catch (e) {
      debugPrint('Error marcando reunión completada: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: carmesiClaro,
      appBar: AppBar(
        title: const Text('Unirse a reunión (Estudiante)'),
        backgroundColor: carmesi,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              carmesi,
              carmesiClaro,
            ],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: carmesi))
            : _meetings.isEmpty
                ? const Center(
                    child: Text(
                      'No tienes reuniones agendadas.',
                      style: TextStyle(color: carmesi, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _meetings.length,
                    itemBuilder: (context, index) {
                      final meeting = _meetings[index]; 
                      final fecha = DateTime.tryParse(meeting['scheduled_at'] ?? meeting['fecha_hora'] ?? '');
                      final disponible = fecha != null && fecha.isAfter(DateTime.now().subtract(const Duration(minutes: 30)));
                      final fechaStr = fecha != null
                          ? DateFormat('EEEE, dd MMM yyyy • HH:mm', 'es').format(fecha)
                          : 'Fecha desconocida';
                      final diff = fecha != null ? fecha.difference(DateTime.now()).inMinutes : null;
                      final roomId = meeting['room_id'] ?? '';

                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300 + (index * 100)),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: carmesi.withOpacity(0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: carmesi,
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: carmesiClaro,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.video_call,
                                      color: carmesi,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      meeting['subject']?.isNotEmpty == true
                                          ? meeting['subject']
                                          : 'Tutoría',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: carmesi,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (meeting['tutor_name'] != null && meeting['tutor_name'].toString().isNotEmpty)
                                Row(
                                  children: [
                                    const Icon(Icons.person, color: carmesi, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Tutor: ${meeting['tutor_name']}',
                                        style: const TextStyle(
                                          color: carmesi,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, color: carmesi, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      fechaStr,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                        color: carmesi,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Código de la sala en un rectángulo blanco con borde carmesí
                              Row(
                                children: [
                                  const Icon(Icons.key, color: carmesi, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: carmesi,
                                          width: 1.8,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: SelectableText(
                                              roomId,
                                              style: const TextStyle(
                                                color: carmesi,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy, color: carmesi, size: 20),
                                            tooltip: 'Copiar código',
                                            onPressed: () => _copiarCodigo(roomId),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (diff != null && diff > 0) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.timer_rounded, size: 20, color: carmesi),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        diff < 60
                                            ? 'Comienza en $diff min'
                                            : 'Comienza en ${(diff / 60).floor()}h ${diff % 60}min',
                                        style: const TextStyle(
                                          color: carmesi,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (disponible) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.live_tv_rounded, size: 20, color: Colors.green),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        '¡Disponible ahora!',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: disponible
                                      ? () async {
                                          final inicio = DateTime.now();
                                          await Permission.camera.request();
                                          await Permission.microphone.request();

                                          // abrir la videollamada y esperar hasta que el usuario cierre/retorne
                                          await _unirseComoEstudiante(roomId);

                                          // Al volver, marcar completada y guardar notificación
                                          try {
                                            await _marcarReunionCompletada(roomId);
                                            // refrescar lista de reuniones del estudiante
                                            await _loadMeetings();
                                            if (!mounted) return; // <-- proteger acceso a contexto/ScaffoldMessenger
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reunión completada y registrada')));
                                          } catch (e) {
                                            debugPrint('Error marcando reunión completada: $e');
                                          }

                                          final fin = DateTime.now();
                                          final duracion = fin.difference(inicio).inMilliseconds;

                                          // Agendar notificaciones (con try/catch para evitar crash por permisos exact alarm)
                                          if (fecha != null) {
                                            try {
                                              await _model.programarNotificacionReunion(
                                                titulo: 'Reunión próxima',
                                                mensaje: 'Tu reunión "${meeting['subject'] ?? 'Tutoría'}" está por comenzar.',
                                                fechaReunion: fecha,
                                                context: context,
                                                referenciaId: roomId,
                                              );
                                            } on PlatformException catch (ex) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('No se pudo programar notificación: ${ex.code}')),
                                              );
                                            } catch (e) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al programar notificación')));
                                            }
                                          }

                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('⏱️ Tiempo de respuesta: $duracion ms\nNotificación (si procede)')),
                                          );
                                        }
                                      : null,
                                  icon: const Icon(Icons.video_call, color: Colors.white),
                                  label: Text(
                                    disponible ? 'Unirse' : 'No disponible',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: disponible
                                        ? carmesi
                                        : carmesiClaro,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}