import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get_it/get_it.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

// 🎯 Importar modelos y servicios
import '../../models/chat_model.dart';
import '../../BackEnd/services/file_service.dart';
import '../../BackEnd/services/download_service.dart';
import '../../BackEnd/services/viewer_service.dart';
import '../../BackEnd/util/constants.dart';

class ChatPage extends StatefulWidget {
  final String solicitudId;
  const ChatPage({Key? key, required this.solicitudId}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  // 🎯 Servicios
  late final ChatModel _chatModel;
  late final FileService _fileService;
  late final DownloadService _downloadService;
  late final ViewerService _viewerService;
  
  // 🎯 Controladores
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // 🎯 Estado del chat
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _solicitudData;
  String _otherUserName = 'Usuario';
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploading = false;
  
  // 🎯 Usuario actual
  String get _currentUserId => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _initializeChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    // ✨ LIMPIAR RECURSOS DEL CHAT MODEL
    _chatModel.dispose();
    super.dispose();
  }

  // 🎯 Inicializar servicios
  void _initializeServices() {
    _chatModel = ChatModel();
    _fileService = GetIt.instance<FileService>();
    _downloadService = GetIt.instance<DownloadService>();
    _viewerService = GetIt.instance<ViewerService>();
  }

  // 🎯 Inicializar chat
  Future<void> _initializeChat() async {
    try {
      setState(() => _isLoading = true);

      // ✨ ESTABLECER SOLICITUD ACTUAL EN EL MODELO DE CHAT
      _chatModel.setSolicitudActual(widget.solicitudId);

      // Verificar acceso
      if (!await _chatModel.hasAccessToSolicitud(widget.solicitudId)) {
        _showErrorAndExit('No tienes acceso a este chat');
        return;
      }

      // Cargar datos
      _solicitudData = await _chatModel.loadSolicitudData(widget.solicitudId);
      await _chatModel.createInitialMessage(widget.solicitudId);
      
      // Cargar mensajes y invertir el orden
      final loadedMessages = await _chatModel.loadMessages(widget.solicitudId);
      _messages = List.from(loadedMessages.reversed);
      
      await _loadOtherUserName();

      // Configurar polling
      _startMessagePolling();
      
      setState(() => _isLoading = false);
      
      // Hacer scroll al final
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

    } catch (e) {
      print('[CHAT] ❌ Error inicializando chat: $e');
      _showErrorAndExit('Error cargando chat: $e');
    }
  }

  // 🎯 Cargar nombre del otro usuario
  Future<void> _loadOtherUserName() async {
    if (_solicitudData == null) return;
    
    final estudianteId = _solicitudData!['estudiante_id']?.toString() ?? '';
    final profesorId = _solicitudData!['profesor_id']?.toString() ?? '';
    
    String otherUserId = '';
    if (_currentUserId == estudianteId) {
      otherUserId = profesorId;
    } else if (_currentUserId == profesorId) {
      otherUserId = estudianteId;
    }
    
    if (otherUserId.isNotEmpty) {
      try {
        final response = await Supabase.instance.client
            .from('usuarios')
            .select('nombre, apellido')
            .eq('id', otherUserId)
            .maybeSingle();
        
        if (response != null) {
          final nombre = response['nombre']?.toString() ?? '';
          final apellido = response['apellido']?.toString() ?? '';
          _otherUserName = '$nombre $apellido'.trim();
          if (mounted) setState(() {});
        }
      } catch (e) {
        debugPrint('[ChatPage] Error cargando nombre: $e');
      }
    }
  }

  // 🎯 Iniciar polling de mensajes
  void _startMessagePolling() {
    _chatModel.startPolling(widget.solicitudId, (newMessage) {
      // ✨ VERIFICAR ANTES DE setState
      if (mounted) {
        setState(() {
          _messages.insert(0, newMessage);
        });
      }
    });
  }

  // 🎯 Enviar mensaje de texto
  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    // ✨ VERIFICAR SI SIGUE MONTADO
    if (!mounted) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final success = await _chatModel.sendMessage(widget.solicitudId, text);
      
      // ✨ VERIFICAR ANTES DE MOSTRAR MENSAJES
      if (!mounted) return;
      
      if (success) {
        _showSuccess('Mensaje enviado');
        // Recargar mensajes inmediatamente
        final loadedMessages = await _chatModel.loadMessages(widget.solicitudId);
        if (mounted) {
          setState(() {
            _messages = List.from(loadedMessages.reversed);
          });
        }
      } else {
        _showError('Error enviando mensaje');
      }
    } catch (e) {
      debugPrint('[ChatPage] Error enviando mensaje: $e');
      if (mounted) _showError('Error enviando mensaje');
    } finally {
      // ✨ VERIFICAR ANTES DE setState
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  // 🎯 Seleccionar y enviar archivos - VERSIÓN MEJORADA
  Future<void> _sendFiles() async {
    if (_isUploading) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        allowCompression: true,
      );

      if (result == null || result.files.isEmpty) return;
      if (!mounted) return;

      // ✨ VALIDAR ARCHIVOS ANTES DE SUBIR
      final validationResult = _validateFiles(result.files);
      if (validationResult.hasErrors) {
        _showFileValidationDialog(validationResult);
        return;
      }

      setState(() => _isUploading = true);
      _showUploadPreview(result.files);

      final uploadedFiles = await _chatModel.uploadFiles(
        result.files,
        onProgress: (current, total, fileName) {
          if (!mounted) return;
          _updateUploadProgress(current, total, fileName);
        },
      );
      
      if (!mounted) return;
      
      if (uploadedFiles == null || uploadedFiles.isEmpty) {
        if (mounted) _showError('No se pudieron subir los archivos');
        return;
      }

      // Enviar mensaje con archivos
      final fileNames = uploadedFiles.map((f) => f['name']).join(', ');
      final message = '📎 ${uploadedFiles.length} archivo(s): $fileNames';
      
      _chatModel.sendMessage(
        widget.solicitudId,
        message,
        attachments: uploadedFiles,
      ).then((success) {
        if (mounted) {
          if (success) {
            _showSuccess('✅ ${uploadedFiles.length} archivo(s) enviado(s)');
          } else {
            _showError('❌ Error enviando archivos al chat');
          }
        }
      });

    } catch (e) {
      debugPrint('[ChatPage] Error enviando archivos: $e');
      if (mounted) {
        // ✨ MOSTRAR ERROR MÁS ESPECÍFICO
        String errorMessage = 'Error subiendo archivos';
        if (e.toString().contains('muy grande')) {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }
        _showError(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
        _hideUploadPreview();
      }
    }
  }

  // ✨ MOSTRAR PREVIEW INMEDIATO
  void _showUploadPreview(List<PlatformFile> files) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text('Subiendo ${files.length} archivo(s)...'),
            ),
          ],
        ),
        duration: Duration(seconds: 10),
        backgroundColor: Constants.colorPrimary,
      ),
    );
  }

  // ✨ MEJORAR el método _updateUploadProgress
  void _updateUploadProgress(int current, int total, String fileName) {
    print('[CHAT] 📤 Progreso: $current/$total - $fileName');
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: current / total,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Subiendo archivos... ($current/$total)'),
                  Text(
                    fileName.length > 30 
                      ? '${fileName.substring(0, 27)}...' 
                      : fileName,
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 30),
        backgroundColor: Constants.colorPrimary,
      ),
    );
  }

  // ✨ MÉTODO FALTANTE: Ocultar preview de subida
  void _hideUploadPreview() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  // ✨ NUEVA FUNCIÓN: Validar archivos antes de subir
  FileValidationResult _validateFiles(List<PlatformFile> files) {
    final result = FileValidationResult();
    
    for (final file in files) {
      final sizeMB = (file.size) / (1024 * 1024);
      final extension = file.name.split('.').last.toLowerCase();
      
      // Límites por tipo de archivo
      double maxSizeMB;
      switch (extension) {
        case 'pdf':
          maxSizeMB = 25;
          break;
        case 'jpg':
        case 'jpeg':
        case 'png':
        case 'bmp':
        case 'gif':
        case 'webp':
          maxSizeMB = 15;
          break;
        case 'mp4':
        case 'mov':
        case 'avi':
        case 'mkv':
          maxSizeMB = 50;
          break;
        default:
          maxSizeMB = 20;
          break;
      }
      
      if (sizeMB > maxSizeMB) {
        result.addError(file.name, 'Muy grande (${sizeMB.toStringAsFixed(1)}MB, máximo ${maxSizeMB}MB)');
      } else {
        result.addValid(file.name);
      }
    }
    
    return result;
  }

  // ✨ NUEVA FUNCIÓN: Mostrar diálogo de validación
  void _showFileValidationDialog(FileValidationResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archivos no válidos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.validFiles.isNotEmpty) ...[
              Text('✅ Archivos válidos:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ...result.validFiles.map((name) => Text('• $name')),
              SizedBox(height: 12),
            ],
            if (result.errorFiles.isNotEmpty) ...[
              Text('❌ Archivos rechazados:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              ...result.errorFiles.entries.map((entry) => 
                Text('• ${entry.key}: ${entry.value}', style: TextStyle(fontSize: 12))),
            ],
          ],
        ),
        actions: [
          if (result.validFiles.isNotEmpty) 
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Aquí podrías permitir subir solo los válidos
              },
              child: Text('Subir válidos (${result.validFiles.length})'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  // 🎯 Abrir archivo
  Future<void> _openFile(String url, String fileName) async {
    try {
      await _viewerService.openFile(context, url, fileName);
    } catch (e) {
      debugPrint('[ChatPage] Error abriendo archivo: $e');
      _showError('Error abriendo archivo');
    }
  }

  // 🎯 Descargar archivo
  Future<void> _downloadFile(String url, String fileName) async {
    try {
      await _viewerService.downloadFile(context, url, fileName);
    } catch (e) {
      debugPrint('[ChatPage] Error descargando: $e');
      _showError('Error descargando archivo');
    }
  }

  // 🎯 UI Helpers - CON VERIFICACIONES DE MOUNTED
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Constants.colorRosa,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Constants.colorError,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorAndExit(String message) {
    if (!mounted) return;
    _showError(message);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Constants.colorPrimaryDark,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
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
        child: SafeArea(
          child: _isLoading ? _buildLoadingView() : _buildChatView(),
        ),
      ),
    );
  }

  // 🎯 AppBar igual que Home Pro
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Constants.colorBackground.withOpacity(0.2),
              Constants.colorBackground.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Constants.colorBackground.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: Constants.colorBackground,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: Text(
        _otherUserName,
        style: Constants.textStyleBLANCOTitle,
      ),
      centerTitle: true,
      actions: [
        if (_isUploading)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Constants.colorBackground.withOpacity(0.2),
                  Constants.colorBackground.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Constants.colorBackground.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Constants.colorBackground),
              ),
            ),
          ),
      ],
      toolbarHeight: 60,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Constants.colorPrimaryDark,
              Constants.colorButton,
            ],
          ),
        ),
      ),
    );
  }

  // 🎯 Vista de carga con el estilo Home Pro
  Widget _buildLoadingView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
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
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Constants.colorButton),
            const SizedBox(height: 16),
            Text(
              'Cargando chat...',
              style: Constants.textStyleFontBold.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Preparando la conversación',
              style: Constants.textStyleFontSmall.copyWith(
                color: Constants.colorFont.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 Vista principal del chat
  Widget _buildChatView() {
    return Column(
      children: [
        // Lista de mensajes
        Expanded(
          child: _messages.isEmpty 
              ? _buildEmptyState() 
              : _buildMessagesList(),
        ),
        // Barra de entrada
        _buildInputBar(),
      ],
    );
  }

  // 🎯 Estado vacío con estilo Home Pro
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(24),
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
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Constants.colorButton.withOpacity(0.1),
                      Constants.colorOnPrimary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 48,
                  color: Constants.colorButton,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Aún no hay mensajes',
                style: Constants.textStyleFontBold.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Envía el primer mensaje para comenzar\nla conversación',
                style: Constants.textStyleFontSmall.copyWith(
                  color: Constants.colorFont.withOpacity(0.7),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎯 Lista de mensajes con fondo transparente
  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message['sender_id'] == _currentUserId;
        
        final showAvatar = index == _messages.length - 1 || 
            _messages[index + 1]['sender_id'] != message['sender_id'];
        
        return _buildMessageBubble(message, isMe, showAvatar);
      },
    );
  }

  // 🎯 Burbuja de mensaje con estilo Home Pro
  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe, bool showAvatar) {
    final content = message['content']?.toString() ?? '';
    final attachments = message['attachments'] as List<dynamic>? ?? [];
    final senderName = message['sender_name']?.toString() ?? 'Usuario';
    final timestamp = DateTime.tryParse(message['created_at']?.toString() ?? '');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // Avatar del otro usuario
          (!isMe && showAvatar)
              ? Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Constants.colorButton, Constants.colorOnPrimary],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Constants.colorBackground, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              : (!isMe
                  ? const SizedBox(width: 32)
                  : const SizedBox.shrink()),

          const SizedBox(width: 8),
          
          // Contenido del mensaje
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: isMe 
                    ? LinearGradient(
                        colors: [Constants.colorButton, Constants.colorOnPrimary],
                      )
                    : LinearGradient(
                        colors: [
                          Constants.colorBackground,
                          Constants.colorBackground.withOpacity(0.98),
                        ],
                      ),
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(6),
                  bottomRight: isMe ? const Radius.circular(6) : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre del remitente
                  if (!isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Constants.colorButton,
                        ),
                      ),
                    ),
                  
                  // Contenido del mensaje
                  if (content.isNotEmpty)
                    GestureDetector(
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Mensaje copiado')),
                        );
                      },
                      child: SelectableText(
                        content,
                        style: TextStyle(
                          color: isMe ? Constants.colorBackground : Constants.colorFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  
                  // Archivos adjuntos
                  if (attachments.isNotEmpty) ...[
                    if (content.isNotEmpty) const SizedBox(height: 8),
                    ...attachments.map((attachment) {
                      final file = attachment as Map<String, dynamic>;
                      return _buildAttachmentWidget(file, isMe);
                    }).toList(),
                  ],
                  
                  // Timestamp
                  if (timestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _formatTime(timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: (isMe ? Constants.colorBackground : Constants.colorFont)
                              .withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Avatar propio
          if (isMe && showAvatar)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Constants.colorRosa, Constants.colorRosaLight],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Constants.colorBackground, width: 2),
              ),
              child: Icon(
                Icons.person_rounded,
                size: 16,
                color: Constants.colorBackground,
              ),
            )
          else if (isMe)
            const SizedBox(width: 32),
        ],
      )
    );
  }

  // 🎯 Widget para archivos adjuntos con estilo Home Pro
  Widget _buildAttachmentWidget(Map<String, dynamic> file, bool isMe) {
    final fileName = file['name']?.toString() ?? 'Archivo';
    final fileUrl = file['url']?.toString() ?? '';
    final fileType = file['type']?.toString() ?? 'file';
    final fileSize = file['size'] as int? ?? 0;
    final extension = fileName.toLowerCase().split('.').last;
    
    // Para imágenes - mostrar inline
    if (fileType == 'image' || ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: fileUrl,
                width: 200,
                height: 150,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 200,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Constants.colorFondo2.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Constants.colorButton,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 200,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Constants.colorError.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_rounded, 
                           color: Constants.colorError, size: 32),
                      const SizedBox(height: 4),
                      Text('Error', style: Constants.textStyleFontSmall),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    fileName,
                    style: TextStyle(
                      color: isMe ? Constants.colorBackground : Constants.colorFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: (isMe ? Constants.colorBackground : Constants.colorButton).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: () => _downloadFile(fileUrl, fileName),
                    icon: Icon(
                      Icons.download_rounded,
                      color: isMe ? Constants.colorBackground : Constants.colorButton,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
    // Para otros archivos
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isMe ? Constants.colorBackground : Constants.colorButton).withOpacity(0.1),
            (isMe ? Constants.colorBackground : Constants.colorButton).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isMe ? Constants.colorBackground : Constants.colorButton).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _fileService.getFileIconColor(fileName).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _fileService.getFileIcon(fileName),
              color: _fileService.getFileIconColor(fileName),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    color: isMe ? Constants.colorBackground : Constants.colorFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (fileSize > 0)
                  Text(
                    _fileService.formatFileSize(fileSize),
                    style: TextStyle(
                      color: (isMe ? Constants.colorBackground : Constants.colorFont)
                          .withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Constants.colorButton.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () => _openFile(fileUrl, fileName),
                  icon: Icon(
                    Icons.open_in_new_rounded,
                    color: Constants.colorButton,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                decoration: BoxDecoration(
                  color: Constants.colorAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () => _downloadFile(fileUrl, fileName),
                  icon: Icon(
                    Icons.download_rounded,
                    color: Constants.colorAccent,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      )
    );
  }

  // 🎯 Barra de entrada con fondo más oscuro
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Constants.colorPrimaryDark.withOpacity(0.95),
            Constants.colorPrimary.withOpacity(0.9),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: Constants.colorBackground.withOpacity(0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Botón de archivos
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Constants.colorBackground.withOpacity(0.15),
                    Constants.colorBackground.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Constants.colorBackground.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: IconButton(
                onPressed: _isUploading ? null : _sendFiles,
                icon: _isUploading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Constants.colorBackground),
                        ),
                      )
                    : Icon(
                        Icons.attach_file_rounded,
                        color: Constants.colorBackground,
                        size: 22,
                      ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Campo de texto
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Constants.colorBackground.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Constants.colorBackground.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  style: Constants.textStyleFont.copyWith(
                    color: Constants.colorBackground,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    hintStyle: Constants.textStyleFont.copyWith(
                      color: Constants.colorBackground.withOpacity(0.6),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) => _sendTextMessage(),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Botón de envío
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isSending
                      ? [Constants.colorBackground.withOpacity(0.3), Constants.colorBackground.withOpacity(0.3)]
                      : [Constants.colorAccent, Constants.colorRosa],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: _isSending ? null : [
                  BoxShadow(
                    color: Constants.colorAccent.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _isSending ? null : _sendTextMessage,
                icon: _isSending
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Constants.colorBackground,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: Constants.colorBackground,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 Formatear tiempo
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}

// ✨ CLASE AUXILIAR: Resultado de validación de archivos
class FileValidationResult {
  final List<String> validFiles = [];
  final Map<String, String> errorFiles = {};
  
  void addValid(String fileName) => validFiles.add(fileName);
  void addError(String fileName, String error) => errorFiles[fileName] = error;
  
  bool get hasErrors => errorFiles.isNotEmpty;
  bool get hasValid => validFiles.isNotEmpty;
}
