import 'package:flutter/material.dart';
import 'package:my_app/src/custom/constants.dart';
import 'package:my_app/src/custom/library.dart';
import 'package:my_app/src/models/usuarios_model.dart';
import 'package:shared_preferences/shared_preferences.dart';


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

  Future<void> _login() async {
    final email = _usuarioController.text.trim();
    final password = _contrasenaController.text;

    try {
      await usuarioService.login(email, password); 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicio de sesión exitoso')),
      );

      // Luego podrías obtener datos del perfil
      final perfil = await usuarioService.obtenerPerfil();
      print('Perfil actual: $perfil');

      // Guardar estado de sesión y tipo de usuario
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('tipoUsuario', perfil?['clase'] == 'Tutor' ? 'profesor' : 'estudiante');

      // Aquí decides a qué pantalla navegar
      if (perfil?['clase'] == 'Tutor') {
        navigate(context, CustomPages.homeProPage);
      } else {
        navigate(context, CustomPages.homeEsPage);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Constants.colorPrimaryDark,
        body: Form(
          key: _formKey,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: Constants.colorAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(40),
              height: 500,
              width: 400,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Iniciar Sesión', style: Constants.textStyleBLANCOTitle),
                  const SizedBox(height: 30),
                  _textoField('Email', _usuarioController, false),
                  const SizedBox(height: 20),
                  _textoField('Contraseña', _contrasenaController, true),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Constants.colorButton,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 50,
                        vertical: 18,
                      ),
                    ),
                    child: Text('Iniciar Sesión', style: Constants.textStyleBLANCO),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                      onPressed: () {
                        navigate(context, CustomPages.registroPage);
                      },
                      child: Text(
                        '¿No tienes cuenta? Regístrate aquí',
                        style: Constants.textStyleBLANCO,
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
        floatingLabelStyle: const TextStyle(
          backgroundColor: Colors.white, 
          color: Colors.black,          
          fontSize: 18,                   
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _mostrarContrasena
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: Constants.colorFont,
                ),
                onPressed: () {
                  setState(() {
                    _mostrarContrasena = !_mostrarContrasena;
                  });
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}