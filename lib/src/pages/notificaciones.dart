import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/services/notifications_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({Key? key}) : super(key: key);

  // Método estático para el contador
  static Future<int> obtenerCantidadNoLeidas() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 0;
    final notis = await NotificationsService.getUserNotifications(userId);
    return notis.where((n) => n['leida'] != true).length;
  }

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  List<Map<String, dynamic>> _notificaciones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final notis = await NotificationsService.getUserNotifications(userId);
      final now = DateTime.now();
      final notisFiltradas = notis.where((n) {
        final fecha = DateTime.tryParse(n['fecha'] ?? '')?.toLocal();
        return fecha != null && !fecha.isAfter(now);
      }).toList();
      setState(() {
        _notificaciones = notisFiltradas;
        _loading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _formatearFecha(String fechaIso) {
    try {
      final fecha = DateTime.parse(fechaIso).toLocal();
      final dia = DateFormat('EEEE d MMMM', 'es').format(fecha);
      final hora = DateFormat('HH:mm', 'es').format(fecha);
      return '$dia a las $hora';
    } catch (_) {
      return fechaIso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notificaciones")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ✨ Mensaje de ayuda
                Container(
                  width: double.infinity,
                  color: Colors.yellow[100],
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Toca una notificación para marcarla como vista.\nDesliza hacia la izquierda para eliminarla.',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                // ✨ Lista de notificaciones
                Expanded(
                  child: _notificaciones.isEmpty
                      ? const Center(child: Text("No tienes notificaciones."))
                      : ListView.builder(
                          itemCount: _notificaciones.length,
                          itemBuilder: (context, index) {
                            final n = _notificaciones[index];
                            final fecha = n['fecha'] != null
                                ? _formatearFecha(n['fecha'])
                                : '';
                            return Dismissible(
                              key: Key(n['id'].toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child:
                                    const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (direction) async {
                                await NotificationsService.deleteNotification(n['id']);
                                setState(() {
                                  _notificaciones.removeAt(index);
                                });
                                _showSnackBar('Notificación eliminada');
                              },
                              child: Card(
                                child: ListTile(
                                  title: Text(n['titulo'] ?? ''),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n['mensaje'] ?? ''),
                                    ],
                                  ),
                                  trailing: n['leida'] == true
                                      ? const Icon(Icons.check, color: Colors.green)
                                      : null,
                                  onTap: () async {
                                    if (n['leida'] != true) {
                                      await NotificationsService.marcarComoLeida(n['id']);
                                      setState(() {
                                        n['leida'] = true;
                                      });
                                      _showSnackBar('Notificación marcada como vista');
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
