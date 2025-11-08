import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../custom/solicitud_data.dart';
import '../models/solicitud_model.dart';
import '../util/constants.dart';

// imports añadidos
import '../models/chat_model.dart';
import 'chat_page.dart';

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
  final chatModel = ChatModel(); // instancia para abrir chats

  @override
  void initState() {
    super.initState();
    // Ordenar: primeras las más recientes; dejar solicitudes aceptadas al final.
    solicitudes = List<SolicitudData>.from(widget.solicitudes);
    solicitudes.sort((a, b) {
      // si uno está aceptada y el otro no, aceptada va después
      if (a.estado == 'aceptada' && b.estado != 'aceptada') return 1;
      if (b.estado == 'aceptada' && a.estado != 'aceptada') return -1;
      // si ambos iguales en aceptación, ordenar por fecha desc
      return b.fechaSolicitud.compareTo(a.fechaSolicitud);
    });
  }

  Future<void> actualizarSolicitudEstado(SolicitudData solicitud, String nuevoEstado) async {
    try {
      if (solicitud.id.isEmpty) return;

      await solicitudModel.actualizarEstado(solicitud.id, nuevoEstado);

      setState(() {
        final index = solicitudes.indexOf(solicitud);
        solicitudes[index] = SolicitudData(
          id: solicitud.id,
          estudianteId: solicitud.estudianteId,
          profesorId: solicitud.profesorId,
          nombreTutor: solicitud.nombreTutor,
          fechaSolicitud: solicitud.fechaSolicitud,
          estado: nuevoEstado,
        );
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

  // Nuevo helper: abrir chat (obtiene/crea room y navega)
  Future<void> _openChat(SolicitudData solicitud) async {
    final sm = ScaffoldMessenger.of(context);
    sm.showSnackBar(const SnackBar(content: Text('Abriendo chat...')));
    try {
      final roomId = await chatModel.ensureAccessAndGetRoom(solicitud.id);
      if (roomId == null) {
        sm.showSnackBar(const SnackBar(content: Text('No tienes acceso al chat o la solicitud no está aceptada.')));
        return;
      }
      // Ajusta el constructor de ChatPage si es distinto (aquí paso solicitudId y roomId)
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(solicitudId: solicitud.id, roomId: roomId),
        ),
      );
    } catch (e) {
      sm.showSnackBar(SnackBar(content: Text('Error al abrir chat: $e')));
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

                final isAccepted = solicitud.estado == 'aceptada';
                final tileColor = isAccepted ? Colors.grey.shade200 : null;
                final textStyle = isAccepted
                    ? TextStyle(color: Colors.grey.shade700.withOpacity(0.7))
                    : const TextStyle();

                return Card(
                  color: tileColor,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      'Tutoría con $displayName',
                      style: TextStyle(fontWeight: FontWeight.bold).merge(textStyle),
                    ),
                    subtitle: Text('Estado: ${solicitud.estado}\nFecha: $fecha\n${solicitud.mensaje.isNotEmpty ? '\nMensaje: ${solicitud.mensaje}' : ''}', style: textStyle),
                    isThreeLine: true,
                    // deshabilitar acciones de aceptar/rechazar si ya aceptada
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // botones aceptar/rechazar solo para profesores (igual que antes)
                        if (widget.esProfesor) ...[
                          IconButton(
                            icon: Icon(Icons.check, color: isAccepted ? Colors.grey : Colors.green),
                            onPressed: !isAccepted ? () => actualizarSolicitudEstado(solicitud, 'aceptada') : null,
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: solicitud.estado == 'rechazada' ? Colors.grey : Colors.red),
                            onPressed: solicitud.estado != 'rechazada' ? () => actualizarSolicitudEstado(solicitud, 'rechazada') : null,
                          ),
                        ],

                        // Mostrar botón de chat SOLO si la solicitud está aceptada
                        if (solicitud.estado == 'aceptada')
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline),
                            tooltip: 'Abrir chat',
                            onPressed: () => _openChat(solicitud),
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

