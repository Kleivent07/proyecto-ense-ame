import 'package:flutter/services.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;


class NotificationsService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _client = Supabase.instance.client;

  // Inicializar plugin + timezone (llamar en main)
  static Future<void> init() async {
    try {
      const androidInit = AndroidInitializationSettings('@drawable/image');
      const iosInit = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );
      tzdata.initializeTimeZones();
      debugPrint('[NOTIFICATIONS] Inicializado plugin y timezone');
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Error iniciando notificaciones: $e');
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? userId,
    String? tipo,
    String? referenciaId,
  }) async {
    final uid = userId ?? _client.auth.currentUser?.id;
    final authUid = _client.auth.currentUser?.id;
    debugPrint('[NOTIFICATIONS] ---');
    debugPrint('[NOTIFICATIONS] Datos para insertar:');
    debugPrint('user_id: $uid');
    debugPrint('auth.uid: $authUid');
    debugPrint('tipo: $tipo');
    debugPrint('referencia_id: $referenciaId');
    debugPrint('titulo: $title');
    debugPrint('mensaje: $body');
    if (uid == null) {
      debugPrint('[NOTIFICATIONS] uid es null, no se envía');
      return;
    }

    final ok = await _shouldSendNotification(
      uid: uid,
      tipo: tipo,
      referenciaId: referenciaId,
    );
    if (!ok) {
      debugPrint('[NOTIFICATIONS] Deduplicada, no se envía');
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default_channel_id',
      'Notificaciones',
      channelDescription: 'Alertas de Enseñame',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/image',
      largeIcon: DrawableResourceAndroidBitmap('@drawable/image'),
      playSound: true,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );

    try {
      final response = await _client.from('notificaciones').upsert({
        'user_id': uid,
        'titulo': title,
        'mensaje': body,
        'fecha': DateTime.now().toIso8601String(),
        'leida': false,
        'tipo': tipo,
        'referencia_id': referenciaId,
      }, onConflict: 'user_id,tipo,referencia_id', ignoreDuplicates: true);
      debugPrint('[NOTIFICATIONS] Respuesta upsert: $response');
    } catch (e) {
      debugPrint('[NOTIFICATIONS] ERROR en upsert: $e');
    }
  }

  // Obtener notificaciones del usuario
  static Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    final notificaciones = await _client
      .from('notificaciones')
      .select()
      .eq('user_id', userId)
      .order('fecha', ascending: false);
    return List<Map<String, dynamic>>.from(notificaciones);
  }

  static Future<void> deleteNotification(dynamic id) async {
    await _client.from('notificaciones').delete().eq('id', id);
  }

  static Future<void> programarNotificacionReunion({
    required String titulo,
    required String mensaje,
    required DateTime fechaReunion,
    required BuildContext context,
    int? notificationId,
    String? userId,
    String? tipo,
    String? referenciaId,
  }) async {
    final uid = userId ?? _client.auth.currentUser?.id;
    if (uid == null) return;

    final scheduledNotificationDateTime = fechaReunion.subtract(const Duration(minutes: 10));

    // Dedup antes de cualquier acción
    final ok = await _shouldSendNotification(
      uid: uid,
      tipo: tipo ?? 'reunion',
      referenciaId: referenciaId,
      fecha: scheduledNotificationDateTime,
    );
    if (!ok) {
      debugPrint('[NOTIFICATIONS] Deduplicada (reunión), no se programa ni inserta');
      return;
    }

    if (scheduledNotificationDateTime.isBefore(DateTime.now())) {
      debugPrint('[NOTIFICATIONS] La fecha programada ya pasó, no se programa notificación.');
      await _client.from('notificaciones').upsert({
        'user_id': uid,
        'titulo': titulo,
        'mensaje': mensaje,
        'fecha': DateTime.now().toIso8601String(),
        'leida': false,
        'tipo': tipo ?? 'reunion',
        'referencia_id': referenciaId,
      }, onConflict: 'user_id,tipo,referencia_id', ignoreDuplicates: true);
      return;
    }

    try {
      debugPrint('[NOTIFICATIONS] Programando notificación para: $scheduledNotificationDateTime');
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'main_channel',
            'Notificaciones',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@drawable/image',
          );
      const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

      await _plugin.zonedSchedule(
        notificationId ?? scheduledNotificationDateTime.millisecondsSinceEpoch ~/ 1000,
        titulo,
        mensaje,
        tz.TZDateTime.from(scheduledNotificationDateTime, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      await _client.from('notificaciones').upsert({
        'user_id': uid,
        'titulo': titulo,
        'mensaje': mensaje,
        'fecha': scheduledNotificationDateTime.toIso8601String(),
        'leida': false,
        'tipo': tipo ?? 'reunion',
        'referencia_id': referenciaId,
      }, onConflict: 'user_id,tipo,referencia_id', ignoreDuplicates: true);
    } on PlatformException catch (ex) {
      debugPrint('[NOTIFICATIONS] PlatformException: ${ex.code} - guardando notificación en BD sin schedule');
      await _client.from('notificaciones').upsert({
        'user_id': uid,
        'titulo': titulo,
        'mensaje': mensaje,
        'fecha': scheduledNotificationDateTime.toIso8601String(),
        'leida': false,
        'tipo': tipo ?? 'reunion',
        'referencia_id': referenciaId,
      }, onConflict: 'user_id,tipo,referencia_id', ignoreDuplicates: true);
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Error programando notificación: $e');
    }
  }

  static Future<void> testNotificacionEnUnMinuto(BuildContext context) async {
    final now = DateTime.now();
    final scheduled = now.add(const Duration(minutes: 1));
    debugPrint('[NOTIFICATIONS] Test: programando notificación para: $scheduled');
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            'main_channel',
            'Notificaciones',
            importance: Importance.max,
            priority: Priority.high);
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _plugin.zonedSchedule(
      scheduled.millisecondsSinceEpoch ~/ 1000,
      'Notificación de prueba',
      'Esto es una notificación programada para 1 minuto después.',
      tz.TZDateTime.from(scheduled, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> marcarComoLeida(dynamic id) async {
    await _client.from('notificaciones').update({'leida': true}).eq('id', id);
  }

  static Future<bool> _shouldSendNotification({
    required String uid,
    String? tipo,
    String? referenciaId,
    DateTime? fecha,
  }) async {
    var query = _client.from('notificaciones').select('id').eq('user_id', uid);
    if (tipo != null) {
      query = query.eq('tipo', tipo);
    }
    if (referenciaId != null && referenciaId.isNotEmpty) {
      query = query.eq('referencia_id', referenciaId);
    } else {
      final since = (fecha ?? DateTime.now())
          .subtract(const Duration(hours: 1))
          .toIso8601String();
      query = query.gte('fecha', since);
    }
    final data = await query.limit(1);
    return !(data is List && data.isNotEmpty);
  }
}