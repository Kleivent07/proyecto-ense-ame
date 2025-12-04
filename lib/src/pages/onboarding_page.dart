// lib/src/pages/onboarding_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/src/BackEnd/custom/library.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingPage extends StatefulWidget {
  final bool esTutor;
  const OnboardingPage({super.key, required this.esTutor});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final controller = PageController();
  int index = 0;

  Future<void> _finalizar() async {
    final prefs = await SharedPreferences.getInstance();
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? 'anon';
    final keyOnboarding = 'onboarding_visto_$userId';

    await prefs.setBool(keyOnboarding, true);
    await prefs.setBool('onboarding_visto', true);
    await prefs.reload();

    debugPrint('[ONBOARDING] Marcado como visto para $userId');
    if (widget.esTutor) {
      navigate(context, CustomPages.homeProPage, finishCurrent: true);
    } else {
      navigate(context, CustomPages.homeEsPage, finishCurrent: true);
    }
  }

  List<({String titulo, String texto, IconData icono})> get _slides {
    if (widget.esTutor) {
      return [
        (titulo: 'Perfil y experiencia', texto: 'Destaca tu biografía, materias y experiencia. Mejora tu visibilidad con una buena foto y descripción.', icono: Icons.workspace_premium),
        (titulo: 'Disponibilidad y solicitudes', texto: 'Publica tus horarios, recibe solicitudes y acepta o rechaza según tu agenda.', icono: Icons.calendar_today),
        (titulo: 'Clases en la app', texto: 'Videollamadas con chat y archivos. Explica, comparte materiales y resuelve dudas sin salir.', icono: Icons.video_call),
        (titulo: 'Calificaciones y desempeño', texto: 'Recibe evaluaciones y revisa tu rating para mejorar tu perfil y obtener más alumnos.', icono: Icons.bar_chart),
      ];
    } else {
      return [
        (titulo: 'Buscar tutores', texto: 'Encuentra por carrera y materia. Revisa perfiles, experiencia y valoraciones.', icono: Icons.search),
        (titulo: 'Perfiles y confianza', texto: 'Ve foto, biografía, materias, horarios y opiniones para elegir bien.', icono: Icons.person_search),
        (titulo: 'Agendar y reunirse', texto: 'Elige horario, envía solicitud y únete por video/chat. Recibe avisos y recordatorios.', icono: Icons.event_available),
        (titulo: 'Materiales y calificaciones', texto: 'Guarda archivos en Documentos y evalúa la tutoría con estrellas y comentarios.', icono: Icons.folder_shared),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final h = size.height;

    // Escala más agresiva y con topes más altos
    final scale = h < 650 ? 0.95 : (h < 800 ? 1.10 : 1.25);

    return Scaffold(
      // Fondo general consistente
      backgroundColor: Constants.colorPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72), // AppBar más alto
        child: AppBar(
          elevation: 8,
          centerTitle: true,
          // Gradiente estilo Perfil/Login
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Constants.colorPrimaryDark, Constants.colorPrimary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: Text(
            widget.esTutor ? 'Guía rápida (Profesor)' : 'Guía rápida (Estudiante)',
            style: Constants.textStyleFontTitle.copyWith(
              color: Colors.white,               // título blanco
              fontWeight: FontWeight.w800,
              fontSize: (20 * scale).clamp(18, 24),
              shadows: [const Shadow(color: Colors.black26, blurRadius: 6)],
            ),
          ),
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: _finalizar,
              child: Text(
                'Saltar',
                style: Constants.textStyleFont.copyWith(
                  color: Colors.white,           // acción en blanco
                  fontSize: (13 * scale).clamp(12, 15),
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white70,
                ),
              ),
            ),
          ],
          // Íconos y back compat
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: Colors.transparent,   // transparente para ver gradiente
        ),
      ),
      body: Column(
        children: [
          // Card más grande y clara sobre fondo primario
          Flexible(
            flex: 3,
            child: PageView.builder(
              controller: controller,
              onPageChanged: (i) => setState(() => index = i),
              itemCount: _slides.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, i) {
                final s = _slides[i];
                return _SlideCard(
                  titulo: s.titulo,
                  texto: s.texto,
                  icono: s.icono,
                  acento: Constants.colorAccent,
                  fondo: Colors.white.withOpacity(0.98), // card clara sobre primario
                  scale: scale,
                );
              },
            ),
          ),
          // Footer liviano, colores consistentes
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DotsIndicator(
                    count: _slides.length,
                    index: index,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withOpacity(0.35),
                  ),
                  const SizedBox(height: 10),
                  // Botón con estilo diferente según etapa
                  if (index < _slides.length - 1)
                    _BotonSecundario(
                      texto: 'Siguiente',
                      onPressed: () {
                        controller.nextPage(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    )
                  else
                    _BotonPrimario(
                      texto: 'Comenzar',
                      onPressed: _finalizar,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideCard extends StatelessWidget {
  final String titulo;
  final String texto;
  final IconData icono;
  final Color acento;
  final Color fondo;
  final double scale; // Nuevo

  const _SlideCard({
    required this.titulo,
    required this.texto,
    required this.icono,
    required this.acento,
    required this.fondo,
    required this.scale, // Nuevo
  });

  @override
  Widget build(BuildContext context) {
    // Tamaños responsivos
    final iconSize = (32 * scale).clamp(28, 40).toDouble();
    final avatarSize = (60 * scale).clamp(54, 72).toDouble();
    final titleSize = (19 * scale).clamp(17, 22).toDouble();
    final bodySize = (16 * scale).clamp(14, 18).toDouble();
    final bodyHeight = (1.42 * (scale > 1.0 ? 1.05 : 1.0)).clamp(1.35, 1.52);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: (12 * (scale > 1.0 ? 1.0 : 0.95)),
        vertical: 8,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 10))],
          border: Border.all(color: Constants.colorAccent.withOpacity(0.08), width: 1),
        ),
        padding: EdgeInsets.all((16 * (scale > 1.0 ? 1.04 : 1.0))),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  height: avatarSize,
                  width: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Constants.colorAccent, Constants.colorPrimaryLight]),
                    boxShadow: [BoxShadow(color: Constants.colorAccent.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 8))],
                  ),
                  child: Icon(icono, size: iconSize, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Constants.textStyleFontTitle.copyWith(
                      color: Constants.colorPrimaryDark,   // título del card acorde al tema
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 2),
                child: Text(
                  texto,
                  style: Constants.textStyleFont.copyWith(
                    color: Constants.colorFont.withOpacity(0.95),
                    fontSize: bodySize,
                    height: bodyHeight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int index;
  final Color activeColor;
  final Color inactiveColor;

  const _DotsIndicator({
    required this.count,
    required this.index,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: active ? 20 : 8,
          decoration: BoxDecoration(
            color: active ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}

class _BotonPrimario extends StatelessWidget {
  final String texto;
  final VoidCallback onPressed;
  const _BotonPrimario({required this.texto, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Gradiente consistente con Perfil/Login
        gradient: LinearGradient(
          colors: [Constants.colorAccent, Constants.colorPrimaryLight],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Constants.colorAccent.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(texto, style: Constants.textStyleBLANCO.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _BotonSecundario extends StatelessWidget {
  final String texto;
  final VoidCallback onPressed;
  const _BotonSecundario({required this.texto, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Fondo blanco, borde gris suave
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          // Botón blanco sin sombra del Elevated
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        // Texto rojo (acento)
        child: Text(
          texto,
          style: Constants.textStyleFont.copyWith(
            color: Constants.colorAccent,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class OnboardingEntry extends StatefulWidget {
  const OnboardingEntry({super.key});

  @override
  State<OnboardingEntry> createState() => _OnboardingEntryState();
}

class _OnboardingEntryState extends State<OnboardingEntry> {
  late final Future<Widget> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolverPantalla(context);
  }

  Future<Widget> _resolverPantalla(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id ?? 'anon';
    final keyOnboarding = 'onboarding_visto_$userId';

    final yaVistoPorUsuario = prefs.getBool(keyOnboarding);
    final yaVistoLegacy = prefs.getBool('onboarding_visto') ?? false;
    final yaVisto = yaVistoPorUsuario ?? yaVistoLegacy;

    final tipoPrefs = prefs.getString('tipoUsuario');
    String? tipoMeta;
    try {
      final meta = user?.userMetadata ?? {};
      final raw = meta['tipoUsuario'] ?? meta['role'];
      if (raw is String) tipoMeta = raw.toLowerCase();
    } catch (_) {
      tipoMeta = null;
    }
    final tipo = tipoPrefs ?? tipoMeta ?? 'estudiante';
    final esTutor = (tipo == 'profesor');

    if (yaVisto) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (esTutor) {
          navigate(context, CustomPages.homeProPage, finishCurrent: true);
        } else {
          navigate(context, CustomPages.homeEsPage, finishCurrent: true);
        }
      });
      return const SizedBox.shrink();
    }

    return OnboardingPage(esTutor: esTutor);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: Constants.colorBackground,
            body: Center(
              child: CircularProgressIndicator(color: Constants.colorAccent),
            ),
          );
        }
        return snapshot.data ?? const SizedBox.shrink();
      },
    );
  }
}