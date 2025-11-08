// ignore_for_file: unused_element_parameter

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_app/src/custom/configuration.dart';
import 'package:flutter/material.dart';
import 'package:my_app/src/custom/no_teclado.dart';
import 'package:my_app/src/util/constants.dart';
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
  final TextEditingController _repetirContrasenaController =
      TextEditingController();
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
        _snack('Tipo de usuario inválido');
        return;
      }

      if (result['ok'] == true) {
        _snack(result['message'] ?? 'Registro exitoso');

        // Intentar login automático para obtener session/accessToken
        try {
          await usuarioService.login(
            _correoController.text.trim().toLowerCase(),
            _contrasenaController.text.trim(),
          );

          final session = Supabase.instance.client.auth.currentSession;
          final token = session?.accessToken;
          final userId = session?.user?.id;

          if (token != null && userId != null) {
            // Intento inicial de sincronizar con Zoom
            final zoomResp = await _tryEnsureZoom(
              userId: userId,
              email: _correoController.text.trim().toLowerCase(),
              firstName: _usuarioController.text.trim(),
              lastName: _apellidoController.text.trim(),
              token: token,
            );

            // Si ok = true -> todo bien (existe o se creó)
            if (zoomResp != null && zoomResp['ok'] == true) {
              // Si la creación devuelto estado 'pending' podrías avisar que hay que aceptar la invitación
              final created = zoomResp['created'] == true ||
                  zoomResp['created'] != null;
              final exists = zoomResp['exists'] == true;
              String msg = 'Sincronización con Zoom completada.';
              if (created) {
                final zoomResult = zoomResp['zoomResult'] ??
                    zoomResp['created'];
                final status = zoomResult != null
                    ? (zoomResult['status'] ?? zoomResult['user']?['status'])
                    : null;
                if (status == 'pending') {
                  msg =
                      'Se envió una invitación a Zoom. Debes aceptar la invitación en tu correo para activar tu cuenta Zoom.';
                } else {
                  msg = 'Cuenta Zoom creada y sincronizada.';
                }
              } else if (exists) {
                msg = 'Cuenta Zoom verificada.';
              }
              // Opcional: mostrar breve notificación
              _snack(msg);
              // Continuar flujo normal
              navigate(context, CustomPages.loginPage);
              return;
            }

            // Si llegamos aquí, hubo fallo en la sincronización -> mostrar diálogo con opciones
            final errorMsg = (zoomResp != null && zoomResp['error'] != null)
                ? 'Error: ${zoomResp['error']}'
                : 'No se pudo sincronizar con Zoom.';

            final action = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Problema con Zoom'),
                content: Text(
                  '$errorMsg\n\n¿Quieres reintentar ahora, continuar sin cuenta Zoom o cancelar el registro?',
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop('cancel'),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop('continue'),
                      child: const Text('Continuar sin Zoom')),
                  ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop('retry'),
                      child: const Text('Reintentar')),
                ],
              ),
            );

            if (action == 'retry') {
              // Reintentar una vez
              final zoomResp2 = await _tryEnsureZoom(
                userId: userId,
                email: _correoController.text.trim().toLowerCase(),
                firstName: _usuarioController.text.trim(),
                lastName: _apellidoController.text.trim(),
                token: token,
              );
              if (zoomResp2 != null && zoomResp2['ok'] == true) {
                _snack('Sincronización con Zoom completada en reintento.');
                navigate(context, CustomPages.loginPage);
                return;
              } else {
                // Si falla otra vez, dejar que el usuario decida: continuamos al login
                _snack(
                    'No fue posible sincronizar con Zoom. Puedes intentarlo luego desde tu perfil.');
                navigate(context, CustomPages.loginPage);
                return;
              }
            } else if (action == 'continue') {
              // Permitir continuar sin Zoom
              _snack('Registro completado. Puedes sincronizar tu cuenta con Zoom más tarde.');
              navigate(context, CustomPages.loginPage);
              return;
            } else {
              // Cancel -> no navegar, quedarse en registro para que usuario corrija (por ejemplo email)
              return;
            }
          } else {
            print('No se obtuvo session/token tras login automático.');
            // Seguir con la navegación a login aunque no se haya sincronizado
            navigate(context, CustomPages.loginPage);
            return;
          }
        } catch (e) {
          print('Login automático falló (no crítico): $e');
          // No bloquear; ir a login
          navigate(context, CustomPages.loginPage);
          return;
        }
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
        backgroundColor: Constants.colorPrimaryDark,
        body: Center(
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                    onVerPassword: () => setState(
                      () => _mostrarContrasena = !_mostrarContrasena,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _textoFieldStyle(
                    label: 'Repetir Contraseña',
                    controller: _repetirContrasenaController,
                    isPassword: true,
                    mostrarPassword: _mostrarRepetirContrasena,
                    onVerPassword: () => setState(
                      () => _mostrarRepetirContrasena =
                          !_mostrarRepetirContrasena,
                    ),
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
                                horizontal: 12,
                                vertical: 0,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Constants.colorFont,
                                ),
                              ),
                              filled: true,
                              fillColor: Constants.colorBackground,
                            ),
                            items: <String>['Estudiante', 'Tutor']
                                .map(
                                  (value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value,
                                      style: TextStyle(
                                        color: Constants.colorFont,
                                      ),
                                    ),
                                  ),
                                )
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
                        child: Text(
                          'Acepto términos y condiciones',
                          style: Constants.textStyleBLANCO,
                        ),
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
                          horizontal: 60,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        backgroundColor: Constants.colorAccent,
                      ),
                      child: Text(
                        'Registrarse',
                        style: Constants.textStyleBLANCOJumbo,
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

