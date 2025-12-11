import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/models/tutor_rating_model.dart';
import 'package:my_app/src/pages/Estudiantes/calificar_tutor_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MisCalificacionesPage extends StatefulWidget {
  const MisCalificacionesPage({Key? key}) : super(key: key);

  @override
  State<MisCalificacionesPage> createState() => _MisCalificacionesPageState();
}

class _MisCalificacionesPageState extends State<MisCalificacionesPage> with TickerProviderStateMixin {
  final TutorRatingModel _ratingModel = TutorRatingModel();
  List<Map<String, dynamic>> _myRatings = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _loadMyRatings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadMyRatings() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      debugPrint('[CLASIFICAR] 🔍 Cargando calificaciones del estudiante...');

      final ratings = await _ratingModel.getStudentSubmittedRatings(currentUser.id);

      debugPrint('[CLASIFICAR] ✅ ${ratings.length} calificaciones cargadas');

      setState(() {
        _myRatings = ratings;
        _isLoading = false;
      });
      
      _animationController.forward();
    } catch (e) {
      debugPrint('[CLASIFICAR] ❌ Error cargando calificaciones: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          'Mis Calificaciones',
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
        child: _isLoading
            ? _buildLoadingState()
            : _myRatings.isEmpty
                ? _buildEmptyState()
                : _buildRatingsList(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Constants.colorBackground.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Constants.colorAccent),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Cargando tus calificaciones...',
            style: Constants.textStyleBLANCO.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 64.0), // <-- Aumenta el vertical
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Constants.colorBackground.withOpacity(0.15),
                        Constants.colorBackground.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    Icons.star_border_rounded,
                    size: 80,
                    color: Constants.colorBackground.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  '¡Aún no has calificado!',
                  style: Constants.textStyleBLANCOTitle.copyWith(fontSize: 24),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Después de completar reuniones con tutores\npodrás calificar tu experiencia aquí',
                  style: Constants.textStyleBLANCO.copyWith(
                    fontSize: 16,
                    color: Constants.colorBackground.withOpacity(0.8),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Constants.colorAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Constants.colorAccent.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: Constants.colorAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Tus calificaciones ayudan a otros estudiantes',
                          style: Constants.textStyleBLANCOSmall.copyWith(
                            color: Constants.colorAccent,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.visible,
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingsList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _loadMyRatings,
        color: Constants.colorAccent,
        backgroundColor: Constants.colorBackground,
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: _myRatings.length + 1, // +1 para el header
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildStatsHeader();
            }
            final rating = _myRatings[index - 1];
            return _buildElegantRatingCard(rating, index - 1);
          },
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    final totalRatings = _myRatings.length;
    final averageRating = totalRatings > 0 
        ? _myRatings.fold<double>(0, (sum, rating) => sum + rating['rating']) / totalRatings
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Constants.colorAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: Constants.colorAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen de Calificaciones',
                      style: Constants.textStyleFontTitle.copyWith(fontSize: 18),
                    ),
                    Text(
                      'Tu historial de evaluaciones',
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
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.star_rounded,
                  value: totalRatings.toString(),
                  label: 'Calificaciones',
                  color: Constants.colorAccent,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Constants.colorFont.withOpacity(0.2),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.trending_up_rounded,
                  value: averageRating.toStringAsFixed(1),
                  label: 'Promedio',
                  color: Constants.colorRosa,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              value,
              style: Constants.textStyleFontTitle.copyWith(
                fontSize: 24,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Constants.textStyleFontSmall.copyWith(
            color: Constants.colorFont.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildElegantRatingCard(Map<String, dynamic> rating, int index) {
    final ratingValue = rating['rating'] as int;
    final tutorName = rating['meeting_tutor_name'] ?? rating['tutor_name'] ?? 'Tutor';
    final subject = rating['meeting_subject'] ?? rating['subject'] ?? 'Tutoría General';
    final scheduledAt = rating['meeting_scheduled_at'] != null 
        ? DateTime.parse(rating['meeting_scheduled_at'])
        : (rating['created_at'] != null ? DateTime.parse(rating['created_at']) : DateTime.now());
    final comments = rating['comments'] as String?;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Container(
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
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _editRating(rating),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con información del tutor y fecha
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      tutorName,
                                      style: Constants.textStyleFontBold.copyWith(fontSize: 18),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Constants.colorAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.subject_rounded,
                                      color: Constants.colorAccent,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      subject,
                                      style: Constants.textStyleAccentSemiBold.copyWith(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Constants.colorFont.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _formatDate(scheduledAt),
                            style: Constants.textStyleFontSmall.copyWith(
                              color: Constants.colorFont.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Estrellas de calificación
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < ratingValue ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: index < ratingValue ? Constants.colorAccent : Constants.colorFont.withOpacity(0.3),
                            size: 24,
                          );
                        }),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getRatingColor(ratingValue).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$ratingValue/5',
                            style: Constants.textStyleFontBold.copyWith(
                              color: _getRatingColor(ratingValue),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // ID de calificación (si existe)
                    if (rating['rating_id'] != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Constants.colorSecondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Constants.colorSecondary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'ID: ${rating['rating_id']}',
                          style: Constants.textStyleFontSmall.copyWith(
                            color: Constants.colorSecondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                    
                    // Comentarios (si existen)
                    if (comments != null && comments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Constants.colorFondo2.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Constants.colorFont.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Constants.colorAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Mi comentario:',
                                  style: Constants.textStyleFontSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Constants.colorAccent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              comments,
                              style: Constants.textStyleFont.copyWith(
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // Botón de editar
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Constants.colorAccent, Constants.colorRosa],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton.icon(
                            onPressed: () => _editRating(rating),
                            icon: Icon(Icons.edit_rounded, size: 16, color: Constants.colorBackground),
                            label: Text(
                              'Editar',
                              style: Constants.textStyleBLANCOSmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
      case 2:
        return Constants.colorError;
      case 3:
        return Constants.colorFont;
      case 4:
      case 5:
        return Constants.colorAccent;
      default:
        return Constants.colorFont;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _editRating(Map<String, dynamic> rating) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CalificarTutorPage(
          meetingId: rating['meeting_id'],
          tutorId: rating['tutor_id'],
          tutorName: rating['meeting_tutor_name'] ?? rating['tutor_name'] ?? 'Tutor',
          subject: rating['meeting_subject'] ?? rating['subject'] ?? 'Tutoría General',
        ),
      ),
    );

    if (result == true) {
      _loadMyRatings();
    }
  }
}