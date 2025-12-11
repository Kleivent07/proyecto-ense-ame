import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/models/tutor_rating_model.dart';
import 'package:my_app/src/pages/Estudiantes/calificar_tutor_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClasificarReunionesPage extends StatefulWidget {
  const ClasificarReunionesPage({Key? key}) : super(key: key);

  @override
  State<ClasificarReunionesPage> createState() => _ClasificarReunionesPageState();
}

class _ClasificarReunionesPageState extends State<ClasificarReunionesPage> {
  final TutorRatingModel _ratingModel = TutorRatingModel();
  List<Map<String, dynamic>> _meetingsToRate = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMeetingsToRate();
  }

  Future<void> _loadMeetingsToRate() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('[CLASIFICAR] ❌ Usuario no autenticado');
        return;
      }

      debugPrint('[CLASIFICAR] 🔍 Cargando reuniones para calificar...');

      final meetings = await TutorRatingModel().getRatableCompletedMeetings(currentUser.id);

      if (!mounted) return;
      setState(() {
        _meetingsToRate = meetings;
        _isLoading = false;
      });

      debugPrint('[CLASIFICAR] ✅ ${meetings.length} reuniones cargadas para calificar');
    } catch (e) {
      debugPrint('[CLASIFICAR] ❌ Error cargando reuniones: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToRating(Map<String, dynamic> meeting) async {
    // Validar tutor_id antes de navegar
    if (!meeting.containsKey('tutor_id') || meeting['tutor_id'] == null) {
      debugPrint('[CLASIFICAR] ❌ tutor_id es null para meeting: ${meeting['id']}');
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CalificarTutorPage(
          meetingId: meeting['id'] ?? '',
          tutorId: meeting['tutor_id'] ?? '',
          tutorName: meeting['tutor_name'] ?? 'Tutor',
          subject: meeting['subject'] ?? 'Tutoría General',
        ),
      ),
    );
    if (!mounted) return;
    // Si se guardó la calificación, recargar la lista
    if (result == true) {
      await _loadMeetingsToRate();
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorBackground,
      appBar: AppBar(
        title: Text(
          'Clasificar Reuniones',
          style: Constants.textStyleBLANCOTitle,
        ),
        centerTitle: true,
        backgroundColor: Constants.colorPrimary,
        iconTheme: IconThemeData(color: Constants.colorBackground),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Constants.colorPrimary),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando reuniones completadas...',
                    style: Constants.textStyleFont,
                  ),
                ],
              ),
            )
          : _meetingsToRate.isEmpty
              ? _buildEmptyState()
              : _buildMeetingsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 80,
              color: Constants.colorShadow,
            ),
            const SizedBox(height: 16),
            Text(
              '¡Perfecto!',
              style: Constants.textStyleFontTitle.copyWith(
                color: Constants.colorAccent,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No tienes reuniones pendientes de calificar',
              style: Constants.textStyleFont.copyWith(
                color: Constants.colorSurface,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Las reuniones completadas aparecerán aquí para que puedas calificarlas',
              style: Constants.textStyleFontSmall.copyWith(
                color: Constants.colorSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingsList() {
    return RefreshIndicator(
      color: Constants.colorPrimary,
      onRefresh: _loadMeetingsToRate,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _meetingsToRate.length,
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final meeting = _meetingsToRate[index];
          return _buildMeetingCard(meeting);
        },
      ),
    );
  }

  Widget _buildMeetingCard(Map<String, dynamic> meeting) {
    // Validación de scheduled_at
    if (!meeting.containsKey('scheduled_at') || meeting['scheduled_at'] == null) return SizedBox.shrink();
    final scheduledAt = DateTime.parse(meeting['scheduled_at']).toLocal();
    final subject = meeting.containsKey('subject') && meeting['subject'] != null ? meeting['subject'] : 'Tutoría General';
    final tutorName = meeting.containsKey('tutor_name') && meeting['tutor_name'] != null ? meeting['tutor_name'] : 'Tutor';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: Constants.colorBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Constants.colorAccent.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Constants.colorAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.star_outline,
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
                        'Reunión completada',
                        style: Constants.textStyleFontBold.copyWith(
                          color: Constants.colorAccent,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        subject,
                        style: Constants.textStyleFontBold.copyWith(
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Información de la reunión
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Constants.colorSurface),
                const SizedBox(width: 4),
                Text(
                  'Tutor: $tutorName',
                  style: Constants.textStyleFontSmall.copyWith(
                    color: Constants.colorSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Constants.colorSurface),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy • HH:mm').format(scheduledAt),
                  style: Constants.textStyleFontSmall.copyWith(
                    color: Constants.colorSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Botón de calificar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToRating(meeting),
                icon: const Icon(Icons.star),
                label: const Text('Evaluar Tutor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.colorAccent,
                  foregroundColor: Constants.colorBackground,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}