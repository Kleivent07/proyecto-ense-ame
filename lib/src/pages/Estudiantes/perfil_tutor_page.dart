import 'package:flutter/material.dart';
import 'package:my_app/src/models/profesores_model.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/models/solicitud_model.dart';
import 'package:my_app/src/BackEnd/custom/solicitud_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PerfilTutorPage extends StatefulWidget {
  final String tutorId;

  const PerfilTutorPage({super.key, required this.tutorId});

  @override
  State<PerfilTutorPage> createState() => _PerfilTutorPageState();
}

class _PerfilTutorPageState extends State<PerfilTutorPage> {
  Map<String, dynamic>? tutor;
  bool isLoading = true;
  final solicitudModel = SolicitudModel();
  String estadoSolicitud = 'none';

  @override
  void initState() {
    super.initState();
    cargarTutor();
  }

  Future<void> cargarTutor() async {
    final profService = ProfesorService();
    final data = await profService.obtenerTutor(widget.tutorId);

    setState(() {
      tutor = data;
      isLoading = false;
    });

    final estudianteId = Supabase.instance.client.auth.currentUser?.id;
    if (estudianteId != null) {
      verificarEstadoSolicitud(estudianteId, widget.tutorId);
    }
  }

  Future<void> enviarSolicitud(String profesorId) async {
    final estudianteId = Supabase.instance.client.auth.currentUser?.id;
    if (estudianteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener tu ID de usuario.')),
      );
      return;
    }

    // show dialog to enter message (optional)
    final TextEditingController messageCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mensaje para la solicitud (opcional)'),
        content: TextField(
          controller: messageCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Escribe un mensaje corto (ej: Hola, me gustaría tener tutorías para la clase X)...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Enviar')),
        ],
      ),
    );

    if (result != true) {
      // user cancelled
      return;
    }

    try {
      final nuevaSolicitud = SolicitudData(
        estudianteId: estudianteId,
        profesorId: profesorId,
        estado: 'pendiente',
        fechaSolicitud: DateTime.now(),
        mensaje: messageCtrl.text.trim(),
      );

      await solicitudModel.crearSolicitud(nuevaSolicitud);

      setState(() {
        estadoSolicitud = 'pendiente';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada correctamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar solicitud: $e')),
      );
    } finally {
      messageCtrl.dispose();
    }
  }

  Future<void> verificarEstadoSolicitud(String estudianteId, String profesorId) async {
    try {
      final solicitudes = await solicitudModel.obtenerSolicitudesPorEstudiante(estudianteId);

      final existente = solicitudes.firstWhere(
        (s) => s.profesorId == profesorId,
        orElse: () => SolicitudData(
          id: '',
          estudianteId: estudianteId,
          profesorId: profesorId,
          estado: 'none',
          fechaSolicitud: DateTime.now(),
        ),
      );

      setState(() {
        estadoSolicitud = existente.estado;
      });
    } catch (e) {
      print('Error al verificar solicitud: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (tutor == null) return const Scaffold(body: Center(child: Text('Tutor no encontrado')));

    final usuario = tutor!['usuarios'] ?? {};
    final nombre = usuario['nombre'] ?? 'Sin nombre';
    final apellido = usuario['apellido'] ?? '';
    final especialidad = tutor!['especialidad'] ?? 'No definida';
    final carrera = tutor!['carrera_profesion'] ?? 'No definida';
    final horario = tutor!['horario'] ?? 'No definido';
    final experiencia = tutor!['experiencia'] ?? 'No especificada';
    final email = usuario['email'] ?? 'Sin correo';
    final biografia = usuario['biografia'] ?? 'Este tutor aún no ha agregado una biografía.';
    final imagenUrl = usuario['imagen_url'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Tutor'),
        foregroundColor: Colors.white,
        backgroundColor: Constants.colorPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundImage: imagenUrl != null && imagenUrl.isNotEmpty
                        ? NetworkImage(imagenUrl)
                        : const AssetImage('assets/default_avatar.jpg') as ImageProvider,
                  ),
                  const SizedBox(height: 16),
                  Text('$nombre $apellido', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(especialidad, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                  Text(carrera, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                  const SizedBox(height: 20),
                  const Divider(thickness: 1),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(Icons.access_time, 'Horario', horario),
                        _buildInfoRow(Icons.school, 'Experiencia', experiencia),
                        _buildInfoRow(Icons.email, 'Correo electrónico', email),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(thickness: 1),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Biografía', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(biografia, style: TextStyle(fontSize: 15, color: Colors.grey[800])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: estadoSolicitud == 'none' ? () => enviarSolicitud(widget.tutorId) : null,
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: Text(
                        estadoSolicitud == 'pendiente'
                            ? 'Solicitud enviada'
                            : estadoSolicitud == 'aceptada'
                                ? 'Solicitud aceptada'
                                : estadoSolicitud == 'rechazada'
                                    ? 'Solicitud rechazada'
                                    : 'Solicitar tutoría',
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        backgroundColor: Constants.colorPrimary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[700]),
          const SizedBox(width: 10),
          Expanded(child: Text('$label: $value', style: TextStyle(fontSize: 15, color: Colors.grey[800]))),
        ],
      ),
    );
  }
}
