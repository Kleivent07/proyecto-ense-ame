import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:my_app/src/models/zoom_meeting_model.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../custom/library.dart';

class ChatPage extends StatefulWidget {
  final String solicitudId;
  final String? roomId;
  const ChatPage({Key? key, required this.solicitudId, this.roomId}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatModel _model = ChatModel();
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _roomId;
  Map<String, dynamic>? _solicitud;

  @override
  void initState() {
    super.initState();
    print('[CHATPAGE] init state, roomId=${widget.roomId}, solicitudId=${widget.solicitudId}');
    _roomId = widget.roomId;
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);

    // cargar datos de la solicitud
    final solicitudData = await _model.loadSolicitudData(widget.solicitudId);
    if (solicitudData != null) _solicitud = solicitudData;

    if (_roomId == null) {
      // try to find existing room quickly
      _roomId = await _model.ensureAccessAndGetRoom(widget.solicitudId);
    }
    if (_roomId != null) {
      _messages = await _model.loadMessages(_roomId!);
    } else {
      _messages = [];
    }
    if (mounted) setState(() => _loading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _scrollToEnd() {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  Future<void> _pickAndSend() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (res == null) return;
    final files = res.files;
    // if no room, create it first
    if (_roomId == null) {
      _roomId = await _model.ensureAccessAndGetRoom(widget.solicitudId);
      if (_roomId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se puede crear conversación')));
        return;
      }
    }
    final uploaded = await _model.uploadFiles(files);
    if (uploaded == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error subiendo archivos')));
      return;
    }
    final ok = await _model.sendMessage(_roomId!, '', attachments: uploaded);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al enviar archivos')));
    } else {
      // reload messages
      final m = await _model.loadMessages(_roomId!);
      if (mounted) setState(() => _messages = m);
      _scrollToEnd();
    }
  }

  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    if (_roomId == null) {
      _roomId = await _model.ensureAccessAndGetRoom(widget.solicitudId);
      if (_roomId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se puede crear conversación')));
        return;
      }
    }
    final local = {
      'id': DateTime.now().toIso8601String(),
      'user_id': Supabase.instance.client.auth.currentUser?.id,
      'content': text,
      'attachments': [],
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    setState(() {
      _messages.add(local);
      _ctrl.clear();
    });
    final ok = await _model.sendMessage(_roomId!, text);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al enviar mensaje')));
      final reloaded = await _model.loadMessages(_roomId!);
      if (mounted) setState(() => _messages = reloaded);
    } else {
      final m = await _model.loadMessages(_roomId!);
      if (mounted) setState(() => _messages = m);
      _scrollToEnd();
    }
  }

  Widget _buildMessage(Map<String, dynamic> m) {
    final meId = Supabase.instance.client.auth.currentUser?.id;
    final isMe = m['user_id'] == meId;
    final attachments = (m['attachments'] is List) ? List<Map<String, dynamic>>.from(m['attachments']) : <Map<String,dynamic>>[];
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((m['content'] ?? '').toString().isNotEmpty)
              Text(m['content'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
            for (final a in attachments)
              Builder(builder: (context) {
                final urlStr = a['url']?.toString() ?? '';
                final name = (a['name'] ?? urlStr.split('/').last ?? 'archivo').toString();
                final urlLower = urlStr.toLowerCase();

                // heurística sencilla por extensión
                bool isImage = urlLower.endsWith('.png') || urlLower.endsWith('.jpg') || urlLower.endsWith('.jpeg') || urlLower.endsWith('.webp') || urlLower.endsWith('.gif');
                bool isVideo = urlLower.endsWith('.mp4') || urlLower.endsWith('.mov') || urlLower.endsWith('.webm') || urlLower.endsWith('.mkv');

                if (isImage && urlStr.isNotEmpty) {
                  // thumbnail image
                  return GestureDetector(
                    onTap: () {
                      // abrir fullscreen (usa la clase FullScreenImagePage que añadiremos)
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => FullScreenImagePage(url: urlStr, fileName: name, downloadFn: _model.downloadAndSaveFile)));
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          urlStr,
                          width: 160,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 160,
                            height: 160,
                            color: Colors.grey,
                            child: const Icon(Icons.broken_image),
                          ),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              width: 160,
                              height: 160,
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1) : null),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                } else {
                  // archivo genérico o video: mostrar fila con icono y botón descargar / abrir
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isVideo ? Icons.videocam : Icons.insert_drive_file, size: 20, color: isMe ? Colors.white : Colors.black87),
                        const SizedBox(width: 8),
                        Flexible(child: Text(name, style: TextStyle(color: isMe ? Colors.white : Colors.black87))),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.open_in_new, size: 18, color: isMe ? Colors.white70 : Colors.black54),
                          onPressed: () async {
                            if (urlStr.isNotEmpty) {
                              try {
                                final uri = Uri.parse(urlStr);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se puede abrir el archivo externamente')));
                                }
                              } catch (e) {
                                print('[CHAT] error al abrir URL: $e');
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error abriendo el archivo')));
                              }
                            }
                          },
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.download_rounded, size: 18, color: isMe ? Colors.white70 : Colors.black54),
                          onPressed: () async {
                            if (urlStr.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay URL para descargar')));
                              return;
                            }
                            final snack = ScaffoldMessenger.of(context);
                            snack.showSnackBar(const SnackBar(content: Text('Descargando...')));
                            final saved = await _model.downloadAndSaveFile(urlStr, name);
                            snack.hideCurrentSnackBar();
                            if (saved != null) {
                              snack.showSnackBar(SnackBar(content: Text('Archivo guardado en: $saved')));
                            } else {
                              snack.showSnackBar(const SnackBar(content: Text('Error al guardar el archivo')));
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }
              }),
            const SizedBox(height: 6),
            Text(
              (m['created_at']?.toString() ?? '').split('T').first,
              style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  // Extrae una URL desde respuestas variadas de Storage (String, Map, etc.)
  String? _extractUrlFromResponse(dynamic resp) {
    if (resp == null) return null;
    if (resp is String) return resp;
    try {
      if (resp is Map) {
        // cubre varias posibles keys que usan diferentes versiones/SDKs
        if (resp.containsKey('signedURL')) return resp['signedURL']?.toString();
        if (resp.containsKey('signed_url')) return resp['signed_url']?.toString();
        if (resp.containsKey('signedUrl')) return resp['signedUrl']?.toString();
        if (resp.containsKey('url')) return resp['url']?.toString();
        // si la respuesta tiene una forma tipo { data: { signedURL: '...' } }
        if (resp.containsKey('data') && resp['data'] is Map) {
          final d = resp['data'] as Map;
          if (d.containsKey('signedURL')) return d['signedURL']?.toString();
          if (d.containsKey('url')) return d['url']?.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _model.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    // ya permitimos ver el chat aunque no exista room o no esté aceptada
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        leading: IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: 'Ir a chats',
          onPressed: () {
            // navega a la lista de chats usando tu helper central
            navigate(context, CustomPages.chatListPage);
          },
        ),
      ),
      body: Column(
        children: [
          if (_solicitud != null) Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: ListTile(
                title: Text(_solicitud!['asunto']?.toString() ?? 'Solicitud'),
                subtitle: Text('Estado: ${_solicitud!['estado'] ?? ''}'),
                trailing: Text(_solicitud!['created_at']?.toString()?.split('T').first ?? ''),
              ),
            ),
          ),
          // FutureBuilder para mostrar información de la reunión (si existe)
          FutureBuilder<List<Map<String, dynamic>>>(
            future: ZoomMeetingModel().listByRoom(_roomId ?? ''),
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
              final meet = snap.data!.first;
              final topic = meet['topic'] ?? 'Reunión';
              final start = meet['start_time']?.toString() ?? '';
              final join = meet['join_url']?.toString() ?? '';
              final startUrl = meet['start_url']?.toString() ?? '';
              final isHost = (meet['created_by']?.toString() ?? '') == Supabase.instance.client.auth.currentUser?.id;
              return Card(
                color: Colors.green[50],
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.video_call, color: Colors.green),
                  title: Text(topic),
                  subtitle: Text(start),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (join.isNotEmpty)
                        TextButton(
                          child: const Text('Unirse'),
                          onPressed: () async {
                            final uri = Uri.parse(join);
                            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                        ),
                      if (isHost && startUrl.isNotEmpty)
                        TextButton(
                          child: const Text('Iniciar'),
                          onPressed: () async {
                            final uri = Uri.parse(startUrl);
                            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessage(_messages[index]),
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.attach_file), onPressed: _pickAndSend),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: TextField(
                      controller: _ctrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Escribe un mensaje', border: OutlineInputBorder()),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: _sendText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenImagePage extends StatelessWidget {
  final String url;
  final String fileName;
  final Future<String?> Function(String url, String fileName) downloadFn;

  const FullScreenImagePage({Key? key, required this.url, required this.fileName, required this.downloadFn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () async {
              final scaffold = ScaffoldMessenger.of(context);
              scaffold.showSnackBar(const SnackBar(content: Text('Descargando...')));
              final saved = await downloadFn(url, fileName);
              scaffold.hideCurrentSnackBar();
              if (saved != null) {
                scaffold.showSnackBar(SnackBar(content: Text('Guardado: $saved')));
              } else {
                scaffold.showSnackBar(const SnackBar(content: Text('Error al guardar'))); 
              }
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64),
            loadingBuilder: (c, child, p) => p == null ? child : const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}
