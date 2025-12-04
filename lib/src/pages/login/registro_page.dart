// ignore_for_file: unused_element_parameter

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_app/src/BackEnd/custom/configuration.dart';
import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/custom/no_teclado.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/BackEnd/custom/library.dart';
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Constants.colorAccent,
              onPrimary: Colors.white,
              onSurface: Constants.colorFont,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Constants.colorAccent,
              ),
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
      final inicio = DateTime.now();

      final claseFormateada =
          _tipoUsuario[0].toUpperCase() +
          _tipoUsuario.substring(1).toLowerCase();
      // Llamada al servicio
      final result = await usuarioService.registrarUsuario(
        email: _correoController.text.trim().toLowerCase(),
        password: _contrasenaController.text.trim(),
        nombre: _usuarioController.text.trim(),
        apellido: _apellidoController.text.trim(),
        clase: claseFormateada,
        fechaNacimiento: _fechaNacimiento!,
      );
      if (claseFormateada != 'Estudiante' && claseFormateada != 'Tutor') {
        final fin = DateTime.now();
        final duracion = fin.difference(inicio).inMilliseconds;
        print('⏱️ Tiempo de respuesta registro: $duracion ms');
        _snack('Tipo de usuario inválido');
        return;
      }

      if (result['ok'] == true) {
        _snack(result['message'] ?? 'Registro exitoso');
        try {
          await usuarioService.login(
            _correoController.text.trim().toLowerCase(),
            _contrasenaController.text.trim(),
          );
          final session = Supabase.instance.client.auth.currentSession;
          final token = session?.accessToken;
          final userId = session?.user?.id;

          final fin = DateTime.now();
          final duracion = fin.difference(inicio).inMilliseconds;
          print('⏱️ Tiempo de respuesta registro: $duracion ms');

          if (token != null && userId != null) {
            navigate(context, CustomPages.loginPage);
            return;
          } else {
            print('No se obtuvo session/token tras login automático.');
            navigate(context, CustomPages.loginPage);
            return;
          }
        } catch (e) {
          final fin = DateTime.now();
          final duracion = fin.difference(inicio).inMilliseconds;
          print('⏱️ Tiempo de respuesta registro: $duracion ms');
          print('Login automático falló (no crítico): $e');
          navigate(context, CustomPages.loginPage);
          return;
        }
      } else {
        final fin = DateTime.now();
        final duracion = fin.difference(inicio).inMilliseconds;
        print('⏱️ Tiempo de respuesta registro: $duracion ms');
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

  Future<Map<String, dynamic>?> _tryEnsureZoom({
    required String userId,
    required String email,
    required String firstName,
    required String lastName,
    required String token,
  }) async {
    final body = {
      'user_id': userId,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'supabase_access_token': token,
    };

    try {
      final resp = await http.post(
        Uri.parse('${Configuration.apiBase}/ensure-zoom-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(resp.body);
        return data;
      } else {
        // No 200: devolver info para mostrar al usuario
        return {
          'ok': false,
          'error': 'http_error',
          'status': resp.statusCode,
          'body': resp.body
        };
      }
    } catch (e) {
      return {'ok': false, 'error': 'request_failed', 'detail': e.toString()};
    }
  }

  void _snack(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return cerrarTecladoAlTocar(
      child: Scaffold(
        backgroundColor: Constants.colorPrimary, // 🎯 IGUAL que login
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Container(
              decoration: BoxDecoration(
                // 🎯 MISMO GRADIENTE que login
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Constants.colorBackground,
                    Constants.colorBackground.withOpacity(0.98),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                // 🎯 MISMAS SOMBRAS que login
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.20),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Constants.colorPrimaryLight.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                // 🎯 MISMO BORDE que login
                border: Border.all(
                  color: Constants.colorAccent.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(24), // 🎯 MÁS PEQUEÑO (antes 30)
              width: 360, // 🎯 MÁS PEQUEÑO (antes 400)
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // 🎯 Header con botón atrás y título
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Constants.colorAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Constants.colorAccent.withOpacity(0.2),
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: Constants.colorAccent,
                            size: 18, // 🎯 MÁS PEQUEÑO (antes 20)
                          ),
                          onPressed: () => navigate(context, CustomPages.loginPage),
                        ),
                      ),
                      const SizedBox(width: 12), // 🎯 MÁS PEQUEÑO (antes 16)
                      Expanded(
                        child: Text(
                          'Crear Cuenta',
                          style: Constants.textStyleFontTitle.copyWith(
                            color: Constants.colorAccent,
                            fontSize: 22, // 🎯 MÁS PEQUEÑO (antes 24)
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6), // 🎯 MÁS PEQUEÑO (antes 8)
                  Text(
                    'Únete a nuestra comunidad',
                    style: Constants.textStyleFont.copyWith(
                      color: Constants.colorFont.withOpacity(0.7),
                      fontSize: 13, // 🎯 MÁS PEQUEÑO (antes 14)
                    ),
                  ),
                  const SizedBox(height: 20), // 🎯 MÁS PEQUEÑO (antes 25)
                  
                  // 🎯 FORMULARIO VERTICAL
                  _textoFieldModerno(
                    label: 'Nombre',
                    controller: _usuarioController,
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 14), // 🎯 MÁS PEQUEÑO (antes 16)
                  
                  _textoFieldModerno(
                    label: 'Apellido',
                    controller: _apellidoController,
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  
                  _fechaFieldModerno(),
                  const SizedBox(height: 14),
                  
                  _textoFieldModerno(
                    label: 'Correo (@uandresbello.edu)',
                    controller: _correoController,
                    icon: Icons.email_rounded,
                  ),
                  const SizedBox(height: 14),
                  
                  _tipoUsuarioModerno(),
                  const SizedBox(height: 14),
                  
                  _textoFieldModerno(
                    label: 'Contraseña',
                    controller: _contrasenaController,
                    icon: Icons.lock_rounded,
                    isPassword: true,
                    mostrarPassword: _mostrarContrasena,
                    onTogglePassword: () => setState(() => _mostrarContrasena = !_mostrarContrasena),
                  ),
                  const SizedBox(height: 14),
                  
                  _textoFieldModerno(
                    label: 'Repetir Contraseña',
                    controller: _repetirContrasenaController,
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                    mostrarPassword: _mostrarRepetirContrasena,
                    onTogglePassword: () => setState(() => _mostrarRepetirContrasena = !_mostrarRepetirContrasena),
                  ),
                  const SizedBox(height: 16), // 🎯 MÁS PEQUEÑO (antes 20)
                  
                  // 🎯 CHECKBOX CON ESTILO MODERNO
                  _checkboxModerno(),
                  const SizedBox(height: 20), // 🎯 MÁS PEQUEÑO (antes 25)
                  
                  // 🎯 BOTÓN CON MISMO ESTILO que login
                  Container(
                    width: double.infinity,
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
                          color: Constants.colorAccent.withOpacity(0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _registrar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14), // 🎯 MÁS PEQUEÑO (antes 16)
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Crear Cuenta',
                        style: Constants.textStyleBLANCO.copyWith(
                          fontSize: 15, // 🎯 MÁS PEQUEÑO (antes 16)
                          fontWeight: FontWeight.w600,
                        ),
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

  // 🎯 CAMPO DE TEXTO MODERNO (tamaños más compactos)
  Widget _textoFieldModerno({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    bool isPassword = false,
    bool mostrarPassword = false,
    VoidCallback? onTogglePassword,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !mostrarPassword,
      style: Constants.textStyleFont.copyWith(fontSize: 15), // 🎯 MÁS PEQUEÑO (antes 16)
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Constants.colorAccent, size: 20) : null, // 🎯 MÁS PEQUEÑO (antes 22)
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  mostrarPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: Constants.colorAccent,
                  size: 20, // 🎯 MÁS PEQUEÑO (antes 22)
                ),
                onPressed: onTogglePassword,
              )
            : null,
        filled: true,
        fillColor: Constants.colorBackground,
        floatingLabelStyle: TextStyle(
          backgroundColor: Colors.transparent,
          color: Constants.colorAccent,
          fontSize: 15, // 🎯 MÁS PEQUEÑO (antes 16)
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(
          color: Constants.colorFont.withOpacity(0.7),
          fontSize: 13, // 🎯 MÁS PEQUEÑO (antes 14)
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Constants.colorAccent.withOpacity(0.3),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Constants.colorAccent.withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Constants.colorAccent,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), // 🎯 MÁS PEQUEÑO (antes 16)
      ),
    );
  }

  // 🎯 DROPDOWN TIPO USUARIO MODERNO (más compacto)
  Widget _tipoUsuarioModerno() {
    return DropdownButtonFormField<String>(
      value: _tipoUsuario,
      style: Constants.textStyleFont.copyWith(fontSize: 15), // 🎯 MÁS PEQUEÑO (antes 16)
      decoration: InputDecoration(
        labelText: 'Tipo de Usuario',
        prefixIcon: Icon(Icons.school_rounded, color: Constants.colorAccent, size: 20), // 🎯 MÁS PEQUEÑO (antes 22)
        filled: true,
        fillColor: Constants.colorBackground,
        floatingLabelStyle: TextStyle(
          backgroundColor: Colors.transparent,
          color: Constants.colorAccent,
          fontSize: 15, // 🎯 MÁS PEQUEÑO (antes 16)
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(
          color: Constants.colorFont.withOpacity(0.7),
          fontSize: 13, // 🎯 MÁS PEQUEÑO (antes 14)
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Constants.colorAccent.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Constants.colorAccent.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Constants.colorAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), // 🎯 MÁS PEQUEÑO (antes 16)
      ),
      items: ['Estudiante', 'Tutor']
          .map((value) => DropdownMenuItem<String>(
                value: value,
                child: Text(value, style: Constants.textStyleFont.copyWith(fontSize: 15)), // 🎯 MÁS PEQUEÑO (antes 16)
              ))
          .toList(),
      onChanged: (newValue) => setState(() => _tipoUsuario = newValue!),
      dropdownColor: Constants.colorBackground,
      borderRadius: BorderRadius.circular(12),
    );
  }

  // 🎯 CAMPO DE FECHA MODERNO (más compacto)
  Widget _fechaFieldModerno() {
    return TextFormField(
      controller: _fechaController,
      readOnly: true,
      onTap: _seleccionarFecha,
      style: Constants.textStyleFont.copyWith(fontSize: 15), // 🎯 MÁS PEQUEÑO (antes 16)
      decoration: InputDecoration(
        labelText: 'Fecha de Nacimiento',
        prefixIcon: Icon(Icons.calendar_today_rounded, color: Constants.colorAccent, size: 20), // 🎯 MÁS PEQUEÑO (antes 22)
        filled: true,
        fillColor: Constants.colorBackground,
        floatingLabelStyle: TextStyle(
          backgroundColor: Colors.transparent,
          color: Constants.colorAccent,
          fontSize: 15, // 🎯 MÁS PEQUEÑO (antes 16)
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(
          color: Constants.colorFont.withOpacity(0.7),
          fontSize: 13, // 🎯 MÁS PEQUEÑO (antes 14)
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Constants.colorAccent.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Constants.colorAccent.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Constants.colorAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), // 🎯 MÁS PEQUEÑO (antes 16)
      ),
    );
  }

  // 🎯 CHECKBOX MODERNO (más compacto)
  Widget _checkboxModerno() {
    return Container(
      padding: const EdgeInsets.all(10), // 🎯 MÁS PEQUEÑO (antes 12)
      decoration: BoxDecoration(
        color: Constants.colorAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Constants.colorAccent.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Transform.scale(
            scale: 1.0, // 🎯 MÁS PEQUEÑO (antes 1.1)
            child: Checkbox(
              value: _aceptoTerminos,
              onChanged: (value) => setState(() => _aceptoTerminos = value ?? false),
              activeColor: Constants.colorAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 6), // 🎯 MÁS PEQUEÑO (antes 8)
          Expanded(
            child: Text(
              'Acepto los términos y condiciones',
              style: Constants.textStyleFont.copyWith(
                color: Constants.colorFont,
                fontSize: 13, // 🎯 MÁS PEQUEÑO (antes 14)
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

