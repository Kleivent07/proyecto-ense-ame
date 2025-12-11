import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/custom/solicitud_data.dart';
import 'package:my_app/src/models/solicitud_model.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:intl/intl.dart';

class ListaSolicitudesProfesorPage extends StatefulWidget {
  final List<SolicitudData> solicitudes;

  const ListaSolicitudesProfesorPage({super.key, required this.solicitudes});

  @override
  State<ListaSolicitudesProfesorPage> createState() => _ListaSolicitudesProfesorPageState();
}

class _ListaSolicitudesProfesorPageState extends State<ListaSolicitudesProfesorPage> {
  late List<SolicitudData> solicitudes;
  final solicitudModel = SolicitudModel();
  bool updating = false;

  @override
  void initState() {
    super.initState();
    solicitudes = widget.solicitudes;
  }

  Future<void> actualizarSolicitudEstado(SolicitudData solicitud, String nuevoEstado) async {
    if (updating) return;
    setState(() => updating = true);
    try {
      final actualizada = await solicitudModel.actualizarEstado(solicitud.id, nuevoEstado);
      setState(() {
        final index = solicitudes.indexOf(solicitud);
        if (index != -1) solicitudes[index] = actualizada;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solicitud $nuevoEstado correctamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar solicitud: $e')),
      );
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }

  Future<void> obtenerSolicitudes() async {
    final profesorId = /* obtén el id del usuario actual */'current_profesor_id';
    final nuevas = await SolicitudModel().obtenerSolicitudesPorProfesor(profesorId);
    setState(() {
      solicitudes = nuevas;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes Recibidas'),
        backgroundColor: Constants.colorPrimary,
        foregroundColor: Colors.white,
      ),
      body: solicitudes.isEmpty
          ? const Center(child: Text('No hay solicitudes recibidas.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: solicitudes.length,
              itemBuilder: (context, index) {
                final solicitud = solicitudes[index];
                final estudiante = solicitud.nombreEstudiante;
                final fecha = DateFormat('dd/MM/yyyy HH:mm').format(solicitud.fechaSolicitud);
                final estadoRaw = solicitud.estado?.toString() ?? '';
                String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
                final estadoVista = estadoRaw == 'enviada' ? 'Recibida' : capitalize(estadoRaw);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      'Solicitud de $estudiante',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Estado: $estadoVista\nFecha: $fecha'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: (!updating && solicitud.estado != 'aceptada')
                              ? () => actualizarSolicitudEstado(solicitud, 'aceptada')
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: solicitud.estado != 'rechazada'
                              ? () => actualizarSolicitudEstado(solicitud, 'rechazada')
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

