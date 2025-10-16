import 'package:flutter/material.dart';
import 'package:my_app/src/models/profesores_model.dart';
import 'package:my_app/src/util/constants.dart';

class PerfilTutorPage extends StatefulWidget {
  final String tutorId;

  const PerfilTutorPage({super.key, required this.tutorId});

  @override
  State<PerfilTutorPage> createState() => _PerfilTutorPageState();
}

class _PerfilTutorPageState extends State<PerfilTutorPage> {
  Map<String, dynamic>? tutor;
  bool isLoading = true;

  // Ejemplo de comentarios
  List<Map<String, dynamic>> comentarios = [];

  @override
  void initState() {
    super.initState();
    cargarTutor();
  }

  Future<void> cargarTutor() async {
    final profService = ProfesorService();
    final data = await profService.obtenerTutor(widget.tutorId);

    if (data != null) {
      setState(() {
        tutor = data;
        isLoading = false;

        // Comentarios de ejemplo (puedes reemplazarlos con los de tu base de datos)
        comentarios = [
          {'usuario': 'Ana P.', 'comentario': 'Muy buen profesor, explica claro.'},
          {'usuario': 'Luis G.', 'comentario': 'Paciente y amable.'},
        ];
      });
    } else {
      setState(() {
        tutor = null;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (tutor == null) {
      return const Scaffold(
        body: Center(child: Text('Tutor no encontrado')),
      );
    }

    final usuario = tutor!['usuarios'] ?? {};
    final nombre = usuario['nombre'] ?? 'Sin nombre';
    final apellido = usuario['apellido'] ?? '';
    final especialidad = tutor!['especialidad'] ?? 'Sin definir';
    final horario = tutor!['horario'] ?? 'Por definir';
    final imagenUrl = usuario['imagen_url'];

    return Scaffold(
      appBar: AppBar(
        title: Text('$nombre $apellido', style: Constants.textStylePrimaryTitle),
        backgroundColor: Constants.colorPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4), // grosor del borde
              decoration: BoxDecoration(
                color: Constants.colorPrimary, // color del borde
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 56, // radio un poco más pequeño que el borde
                backgroundImage: imagenUrl != null
                    ? NetworkImage(imagenUrl)
                    : const AssetImage('assets/default_avatar.jpg') as ImageProvider,
              ),
            ),
            const SizedBox(height: 16),
            Text('$nombre $apellido', style: Constants.textStylePrimaryTitle),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(especialidad, style: Constants.textStyleFont),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.schedule, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(horario, style: Constants.textStyleFont),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.star, color: Colors.amber),
                Icon(Icons.star, color: Colors.amber),
                Icon(Icons.star, color: Colors.amber),
                Icon(Icons.star_half, color: Colors.amber),
                Icon(Icons.star_border, color: Colors.amber),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Clasificación: 3.5 / 5.0', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Solicitud enviada (ejemplo)')),
                );
              },
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text('Solicitar tutoría', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Constants.colorPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Sección de comentarios
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Comentarios', style: Constants.textStylePrimaryTitle),
            ),
            const SizedBox(height: 16),
            comentarios.isEmpty
                ? const Text('No hay comentarios todavía.', style: TextStyle(fontSize: 16))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: comentarios.length,
                    itemBuilder: (context, index) {
                      final com = comentarios[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(com['usuario'] ?? '', style: Constants.textStylePrimarySemiBold),
                          subtitle: Text(com['comentario'] ?? '', style: Constants.textStyleFont),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
