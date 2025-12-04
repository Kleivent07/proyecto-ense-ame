import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/custom/no_teclado.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

import 'package:my_app/src/models/usuarios_model.dart';
import 'package:my_app/src/models/profesores_model.dart';
import 'package:my_app/src/models/estudiantes_model.dart';

import 'package:my_app/src/BackEnd/util/lista_carreras.dart';
import 'package:my_app/src/BackEnd/util/lista_materias.dart';

class EditarPerfilPage extends StatefulWidget {
  final Map<String, dynamic> perfil;
  const EditarPerfilPage({required this.perfil, Key? key}) : super(key: key);
  @override
  State<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends State<EditarPerfilPage> {
  List<String> especialidadesSeleccionadas = [];

  late TextEditingController nombreController;
  late TextEditingController bioController;
  late TextEditingController apellidoController;
  late TextEditingController fechaNacimientoController;
  late TextEditingController confirmPasswordController;

  // Campos específicos según tipo
  late TextEditingController especialidadController;
  late TextEditingController carreraProfesionController;
  late TextEditingController experienciaController;
  late TextEditingController horarioController;

  late TextEditingController disponibilidadController;
  late TextEditingController carreraController;
  late TextEditingController semestreController;
  late TextEditingController interesesController;
  late bool esProfesor;

  bool guardando = false;
  Uint8List? imagenSeleccionada;
  String? extensionImagen;

  // Días de la semana disponibles
  final List<String> diasSemana = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];
  List<String> diasSeleccionados = [];

  @override
  void initState() {
    super.initState();
    final perfil = widget.perfil;
    esProfesor = perfil['clase'] == 'Tutor';
    confirmPasswordController = TextEditingController();

    // Datos comunes
    nombreController = TextEditingController(text: perfil['nombre'] ?? '');
    bioController = TextEditingController(text: perfil['biografia'] ?? '');
    apellidoController = TextEditingController(text: perfil['apellido'] ?? '');
    fechaNacimientoController = TextEditingController(
      text: perfil['fecha_nacimiento'] != null
          ? perfil['fecha_nacimiento'].toString().substring(0, 10)
          : '',
    );

    // Datos de profesor
    experienciaController = TextEditingController(
      text: perfil['experiencia'] ?? '',
    );
    carreraProfesionController = TextEditingController(
      text: perfil['carrera_profesion'] ?? '',
    );
    especialidadesSeleccionadas = (perfil['especialidad'] ?? '')
        .toString()
        .split(',')
        .map((e) => e.trim())
        .toList();
    horarioController = TextEditingController(
      text: perfil['horario'] ?? '',
    ); // <-- AGREGA ESTA LÍNEA

    // Datos de estudiante
    carreraController = TextEditingController(text: perfil['carrera'] ?? '');
    semestreController = TextEditingController(
      text: perfil['semestre']?.toString() ?? '',
    );
    interesesController = TextEditingController(
      text: perfil['intereses'] ?? '',
    );
    disponibilidadController = TextEditingController(
      text: perfil['disponibilidad'] ?? '',
    );

    // Inicializar días seleccionados si ya hay horarios guardados
    if (esProfesor && perfil['horario'] != null && perfil['horario'].toString().isNotEmpty) {
      diasSeleccionados = perfil['horario'].toString().split(',').map((e) => e.trim()).toList();
    }
  }

  Future<void> seleccionarImagen() async {
    final picker = ImagePicker();
    final resultado = await picker.pickImage(source: ImageSource.gallery);

    if (resultado != null) {
      imagenSeleccionada = await resultado.readAsBytes();
      extensionImagen = resultado.path.split('.').last;

      print('Imagen seleccionada correctamente');
      print('Extensión de imagen: $extensionImagen');
      print('Bytes de imagen: ${imagenSeleccionada!.length}');

      setState(() {});
    }
  }

  Future<void> _guardarCambios() async {
    final confirmPasswordController = TextEditingController();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar contraseña'),
        content: TextField(
          controller: confirmPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Ingresa tu contraseña',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    final user = Supabase.instance.client.auth.currentUser!;

    try {
      // Solo verifica la contraseña, no hagas signOut ni signIn de nuevo
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: user.email!,
        password: confirmPasswordController.text,
      );

      if (response.user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña incorrecta')),
        );
        return;
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de autenticación: ${e.message}')),
      );
      return;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al verificar la contraseña: $e')),
      );
      return;
    }

    setState(() => guardando = true);

    final userId = Supabase.instance.client.auth.currentUser!.id;

    try {
      String? nombreArchivo;
      if (imagenSeleccionada != null && extensionImagen != null) {
        nombreArchivo =
            '${DateTime.now().millisecondsSinceEpoch}.$extensionImagen';
        print('Nombre del archivo generado: $nombreArchivo');
      }
      // Limpiar "Sin definir" en carrera y especialidades
      if (carreraController.text == 'Sin definir') {
        carreraController.text = '';
      }
      especialidadesSeleccionadas.removeWhere((e) => e == 'Sin definir');

      // Actualizar perfil
      await Usuario().actualizarPerfil(
        nuevoNombre: nombreController.text,
        nuevoApellido: apellidoController.text,
        nuevaBiografia: bioController.text,
        nuevaFechaNacimiento: fechaNacimientoController.text,
        nuevaImagen: imagenSeleccionada,
        nombreArchivo: nombreArchivo,
      );

      if (imagenSeleccionada != null && nombreArchivo != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen de perfil actualizada correctamente'),
          ),
        );
      }

      // Actualizar tabla específica según tipo
      if (esProfesor) {
        await ProfesorService().actualizarProfesor(
          userId: userId,
          especialidad: especialidadesSeleccionadas.join(', '),
          carreraProfesion: carreraProfesionController.text,
          experiencia: experienciaController.text,
          horario: horarioController.text,
        );
      } else {
        await EstudianteService().actualizarEstudiante(
          userId: userId,
          carrera: carreraController.text,
          semestre: int.tryParse(semestreController.text),
          intereses: interesesController.text,
          disponibilidad: disponibilidadController.text,
          // NO ENVÍES HORARIO AQUÍ
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar los cambios: $e')),
      );
    } finally {
      setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return cerrarTecladoAlTocar(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar Perfil'),
          backgroundColor: Constants.colorPrimaryDark, // Rojo oscuro
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: guardando
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Constants.colorPrimaryDark, // Rojo oscuro
                        Constants.colorPrimary,     // Rojo principal
                        Constants.colorPrimaryLight // Rojo claro
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar con borde y sombra
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Constants.colorPrimaryDark.withOpacity(0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 55,
                                  backgroundColor: Colors.white,
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundImage: imagenSeleccionada != null
                                        ? MemoryImage(imagenSeleccionada!)
                                        : (widget.perfil['imagen_url'] != null
                                            ? NetworkImage(widget.perfil['imagen_url'])
                                            : const AssetImage('assets/default_avatar.jpg') as ImageProvider),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: InkWell(
                                    onTap: seleccionarImagen,
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Constants.colorPrimary,
                                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Título general
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Información general',
                            style: TextStyle(
                              color: Constants.colorPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1,
                            ),
                          ),
                        ),

                        // Campos generales en tarjeta
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 7,
                          color: Colors.white.withOpacity(0.97),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildTextField(nombreController, 'Nombre'),
                                _buildTextField(bioController, 'Biografía', maxLines: 3),
                                _buildTextField(apellidoController, 'Apellido'),
                                _buildTextField(fechaNacimientoController, 'Fecha de nacimiento (YYYY-MM-DD)', keyboardType: TextInputType.datetime),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Campos específicos según tipo en tarjeta
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 7,
                          color: Colors.white.withOpacity(0.97),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: esProfesor
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Datos de profesor', style: TextStyle(color: Constants.colorPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                                      const SizedBox(height: 10),
                                      MultiSelectDialogField(
                                        items: materias.map((materia) => MultiSelectItem<String>(materia, materia)).toList(),
                                        title: const Text("Especialidades"),
                                        selectedColor: Constants.colorPrimary,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Constants.colorPrimaryLight),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Constants.colorPrimaryLight.withOpacity(0.08),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        buttonIcon: Icon(Icons.school, color: Constants.colorPrimary),
                                        buttonText: Text("Selecciona especialidades", style: TextStyle(color: Constants.colorPrimary)),
                                        initialValue: especialidadesSeleccionadas,
                                        onConfirm: (values) {
                                          setState(() {
                                            especialidadesSeleccionadas = List<String>.from(values);
                                          });
                                        },
                                      ),
                                      _buildTextField(carreraProfesionController, 'Carrera o profesión'),
                                      _buildTextField(experienciaController, 'Experiencia'),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Text(
                                          'Días disponibles',
                                          style: TextStyle(
                                            color: Constants.colorPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Wrap(
                                        spacing: 8,
                                        children: diasSemana.map((dia) {
                                          final seleccionado = diasSeleccionados.contains(dia);
                                          return FilterChip(
                                            label: Text(dia),
                                            selected: seleccionado,
                                            selectedColor: Constants.colorPrimary,
                                            checkmarkColor: Colors.white,
                                            onSelected: (valor) {
                                              setState(() {
                                                if (valor) {
                                                  diasSeleccionados.add(dia);
                                                } else {
                                                  diasSeleccionados.remove(dia);
                                                }
                                                horarioController.text = diasSeleccionados.join(', ');
                                              });
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Datos de estudiante', style: TextStyle(color: Constants.colorPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                                      const SizedBox(height: 10),
                                      _buildDropdownField(carreraController, 'Carrera', CarrerasUNAB.lista),
                                      _buildTextField(semestreController, 'Semestre (número)', keyboardType: TextInputType.number),
                                      _buildTextField(interesesController, 'Intereses'),
                                      _buildTextField(disponibilidadController, 'Disponibilidad'),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Botones
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _EditarButton(
                              icon: Icons.save,
                              text: 'Guardar cambios',
                              color1: Constants.colorPrimaryDark,
                              color2: Constants.colorPrimary,
                              onTap: _guardarCambios,
                            ),
                            _EditarButton(
                              icon: Icons.cancel,
                              text: 'Cancelar',
                              color1: Colors.grey.shade400,
                              color2: Colors.grey.shade700,
                              onTap: () async {
                                final confirmar = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('¿Cancelar edición?'),
                                    content: const Text('¿Seguro que quieres cancelar los cambios?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('No'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Sí, cancelar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmar == true && mounted) Navigator.pop(context, false);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // === FUNCIONES AUXILIARES PARA CAMPOS ===
  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    TextEditingController controller,
    String label,
    List<String> items,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: items.contains(controller.text) && controller.text != 'Sin definir' ? controller.text : null,
        decoration: InputDecoration(labelText: label, border: InputBorder.none),
        isExpanded: true,
        items: items
            .where((item) => item != 'Sin definir') // Elimina "Sin definir" de las opciones
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (value) {
          controller.text = value ?? '';
        },
      ),
    );
  }
}

// Nuevo botón bonito para editar perfil
class _EditarButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color1;
  final Color color2;
  final VoidCallback onTap;

  const _EditarButton({
    required this.icon,
    required this.text,
    required this.color1,
    required this.color2,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color2.withOpacity(0.22),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

