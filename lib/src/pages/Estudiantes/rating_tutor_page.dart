import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/models/tutor_rating_model.dart'; // ✅ Cambiar a TutorRatingModel
import 'package:supabase_flutter/supabase_flutter.dart';

class RatingTutorPage extends StatefulWidget {
  final String meetingId;
  final String tutorId;
  final String tutorName;
  final String subject;

  const RatingTutorPage({
    Key? key,
    required this.meetingId,
    required this.tutorId,
    required this.tutorName,
    required this.subject,
  }) : super(key: key);

  @override
  State<RatingTutorPage> createState() => _RatingTutorPageState();
}

class _RatingTutorPageState extends State<RatingTutorPage> {
  int _selectedRating = 0;
  final TextEditingController _commentsController = TextEditingController();
  bool _isLoading = false;
  final TutorRatingModel _ratingModel = TutorRatingModel(); // ✅ Usar modelo avanzado

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) {
      _showMessage('Por favor selecciona una calificación');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final studentId = Supabase.instance.client.auth.currentUser?.id;
      if (studentId == null) {
        _showMessage('Error: Usuario no autenticado');
        return;
      }

      // ✅ Usar el método avanzado con ID único
      final result = await _ratingModel.createRating(
        meetingId: widget.meetingId,
        tutorId: widget.tutorId,
        studentId: studentId,
        subject: widget.subject.isNotEmpty ? widget.subject : 'Tutoría General', // ✅ Incluir materia
        rating: _selectedRating,
        comments: _commentsController.text.trim().isEmpty
            ? null
            : _commentsController.text.trim(),
      );

      if (result['success']) {
        // ✅ Mostrar información del ID único generado
        final ratingId = result['rating_id'];
        _showMessage('¡Gracias por tu calificación! ID: ${ratingId?.substring(0, 12)}...', isSuccess: true);
        await Future.delayed(Duration(seconds: 2));
        Navigator.pop(context, true);
      } else {
        _showMessage(result['message']);
      }
    } catch (e) {
      _showMessage('Error inesperado: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Constants.colorAccent : Constants.colorError,
        duration: Duration(seconds: isSuccess ? 4 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... resto del código build igual, pero con mejoras en la UI
    return Scaffold(
      backgroundColor: Constants.colorPrimaryDark,
      appBar: AppBar(
        backgroundColor: Constants.colorPrimaryDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Constants.colorBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Calificar Tutoría',
          style: TextStyle(
            color: Constants.colorBackground,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
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
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ✅ Información mejorada de la reunión
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Constants.colorBackground.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Constants.colorBackground.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Constants.colorAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Sistema de IDs únicos activado',
                            style: TextStyle(
                              color: Constants.colorAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Reunión completada',
                        style: TextStyle(
                          color: Constants.colorBackground,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tutor: ${widget.tutorName}',
                        style: TextStyle(
                          color: Constants.colorBackground.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Materia: ${widget.subject.isEmpty ? "Tutoría general" : widget.subject}',
                        style: TextStyle(
                          color: Constants.colorBackground.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),

                // Título de calificación
                Text(
                  '¿Cómo calificas esta tutoría?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Constants.colorBackground,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 20),

                // Estrellas de calificación
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () => setState(() => _selectedRating = index + 1),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.star,
                            size: 40,
                            color: index < _selectedRating
                                ? Constants.colorAccent
                                : Constants.colorBackground.withOpacity(0.3),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Texto de la calificación seleccionada
                if (_selectedRating > 0)
                  Text(
                    _getRatingText(_selectedRating),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Constants.colorBackground.withOpacity(0.8),
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                const SizedBox(height: 30),

                // Campo de comentarios
                Container(
                  decoration: BoxDecoration(
                    color: Constants.colorBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _commentsController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Comentarios adicionales (opcional)',
                      hintStyle: TextStyle(color: Constants.colorFont.withOpacity(0.6)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: TextStyle(
                      color: Constants.colorFont,
                      fontSize: 16,
                    ),
                  ),
                ),

                const Spacer(),

                // Botón de enviar
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitRating,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Constants.colorAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(
                            color: Constants.colorBackground,
                            strokeWidth: 2,
                          )
                        : Text(
                            'Enviar Calificación con ID Único',
                            style: TextStyle(
                              color: Constants.colorBackground,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return '😞 Muy insatisfecho';
      case 2:
        return '😐 Insatisfecho';
      case 3:
        return '😊 Satisfecho';
      case 4:
        return '😄 Muy satisfecho';
      case 5:
        return '🤩 Excelente';
      default:
        return '';
    }
  }
}