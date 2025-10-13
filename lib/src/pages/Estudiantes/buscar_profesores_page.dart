import 'package:flutter/material.dart';
import 'package:my_app/src/util/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BuscarProfesoresPage extends StatefulWidget {
  const BuscarProfesoresPage({super.key});

  @override
  State<BuscarProfesoresPage> createState() => _BuscarProfesoresPageState();
}

class _BuscarProfesoresPageState extends State<BuscarProfesoresPage> {
  String busqueda = '';
  List<Map<String, dynamic>> profesores = [];
  List<Map<String, dynamic>> profesoresFiltrados = [];
  bool cargando = true;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _cargarProfesores();
  }

  Future<void> _cargarProfesores() async {
    setState(() => cargando = true);
    try {
      // Traemos todos los profesores y usuarios relacionados
      final dataProfesoresRaw = await supabase
          .from('usuarios')
          .select('id, nombre, apellido, imagen_url, clase, profesores(id, especialidad)')
          .ilike('clase', 'tutor');

      final dataProfesores = List<Map<String, dynamic>>.from(dataProfesoresRaw as List);

      profesores = dataProfesores.map((prof) {
        final profesorData = (prof['profesores'] as List).isNotEmpty
            ? prof['profesores'][0]
            : {'especialidad': 'Sin definir'};

        return {
          'id': prof['id'],
          'especialidad': profesorData['especialidad'] ?? '',
          'usuario': prof,
        };
      }).toList();

      print('Profesores combinados: $profesores');
      _filtrarProfesores();
    } catch (e) {
      print('Error cargando profesores: $e');
      profesores = [];
      _filtrarProfesores();
    }
    setState(() => cargando = false);
  }

  void _filtrarProfesores() {
    if (busqueda.isEmpty) {
      profesoresFiltrados = List.from(profesores);
    } else {
      final b = busqueda.toLowerCase();
      profesoresFiltrados = profesores.where((prof) {
        final usuario = prof['usuario'] ?? {};
        final nombre = (usuario['nombre'] ?? '').toString().toLowerCase();
        final apellido = (usuario['apellido'] ?? '').toString().toLowerCase();
        final especialidad = (prof['especialidad'] ?? '').toString().toLowerCase();
        return nombre.contains(b) || apellido.contains(b) || especialidad.contains(b);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          onChanged: (val) {
            setState(() {
              busqueda = val;
              _filtrarProfesores();
            });
          },
          decoration: InputDecoration(
            hintText: 'Buscar tutores...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          ),
        ),
        backgroundColor: Constants.colorPrimary,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: profesoresFiltrados.length,
              itemBuilder: (context, index) {
                final prof = profesoresFiltrados[index];
                final usuario = prof['usuario'] ?? {};
                final nombre = usuario['nombre'] ?? '';
                final apellido = usuario['apellido'] ?? '';
                final especialidad = prof['especialidad'] ?? '';
                final imagenUrl = usuario['imagen_url'];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: imagenUrl != null
                          ? NetworkImage(imagenUrl)
                          : const AssetImage('assets/default_avatar.jpg') as ImageProvider,
                    ),
                    title: Text('$nombre $apellido'),
                    subtitle: Text(especialidad),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // Navegar al perfil del tutor
                    },
                  ),
                );
              },
            ),
    );
  }
}
