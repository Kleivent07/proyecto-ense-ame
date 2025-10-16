import 'package:flutter/material.dart';

Widget cerrarTecladoAlTocar({required Widget child}) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
    child: child,
  );
}
