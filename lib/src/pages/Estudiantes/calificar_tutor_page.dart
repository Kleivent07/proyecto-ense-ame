import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/BackEnd/custom/no_teclado.dart';
import 'package:my_app/src/models/tutor_rating_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalificarTutorPage extends StatefulWidget {
  final String meetingId;
  final String tutorId;
  final String tutorName;
  final String subject;

  const CalificarTutorPage({
    Key? key,
    required this.meetingId,
    required this.tutorId,
    required this.tutorName,
    required this.subject,
  }) : super(key: key);

  @override
  State<CalificarTutorPage> createState() => _CalificarTutorPageState();
}

class _CalificarTutorPageState extends State<CalificarTutorPage> with TickerProviderStateMixin {
  final TutorRatingModel _ratingModel = TutorRatingModel();
  final TextEditingController _commentsController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  int _selectedRating = 0;
  bool _isSubmitting = false;
  bool _hasExistingRating = false;
  String? _existingRatingId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _checkExistingRating();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingRating() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    debugPrint('[CALIFICAR] 🔍 Verificando calificación existente para reunión: ${widget.meetingId}');

    final existingRating = await _ratingModel.getStudentRatingForMeeting(
      meetingId: widget.meetingId,
      studentId: currentUser.id,
    );

    if (!mounted) return;

    if (existingRating != null) {
      setState(() {
        _hasExistingRating = true;
        _selectedRating = existingRating['rating'] ?? 0;
        _commentsController.text = existingRating['comments'] ?? '';
        _existingRatingId = existingRating['rating_id']?.toString() ?? existingRating['id']?.toString();
      });

      debugPrint('[CALIFICAR] ✅ Calificación existente encontrada: Rating=${existingRating['rating']}, ID=$_existingRatingId');
    } else {
      debugPrint('[CALIFICAR] 📝 No hay calificación existente, creando nueva');
    }
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) {
      _showSnackBar('Por favor selecciona una calificación', isError: true);
      return;
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      _showSnackBar('Usuario no autenticado', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      Map<String, dynamic> result;
      final subjectToRate = widget.subject.isNotEmpty ? widget.subject : 'Tutoría General';

      if (_hasExistingRating && _existingRatingId != null) {
        debugPrint('[CALIFICAR] 🔄 Actualizando calificación existente: $_existingRatingId');
        result = await _ratingModel.updateRating(
          ratingId: _existingRatingId!,
          rating: _selectedRating,
          subject: subjectToRate,
          comments: _commentsController.text.trim().isEmpty ? null : _commentsController.text.trim(),
        );
      } else {
        debugPrint('[CALIFICAR] ✨ Creando nueva calificación');
        result = await _ratingModel.createRating(
          meetingId: widget.meetingId,
          tutorId: widget.tutorId,
          studentId: currentUser.id,
          subject: subjectToRate,
          rating: _selectedRating,
          comments: _commentsController.text.trim().isEmpty ? null : _commentsController.text.trim(),
        );
      }

      if (result['success'] == true) {
        _showSnackBar(result['message'], isError: false);
        debugPrint('[CALIFICAR] ✅ Operación exitosa: ${result['message']}');
        Navigator.pop(context, true);
      } else {
        _showSnackBar(result['message'], isError: true);
        debugPrint('[CALIFICAR] ❌ Error: ${result['message']}');
      }
    } catch (e) {
      _showSnackBar('Error inesperado: $e', isError: true);
      debugPrint('[CALIFICAR] ❌ Excepción: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Constants.colorBackground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Constants.textStyleBLANCO,
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Constants.colorError : Constants.colorAccent,
        duration: Duration(seconds: isError ? 4 : 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return cerrarTecladoAlTocar(
      child: Scaffold(
        backgroundColor: Constants.colorPrimaryDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Constants.colorBackground.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back, color: Constants.colorBackground, size: 20),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _hasExistingRating ? 'Editar Calificación' : 'Calificar Reunión',
            style: Constants.textStyleBLANCOTitle,
          ),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Constants.colorPrimaryDark,
                  Constants.colorPrimary,
                ],
              ),
            ),
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
                Constants.colorPrimaryLight.withOpacity(0.1),
              ],
              stops: const [0.0, 0.7, 1.0],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ✨ Header elegante con información de la reunión
                      _buildElegantMeetingInfo(),
                      const SizedBox(height: 24),
                      
                      // ✨ Tarjeta de información sobre calificación anónima
                      _buildAnonymousInfo(),
                      const SizedBox(height: 24),
                      
                      // ✨ Sección principal de calificación
                      _buildModernRatingSection(),
                      const SizedBox(height: 24),
                      
                      // ✨ Sección de comentarios mejorada
                      _buildModernCommentsSection(),
                      const SizedBox(height: 32),
                      
                      // ✨ Botón de envío elegante
                      _buildElegantSubmitButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildElegantMeetingInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con icono de estrella
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Constants.colorAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.star_rounded,
                  color: Constants.colorAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Califica tu experiencia',
                      style: Constants.textStyleFontBold.copyWith(fontSize: 18),
                    ),
                    Text(
                      'Tu opinión es valiosa para la comunidad',
                      style: Constants.textStyleFont.copyWith(
                        color: Constants.colorFont.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Información del tutor
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Constants.colorRosa.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: Constants.colorRosa,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tutor',
                      style: Constants.textStyleFontSmall.copyWith(
                        color: Constants.colorFont.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      widget.tutorName,
                      style: Constants.textStyleFontBold.copyWith(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Información de la materia
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Constants.colorSecondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.subject_rounded,
                  color: Constants.colorAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Materia',
                      style: Constants.textStyleFontSmall.copyWith(
                        color: Constants.colorFont.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      widget.subject.isNotEmpty ? widget.subject : 'Tutoría General',
                      style: Constants.textStyleFontSemiBold.copyWith(
                        fontSize: 16,
                        color: Constants.colorAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnonymousInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Constants.colorRosaLight.withOpacity(0.1),
            Constants.colorRosa.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Constants.colorRosa.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            color: Constants.colorRosa,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calificación 100% Anónima',
                  style: Constants.textStyleFontBold.copyWith(
                    color: Constants.colorRosa,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tu identidad permanece completamente privada. Solo tu calificación y comentarios serán visibles.',
                  style: Constants.textStyleFontSmall.copyWith(
                    color: Constants.colorFont.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernRatingSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Constants.colorBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Cómo estuvo el tutor en esta materia?',
            style: Constants.textStyleFontTitle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Constants.colorAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.subject.isNotEmpty ? widget.subject : 'Tutoría General',
              style: Constants.textStyleAccentSemiBold.copyWith(fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          
          // Estrellas interactivas mejoradas
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNumber = index + 1;
                final isActive = starNumber <= _selectedRating;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRating = starNumber;
                    });
                    // Pequeña vibración al seleccionar
                    // HapticFeedback.lightImpact();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isActive ? Constants.colorAccent.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Icon(
                      isActive ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isActive ? Constants.colorAccent : Constants.colorFont.withOpacity(0.3),
                      size: 36,
                    ),
                  ),
                );
              }),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Texto descriptivo de la calificación
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey(_selectedRating),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getReactionColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getRatingText(_selectedRating),
                  style: Constants.textStyleFontSemiBold.copyWith(
                    color: _getReactionColor(),
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCommentsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Constants.colorBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: Constants.colorAccent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Comentarios (opcional)',
                style: Constants.textStyleFontTitle.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Comparte detalles sobre tu experiencia de aprendizaje',
            style: Constants.textStyleFont.copyWith(
              color: Constants.colorFont.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          
          TextField(
            controller: _commentsController,
            maxLines: 4,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: '¿Qué tal fue la explicación? ¿Te ayudó a entender mejor? ¿Recomendarías este tutor?',
              hintStyle: Constants.textStyleFont.copyWith(
                color: Constants.colorFont.withOpacity(0.5),
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Constants.colorFont.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Constants.colorFont.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Constants.colorAccent,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Constants.colorFondo2.withOpacity(0.3),
              contentPadding: const EdgeInsets.all(16),
              counterStyle: Constants.textStyleFontSmall.copyWith(
                color: Constants.colorFont.withOpacity(0.6),
              ),
            ),
            style: Constants.textStyleFont,
          ),
        ],
      ),
    );
  }

  Widget _buildElegantSubmitButton() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: _isSubmitting 
              ? [Constants.colorFont.withOpacity(0.3), Constants.colorFont.withOpacity(0.3)]
              : [Constants.colorAccent, Constants.colorRosa],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Constants.colorAccent.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitRating,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Constants.colorBackground),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Enviando...',
                    style: Constants.textStyleBLANCOSemiBold.copyWith(fontSize: 16),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _hasExistingRating ? Icons.edit_rounded : Icons.send_rounded,
                    color: Constants.colorBackground,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _hasExistingRating ? 'Actualizar Calificación' : 'Enviar Calificación',
                    style: Constants.textStyleBLANCOSemiBold.copyWith(fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }

  Color _getReactionColor() {
    switch (_selectedRating) {
      case 1:
        return Constants.colorError;
      case 2:
        return Constants.colorError.withOpacity(0.8);
      case 3:
        return Constants.colorFont;
      case 4:
        return Constants.colorAccent;
      case 5:
        return Constants.colorRosa;
      default:
        return Constants.colorFont.withOpacity(0.5);
    }
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return '😞 Necesita mejorar mucho';
      case 2:
        return '😐 Puede mejorar';
      case 3:
        return '🙂 Estuvo bien';
      case 4:
        return '😊 Muy bueno';
      case 5:
        return '🤩 ¡Excelente!';
      default:
        return 'Toca una estrella para calificar';
    }
  }
}