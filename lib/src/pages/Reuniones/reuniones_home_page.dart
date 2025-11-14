import 'package:flutter/material.dart';
import 'package:my_app/src/pages/Reuniones/crear_reunion_page.dart';
import 'package:my_app/src/pages/Reuniones/unir_reunion_page.dart';
import 'package:my_app/src/pages/Reuniones/pasadas_reunion_page.dart';

class ReunionesHomePage extends StatefulWidget {
  const ReunionesHomePage({Key? key}) : super(key: key);

  @override
  _ReunionesHomePageState createState() => _ReunionesHomePageState();
}

class _ReunionesHomePageState extends State<ReunionesHomePage> {
  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    final cardColor = color ?? Theme.of(context).colorScheme.surface;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  void _goToCreate() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateMeetingPage()));
  }

  void _goToJoin() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinMeetingPage()));
  }

  void _goToHistory() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MeetingsHistoryPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reuniones'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Gestiona tus reuniones: crea, únete o revisa el historial.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              _buildFeatureCard(
                icon: Icons.add,
                title: 'Crear reunión',
                subtitle: 'Programa una nueva sesión y activa opciones como grabación.',
                onTap: _goToCreate,
              ),
              _buildFeatureCard(
                icon: Icons.meeting_room,
                title: 'Unirse a reunión',
                subtitle: 'Introduce el ID de sala para entrar a una videollamada.',
                onTap: _goToJoin,
              ),
              _buildFeatureCard(
                icon: Icons.history,
                title: 'Reuniones pasadas',
                subtitle: 'Consulta reuniones previas y copia IDs rápidamente.',
                onTap: _goToHistory,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    'Consejo: copia el Room ID desde la pantalla de la reunión creada para compartirlo.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}