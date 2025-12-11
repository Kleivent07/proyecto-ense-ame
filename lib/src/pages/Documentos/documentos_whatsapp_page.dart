import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/documentos_compartidos_model.dart';
import '../../BackEnd/util/constants.dart';
import '../../BackEnd/custom/custom_bottom_nav_bar.dart';

class DocumentosWhatsappPage extends StatefulWidget {
  const DocumentosWhatsappPage({Key? key}) : super(key: key);

  @override
  State<DocumentosWhatsappPage> createState() => _DocumentosWhatsappPageState();
}

class _DocumentosWhatsappPageState extends State<DocumentosWhatsappPage> with TickerProviderStateMixin {
  final DocumentosCompartidosModel _model = DocumentosCompartidosModel();
  List<ConversacionDocumentos> _conversaciones = [];
  bool _loading = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _cargarConversaciones();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _cargarConversaciones() async {
    setState(() => _loading = true);
    try {
      final conversaciones = await _model.obtenerConversacionesDocumentos();
      
      setState(() {
        _conversaciones = conversaciones;
        _loading = false;
      });
      
      _fadeController.forward();
      
    } catch (e) {
      setState(() => _loading = false);
      _showError('Error cargando conversaciones: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Constants.colorPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Constants.colorError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: _loading ? _buildLoadingView() : _buildMainContent(),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 1,
        isEstudiante: true,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        'Documentos Compartidos',
        style: Constants.textStyleBLANCOTitle.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
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

  Widget _buildLoadingView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Constants.colorBackground,
              Constants.colorBackground.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Constants.colorButton, Constants.colorOnPrimary],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: Constants.colorBackground,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Cargando documentos...',
              style: Constants.textStyleFontBold.copyWith(
                fontSize: 18,
                color: Constants.colorFont,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Organizando tus conversaciones',
              style: Constants.textStyleFont.copyWith(
                color: Constants.colorFont.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _conversaciones.isEmpty ? _buildEmptyState() : _buildConversacionesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Constants.colorBackground,
                Constants.colorBackground.withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Constants.colorButton.withOpacity(0.1),
                      Constants.colorOnPrimary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.folder_shared_outlined,
                  size: 40,
                  color: Constants.colorButton,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No hay documentos compartidos',
                style: Constants.textStyleFontBold.copyWith(
                  fontSize: 20,
                  color: Constants.colorFont,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Los documentos enviados en el chat\naparecerán aquí organizados por conversación',
                style: Constants.textStyleFont.copyWith(
                  color: Constants.colorFont.withOpacity(0.7),
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversacionesList() {
    return RefreshIndicator(
      onRefresh: _cargarConversaciones,
      color: Constants.colorButton,
      backgroundColor: Constants.colorBackground,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _conversaciones.length,
        itemBuilder: (context, index) {
          final conversacion = _conversaciones[index];
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 300 + (index * 100)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 50 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: _buildConversacionCard(conversacion, index),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildConversacionCard(ConversacionDocumentos conversacion, int index) {
    final ultimoDoc = conversacion.ultimoDocumento;
    final hasUnread = conversacion.documentosNoVistos > 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Constants.colorBackground,
            Constants.colorBackground.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          if (hasUnread)
            BoxShadow(
              color: Constants.colorAccent.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 0),
              spreadRadius: 1,
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ConversacionDocumentosPage(
                  conversacion: conversacion,
                ),
              ),
            ).then((_) => _cargarConversaciones());
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Avatar con gradiente
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _getAvatarColors(index),
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: hasUnread ? Constants.colorAccent : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getAvatarColors(index)[0].withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      conversacion.otroUsuarioNombre.isNotEmpty 
                          ? conversacion.otroUsuarioNombre[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Constants.colorBackground,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Contenido principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre del usuario
                      Text(
                        conversacion.otroUsuarioNombre,
                        style: Constants.textStyleFontBold.copyWith(
                          fontSize: 16,
                          color: Constants.colorFont,
                        ),
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // Último documento o mensaje
                      if (ultimoDoc != null) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _getFileTypeColor(ultimoDoc.tipoArchivo).withOpacity(0.2),
                                    _getFileTypeColor(ultimoDoc.tipoArchivo).withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getFileIcon(ultimoDoc.tipoArchivo),
                                size: 16,
                                color: _getFileTypeColor(ultimoDoc.tipoArchivo),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ultimoDoc.nombreArchivo,
                                style: Constants.textStyleFont.copyWith(
                                  fontSize: 13,
                                  color: Constants.colorFont.withOpacity(0.8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd/MM/yyyy - HH:mm').format(ultimoDoc.fechaSubida.toLocal()),
                          style: Constants.textStyleFont.copyWith(
                            fontSize: 11,
                            color: Constants.colorFont.withOpacity(0.6),
                          ),
                        ),
                      ] else
                        Text(
                          'No hay documentos',
                          style: Constants.textStyleFont.copyWith(
                            color: Constants.colorFont.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Badge de no leídos o flecha
                if (hasUnread)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Constants.colorAccent, Constants.colorRosa],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Constants.colorAccent.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      conversacion.documentosNoVistos.toString(),
                      style: TextStyle(
                        color: Constants.colorBackground,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Constants.colorFont.withOpacity(0.4),
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getAvatarColors(int index) {
    final colors = [
      [Constants.colorButton, Constants.colorOnPrimary],
      [Constants.colorAccent, Constants.colorRosa],
      [Constants.colorPrimary, Constants.colorButton],
      [Constants.colorOnPrimary, Constants.colorAccent],
    ];
    return colors[index % colors.length];
  }

  Color _getFileTypeColor(String? tipoArchivo) {
    switch (tipoArchivo?.toLowerCase()) {
      case 'pdf':
        return Colors.red.shade600;
      case 'doc':
      case 'docx':
        return Colors.blue.shade600;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.green.shade600;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Colors.purple.shade600;
      case 'mp3':
      case 'wav':
        return Colors.orange.shade600;
      default:
        return Constants.colorFont.withOpacity(0.7);
    }
  }

  IconData _getFileIcon(String? tipoArchivo) {
    switch (tipoArchivo?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image_rounded;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file_rounded;
      case 'mp3':
      case 'wav':
        return Icons.audio_file_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}

// ✨ PÁGINA DE CONVERSACIÓN LIMPIA
class ConversacionDocumentosPage extends StatefulWidget {
  final ConversacionDocumentos conversacion;
  
  const ConversacionDocumentosPage({Key? key, required this.conversacion}) : super(key: key);
  
  @override
  State<ConversacionDocumentosPage> createState() => _ConversacionDocumentosPageState();
}

class _ConversacionDocumentosPageState extends State<ConversacionDocumentosPage> with TickerProviderStateMixin {
  final DocumentosCompartidosModel _model = DocumentosCompartidosModel();
  List<DocumentoCompartido> _documentos = [];
  bool _loading = true;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));
    
    _cargarDocumentosConversacion();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _cargarDocumentosConversacion() async {
    setState(() => _loading = true);
    try {
      final documentos = await _model.obtenerDocumentosConversacion(
        widget.conversacion.solicitudId ?? '',
      );
      
      if (documentos.isEmpty && widget.conversacion.documentos.isNotEmpty) {
        setState(() {
          _documentos = widget.conversacion.documentos;
          _loading = false;
        });
      } else {
        setState(() {
          _documentos = documentos;
          _loading = false;
        });
      }
      
      _slideController.forward();
      
      if (widget.conversacion.solicitudId != null) {
        await _model.marcarDocumentosComoVistos(widget.conversacion.solicitudId!);
      }
      
    } catch (e) {
      setState(() => _loading = false);
      _showError('Error cargando documentos: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Constants.colorError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _descargarDocumento(DocumentoCompartido documento) async {
    try {
      _showMessage('Descargando ${documento.nombreArchivo}...');
      
      // Aquí implementarías la lógica real de descarga
      await Future.delayed(Duration(seconds: 1));
      _showMessage('✅ Descarga completada');
      
    } catch (e) {
      _showError('Error descargando archivo');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Constants.colorPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: _loading ? _buildLoadingView() : _buildMainContent(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.conversacion.otroUsuarioNombre,
            style: Constants.textStyleBLANCOTitle.copyWith(fontSize: 18),
          ),
          Text(
            '${_documentos.length} documento(s)',
            style: Constants.textStyleFont.copyWith(
              color: Constants.colorBackground.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
      centerTitle: false,
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

  Widget _buildLoadingView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Constants.colorBackground,
              Constants.colorBackground.withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Constants.colorButton, Constants.colorOnPrimary],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: Constants.colorBackground,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Cargando documentos...',
              style: Constants.textStyleFontBold.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Organizando archivos de la conversación',
              style: Constants.textStyleFont.copyWith(
                color: Constants.colorFont.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SlideTransition(
      position: _slideAnimation,
      child: _documentos.isEmpty ? _buildEmptyState() : _buildDocumentosList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Constants.colorBackground,
                Constants.colorBackground.withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Constants.colorButton.withOpacity(0.1),
                      Constants.colorOnPrimary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.folder_open_outlined,
                  size: 40,
                  color: Constants.colorButton,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No hay documentos',
                style: Constants.textStyleFontBold.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 12),
              Text(
                'No se han compartido documentos\nen esta conversación',
                style: Constants.textStyleFont.copyWith(
                  color: Constants.colorFont.withOpacity(0.7),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentosList() {
    return RefreshIndicator(
      onRefresh: _cargarDocumentosConversacion,
      color: Constants.colorButton,
      backgroundColor: Constants.colorBackground,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _documentos.length,
        itemBuilder: (context, index) {
          final documento = _documentos[index];
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 400 + (index * 100)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: _buildDocumentoCard(documento),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDocumentoCard(DocumentoCompartido documento) {
    final isFromCurrentUser = documento.emisorId == Supabase.instance.client.auth.currentUser?.id;
    final fileColor = _getFileTypeColor(documento.tipoArchivo);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Constants.colorBackground,
            Constants.colorBackground.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: fileColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 0),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con icono y info del archivo
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        fileColor.withOpacity(0.2),
                        fileColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: fileColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _getFileIcon(documento.tipoArchivo),
                    size: 24,
                    color: fileColor,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        documento.nombreArchivo,
                        style: Constants.textStyleFontBold.copyWith(
                          fontSize: 16,
                          color: Constants.colorFont,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatFileSize(documento.tamano)} • ${documento.tipoArchivo.toUpperCase()}',
                        style: Constants.textStyleFont.copyWith(
                          fontSize: 12,
                          color: Constants.colorFont.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Botón de descarga
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Constants.colorButton, Constants.colorOnPrimary],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Constants.colorButton.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () => _descargarDocumento(documento),
                    icon: Icon(
                      Icons.download_rounded,
                      color: Constants.colorBackground,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            
            // Descripción si existe
            if (documento.descripcion != null && documento.descripcion!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Constants.colorButton.withOpacity(0.05),
                      Constants.colorOnPrimary.withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Constants.colorButton.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Text(
                  documento.descripcion!,
                  style: Constants.textStyleFont.copyWith(
                    fontSize: 14,
                    color: Constants.colorFont.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ),
            ],
            
            // Footer con fecha y emisor
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy - HH:mm').format(documento.fechaSubida.toLocal()),
                  style: Constants.textStyleFont.copyWith(
                    fontSize: 12,
                    color: Constants.colorFont.withOpacity(0.6),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isFromCurrentUser 
                          ? [Colors.green.shade400, Colors.green.shade600]
                          : [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isFromCurrentUser ? Colors.green : Colors.blue).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    isFromCurrentUser ? 'Enviado por ti' : 'Recibido',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getFileTypeColor(String? tipoArchivo) {
    switch (tipoArchivo?.toLowerCase()) {
      case 'pdf':
        return Colors.red.shade600;
      case 'doc':
      case 'docx':
        return Colors.blue.shade600;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.green.shade600;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Colors.purple.shade600;
      case 'mp3':
      case 'wav':
        return Colors.orange.shade600;
      default:
        return Constants.colorFont.withOpacity(0.7);
    }
  }

  IconData _getFileIcon(String? tipoArchivo) {
    switch (tipoArchivo?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image_rounded;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file_rounded;
      case 'mp3':
      case 'wav':
        return Icons.audio_file_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    return '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${suffixes[i]}';
  }
}