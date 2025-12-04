import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/custom/no_teclado.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/BackEnd/custom/library.dart';
import 'package:my_app/src/models/usuarios_model.dart';
import 'package:my_app/src/pages/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _contrasenaController = TextEditingController();

  final Usuario usuarioService = Usuario();

  bool _mostrarContrasena = false;

  final inicio = DateTime.now();

  Future<void> _login() async {
    final email = _usuarioController.text.trim().toLowerCase();
    final password = _contrasenaController.text;
    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingrese su email y contraseña')),
        );
      }
      return;
    }

    try {
      final inicio = DateTime.now();
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      final fin = DateTime.now();
      print('⏱️ Tiempo de respuesta login: ${fin.difference(inicio).inMilliseconds} ms');

      // Espera a que currentUser esté disponible
      await Future.delayed(const Duration(milliseconds: 200));
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('[LOGIN] currentUser aún es null, reintentando obtener usuario...');
      }

      // Si el widget se desmontó (por ejemplo, navegación automática), corta aquí
      if (!mounted) return;

      await usuarioService.login(email, password);

      final perfil = await usuarioService.obtenerPerfil();
      final esTutor = (perfil?['clase'] == 'Tutor');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tipoUsuario', esTutor ? 'profesor' : 'estudiante');
      await prefs.setBool('isLoggedIn', true);

      final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
      final keyOnboarding = 'onboarding_visto_$uid';
      final yaVisto = prefs.getBool(keyOnboarding) ?? false;
      debugPrint('[ONBOARDING] user=$uid yaVisto=$yaVisto');

      if (!mounted) return;

      if (!yaVisto) {
        // Mostrar onboarding solo una vez y reemplazar la pantalla de login
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => OnboardingPage(esTutor: esTutor),
        ));
      } else {
        if (esTutor) {
          navigate(context, CustomPages.homeProPage, finishCurrent: true);
        } else {
          navigate(context, CustomPages.homeEsPage, finishCurrent: true);
        }
      }
    } on AuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tu email o contraseña está mal')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tu email o contraseña está mal')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return cerrarTecladoAlTocar(
      child: Scaffold(
        backgroundColor: Constants.colorPrimary, // 🎯 CAMBIO: Fondo colorPrimary
        body: Form(
          key: _formKey,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                // 🎯 NUEVO: Gradiente moderno en lugar de color plano
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Constants.colorBackground,
                    Constants.colorBackground.withOpacity(0.98),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                // 🎯 NUEVO: Sombras ajustadas para colorPrimary
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.20),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Constants.colorPrimaryLight.withOpacity(0.15), // 🎯 Sombra primary
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                // 🎯 NUEVO: Borde primary sutil
                border: Border.all(
                  color: Constants.colorAccent.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(40),
              height: 500,
              width: 400,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🎯 CAMBIO: Título con colorAccent
                  Text(
                    'Iniciar Sesión',
                    style: Constants.textStyleFontTitle.copyWith(
                      color: Constants.colorAccent, // 🎯 Color accent para el título
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _textoField('Email', _usuarioController, false),
                  const SizedBox(height: 20),
                  _textoField('Contraseña', _contrasenaController, true),
                  const SizedBox(height: 30),
                  // 🎯 CAMBIO: Botón con gradiente primary
                  _botonPrimario('Iniciar Sesión', _login),
                  const SizedBox(height: 20),
                  // 🎯 CAMBIO: TextButton con colorAccent
                  TextButton(
                    onPressed: () {
                      navigate(context, CustomPages.registroPage);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '¿No tienes cuenta? Regístrate aquí',
                      style: Constants.textStyleFont.copyWith(
                        color: Constants.colorAccent, // 🎯 Color accent
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor: Constants.colorAccent.withOpacity(0.6),
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

  Widget _textoField(
    String label,
    TextEditingController controller,
    bool isPassword,
  ) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_mostrarContrasena,
      style: Constants.textStyleFont,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Constants.colorBackground,
        // 🎯 CAMBIO: Label con colorAccent
        floatingLabelStyle: TextStyle(
          backgroundColor: Colors.transparent,
          color: Constants.colorAccent, // 🎯 Color accent
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(
          color: Constants.colorFont.withOpacity(0.7),
          fontSize: 14,
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _mostrarContrasena ? Icons.visibility : Icons.visibility_off,
                  color: Constants.colorAccent, // 🎯 Icono accent
                ),
                onPressed: () {
                  setState(() {
                    _mostrarContrasena = !_mostrarContrasena;
                  });
                },
              )
            : null,
        // 🎯 CAMBIO: Bordes con colorAccent
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Constants.colorAccent.withOpacity(0.3), // 🎯 Borde accent
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Constants.colorAccent.withOpacity(0.3), // 🎯 Borde accent
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Constants.colorAccent, // 🎯 Borde accent cuando está enfocado
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Constants.colorError,
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _botonPrimario(String texto, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Constants.colorAccent,
            Constants.colorPrimaryLight,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Constants.colorAccent.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(texto, style: Constants.textStyleBLANCO),
      ),
    );
  }

  Widget _botonSecundario(String texto, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        foregroundColor: Constants.colorAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        texto,
        style: Constants.textStyleFont.copyWith(
          color: Constants.colorAccent,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: Constants.colorAccent.withOpacity(0.45),
        ),
      ),
    );
  }
}

