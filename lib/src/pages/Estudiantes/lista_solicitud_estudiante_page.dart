import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/custom/solicitud_data.dart';
import 'package:my_app/src/models/solicitud_model.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:intl/intl.dart';


class ListaSolicitudesEstudiantePage extends StatefulWidget {
  final List<SolicitudData> solicitudes;

  const ListaSolicitudesEstudiantePage({super.key, required this.solicitudes});

  @override
  State<ListaSolicitudesEstudiantePage> createState() => _ListaSolicitudesEstudiantePageState();
}

class _ListaSolicitudesEstudiantePageState extends State<ListaSolicitudesEstudiantePage> {
  late List<SolicitudData> solicitudes;
  final solicitudModel = SolicitudModel();

  @override
  void initState() {
    super.initState();
    solicitudes = widget.solicitudes;
  }

  Future<void> eliminarSolicitud(SolicitudData solicitud) async {
    try {
      await solicitudModel.eliminarSolicitud(solicitud.id);
      setState(() {
        solicitudes.remove(solicitud);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud eliminada correctamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar solicitud: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Solicitudes'),
        backgroundColor: Constants.colorPrimary,
        foregroundColor: Colors.white,
      ),
      body: solicitudes.isEmpty
          ? const Center(child: Text('No hay solicitudes enviadas.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: solicitudes.length,
              itemBuilder: (context, index) {
                final solicitud = solicitudes[index];
                final displayName = solicitud.nombreTutor.isNotEmpty
                    ? solicitud.nombreTutor
                    : solicitud.profesorId;
                final fecha = DateFormat('dd/MM/yyyy HH:mm').format(solicitud.fechaSolicitud);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      'Tutoría con $displayName',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Estado: ${solicitud.estado}\nFecha: $fecha'),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => eliminarSolicitud(solicitud),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

