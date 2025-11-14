import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:my_app/src/models/reuniones_model.dart';
import 'package:my_app/src/pages/Reuniones/unir_reunion_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class MeetingsHistoryPage extends StatefulWidget {
  const MeetingsHistoryPage({Key? key}) : super(key: key);

  @override
  State<MeetingsHistoryPage> createState() => _MeetingsHistoryPageState();
}

class _MeetingsHistoryPageState extends State<MeetingsHistoryPage> {
  final MeetingModel _model = MeetingModel();
  late Future<List<Map<String, dynamic>>> _futureRows;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _futureRows = _loadPastMeetingsWithRecordings();
  }

  Future<List<Map<String, dynamic>>> _loadPastMeetingsWithRecordings() async {
    final all = await _model.listMeetings();
    final now = DateTime.now().toUtc();
    
    // Filtrar solo reuniones pasadas que tengan grabación
    return all.where((r) {
      if (r['scheduled_at'] == null) return false;
      
      // Verificar que sea una reunión pasada
      try {
        final dt = DateTime.parse(r['scheduled_at']).toUtc();
        final isPast = dt.isBefore(now);
        
        // Verificar que tenga grabación disponible
        final recordingUrl = (r['recording_url'] as String?)?.trim();
        final hasRecording = recordingUrl != null && recordingUrl.isNotEmpty;
        
        return isPast && hasRecording;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  bool _isVideoUrl(String url) {
    final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'];
    final lowerUrl = url.toLowerCase();
    return videoExtensions.any((ext) => lowerUrl.contains(ext)) || 
           lowerUrl.contains('youtube.com') || 
           lowerUrl.contains('youtu.be') ||
           lowerUrl.contains('vimeo.com') ||
           lowerUrl.contains('drive.google.com');
  }

  void _showVideoPlayer(String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          videoUrl: url,
          title: title,
        ),
      ),
    );
  }

  Future<void> _openRecording(String url, String title) async {
    if (_isVideoUrl(url)) {
      // Si es un video, abrir el reproductor integrado
      _showVideoPlayer(url, title);
    } else {
      // Si no es un video reconocido, abrir externamente
      final uri = Uri.tryParse(url);
      if (uri == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL de grabación inválida'))
        );
        return;
      }
      
      if (!await canLaunchUrl(uri)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se puede abrir la URL de la grabación'))
        );
        return;
      }
      
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showEditRecordingDialog(String roomId, String? currentUrl) async {
    final controller = TextEditingController(text: currentUrl ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar URL de grabación'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.url,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'URL de la grabación',
                  hintText: 'https://...',
                  helperText: 'Soporta videos de YouTube, Vimeo, Google Drive y archivos directos',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return null; // permitimos limpiar
                  }
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || (!uri.isAbsolute)) {
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
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? true) {
                final url = controller.text.trim();
                try {
                  await _model.updateMeetingByRoom(
                    roomId, 
                    recordingUrl: url.isEmpty ? null : url
                  );
                  Navigator.of(ctx).pop(true);
                } catch (e) {
                  debugPrint('Error guardando recording_url: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error guardando URL'))
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved == true) {
      // refrescar la lista
      setState(() => _futureRows = _loadPastMeetingsWithRecordings());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL guardada'))
      );
    }
  }

  Widget _buildRecordingPreview(String url) {
    if (_isVideoUrl(url)) {
      return Container(
        width: 60,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.play_circle_filled,
          color: Colors.blue,
          size: 24,
        ),
      );
    }
    return Container(
      width: 60,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.link,
        color: Colors.grey,
        size: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grabaciones de Reuniones'),
        backgroundColor: Colors.blue[50],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureRows,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          
          final rows = snap.data ?? [];
          if (rows.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay grabaciones disponibles',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Las grabaciones aparecerán aquí después de las reuniones',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              final subject = r['subject']?.toString() ?? 'Sin asunto';
              final roomId = r['room_id']?.toString() ?? '';
              final recordingUrl = (r['recording_url'] as String?)!.trim();
              final scheduled = r['scheduled_at'] != null 
                  ? DateTime.parse(r['scheduled_at']).toLocal() 
                  : null;
              final tutorId = r['tutor_id']?.toString();
              final tutorName = r['tutor_name']?.toString() ?? 'Tutor';
              final studentName = r['student_name']?.toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openRecording(recordingUrl, subject),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Preview de la grabación
                        _buildRecordingPreview(recordingUrl),
                        const SizedBox(width: 16),
                        
                        // Información de la reunión
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              if (scheduled != null)
                                Text(
                                  DateFormat('dd/MM/yyyy – HH:mm').format(scheduled),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              if (studentName != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Estudiante: $studentName',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                              Text(
                                'Tutor: $tutorName',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Botones de acción
                        Column(
                          children: [
                            // Botón principal para ver grabación
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.play_arrow, color: Colors.white),
                                tooltip: 'Ver grabación',
                                onPressed: () => _openRecording(recordingUrl, subject),
                              ),
                            ),
                            
                            // Menú de opciones adicionales
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    if (_currentUserId != null && tutorId == _currentUserId) {
                                      _showEditRecordingDialog(roomId, recordingUrl);
                                    }
                                    break;
                                  case 'copy':
                                    Clipboard.setData(ClipboardData(text: roomId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Room ID copiado'))
                                    );
                                    break;
                                  case 'join':
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => JoinMeetingPage(prefillRoomId: roomId)
                                      )
                                    );
                                    break;
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                if (_currentUserId != null && tutorId == _currentUserId)
                                  const PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 20),
                                        SizedBox(width: 8),
                                        Text('Editar grabación'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem<String>(
                                  value: 'join',
                                  child: Row(
                                    children: [
                                      Icon(Icons.meeting_room, size: 20),
                                      SizedBox(width: 8),
                                      Text('Ir a reunión'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'copy',
                                  child: Row(
                                    children: [
                                      Icon(Icons.copy, size: 20),
                                      SizedBox(width: 8),
                                      Text('Copiar Room ID'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Página para reproducir videos
class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerPage({
    Key? key,
    required this.videoUrl,
    required this.title,
  }) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      // Para URLs de YouTube, Vimeo, etc., abrimos externamente
      if (widget.videoUrl.contains('youtube.com') || 
          widget.videoUrl.contains('youtu.be') ||
          widget.videoUrl.contains('vimeo.com')) {
        final uri = Uri.parse(widget.videoUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        Navigator.of(context).pop();
        return;
      }

      // Para videos directos, usar VideoPlayer
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize();
      setState(() {
        _isLoading = false;
      });
      _controller!.play();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error cargando el video: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : _error != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          final uri = Uri.parse(widget.videoUrl);
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        child: const Text('Abrir externamente'),
                      ),
                    ],
                  )
                : _controller != null
                    ? AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      )
                    : const Text(
                        'Error inicializando reproductor',
                        style: TextStyle(color: Colors.white),
                      ),
      ),
      floatingActionButton: _controller != null && !_isLoading && _error == null
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                });
              },
              backgroundColor: Colors.blue,
              child: Icon(
                _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}