import 'package:flutter/material.dart';
import 'package:my_app/src/models/reuniones_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/BackEnd/custom/zego_keys.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class UnirPROPage extends StatefulWidget {
  const UnirPROPage({Key? key}) : super(key: key);

  @override
  State<UnirPROPage> createState() => _UnirPROPageState();
}

class _UnirPROPageState extends State<UnirPROPage> {
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
      final meetings = await _model.listMeetingsByTutor(userId);
      // Filtrar reuniones: solo las que no han pasado más de 1 hora
      final now = DateTime.now();
      final filtered = meetings.where((m) {
        final fecha = DateTime.tryParse(m['scheduled_at'] ?? m['fecha_hora'] ?? '');
        if (fecha == null) return false;
        return fecha.isAfter(now.subtract(const Duration(hours: 1)));
      }).toList();
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

  Future<void> _unirseComoProfesor(String roomId) async {
    // Solicitar permisos
    await Permission.camera.request();
    await Permission.microphone.request();

    // Verificar permisos
    if (await Permission.camera.isGranted && await Permission.microphone.isGranted) {
      final user = Supabase.instance.client.auth.currentUser;
      final userName = user?.userMetadata?['full_name']?.toString() ?? user?.email?.split('@').first ?? 'Profesor';
      if (user == null) return;

      Navigator.push(
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Debes conceder permisos de cámara y micrófono para la reunión')),
      );
    }
  }

  void _copiarCodigo(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Código copiado: $code'),
        backgroundColor: Constants.colorError,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorPrimaryDark,
      appBar: AppBar(
        title: const Text('Unirse a reunión (Profesor)'),
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _meetings.isEmpty
                ? Center(
                    child: Text(
                      'No tienes reuniones próximas.',
                      style: TextStyle(
                        color: Constants.colorFont.withOpacity(0.7),
                        fontSize: 18,
                      ),
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
                          border: Border.all(
                            color: Constants.colorButton.withOpacity(0.2),
                            width: 1.5,
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
                                      color: Constants.colorButton.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.video_call,
                                      color: Constants.colorButton,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      meeting['subject']?.isNotEmpty == true
                                          ? meeting['subject']
                                          : 'Tutoría',
                                      style: Constants.textStyleFontBold.copyWith(fontSize: 18),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Icons.person, color: Constants.colorButton, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Estudiante: ${meeting['student_name'] ?? 'Sin asignar'}',
                                      style: Constants.textStyleFont.copyWith(
                                        color: Constants.colorButton,
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
                                  Icon(Icons.schedule_rounded, color: Constants.colorFont.withOpacity(0.7), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      fechaStr,
                                      style: Constants.textStyleFontSemiBold.copyWith(fontSize: 15),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Código de la sala en un rectángulo con colores café
                              Row(
                                children: [
                                  Icon(Icons.key, color: Constants.colorPrimary, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white, // Fondo blanco
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Constants.colorPrimary, // Borde café
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: SelectableText(
                                              roomId,
                                              style: TextStyle(
                                                color: Constants.colorPrimary, // Texto café
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.copy, color: Constants.colorPrimary, size: 20),
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
                                    Icon(Icons.timer_rounded, size: 20, color: Constants.colorButton),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        diff < 60
                                            ? 'Comienza en $diff min'
                                            : 'Comienza en ${(diff / 60).floor()}h ${diff % 60}min',
                                        style: Constants.textStyleFont.copyWith(
                                          color: Constants.colorButton,
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
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: disponible
                                      ? () async {
                                          final inicio = DateTime.now();
                                          await _unirseComoProfesor(roomId); // o _unirseComoEstudiante(roomId)
                                          final fin = DateTime.now();
                                          final duracion = fin.difference(inicio).inMilliseconds;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('⏱️ Tiempo de respuesta: $duracion ms')),
                                          );
                                        }
                                      : null,
                                  icon: const Icon(Icons.video_call, color: Colors.white),
                                  label: Text(
                                    disponible ? 'Unirse' : 'No disponible',
                                    style: Constants.textStyleBLANCOSemiBold.copyWith(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: disponible
                                        ? Constants.colorError
                                        : Constants.colorFont.withOpacity(0.2),
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