import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/custom/zego_keys.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:my_app/src/models/reuniones_model.dart';

class JoinMeetingPage extends StatefulWidget {
  final String? prefillRoomId;
  const JoinMeetingPage({Key? key, this.prefillRoomId}) : super(key: key);

  @override
  State<JoinMeetingPage> createState() => _JoinMeetingPageState();
}

class _JoinMeetingPageState extends State<JoinMeetingPage> {
  final _roomCtrl = TextEditingController();
  final MeetingModel _model = MeetingModel();
  bool _loading = false;
  List<Map<String, dynamic>> _myMeetings = [];

  @override
  void initState() {
    super.initState();
    if (widget.prefillRoomId != null) {
      _roomCtrl.text = widget.prefillRoomId!;
    }
    _loadMyMeetings();
  }

  /// Carga reuniones creadas por el usuario y filtra las expiradas (más de 1 hora pasada).
  Future<void> _loadMyMeetings() async {
    setState(() => _loading = true);
    try {
      final list = await _model.listMeetingsByTutor();
      final nowUtc = DateTime.now().toUtc();

      // Filtrar reuniones expiradas: si scheduled_at existe y ahora > scheduled_utc + 1 hora -> excluir.
      final filtered = <Map<String, dynamic>>[];
      for (final m in list) {
        final scheduledRaw = m['scheduled_at'] as String?;
        if (scheduledRaw == null) {
          // sin horario, la dejamos
          filtered.add(m);
          continue;
        }
        try {
          final scheduledUtc = DateTime.parse(scheduledRaw).toUtc();
          final expiry = scheduledUtc.add(const Duration(hours: 1));
          if (nowUtc.isAfter(expiry)) {
            // expired -> no la añadimos a la lista de unirse
            continue;
          } else {
            filtered.add(m);
          }
        } catch (e) {
          // Si falla el parseo, incluimos por seguridad
          filtered.add(m);
        }
      }

      setState(() => _myMeetings = filtered);
    } catch (e, st) {
      debugPrint('Error cargando reuniones del tutor: $e\n$st');
      setState(() => _myMeetings = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Intenta unirse por roomId. Primero valida si la reunión existe y si no está expirado.
  Future<void> _joinMeetingById(String roomId) async {
    final idTrim = roomId.trim();
    if (idTrim.isEmpty) return;

    Map<String, dynamic>? meeting;
    bool shouldRecord = false;

    // Consultar la reunión para saber si debe grabarse
    try {
      meeting = await _model.findByRoom(idTrim);
      if (meeting != null) {
        shouldRecord = meeting['record'] == true;

        final scheduledRaw = meeting['scheduled_at'] as String?;
        if (scheduledRaw != null) {
          try {
            final scheduledUtc = DateTime.parse(scheduledRaw).toUtc();
            final expiry = scheduledUtc.add(const Duration(hours: 1));
            final nowUtc = DateTime.now().toUtc();
            if (nowUtc.isAfter(expiry)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Esta reunión ya expiró y no se puede unirse.')),
              );
              return;
            }
          } catch (e) {
            debugPrint('Error parsing scheduled_at: $e');
          }
        }
      }
    } catch (e, st) {
      debugPrint('Error comprobando reunión por ID: $e\n$st');
    }

    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['full_name']?.toString() ??
        user?.email?.split('@').first ??
        'Usuario';
    final userID = user?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}';

    // Configuración básica sin onCallEnd
    ZegoUIKitPrebuiltCallConfig config = ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall();

    // Navegar a la llamada y manejar el regreso
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ZegoUIKitPrebuiltCall(
          appID: zegoAppID,
          appSign: zegoAppSign,
          userID: userID,
          userName: userName,
          callID: idTrim,
          config: config,
        ),
      ),
    );

    // Cuando regrese de la llamada, si tenía grabación y es el tutor, mostrar diálogo
    if (shouldRecord) {
      _handleCallEndForRecording(idTrim, meeting);
    }
  }

  Widget _buildTopCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Column(
          children: [
            TextField(
              controller: _roomCtrl,
              decoration: const InputDecoration(
                labelText: 'Room ID',
                prefixIcon: Icon(Icons.meeting_room),
                hintText: 'Ingresa el Room ID o pégalo aquí',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _joinMeetingById(_roomCtrl.text.trim()),
                    icon: const Icon(Icons.login),
                    label: const Text('Unirse a la videollamada'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Pegar desde portapapeles',
                  onPressed: () async {
                    final clip = await Clipboard.getData('text/plain');
                    if (clip?.text != null && clip!.text!.isNotEmpty) {
                      _roomCtrl.text = clip.text!;
                    }
                  },
                  icon: const Icon(Icons.paste),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingCard(Map<String, dynamic> m) {
    final roomId = m['room_id']?.toString() ?? '';
    final subject = m['subject']?.toString() ?? 'Reunión';
    final scheduledRaw = m['scheduled_at'] as String?;
    String scheduledLabel = '';
    bool isExpired = false;

    if (scheduledRaw != null) {
      try {
        final dt = DateTime.parse(scheduledRaw).toUtc();
        final local = dt.toLocal();
        scheduledLabel = DateFormat('dd/MM/yyyy – HH:mm').format(local);
        final expiry = dt.add(const Duration(hours: 1));
        if (DateTime.now().toUtc().isAfter(expiry)) {
          isExpired = true;
        }
      } catch (_) {
        scheduledLabel = scheduledRaw;
      }
    }

    return Opacity(
      opacity: isExpired ? 0.6 : 1.0,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(subject, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(scheduledLabel.isNotEmpty ? scheduledLabel : 'Sin fecha', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  SelectableText('ID: $roomId', style: const TextStyle(fontWeight: FontWeight.w500)),
                ]),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: isExpired ? null : () => _joinMeetingById(roomId),
                    icon: const Icon(Icons.videocam),
                    label: const Text('Unirse'),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: roomId));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room ID copiado')));
                    },
                    icon: const Icon(Icons.copy),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unirse a reunión'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refrescar mis reuniones',
            onPressed: _loadMyMeetings,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadMyMeetings,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopCard(),
                const SizedBox(height: 12),
                const Text('Mis reuniones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (!_loading && _myMeetings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No tienes reuniones programadas')),
                  ),
                if (!_loading)
                  ..._myMeetings.map((m) => _buildMeetingCard(m)).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCallEndForRecording(String roomId, Map<String, dynamic>? meeting) async {
    // Solo el tutor que creó la reunión puede agregar la grabación
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final tutorId = meeting?['tutor_id']?.toString();

    if (currentUserId != null && tutorId == currentUserId) {
      // Esperar un poco y mostrar el diálogo
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        _showRecordingUrlDialog(roomId);
      }
    }
  }

  Future<void> _showRecordingUrlDialog(String roomId) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Grabación de la reunión'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'La reunión ha terminado. Si tienes la URL de grabación, ingrésala aquí:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.url,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'URL de la grabación (opcional)',
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                  helperText: 'También puedes agregar esto después en "Reuniones Pasadas"',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return null;
                  }
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || !uri.isAbsolute) {
                    return 'Introduce una URL válida';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Omitir por ahora'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? true) {
                final url = controller.text.trim();
                if (url.isNotEmpty) {
                  try {
                    await _model.updateMeetingByRoom(roomId, recordingUrl: url);
                    Navigator.of(ctx).pop(true);
                  } catch (e) {
                    debugPrint('Error guardando recording_url: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error guardando URL'))
                    );
                  }
                } else {
                  Navigator.of(ctx).pop(false);
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL de grabación guardada'))
      );
    }
  }
}