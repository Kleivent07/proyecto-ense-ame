import 'package:flutter/material.dart';

class RefrescarHelper {
  static Future<void> actualizarDatos({
    required BuildContext context,
    required VoidCallback onUpdate,
  }) async {
    // Aquí puedes poner lógica de recarga global, como llamar a una API, etc.
    // Ejemplo: await MiApi.obtenerDatos();

    // Luego actualizas el estado del widget
    onUpdate();
  }
}
