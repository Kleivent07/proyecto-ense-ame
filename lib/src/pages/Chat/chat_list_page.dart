import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/custom/custom_bottom_nav_bar.dart';
import 'package:my_app/src/pages/Chat/chat_page.dart';
import 'package:my_app/src/models/chat_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({Key? key}) : super(key: key);

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatModel _model = ChatModel();
  bool _loading = true;
  List<Map<String, dynamic>> _conversations = [];
  bool _isEstudiante = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _detectRole();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    try {
      final conversations = await _model.listConversations();
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _loading = false;
        });
      }
    } catch (e) {
      print('[CHAT_LIST] Error cargando conversaciones: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando chats: $e')),
        );
      }
    }
  }

  Future<void> _detectRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isEstudiante = true);
        return;
      }

      // Intentar detectar el rol desde diferentes tablas
      try {
        final perfilResponse = await Supabase.instance.client
            .from('perfiles')
            .select('clase')
            .eq('user_id', user.id)
            .maybeSingle();

        if (perfilResponse != null) {
          final clase = perfilResponse['clase']?.toString() ?? '';
          setState(() => _isEstudiante = (clase != 'Tutor'));
          return;
        }
      } catch (_) {}

      // Fallback: verificar si existe en tabla profesores
      try {
        final profesorResponse = await Supabase.instance.client
            .from('profesores')
            .select('id')
            .eq('user_id', user.id)
            .maybeSingle();

        setState(() => _isEstudiante = (profesorResponse == null));
      } catch (_) {
        setState(() => _isEstudiante = true);
      }
    } catch (e) {
      print('[CHAT_LIST] Error detectando rol: $e');
      setState(() => _isEstudiante = true);
    }
  }

  String _getOtherParticipantInfo(Map<String, dynamic> solicitud) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 'Usuario desconocido';

    final estudianteId = solicitud['estudiante_id']?.toString();
    final profesorId = solicitud['profesor_id']?.toString();
    
    if (user.id == estudianteId) {
      return 'Conversación con profesor';
    } else if (user.id == profesorId) {
      return 'Conversación con estudiante';
    }
    
    return 'Participantes: Estudiante y Profesor';
  }

  String _formatLastMessageTime(String? dateTimeString) {
    if (dateTimeString == null) return '';
    
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
      
      if (messageDate == today) {
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else {
        final diff = today.difference(messageDate).inDays;
        if (diff == 1) return 'Ayer';
        if (diff < 7) return '${diff} días';
        return '${dateTime.day}/${dateTime.month}';
      }
    } catch (e) {
      return dateTimeString.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedConversations = List<Map<String, dynamic>>.from(_conversations);
    sortedConversations.sort((a, b) {
      final fechaA = a['last_message']?['created_at'] ?? '';
      final fechaB = b['last_message']?['created_at'] ?? '';
      return fechaB.compareTo(fechaA); // Más reciente arriba
    });

    return Scaffold(
      backgroundColor: Constants.colorPrimaryDark,
      appBar: AppBar(
        title: Text(
          'Mis Chats',
          style: TextStyle(
            color: Constants.colorBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Constants.colorPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : sortedConversations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedConversations.length,
                    itemBuilder: (context, index) => _buildConversationItem(sortedConversations[index]),
                  ),
                ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 3, // índice del tab Chat
        isEstudiante: _isEstudiante,
        onReloadHome: _loadConversations,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Constants.colorBackground.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay conversaciones',
            style: TextStyle(
              fontSize: 18,
              color: Constants.colorBackground.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las conversaciones aparecerán cuando tengas\nsolicitudes de tutoría aceptadas',
            style: TextStyle(
              color: Constants.colorBackground.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConversationItem(Map<String, dynamic> conversation) {
    final solicitudData = conversation['solicitud'];
    final solicitud = solicitudData is Map<String, dynamic> 
        ? solicitudData 
        : Map<String, dynamic>.from(solicitudData as Map);

    final lastMessageData = conversation['last_message'];
    final lastMessage = lastMessageData != null && lastMessageData is Map<String, dynamic>
        ? lastMessageData
        : (lastMessageData != null ? Map<String, dynamic>.from(lastMessageData as Map) : null);

    // Contador de mensajes
    final mensajesCount = (conversation['mensajes'] is List)
        ? (conversation['mensajes'] as List).length
        : (conversation['mensajes_count'] ?? 0);

    final title = solicitud['other_user_name']?.toString() ?? 'Usuario';
    final subtitle = solicitud['mensaje']?.toString().isNotEmpty == true 
        ? 'Solicitud: ${solicitud['mensaje']?.toString()}'
        : 'Solicitud de tutoría';
    final hasMessages = lastMessage != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Constants.colorBackground,
            Constants.colorBackground.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: hasMessages ? Constants.colorAccent : Constants.colorFondo2,
          child: Icon(
            hasMessages ? Icons.chat : Icons.chat_bubble_outline,
            color: Constants.colorBackground,
            size: 24,
          ),
        ),
        title: Text(
          mensajesCount > 0
            ? '$title (${mensajesCount} mensajes)'
            : title, // Solo muestra el contador si hay al menos 1 mensaje
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Constants.colorFont.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
            if (hasMessages) ...[
              const SizedBox(height: 4),
              Text(
                lastMessage['content']?.toString() ?? 'Archivo adjunto',
                style: TextStyle(
                  color: Constants.colorFont.withOpacity(0.8),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasMessages)
              Text(
                _formatLastMessageTime(lastMessage['created_at']?.toString()),
                style: TextStyle(
                  color: Constants.colorFont.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
            const SizedBox(height: 4),
            Icon(
              Icons.arrow_forward_ios,
              color: Constants.colorAccent,
              size: 16,
            ),
          ],
        ),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatPage(solicitudId: solicitud['id'].toString()),
            ),
          );
          // Recargar conversaciones al volver
          _loadConversations();
        },
      ),
    );
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }
}
