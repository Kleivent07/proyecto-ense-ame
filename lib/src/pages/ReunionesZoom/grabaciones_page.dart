import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class GrabacionesPage extends StatefulWidget {
  const GrabacionesPage({super.key});

  @override
  State<GrabacionesPage> createState() => _GrabacionesPageState();
}

class _GrabacionesPageState extends State<GrabacionesPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _grabaciones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarGrabaciones();
  }

  Future<void> _cargarGrabaciones() async {
    setState(() => _loading = true);
    try {
      final response = await supabase
          .from('zoom_meetings')
          .select('topic, start_time, recording_url')
          .order('start_time', ascending: false) as List<dynamic>?;
      setState(() {
        _grabaciones = (response ?? []).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      setState(() => _grabaciones = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _abrirGrabacion(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir la grabación.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('URL inválida: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Grabaciones")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _grabaciones.isEmpty
              ? const Center(child: Text('No hay grabaciones.'))
              : ListView.builder(
                  itemCount: _grabaciones.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final g = _grabaciones[index];
                    final start = g['start_time']?.toString() ?? '';
                    return ListTile(
                      title: Text(g['topic'] ?? 'Sin tema'),
                      subtitle: Text(start),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_circle),
                        onPressed: g['recording_url'] != null ? () => _abrirGrabacion(g['recording_url'] as String) : null,
                      ),
                    );
                  },
                ),
    );
  }
}