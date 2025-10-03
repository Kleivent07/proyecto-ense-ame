import 'package:flutter/material.dart';
import 'package:my_app/src/custom/constants.dart';
import 'package:my_app/src/custom/library.dart';
import 'package:my_app/src/models/create_perfiles.dart';

class RegistroUsuario extends StatefulWidget {
  const RegistroUsuario({super.key});

  @override
  State<RegistroUsuario> createState() => _RegistroUsuarioState();
}

class _RegistroUsuarioState extends State<RegistroUsuario> {
  bool _aceptoTerminos = false;
  String _tipoUsuario = 'Estudiante';
  bool _mostrarContrasena = false;
  bool _mostrarRepetirContrasena = false;

  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();
  final TextEditingController _repetirContrasenaController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorPrimaryDark,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                color: Constants.colorPrimaryLight,
                border: Border.all(color: Constants.colorFont),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 29),
              width: 390,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Título y botón atrás
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: Constants.colorFont),
                      onPressed: () => navigate(context, CustomPages.loginPage),
                    ),
                  ),
                  Text(
                    'Hola, regístrate y únete a nuestra comunidad ^^',
                    style: Constants.textStyleFontTitle,
                  ),
                  const SizedBox(height: 40),
                  // Campos
                  _textoFieldStyle(label: 'Nombre de usuario', controller: _usuarioController),
                  const SizedBox(height: 10),
                  _textoFieldStyle(
                    label: 'Correo electrónico (@uandresbello.edu)',
                    controller: _correoController,
                    icon: Icons.email,
                    fondoColor: Constants.colorBackground,
                    textoColor: Constants.colorFont,
                    textoTamanio: 18,
                  ),
                  const SizedBox(height: 10),
                  _textoFieldStyle(
                    label: 'Contraseña',
                    controller: _contrasenaController,
                    isPassword: true,
                    mostrarPassword: _mostrarContrasena,
                    onVerPassword: () => setState(() => _mostrarContrasena = !_mostrarContrasena),
                  ),
                  const SizedBox(height: 10),
                  _textoFieldStyle(
                    label: 'Repetir Contraseña',
                    controller: _repetirContrasenaController,
                    isPassword: true,
                    mostrarPassword: _mostrarRepetirContrasena,
                    onVerPassword: () =>
                        setState(() => _mostrarRepetirContrasena = !_mostrarRepetirContrasena),
                  ),
                  const SizedBox(height: 10),
                  // Tipo de usuario
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Text('Soy:', style: Constants.textStyleBLANCOJumbo),
                        const SizedBox(width: 20),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _tipoUsuario,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Constants.colorFont),
                              ),
                              filled: true,
                              fillColor: Constants.colorBackground,
                            ),
                            items: <String>['Estudiante', 'Tutor (profesor)']
                                .map((value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value, style: TextStyle(color: Constants.colorFont)),
                                    ))
                                .toList(),
                            onChanged: (newValue) => setState(() => _tipoUsuario = newValue!),
                            dropdownColor: Constants.colorShadow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Aceptar términos
                  Row(
                    children: [
                      Checkbox(
                        value: _aceptoTerminos,
                        onChanged: (value) => setState(() => _aceptoTerminos = value ?? false),
                        activeColor: Constants.colorAccent,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text('Acepto términos y condiciones', style: Constants.textStyleBLANCO),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Botón de registro
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _registrarUsuario,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Constants.colorAccent,
                      ),
                      child: Text('Registrarse', style: Constants.textStyleBLANCOJumbo),
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

  // Función de registro
  Future<void> _registrarUsuario() async {
    // Validaciones
    if (!_aceptoTerminos) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Debes aceptar los términos y condiciones')));
      return;
    }
    if (_usuarioController.text.isEmpty ||
        _correoController.text.isEmpty ||
        _contrasenaController.text.isEmpty ||
        _repetirContrasenaController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Completa todos los campos')));
      return;
    }
    if (!_correoController.text.endsWith('@uandresbello.edu')) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('El correo debe ser @uandresbello.edu')));
      return;
    }
    if (_contrasenaController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 8 caracteres')),
      );
      return;
    }
    if (_contrasenaController.text != _repetirContrasenaController.text) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden')));
      return;
    }

    // Crear perfil
    bool registrado = await PerfilRepository.createPerfil(
      email: _correoController.text.trim(),
      password: _contrasenaController.text,
      nombre: _usuarioController.text.trim(),
      clase: _tipoUsuario,
    );

    if (registrado) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Usuario registrado con éxito')));
      navigate(context, CustomPages.loginPage);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error al registrar usuario')));
    }
  }

  // Widget de campos
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
            backgroundColor: Colors.white,
            color: textoColor,
            fontSize: textoTamanio + 4,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white, width: 2),
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
}
