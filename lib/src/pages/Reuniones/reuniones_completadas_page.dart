import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/models/tutor_rating_model.dart';
import 'package:my_app/src/pages/Estudiantes/calificar_tutor_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReunionesCompletadasPage extends StatefulWidget {
  const ReunionesCompletadasPage({Key? key}) : super(key: key);

  @override
  State<ReunionesCompletadasPage> createState() => _ReunionesCompletadasPageState();
}

class _ReunionesCompletadasPageState extends State<ReunionesCompletadasPage> {
  final TutorRatingModel _ratingModel = TutorRatingModel();
  List<Map<String, dynamic>> _completedMeetings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompletedMeetings();
  }

  Future<void> _loadCompletedMeetings() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final meetings = await _ratingModel.getRatableCompletedMeetings(currentUser.id);
      setState(() {
        _completedMeetings = meetings;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[COMPLETED] Error cargando reuniones: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToRating(Map<String, dynamic> meeting) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CalificarTutorPage(
          meetingId: meeting['id'],
          tutorId: meeting['tutor_id'] ?? '',
          tutorName: meeting['tutor_name'] ?? 'Tutor',
          subject: meeting['subject'] ?? '',
        ),
      ),
    );

    // Si se guardó una calificación, recargar la lista
    if (result == true) {
      _loadCompletedMeetings();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Reuniones Completadas',
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
          child: _isLoading ? _buildLoadingState() : _buildMeetingsList(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Constants.colorAccent),
          ),
          const SizedBox(height: 20),
          Text(
            'Cargando reuniones...',
            style: TextStyle(
              color: Constants.colorBackground.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingsList() {
    if (_completedMeetings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Constants.colorBackground.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            Text(
              'No hay reuniones para calificar',
              style: TextStyle(
                color: Constants.colorBackground.withOpacity(0.7),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Las reuniones completadas aparecerán aquí',
              style: TextStyle(
                color: Constants.colorBackground.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Califica las reuniones que has completado',
            style: TextStyle(
              color: Constants.colorBackground.withOpacity(0.8),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _completedMeetings.length,
            itemBuilder: (context, index) {
              final meeting = _completedMeetings[index];
              return _buildMeetingCard(meeting);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMeetingCard(Map<String, dynamic> meeting) {
    final scheduledAt = DateTime.parse(meeting['scheduled_at']);
    final formattedDate = DateFormat('dd/MM/yyyy').format(scheduledAt);
    final formattedTime = DateFormat('HH:mm').format(scheduledAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Constants.colorBackground,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToRating(meeting),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Constants.colorAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.videocam,
                      color: Constants.colorAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meeting['subject']?.isNotEmpty == true 
                              ? meeting['subject'] 
                              : 'Tutoría con ${meeting['tutor_name']}',
                          style: TextStyle(
                            color: Constants.colorFont,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Tutor: ${meeting['tutor_name']}',
                          style: TextStyle(
                            color: Constants.colorFont.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Constants.colorError.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Sin calificar',
                      style: TextStyle(
                        color: Constants.colorError,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Constants.colorFont.withOpacity(0.5),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$formattedDate a las $formattedTime',
                    style: TextStyle(
                      color: Constants.colorFont.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Constants.colorFont.withOpacity(0.3),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}