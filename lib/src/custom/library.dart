// ignore_for_file: unreachable_switch_default
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
//inicio
import 'package:my_app/src/pages/splash_page.dart';
//login/registro
import 'package:my_app/src/pages/login/registro_page.dart';
import 'package:my_app/src/pages/login/login_page.dart';

//home
import 'package:my_app/src/pages/home_es_page.dart';
import 'package:my_app/src/pages/home_pro_page.dart';

import 'package:my_app/src/pages/chatPage.dart';





enum CustomPages {
  splashPage,
  homeEsPage,
  homeProPage,
  perfilPage,
  registroPage,
  loginPage,
  chatPage,
}

enum TypeAnimation {
  transition,
}
enum Preference {
  onboarding,
}

BuildContext? globalContext;

navigate(BuildContext mContext, CustomPages mPage,{bool finishCurrent = false}) {
  if (finishCurrent) {
    Navigator.of(mContext).pop();
  }
  switch (mPage) {
    case CustomPages.splashPage:
      Navigator.pushAndRemoveUntil(mContext, _goPage(const SplashPage(), TypeAnimation.transition, 500), (Route<dynamic> route) => false);
      break;
    case CustomPages.registroPage:
      Navigator.pushAndRemoveUntil(mContext, _goPage(RegistroPage(), TypeAnimation.transition, 500), (Route<dynamic> route) => false);
      break;
    case CustomPages.loginPage:
      Navigator.pushAndRemoveUntil(mContext, _goPage(LoginPage(), TypeAnimation.transition, 500), (Route<dynamic> route) => false);
      break;
    case CustomPages.homeProPage:
      Navigator.push(mContext, _goPage(const HomePROPage(), TypeAnimation.transition, 500));
      break;
    case CustomPages.homeEsPage:
      Navigator.push(mContext, _goPage(const HomeESPage(), TypeAnimation.transition, 500));
      break;

    case CustomPages.chatPage:
      Navigator.push(mContext, _goPage(const ChatsPage(), TypeAnimation.transition, 500));
      break;  
    default:
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


Route _goPage(Widget page, TypeAnimation type, int milliseconds) {
  return PageRouteBuilder(
    pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => page,
    transitionDuration: Duration(milliseconds: milliseconds),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final mCurvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeInBack);

      switch (type) {
        case TypeAnimation.transition:
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(mCurvedAnimation),
            child: child,
          );
      }
    },
  );
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

