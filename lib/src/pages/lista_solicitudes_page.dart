import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../custom/solicitud_data.dart';
import '../models/solicitud_model.dart';
import '../util/constants.dart';

class ListaSolicitudesPage extends StatefulWidget {
  final List<SolicitudData> solicitudes;
  final bool esProfesor;

  const ListaSolicitudesPage({
    super.key,
    required this.solicitudes,
    required this.esProfesor,
  });

  @override
  State<ListaSolicitudesPage> createState() => _ListaSolicitudesPageState();
}

class _ListaSolicitudesPageState extends State<ListaSolicitudesPage> {
  late List<SolicitudData> solicitudes;
  final solicitudModel = SolicitudModel();

  @override
  void initState() {
    super.initState();
    solicitudes = widget.solicitudes;
  }

  Future<void> actualizarSolicitudEstado(SolicitudData solicitud, String nuevoEstado) async {
    try {
      if (solicitud.id.isEmpty) return;

      await solicitudModel.actualizarEstado(solicitud.id, nuevoEstado);

      setState(() {
        solicitud.estado = nuevoEstado;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solicitud $nuevoEstado correctamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar solicitud: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esProfesor ? 'Solicitudes Recibidas' : 'Mis Solicitudes'),
        backgroundColor: Constants.colorPrimary,
        foregroundColor: Colors.white,
      ),
      body: solicitudes.isEmpty
          ? const Center(child: Text('No hay solicitudes disponibles.'))
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
                    trailing: widget.esProfesor
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: solicitud.estado != 'aceptada'
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
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
