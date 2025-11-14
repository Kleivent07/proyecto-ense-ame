import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/src/BackEnd/custom/GrabacionAutomatica.dart';
import 'package:my_app/src/BackEnd/custom/hybrid_recording_service.dart';
import 'package:my_app/src/BackEnd/custom/notifications_service.dart';
import 'package:my_app/src/BackEnd/custom/zego_keys.dart';
import 'package:my_app/src/models/reuniones_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:flutter/services.dart';


class CreateMeetingPage extends StatefulWidget {
  const CreateMeetingPage({Key? key}) : super(key: key);

  @override
  State<CreateMeetingPage> createState() => _CreateMeetingPageState();
}

class _CreateMeetingPageState extends State<CreateMeetingPage> {
  final _tutorCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  DateTime? _selectedDate;
  final MeetingModel _model = MeetingModel();
  bool _saving = false;
  bool _opening = false;
  String? _createdRoomId;
  bool _recordSession = false;
  final HybridRecordingService _recordingService = HybridRecordingService();
  final AutoRecordingService _autoRecordingService = AutoRecordingService();

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final displayName = user.userMetadata?['full_name']?.toString() ??
          user.email?.split('@').first ??
          '';
      if (displayName.isNotEmpty) {
        _tutorCtrl.text = displayName;
      }
    }
  }

  @override
  void dispose() {
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
    );
    if (picked != null) {
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) {
        setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
      } else {
        setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day));
      }
    }
  }

  Future<void> _create() async {
    if (_tutorCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa el nombre del tutor')));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona fecha y hora')));
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
        record: _recordSession,
      );

      setState(() {
        _saving = false;
        _createdRoomId = created?['room_id']?.toString() ?? roomId;
      });

      if (created != null) {
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reunión creada')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error creando reunión')));
      }
    } catch (e, st) {
      debugPrint('Error en _create: $e\n$st');
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ocurrió un error al crear la reunión')));
    }
  }

  void _openCreatedMeeting() async {
    if (_createdRoomId == null) return;
    setState(() => _opening = true);

    final user = Supabase.instance.client.auth.currentUser;
    final userID = user?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
    final userName = _tutorCtrl.text.trim().isEmpty ? 'Tutor' : _tutorCtrl.text.trim();

    bool recordingStarted = false;

    // Si la grabación está activada, intentar iniciar grabación automática
    if (_recordSession) {
      recordingStarted = await _autoRecordingService.startAutoRecording(context, _createdRoomId!);
      
      // Si no se pudo iniciar grabación automática, mostrar instrucciones manuales como fallback
      if (!recordingStarted) {
        await _recordingService.showPreMeetingDialog(context, _createdRoomId!);
      }
    }

    // Configuración básica
    ZegoUIKitPrebuiltCallConfig config = ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall();

    // Navegar a la llamada
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

    // Después de la llamada
    if (_recordSession && mounted) {
      if (recordingStarted && _autoRecordingService.isRecording) {
        // Detener grabación automática
        await _autoRecordingService.stopAutoRecording(context, _createdRoomId!);
      } else {
        // Mostrar diálogo manual como fallback
        await _recordingService.showPostMeetingDialog(context, _createdRoomId!);
      }
    }
  }

  Widget _buildHeader() {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.video_call, size: 28, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Crear reunión', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Agenda una sesión y configura opciones como grabación y recordatorios.', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Column(
          children: [
            TextField(
              controller: _tutorCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre del tutor',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _subjectCtrl,
              decoration: InputDecoration(
                labelText: 'Asignatura (opcional)',
                prefixIcon: const Icon(Icons.book),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_selectedDate == null
                        ? 'Elegir fecha y hora'
                        : DateFormat('dd/MM/yyyy – HH:mm').format(_selectedDate!.toLocal())),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _recordSession,
              onChanged: (v) => setState(() => _recordSession = v),
              title: const Text('Grabar clase'),
              subtitle: const Text('Marca para indicar que la sesión debe grabarse'),
              secondary: Icon(Icons.fiber_manual_record, color: _recordSession ? Colors.red : Colors.grey),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _create,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Crear reunión', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    if (_createdRoomId == null) return const SizedBox.shrink();
    return Card(
      color: Colors.grey.shade50,
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reunión creada', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SelectableText('Room ID: $_createdRoomId', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: _opening ? null : _openCreatedMeeting,
                  icon: _opening ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.videocam),
                  label: const Text('Abrir videollamada'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _createdRoomId ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room ID copiado')));
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar ID'),
                ),
                if (_recordSession)
                  Chip(label: const Text('Grabación: activada'), backgroundColor: Colors.green.shade50),
              ],
            ),
            const SizedBox(height: 6),
            Text('Comparte el Room ID con los participantes para que se unan.', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear reunión'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              _buildFormCard(),
              _buildResultCard(),
            ],
          ),
        ),
      ),
    );
  }
}