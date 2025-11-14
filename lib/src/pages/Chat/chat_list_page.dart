import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/custom/custom_bottom_nav_bar.dart';
import 'package:my_app/src/pages/Chat/chat_page.dart';
import 'package:my_app/src/models/chat_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({Key? key}) : super(key: key);

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatModel _model = ChatModel();
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  bool? _isEstudiante;

  @override
  void initState() {
    super.initState();
    _load();
    _detectRole();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _model.listConversations();
    if (mounted)
      setState(() {
        _items = items;
        _loading = false;
      });
  }

  Future<void> _detectRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isEstudiante = true); // fallback
        return;
      }
      final raw = await Supabase.instance.client
          .from('perfiles') // o la tabla que uses para perfil; ajusta si es distinta
          .select('clase')
          .eq('user_id', user.id)
          .maybeSingle();

      final Map<String, dynamic>? data = (() {
        if (raw is Map<String, dynamic>) {
          final map = raw as Map<String, dynamic>;
          if (map.containsKey('clase')) return map;
          if (map['data'] is Map<String, dynamic>) return map['data'] as Map<String, dynamic>;
        }
        return null;
      })();
      final clase = data != null ? (data['clase'] ?? '') : '';
      setState(() => _isEstudiante = (clase != 'Tutor'));
    } catch (_) {
      setState(() => _isEstudiante = true);
    }
  }

  String _otherParticipant(Map<String, dynamic> solicitud) {
    // Muestra estudiante o profesor según quien no sea el current user.
    final s = solicitud;
    // Aquí simplificado: mostramos ids; adapta para pedir profiles si quieres nombre.
    final estudiante = s['estudiante_id']?.toString() ?? '';
    final profesor = s['profesor_id']?.toString() ?? '';
    return 'Estudiante: $estudiante\nProfesor: $profesor';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final it = _items[i];
                  final solicitud = it['solicitud'] as Map<String, dynamic>;
                  final roomId = it['room_id'] as String?;
                  // ejemplo dentro del ListTile:
                  final title = (solicitud['asunto'] ??
                      solicitud['titulo'] ??
                      solicitud['title'] ??
                      solicitud['subject'] ??
                      solicitud['descripcion'] ??
                      solicitud['descripcion_solicitud'] ??
                      'Solicitud').toString();

                  final estadoStr = (solicitud['estado'] ??
                      solicitud['status'] ??
                      solicitud['estado_solicitud'] ??
                      '').toString();

                  return Card(
                    child: ListTile(
                      title: Text(title),
                      subtitle: Text('Estado: $estadoStr\n${_otherParticipant(solicitud)}'),
                      trailing: roomId == null ? const Icon(Icons.chat_bubble_outline) : const Icon(Icons.chat),
                      onTap: () async {
                        // Navegar a chat page, si roomId null, ChatPage intentará crear room al enviar (si las políticas lo permiten)
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatPage(solicitudId: solicitud['id'].toString(), roomId: roomId)));
                        _load(); // reload after returning (maybe a room was created)
                      },
                    ),
                  );
                },
              ),
            ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 3, // índice del tab Chat
        isEstudiante: true, // valor por defecto; ver nota abajo para hacerlo dinámico
        onReloadHome: () {
          // si quieres recargar la lista cuando vienen desde Home
          _load();
        },
      ),
    );
  }
}
