// ignore_for_file: unused_element_parameter

import 'package:flutter/material.dart';
import 'package:my_app/src/custom/constants.dart';
import 'package:my_app/src/custom/library.dart';

import 'package:my_app/src/models/usuarios_model.dart';



class RegistroPage extends StatefulWidget {
  const RegistroPage({super.key});

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  bool _aceptoTerminos = false;
  String _tipoUsuario = 'Estudiante';
  bool _mostrarContrasena = false;
  bool _mostrarRepetirContrasena = false;

  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();
  final TextEditingController _repetirContrasenaController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final TextEditingController _fechaController = TextEditingController();

  DateTime? _fechaNacimiento; 

  final Usuario usuarioService = Usuario();

  @override
  void dispose() {
    _usuarioController.dispose();
    _correoController.dispose();
    _contrasenaController.dispose();
    _repetirContrasenaController.dispose();
    _apellidoController.dispose();
    _fechaController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
      final DateTime? fecha = await showDatePicker(
        context: context,
        initialDate: DateTime(2000, 1, 1),
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
        builder: (context, child) {
          // Cambiar colores del DatePicker
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Constants.colorAccent,
                onPrimary: Colors.white,
                onSurface: Constants.colorFont,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: Constants.colorAccent),
              ),
            ),
            child: child!,
          );
        },
      );

      if (fecha != null) {
        setState(() {
          _fechaNacimiento = fecha;
          _fechaController.text =
              "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}";
        });
      }
    }

  Future<void> _registrar() async {
    // Validaciones básicas
    if (!_aceptoTerminos) {
      _snack('Debes aceptar los términos y condiciones');
      return;
    }
    if (_usuarioController.text.isEmpty ||
        _correoController.text.isEmpty ||
        _contrasenaController.text.isEmpty ||
        _repetirContrasenaController.text.isEmpty ||
        _apellidoController.text.isEmpty ||
        _fechaController.text.isEmpty) {
      _snack('Completa todos los campos y selecciona tu fecha de nacimiento');
      return;
    }
    if (!_correoController.text.endsWith('@uandresbello.edu')) {
      _snack('El correo debe terminar en @uandresbello.edu');
      return;
    }
    if (_contrasenaController.text.length < 8) {
      _snack('La contraseña debe tener al menos 8 caracteres');
      return;
    }
    if (_contrasenaController.text != _repetirContrasenaController.text) {
      _snack('Las contraseñas no coinciden');
      return;
    }
  

  try {
    final claseFormateada = _tipoUsuario[0].toUpperCase() + _tipoUsuario.substring(1).toLowerCase();
    // Llamada al servicio
    final result = await usuarioService.registrarUsuario(
      email: _correoController.text.trim(),
      password: _contrasenaController.text.trim(),
      nombre: _usuarioController.text.trim(),
      apellido: _apellidoController.text.trim(),
      clase: claseFormateada,
      fechaNacimiento: _fechaNacimiento!,
    );
    if (claseFormateada != 'Estudiante' && claseFormateada != 'Tutor') {
      _snack('Tipo de usuario inválido');
      return;
    }

    if (result['ok'] == true) {
      _snack(result['message'] ?? 'Registro exitoso');
      navigate(context, CustomPages.loginPage);

    } else {
      // Traducimos posibles mensajes de error de Supabase
      String mensaje = result['message'] ?? 'Error al registrar usuario';
      if (mensaje.contains('User already registered')) {
        mensaje = 'El usuario ya está registrado';
      } else if (mensaje.contains('Invalid email')) {
        mensaje = 'El correo electrónico no es válido';
      } else if (mensaje.contains('Weak password')) {
        mensaje = 'La contraseña es demasiado débil';
      }
      _snack(mensaje);
    }
  } catch (e) {
    String error = e.toString();
    if (error.contains('User already registered')) {
      _snack('El usuario ya está registrado');
    } else if (error.contains('Invalid email')) {
      _snack('Correo electrónico no válido');
    } else {
      _snack('Ocurrió un error inesperado: $error');
    }
  }
}


  void _snack(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

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
                  _textoFieldStyle(
                    label: 'Nombre de usuario',
                    controller: _usuarioController,
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 10),
                  _textoFieldStyle(
                    label: 'Apellido',
                    controller: _apellidoController,
                    icon: Icons.person,
                    fondoColor: Constants.colorBackground,
                    textoColor: Constants.colorFont,
                    textoTamanio: 18,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _fechaController,
                    decoration: InputDecoration(
                      labelText: 'Fecha de nacimiento',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    readOnly: true,
                    onTap: _seleccionarFecha, // 🔹 aquí usas la función
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Selecciona tu fecha de nacimiento';
                      }
                      return null;
                    },
                  ),
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
                    onVerPassword: () =>
                        setState(() => _mostrarContrasena = !_mostrarContrasena),
                  ),
                  const SizedBox(height: 10),
                  _textoFieldStyle(
                    label: 'Repetir Contraseña',
                    controller: _repetirContrasenaController,
                    isPassword: true,
                    mostrarPassword: _mostrarRepetirContrasena,
                    onVerPassword: () => setState(
                        () => _mostrarRepetirContrasena = !_mostrarRepetirContrasena),
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
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Constants.colorFont),
                              ),
                              filled: true,
                              fillColor: Constants.colorBackground,
                            ),
                            items: <String>['Estudiante', 'Tutor']
                                .map((value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value,
                                          style:
                                              TextStyle(color: Constants.colorFont)),
                                    ))
                                .toList(),
                            onChanged: (newValue) =>
                                setState(() => _tipoUsuario = newValue!),
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
                        onChanged: (value) =>
                            setState(() => _aceptoTerminos = value ?? false),
                        activeColor: Constants.colorAccent,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text('Acepto términos y condiciones',
                            style: Constants.textStyleBLANCO),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Botón de registro
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _registrar,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 60, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Constants.colorAccent,
                      ),
                      child:
                          Text('Registrarse', style: Constants.textStyleBLANCOJumbo),
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
    bool readOnly = false,
    VoidCallback? onTap, 
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
