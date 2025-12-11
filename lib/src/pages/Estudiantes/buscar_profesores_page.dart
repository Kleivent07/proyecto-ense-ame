import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/custom/no_teclado.dart';
import 'package:my_app/src/pages/Estudiantes/perfil_tutor_page.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BuscarProfesoresPage extends StatefulWidget {
  const BuscarProfesoresPage({super.key});

  @override
  State<BuscarProfesoresPage> createState() => _BuscarProfesoresPageState();
}

class _BuscarProfesoresPageState extends State<BuscarProfesoresPage> 
    with TickerProviderStateMixin {
  String busqueda = '';
  List<Map<String, dynamic>> profesores = [];
  List<Map<String, dynamic>> profesoresFiltrados = [];
  bool cargando = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _cargarProfesores();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarProfesores() async {
    setState(() => cargando = true);
    try {
      // Traemos todos los profesores con su usuario
      final List<Map<String, dynamic>> dataProfesoresRaw = await supabase
          .from('profesores')
          .select('id, especialidad, horario, usuarios(*)');

      // Mapear la lista para usarla en la UI
      profesores = dataProfesoresRaw.map((prof) {
        return {
          'idProfesor': prof['id'],
          'especialidad': prof['especialidad'] ?? 'Sin definir',
          'horario': prof['horario'] ?? 'Por definir',
          'usuario': prof['usuarios'] ?? {},
        };
      }).toList();

      _filtrarProfesores();
      _animationController.forward();
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
    return cerrarTecladoAlTocar(
      child: Scaffold(
        backgroundColor: Constants.colorPrimaryDark,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Constants.colorBackground.withOpacity(0.25),
                  Constants.colorBackground.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Constants.colorBackground.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: Constants.colorBackground,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          title: Text(
            'Buscar Tutores',
            style: Constants.textStyleBLANCOTitle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          toolbarHeight: 60,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Constants.colorPrimary,
                  Constants.colorAccent,
                  Constants.colorPrimaryDark.withOpacity(0.8),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),

        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Constants.colorPrimary,
                Constants.colorAccent,
                Constants.colorPrimaryDark,
                Constants.colorPrimaryDark,
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          width: double.infinity,
          height: double.infinity,
          child: SafeArea(
            child: Column(
              children: [
                // Barra de búsqueda elegante
                _buildSearchBar(),
                
                // Lista de profesores
                Expanded(
                  child: cargando
                      ? _buildLoadingState()
                      : profesoresFiltrados.isEmpty
                          ? _buildEmptyState()
                          : _buildProfesoresList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Constants.colorBackground,
            Constants.colorBackground.withOpacity(0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Constants.colorPrimaryDark.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            busqueda = val;
            _filtrarProfesores();
          });
        },
        style: Constants.textStyleFont.copyWith(fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o especialidad...',
          hintStyle: Constants.textStyleFontSmall.copyWith(
            color: Constants.colorFont.withOpacity(0.6),
            fontSize: 14,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.search_rounded,
              color: Constants.colorAccent,
              size: 22,
            ),
          ),
          suffixIcon: busqueda.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: Constants.colorFont.withOpacity(0.6),
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      busqueda = '';
                      _filtrarProfesores();
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Constants.colorBackground),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando tutores...',
            style: Constants.textStyleBLANCO.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 80,
            color: Constants.colorBackground.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            busqueda.isEmpty ? 'No hay tutores disponibles' : 'No se encontraron tutores',
            style: Constants.textStyleBLANCO.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            busqueda.isEmpty 
                ? 'Intenta recargar la página'
                : 'Intenta con otros términos de búsqueda',
            style: Constants.textStyleBLANCO.copyWith(
              fontSize: 14,
              color: Constants.colorBackground.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfesoresList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: profesoresFiltrados.length,
        itemBuilder: (context, index) {
          final prof = profesoresFiltrados[index];
          return _buildProfesorCard(prof, index);
        },
      ),
    );
  }

  Widget _buildProfesorCard(Map<String, dynamic> prof, int index) {
    final usuario = prof['usuario'] ?? {};
    final nombre = usuario['nombre'] ?? '';
    final apellido = usuario['apellido'] ?? '';
    final especialidad = prof['especialidad'] ?? '';
    final imagenUrl = usuario['imagen_url'];

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Constants.colorBackground,
              Constants.colorBackground.withOpacity(0.98),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Constants.colorPrimaryDark.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PerfilTutorPage(tutorId: prof['idProfesor']),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Avatar elegante
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Constants.colorAccent.withOpacity(0.1),
                          Constants.colorPrimary.withOpacity(0.05),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Constants.colorAccent.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 60,
                        height: 60,
                        child: imagenUrl != null
                            ? Image.network(
                                imagenUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildDefaultAvatar();
                                },
                              )
                            : _buildDefaultAvatar(),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Información del tutor
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$nombre $apellido',
                          style: Constants.textStyleFontBold.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Constants.colorPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Constants.colorAccent.withOpacity(0.1),
                                Constants.colorPrimary.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            especialidad,
                            style: Constants.textStyleFontSmall.copyWith(
                              color: Constants.colorAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Flecha indicadora
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Constants.colorAccent.withOpacity(0.1),
                          Constants.colorPrimary.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Constants.colorAccent,
                      size: 20,
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

  Widget _buildDefaultAvatar() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Constants.colorAccent.withOpacity(0.8),
            Constants.colorPrimary.withOpacity(0.6),
          ],
        ),
      ),
      child: Icon(
        Icons.person_rounded,
        color: Constants.colorBackground,
        size: 30,
      ),
    );
  }
}

