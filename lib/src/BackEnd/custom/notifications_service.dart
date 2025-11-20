import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationsService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Inicializar notificaciones locales
  static Future<void> init() async {
    if (_initialized) return;

    // Configuración de notificaciones
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);

    // Inicializar zonas horarias
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Bogota'));
    } catch (e) {
      debugPrint('Error inicializando zonas horarias: $e — usando UTC');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    _initialized = true;
    debugPrint('[NOTIFICATIONS] Servicio inicializado');
  }

  /// Mostrar notificación instantánea
  static Future<void> showNotification(int id, String title, String body, {String? payload}) async {
    if (!_initialized) await init();
    
    const android = AndroidNotificationDetails(
      'default_channel',
      'Notificaciones',
      channelDescription: 'Notificaciones de la app',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    
    try {
      await _plugin.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Error mostrando notificación: $e');
    }
  }

  /// Programar una notificación
  static Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate, {
    String? payload,
  }) async {
    if (!_initialized) await init();

    try {
      const android = AndroidNotificationDetails(
        'scheduled_channel',
        'Notificaciones Programadas',
        channelDescription: 'Notificaciones programadas',
        importance: Importance.max,
        priority: Priority.high,
      );
      const ios = DarwinNotificationDetails();
      const details = NotificationDetails(android: android, iOS: ios);

      final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);
      
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      
      debugPrint('[NOTIFICATIONS] Notificación programada para: $scheduledDate');
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Error programando notificación: $e');
    }
  }

  /// Cancelar una notificación
  static Future<void> cancelNotification(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Error cancelando notificación: $e');
    }
  }

  /// Cancelar todas las notificaciones
  static Future<void> cancelAllNotifications() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Error cancelando todas las notificaciones: $e');
    }
  }
}