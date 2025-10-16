import 'package:flutter/material.dart';
import 'package:my_app/src/custom/no_teclado.dart';
import 'package:my_app/src/util/constants.dart';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

import 'package:my_app/src/models/usuarios_model.dart';
import 'package:my_app/src/models/profesores_model.dart';
import 'package:my_app/src/models/estudiantes_model.dart';

import 'package:my_app/src/util/lista_carreras.dart';
import 'package:my_app/src/util/lista_materias.dart';

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
    horarioController = TextEditingController(text: perfil['horario'] ?? '');

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
    } else {
      print('No se seleccionó ninguna imagen');
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
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: user.email!,
        password: confirmPasswordController.text,
      );

      if (response.user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Contraseña incorrecta')));
        return;
      }

      await Supabase.instance.client.auth.signOut();
      await Supabase.instance.client.auth.signInWithPassword(
        email: user.email!,
        password: confirmPasswordController.text,
      );
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
      // Actualizar perfil
      await Usuario().actualizarPerfil(
        nuevoNombre: nombreController.text,
        nuevoApellido: apellidoController.text,
        nuevaBiografia: bioController.text,
        nuevaFechaNacimiento: fechaNacimientoController.text,
        nuevaImagen: imagenSeleccionada,
        nombreArchivo: nombreArchivo,
      );
      // Verificación visual de subida de imagen
      if (imagenSeleccionada != null && nombreArchivo != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen de perfil actualizada correctamente'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se seleccionó una nueva imagen')),
        );
      }

      // === 2 Actualizar tabla específica según tipo ===
      if (esProfesor) {
        await ProfesorService().actualizarProfesor(
          userId: userId,
          especialidad: '',
          carreraProfesion: carreraProfesionController.text,
          experiencia: experienciaController.text,
          horario: horarioController.text,
        );

        // Luego guarda las nuevas especialidades
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
          backgroundColor: Constants.colorPrimary,
          foregroundColor: Colors.white,
        ),
        backgroundColor: Constants.colorShadow,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: guardando
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // === AVATAR CON BORDE Y BORDES REDONDEADOS ===
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 55,
                              backgroundColor: Constants.colorFont,
                              child: CircleAvatar(
                                radius: 50,
                                backgroundImage: imagenSeleccionada != null
                                    ? MemoryImage(imagenSeleccionada!)
                                    : (widget.perfil['imagen_url'] != null
                                          ? NetworkImage(
                                              widget.perfil['imagen_url'],
                                            )
                                          : const AssetImage(
                                                  'assets/default_avatar.jpg',
                                                )
                                                as ImageProvider),
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
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // === TÍTULO GENERAL ===
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Información general',
                          style: Constants.textStyleAccentTitle,
                        ),
                      ),

                      // === CAMPOS DE INFORMACIÓN GENERAL ===
                      _buildTextField(nombreController, 'Nombre'),
                      _buildTextField(bioController, 'Biografía', maxLines: 3),
                      _buildTextField(apellidoController, 'Apellido'),
                      _buildTextField(
                        fechaNacimientoController,
                        'Fecha de nacimiento (YYYY-MM-DD)',
                        keyboardType: TextInputType.datetime,
                      ),

                      const SizedBox(height: 24),

                      // === CAMPOS ESPECÍFICOS SEGÚN TIPO ===
                      if (esProfesor) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Datos de profesor',
                            style: Constants.textStyleAccentTitle,
                          ),
                        ),

                        MultiSelectDialogField(
                          items: materias
                              .map(
                                (materia) =>
                                    MultiSelectItem<String>(materia, materia),
                              )
                              .toList(),
                          title: const Text("Especialidades"),
                          selectedColor: Constants.colorPrimary,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade200,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          buttonIcon: const Icon(Icons.school),
                          buttonText: const Text("Selecciona especialidades"),
                          initialValue: especialidadesSeleccionadas,
                          onConfirm: (values) {
                            setState(() {
                              especialidadesSeleccionadas = List<String>.from(
                                values,
                              );
                            });
                          },
                        ),
                        _buildTextField(
                          carreraProfesionController,
                          'Carrera o profesión',
                        ),
                        _buildTextField(experienciaController, 'Experiencia'),
                        _buildTextField(horarioController, 'Horario'),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Datos de estudiante',
                            style: Constants.textStyleAccentTitle,
                          ),
                        ),
                        _buildDropdownField(
                          carreraController,
                          'Carrera',
                          CarrerasUNAB.lista,
                        ),
                        _buildTextField(
                          semestreController,
                          'Semestre (número)',
                          keyboardType: TextInputType.number,
                        ),
                        _buildTextField(interesesController, 'Intereses'),
                        _buildTextField(
                          disponibilidadController,
                          'Disponibilidad',
                        ),
                      ],

                      const SizedBox(height: 32),

                      // === BOTONES ===
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('Guardar cambios'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Constants.colorPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _guardarCambios,
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.cancel),
                            label: const Text('Cancelar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              final confirmar = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Cancelar edición'),
                                  content: const Text(
                                    '¿Estás seguro de que deseas cancelar? Los cambios no guardados se perderán.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('No'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                      ),
                                      child: const Text('Sí, cancelar'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmar == true && mounted)
                                Navigator.pop(context, false);
                            },
                          ),
                        ],
                      ),
                    ],
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
        value: items.contains(controller.text) ? controller.text : null,
        decoration: InputDecoration(labelText: label, border: InputBorder.none),
        isExpanded: true,
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (value) => controller.text = value ?? '',
      ),
    );
  }
}
