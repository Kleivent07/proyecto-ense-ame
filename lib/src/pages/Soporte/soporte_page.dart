import 'package:flutter/material.dart';
import '../../BackEnd/util/constants.dart';

class SoportePage extends StatefulWidget {
  const SoportePage({Key? key}) : super(key: key);

  @override
  State<SoportePage> createState() => _SoportePageState();
}

class _SoportePageState extends State<SoportePage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _mostrarContacto(String tipo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Constants.colorBackground,
              Constants.colorBackground.withOpacity(0.95),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Constants.colorFont.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                'Contactar Soporte',
                style: Constants.textStyleFontTitle.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 16),
              
              _buildContactOption(
                Icons.email,
                'Email',
                'soporte@tuapp.com',
                'Respuesta en 24-48 horas',
                Colors.blue,
              ),
              const SizedBox(height: 12),
              
              _buildContactOption(
                Icons.phone,
                'Teléfono',
                '+1 (555) 123-4567',
                'Lun-Vie 9:00 AM - 6:00 PM',
                Colors.green,
              ),
              const SizedBox(height: 12),
              
              _buildContactOption(
                Icons.chat,
                'Chat en Vivo',
                'Disponible ahora',
                'Respuesta inmediata',
                Colors.orange,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactOption(IconData icon, String titulo, String info, String horario, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: Constants.textStyleFontBold.copyWith(fontSize: 16),
                ),
                Text(
                  info,
                  style: Constants.textStyleFont.copyWith(
                    color: Constants.colorFont.withOpacity(0.8),
                  ),
                ),
                Text(
                  horario,
                  style: Constants.textStyleFont.copyWith(
                    fontSize: 12,
                    color: Constants.colorFont.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.colorPrimaryDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(0, 243, 8, 8),
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Constants.colorBackground.withOpacity(0.2),
                Constants.colorBackground.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Constants.colorBackground.withOpacity(0.3),
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
          'Centro de Soporte',
          style: Constants.textStyleBLANCOTitle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
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
                Constants.colorPrimaryDark,
                const Color.fromARGB(255, 204, 25, 25),
              ],
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
              Constants.colorPrimaryDark,
              Constants.colorPrimary,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // FAQ Section
                _buildSectionCard(
                  'Preguntas Frecuentes',
                  Icons.quiz_rounded,
                  [
                    {
                      'pregunta': '¿Cómo envío documentos en el chat?',
                      'respuesta': 'Toca el ícono de clip 📎 en el chat, selecciona tus archivos y envíalos. Los documentos aparecerán automáticamente en la sección de Documentos.',
                    },
                    {
                      'pregunta': '¿Cómo programo una reunión?',
                      'respuesta': 'Ve a la sección Reuniones, toca "Crear Reunión", completa los detalles y envía la invitación.',
                    },
                    {
                      'pregunta': '¿Cómo cambio mi información de perfil?',
                      'respuesta': 'En tu perfil, toca el ícono de edición ✏️ en la parte superior derecha para modificar tus datos.',
                    },
                    {
                      'pregunta': '¿Por qué no recibo notificaciones?',
                      'respuesta': 'Verifica que las notificaciones estén habilitadas en la configuración de tu dispositivo para esta aplicación.',
                    },
                  ],
                  Colors.blue,
                ),
                
                const SizedBox(height: 16),
                
                // Contact Support
                _buildContactCard(),
                
                const SizedBox(height: 16),
                
                // Tutorials
                _buildSectionCard(
                  'Guías de Uso',
                  Icons.play_lesson_rounded,
                  [
                    {
                      'pregunta': 'Tutorial: Usar el chat',
                      'respuesta': 'Aprende a enviar mensajes, compartir archivos y usar todas las funciones del chat.',
                    },
                    {
                      'pregunta': 'Tutorial: Gestionar documentos',
                      'respuesta': 'Descubre cómo organizar y acceder a todos tus documentos compartidos.',
                    },
                    {
                      'pregunta': 'Tutorial: Crear reuniones',
                      'respuesta': 'Guía paso a paso para programar y gestionar reuniones virtuales.',
                    },
                  ],
                  Colors.green,
                ),
                
                const SizedBox(height: 16),
                
                // Tips & Tricks
                _buildSectionCard(
                  'Consejos y Trucos',
                  Icons.lightbulb_rounded,
                  [
                    {
                      'pregunta': '💡 Acceso rápido',
                      'respuesta': 'Mantén presionado cualquier conversación para acceder a opciones rápidas.',
                    },
                    {
                      'pregunta': '💡 Buscar archivos',
                      'respuesta': 'Usa el buscador en Documentos para encontrar archivos específicos rápidamente.',
                    },
                    {
                      'pregunta': '💡 Notificaciones',
                      'respuesta': 'Personaliza tus notificaciones desde el perfil para recibir solo lo importante.',
                    },
                  ],
                  Colors.amber,
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(String titulo, IconData icono, List<Map<String, String>> items, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Constants.colorBackground,
            Constants.colorBackground.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.2),
                        color.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icono, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    titulo,
                    style: Constants.textStyleFontBold.copyWith(
                      fontSize: 18,
                      color: Constants.colorFont,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Items
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              
              return Container(
                margin: EdgeInsets.only(bottom: index < items.length - 1 ? 16 : 0),
                child: ExpansionTile(
                  title: Text(
                    item['pregunta']!,
                    style: Constants.textStyleFontBold.copyWith(
                      fontSize: 14,
                      color: Constants.colorFont,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                      child: Text(
                        item['respuesta']!,
                        style: Constants.textStyleFont.copyWith(
                          color: Constants.colorFont.withOpacity(0.8),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color.fromARGB(255, 255, 38, 38),
            const Color.fromARGB(255, 131, 4, 4),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.support_agent, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '¿Necesitas ayuda personalizada?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Nuestro equipo de soporte está listo para ayudarte con cualquier problema o pregunta que tengas.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _mostrarContacto('general'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color.fromARGB(255, 255, 61, 61),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Contactar Soporte',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}