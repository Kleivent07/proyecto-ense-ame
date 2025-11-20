import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/models/reuniones_model.dart';
import 'package:my_app/src/pages/Reuniones/meeting_completion_handler.dart';
import 'package:my_app/src/pages/Estudiantes/calificar_tutor_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DebugReunionTestPage extends StatefulWidget {
  const DebugReunionTestPage({Key? key}) : super(key: key);

  @override
  State<DebugReunionTestPage> createState() => _DebugReunionTestPageState();
}

class _DebugReunionTestPageState extends State<DebugReunionTestPage> {
  final MeetingModel _meetingModel = MeetingModel();
  final TextEditingController _tutorIdController = TextEditingController();
  final TextEditingController _tutorNameController = TextEditingController(text: 'Profesor Test');
  
  bool _isLoading = false;
  List<Map<String, dynamic>> _availableTutors = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableTutors();
  }

  @override
  void dispose() {
    _tutorIdController.dispose();
    _tutorNameController.dispose();
    super.dispose();
  }

  /// Cargar lista de tutores disponibles
  Future<void> _loadAvailableTutors() async {
    try {
      // Obtener tutores de la tabla profesores o usuarios
      final tutors = await Supabase.instance.client
          .from('usuarios')
          .select('id, nombre, apellido, email')
          .eq('clase', 'Tutor')
          .limit(10);

      setState(() {
        _availableTutors = List<Map<String, dynamic>>.from(tutors);
      });

      // Si hay tutores, pre-llenar con el primero
      if (_availableTutors.isNotEmpty && _tutorIdController.text.isEmpty) {
        final firstTutor = _availableTutors.first;
        _tutorIdController.text = firstTutor['id'];
        _tutorNameController.text = '${firstTutor['nombre']} ${firstTutor['apellido']}';
      }
    } catch (e) {
      debugPrint('Error cargando tutores: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorPrimaryDark,
      appBar: AppBar(
        backgroundColor: Constants.colorPrimaryDark,
        title: const Text('Test Reuniones', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Constants.colorPrimaryDark, Constants.colorPrimary],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prueba el Sistema de Calificaciones',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Configura los datos del tutor y usa los botones para simular reuniones.',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ✅ Configuración del tutor
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '👨‍🏫 Configurar Tutor para Pruebas',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          
                          // Campo ID del tutor
                          TextField(
                            controller: _tutorIdController,
                            decoration: const InputDecoration(
                              labelText: 'ID del Tutor',
                              hintText: 'Ingresa el ID del tutor',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Campo nombre del tutor
                          TextField(
                            controller: _tutorNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del Tutor',
                              hintText: 'Nombre para mostrar',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Lista de tutores disponibles
                          if (_availableTutors.isNotEmpty) ...[
                            const Text(
                              'Tutores Disponibles:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 120,
                              child: ListView.builder(
                                itemCount: _availableTutors.length,
                                itemBuilder: (context, index) {
                                  final tutor = _availableTutors[index];
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.person, size: 16),
                                    title: Text(
                                      '${tutor['nombre']} ${tutor['apellido']}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    subtitle: Text(
                                      tutor['id'],
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _tutorIdController.text = tutor['id'];
                                        _tutorNameController.text = '${tutor['nombre']} ${tutor['apellido']}';
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                
                  // Crear reunión de prueba
                  _buildTestButton(
                    'Crear reunión de prueba',
                    Icons.add_circle,
                    Colors.blue,
                    _createTestMeeting,
                  ),
                  const SizedBox(height: 10),
                  
                  // Simular reunión completada
                  _buildTestButton(
                    'Simular reunión completada',
                    Icons.check_circle,
                    Colors.green,
                    _simulateCompletedMeeting,
                  ),
                  const SizedBox(height: 10),
                  
                  // Forzar verificación de reuniones
                  _buildTestButton(
                    'Verificar reuniones pendientes',
                    Icons.refresh,
                    Colors.orange,
                    _checkPendingMeetings,
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Forzar diálogo de calificación
                  _buildTestButton(
                    'Forzar diálogo de calificación',
                    Icons.rate_review,
                    Colors.purple,
                    _forceRatingDialog,
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Debug estado de calificaciones
                  _buildTestButton(
                    'Ver estado de calificaciones',
                    Icons.analytics,
                    Colors.teal,
                    _debugRatingStatus,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(title, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _createTestMeeting() async {
    if (_tutorIdController.text.trim().isEmpty) {
      _showSnackBar('Por favor ingresa un ID de tutor', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _showSnackBar('Usuario no autenticado', isError: true);
        return;
      }

      final roomId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      final tutorId = _tutorIdController.text.trim();
      final tutorName = _tutorNameController.text.trim().isEmpty 
          ? 'Profesor Test' 
          : _tutorNameController.text.trim();
      
      final meeting = await _meetingModel.createMeeting(
        tutorName: tutorName,
        studentName: 'Estudiante Test',
        roomId: roomId,
        subject: 'Matemáticas',
        scheduledAt: DateTime.now().subtract(const Duration(hours: 1)), // Reunión pasada
        tutorId: tutorId, // ✅ Usar el ID real del tutor
      );

      if (meeting != null) {
        _showSnackBar('✅ Reunión creada: $roomId\nTutor: $tutorName ($tutorId)');
      } else {
        _showSnackBar('Error creando reunión de prueba', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _simulateCompletedMeeting() async {
    setState(() => _isLoading = true);
    
    try {
      final meetings = await _meetingModel.listMeetings();
      
      if (meetings.isEmpty) {
        _showSnackBar('No hay reuniones. Crea una primero.', isError: true);
        return;
      }

      final meeting = meetings.first;
      final roomId = meeting['room_id'];
      
      final success = await MeetingCompletionHandler.completeMeeting(roomId);
      
      if (success) {
        _showSnackBar('✅ Reunión $roomId marcada como completada');
        await Future.delayed(const Duration(seconds: 1));
        await _checkPendingMeetings();
      } else {
        _showSnackBar('Error marcando reunión como completada', isError: true);
      }
      
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPendingMeetings() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _showSnackBar('Usuario no autenticado', isError: true);
        return;
      }

      final pendingMeetings = await MeetingCompletionHandler.checkCompletedMeetings(currentUser.id);
      
      _showSnackBar('📊 Reuniones pendientes de calificar: ${pendingMeetings.length}');
      
      if (pendingMeetings.isNotEmpty) {
        for (final meeting in pendingMeetings.take(3)) {
          debugPrint('Reunión pendiente: ${meeting['tutor_name']} - ${meeting['subject']}');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔄 El diálogo debería aparecer automáticamente'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _forceRatingDialog() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _showSnackBar('Usuario no autenticado', isError: true);
        return;
      }

      final pendingMeetings = await MeetingCompletionHandler.checkCompletedMeetings(currentUser.id);
      
      if (pendingMeetings.isEmpty) {
        _showSnackBar('No hay reuniones para calificar. Crea y completa una primero.', isError: true);
        return;
      }

      final meeting = pendingMeetings.first;
      
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => CalificarTutorPage(
            meetingId: meeting['id'],
            tutorId: meeting['tutor_id'] ?? '',
            tutorName: meeting['tutor_name'] ?? 'Tutor',
            subject: meeting['subject'] ?? 'Tutoría General',
          ),
        ),
      );

      if (result == true) {
        _showSnackBar('✅ Calificación guardada exitosamente');
      }
      
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// ✅ Método para depurar el estado de calificaciones
  Future<void> _debugRatingStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        _showSnackBar('Usuario no autenticado', isError: true);
        return;
      }

      final allMeetings = await _meetingModel.listMeetings();
      
      print('\n📊 ESTADO DE CALIFICACIONES:');
      print('Usuario ID: ${currentUser.id}');
      print('Total reuniones: ${allMeetings.length}');
      
      for (final meeting in allMeetings.take(5)) {
        final meetingId = meeting['id'];
        final roomId = meeting['room_id'];
        final token = meeting['token'];
        final tutorId = meeting['tutor_id'];
        
        final existingRating = await Supabase.instance.client
            .from('tutor_ratings')
            .select('*')
            .eq('meeting_id', meetingId)
            .eq('student_id', currentUser.id)
            .maybeSingle();
        
        print('');
        print('🏠 Reunión: $roomId');
        print('   📅 Meeting ID: $meetingId');
        print('   👨‍🏫 Tutor ID: $tutorId');
        print('   🏷️  Token: $token');
        print('   ⭐ Calificada: ${existingRating != null ? "SÍ (${existingRating['rating']} estrellas)" : "NO"}');
        print('   📝 Comentarios: ${existingRating?['comments'] ?? "Sin comentarios"}');
      }
      
      _showSnackBar('✅ Ver consola para detalles completos');
      
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }
}