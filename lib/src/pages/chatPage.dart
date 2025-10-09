import 'package:flutter/material.dart';
import 'package:my_app/src/custom/CustomBottomNavBar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  int _selectedIndex = 3; // NavBar
  String? tipoUsuario; // 'Estudiante' o 'Tutor'
  String? nombreActual; // Nombre del usuario logeado
  List<Map<String, String>> chats = [];

  @override
  void initState() {
    super.initState();
    _cargarUsuarioYChats();
  }

  Future<void> _cargarUsuarioYChats() async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return;

  // Obtener perfil desde Supabase
  final perfil = await supabase
      .from('perfiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  if (perfil == null) return;

  tipoUsuario = perfil['clase'];       // 'Estudiante' o 'Tutor'
  nombreActual = perfil['nombre'];     // Nombre del usuario logeado

  // Simulación de chats según tipo
  if (tipoUsuario == 'Estudiante') {
    if (nombreActual == 'francisca') {
      chats = [
        {
          'nombre': 'Profesor Matías',
          'ultimoMensaje': 'Hola Francisca, ¿lista para la clase?',
          'avatar': 'https://i.pravatar.cc/150?img=10',
        }
      ];
    } else if (nombreActual == 'matias') {
      chats = [
        {
          'nombre': 'Profesora Maria',
          'ultimoMensaje': 'Hola Francisca, ¿cómo va todo?',
          'avatar': 'https://i.pravatar.cc/150?img=11',
        }
      ];
    } else {
      chats = [];
    }
  } else if (tipoUsuario == 'Tutor (profesor)') {
    chats = [
      {
        'nombre': 'Fernanda',
        'ultimoMensaje': 'Hola profe, necesito ayuda con la tarea.',
        'avatar': 'https://i.pravatar.cc/150?img=5',
      },
      {
        'nombre': 'Matías',
        'ultimoMensaje': 'Profe, ¿puede explicarme el tema?',
        'avatar': 'https://i.pravatar.cc/150?img=6',
      },
    ];
  }

  setState(() {});
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: chats.isEmpty
          ? Center(
              child: Text(
                '¡Ve a buscar!',
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
              ),
            )
          : ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(chat['avatar']!),
                        radius: 28,
                      ),
                      title: Text(
                        chat['nombre']!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(chat['ultimoMensaje']!),
                      onTap: () {
                        // Aquí abrirías el ChatPage individual
                        // Por ejemplo: navigateChat(context, tipoUsuario, chat['nombre']);
                      },
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: CustomBottomNavBarES(selectedIndex: _selectedIndex),
    );
  }
}
