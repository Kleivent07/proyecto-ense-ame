import 'package:flutter/material.dart';
import 'package:my_app/src/custom/constants.dart';
import 'package:my_app/src/custom/library.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginRegistro extends StatefulWidget {
  const LoginRegistro({super.key});

  @override
  State<LoginRegistro> createState() => _LoginRegistroState();
}

class _LoginRegistroState extends State<LoginRegistro> {
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();
  bool _mostrarContrasena = false; 

  Future<void> _login() async {
  String email = _usuarioController.text.trim();
  String password = _contrasenaController.text;

  if (email.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Completa todos los campos')),
    );
    return;
  }

  try {
    final supabase = Supabase.instance.client;

    final resAuth = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (resAuth.session != null && resAuth.user != null) {
      // Login exitoso, ahora obtenemos el perfil
      final perfil = await supabase
          .from('perfiles')
          .select()
          .eq('id', resAuth.user!.id)
          .maybeSingle();

      if (perfil != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLogged', true);
        await prefs.setString('tipoUsuario', perfil['clase']);

        if (perfil['clase'] == 'Estudiante') {
          navigate(context, CustomPages.homeEsPage, finishCurrent: true);
        } else if (perfil['clase'] == 'Tutor (profesor)') {
          navigate(context, CustomPages.homeProPage, finishCurrent: true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil no encontrado')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email o contraseña incorrectos')),
      );
    }
  } catch (e) {
    print('Excepción al intentar login: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error al iniciar sesión')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorPrimaryDark,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus(); 
        },
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              color: Constants.colorAccent,
              border: Border.all(color: Constants.colorFont),
              borderRadius: const BorderRadius.all(Radius.circular(20)),
            ),
            height: 600,
            width: 400,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      'Bienvenido a ¡Enseñame!',
                      style: Constants.textStyleBLANCOTitle,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Inicia sesión para continuar',
                      style: Constants.textStyleBLANCOJumbo.copyWith(
                        color: Constants.colorShadow,
                      ),
                    ),
                    const SizedBox(height: 60),
                    _textoFieldStyle(
                      label: 'Usuario(Email)',
                      controller: _usuarioController,
                      isPassword: false,
                    ),
                    const SizedBox(height: 20),
                    _textoFieldStyle(
                      label: 'Contraseña',
                      controller: _contrasenaController,
                      isPassword: true,
                      mostrarPassword: _mostrarContrasena,
                      onVerPassword: () {
                        setState(() {
                          _mostrarContrasena = !_mostrarContrasena;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Constants.colorButton,
                      ),
                      child: Text(
                        'Iniciar Sesión',
                        style: Constants.textStyleBLANCO.copyWith(
                          color: Constants.colorBackground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextButton(
                      onPressed: () {
                        navigate(context, CustomPages.registroPage);
                      },
                      child: Text(
                        '¿No tienes cuenta? Regístrate aquí',
                        style: Constants.textStyleBLANCO,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

  Widget _textoFieldStyle({
    required String label,
    required TextEditingController controller,
    bool isPassword = false,
    bool mostrarPassword = false,
    VoidCallback? onVerPassword,
    IconData? icon,
    Color fondoColor = Colors.white,
    Color textoColor = Colors.black,
    double textoTamanio = 16,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !mostrarPassword,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: textoColor) : null,
          filled: true,
          fillColor: fondoColor,
          labelStyle: TextStyle(color: textoColor, fontSize: textoTamanio),
          floatingLabelStyle: TextStyle(
            backgroundColor: Colors.white, // Fondo blanco para el label flotante
            color: textoColor,
            fontSize: textoTamanio + 4,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white, width: 2),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    mostrarPassword ? Icons.visibility : Icons.visibility_off,
                    color: textoColor,
                  ),
                  onPressed: onVerPassword,
                )
              : null,
        ),
        style: TextStyle(color: textoColor, fontSize: textoTamanio),
      ),
    );
  }



