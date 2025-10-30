// ignore_for_file: unreachable_switch_default
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// imports relativos (ajustados)
import '../pages/splash_page.dart';
import '../pages/login/registro_page.dart';
import '../pages/login/login_page.dart';
import '../pages/Estudiantes/home_es_page.dart';
import '../pages/Profesores/home_pro_page.dart';
import '../pages/perfil_page.dart';
import '../pages/editar_perfil_page.dart';
import '../pages/chat_list_page.dart';
import '../pages/chat_page.dart';



enum CustomPages {
  splashPage,
  homeEsPage,
  homeProPage,
  perfilPage,
  registroPage,
  loginPage,
  chatPage,
  chatListPage,
}

enum TypeAnimation {
  transition,
  fade,
  scale,
  rotation,
  slideUp,
  slideRight,
  slideLeft,
}
enum Preference {
  onboarding,
}

BuildContext? globalContext;

Route _goPage(Widget page, TypeAnimation anim, int duration) {
  return MaterialPageRoute(builder: (_) => page);
}

navigate(BuildContext context, CustomPages page, {bool finishCurrent = false, Map<String, dynamic>? args}) {
  Widget target;
  switch (page) {
    case CustomPages.splashPage:
      target = const SplashPage();
      break;
    case CustomPages.registroPage:
      target = const RegistroPage();
      break;
    case CustomPages.loginPage:
      target = const LoginPage();
      break;
    case CustomPages.homeProPage:
      target = const HomePROPage();
      break;
    case CustomPages.homeEsPage:
      target = const HomeESPage();
      break;
    case CustomPages.perfilPage:
      target = const PerfilPage();
      break;
    case CustomPages.chatListPage:
      target = const ChatListPage();
      break;
    case CustomPages.chatPage:
      final solicitudId = args?['solicitudId']?.toString() ?? '';
      // NO pasar solicitudId como roomId; roomId es opcional
      target = ChatPage(solicitudId: solicitudId);
      break;
    default:
      target = const SizedBox.shrink();
  }

  final route = _goPage(target, TypeAnimation.transition, 400);
  if (finishCurrent) {
    Navigator.pushReplacement(context, route);
  } else {
    Navigator.push(context, route);
  }
}
class DismissKeyboard extends StatelessWidget {
  final Widget child;
  const DismissKeyboard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: child,
    );
  }
}

/// Abre un chat. `chatType` permite soportar distintos formatos de chat en el futuro.
/// `extra` permite pasar cualquier dato adicional (por ejemplo: roomId, usuario, config).
void navigateToChat(BuildContext context, {required String solicitudId, String? chatType, Map<String, dynamic>? extra, bool replace = false}) {
  Widget page;

  // elegir página según tipo de chat (fácilmente ampliable)
  switch (chatType) {
    case 'grupo':
      // page = GroupChatPage(...); // ejemplo futuro
      page = ChatPage(solicitudId: solicitudId);
      break;
    case 'privado':
      // page = PrivateChatPage(...);
      page = ChatPage(solicitudId: solicitudId);
      break;
    case 'solicitud':
    default:
      page = ChatPage(solicitudId: solicitudId);
  }

  final route = _goPage(page, TypeAnimation.transition, 500);
  if (replace) {
    Navigator.pushReplacement(context, route);
  } else {
    Navigator.push(context, route);
  }
}

//para convertir un color hexadecimal a un color de flutter
extension HexColor on String {
  // String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
  //Prefixes a hash sign if [leadingHashSign] is set to 'true' (default is 'true').
  String toHex({bool leadingHashSign = true}) {
    String hex = replaceFirst('#', '');
    if (hex.length == 6) hex = 'ff$hex'; // Si no tiene alpha, se agrega 'ff'
    // Devuelve en formato #aarrggbb
    return '${leadingHashSign ? '#' : ''}$hex';
  }
}
setOnePreference(Preference mAuxKey, String value) async {
  String mKey = '';
  switch (mAuxKey) {
    case Preference.onboarding:
      mKey = 'onboarding';
      break;
    default:
  }

  SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setString(mKey, value);
}

getOnePreference(Preference mAuxKey) async {
  String mKey = '';
  switch (mAuxKey) {
    case Preference.onboarding:
      mKey = 'onboarding';
      break;
    default:
  }

  String result = "";
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool checkValue = prefs.containsKey(mKey);
  if (checkValue) {
    result = prefs.getString(mKey) ?? '';
  }

  return result;
}


