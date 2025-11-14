import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class NotificationsService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Para evitar notificaciones duplicadas cuando el stream devuelve
  // el snapshot inicial, guardamos los ids ya vistos en memoria.
  static final Set<int> _seenMessageIds = <int>{};
  static final Set<int> _seenMeetingIds = <int>{};

  // Mantener las subscripciones si queremos cancelarlas en el futuro
  static final List<StreamSubscription> _subscriptions = [];

  /// Inicializa el plugin y las subscripciones
  static Future<void> init() async {
    if (_initialized) return;
    // Inicialización de flutter_local_notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    final settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(settings, onDidReceiveNotificationResponse: (response) {
      // Opcional: manejar click sobre notificación
      debugPrint('Notification clicked: ${response.payload}');
    });

    // Inicializar zona horaria para programación precisa
    tzdata.initializeTimeZones();
    try {
      // Usar la información que aporta la librería `timezone`.
      // tz.local.name devuelve el nombre de la zona local conocida por la librería.
      final String localName = tz.local.name;
      try {
        final loc = tz.getLocation(localName);
        tz.setLocalLocation(loc);
      } catch (lookupError) {
        debugPrint('Timezone "$localName" no encontrada en la DB tz: $lookupError — usando UTC');
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    } catch (e) {
      debugPrint('Error inicializando zonas horarias con timezone: $e — usando UTC');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // Inicia listeners de Supabase (mensajes y reuniones)
    _initSupabaseListeners();

    _initialized = true;
  }

  /// Muestra notificación instantánea
  static Future<void> showNotification(int id, String title, String body, {String? payload}) async {
    const android = AndroidNotificationDetails(
      'default_channel',
      'Notificaciones',
      channelDescription: 'Notificaciones del app',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    final details = NotificationDetails(android: android, iOS: ios);
    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// Programa una notificación para una fecha/horario (DateTime en UTC o local).
  /// Nota: usamos zonedSchedule si está disponible; si falla, usamos schedule como fallback.
  static Future<void> scheduleNotification(int id, String title, String body, DateTime scheduledDateUtc, {String? payload}) async {
    // Convertimos a hora local del dispositivo y usamos schedule si zonedSchedule no acepta esos parámetros
    final scheduledLocal = scheduledDateUtc.toLocal();
    const android = AndroidNotificationDetails(
      'scheduled_channel',
      'Recordatorios',
      channelDescription: 'Recordatorios programados',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    final details = NotificationDetails(android: android, iOS: ios);

    try {
      // Intentamos usar zonedSchedule con el parámetro requerido androidScheduleMode
      final tzDate = tz.TZDateTime.from(scheduledDateUtc.toUtc(), tz.local);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint('zonedSchedule no disponible con estos parámetros: $e — usando schedule (local DateTime) como fallback.');
      // Fallback: usar schedule con DateTime local (menos preciso en edge cases, pero más compatible)
      try {
        final tzFallbackDate = tz.TZDateTime.from(scheduledLocal, tz.local);
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tzFallbackDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );
      } catch (e2) {
        debugPrint('schedule fallback falló: $e2');
      }
    }
  }

  /// Cancela una notificación programada por id
  static Future<void> cancelNotification(int id) => _plugin.cancel(id);

  /// Subscribirse a eventos de Supabase para notificaciones en tiempo real
  static void _initSupabaseListeners() {
    final sb = Supabase.instance.client;

    try {
      // Mensajes: usamos .stream([...]).listen(...) y evitamos duplicados con _seenMessageIds
      final messagesStream = sb
          .from('messages')
          // la lista de columnas/keys para identificar rows; 'id' es lo habitual
          .stream(primaryKey: ['id']);

      final subMessages = messagesStream.listen((List<Map<String, dynamic>> payload) {
        try {
          for (final record in payload) {
            final rawId = record['id'];
            final int idHash = rawId != null ? rawId.hashCode : DateTime.now().millisecondsSinceEpoch;
            if (_seenMessageIds.contains(idHash)) {
              // ya lo vimos antes, ignorar
              continue;
            }
            _seenMessageIds.add(idHash);

            final sender = record['sender_name'] ?? record['sender_id'] ?? 'Nuevo mensaje';
            final content = record['content'] ?? record['message'] ?? 'Tienes un nuevo mensaje';
            showNotification(idHash, 'Mensaje de $sender', content, payload: record['room_id']?.toString());
          }
        } catch (e, st) {
          debugPrint('Error procesando stream de mensajes: $e\n$st');
        }
      }, onError: (err) {
        debugPrint('Error en stream de mensajes: $err');
      });

      _subscriptions.add(subMessages);

      // Reuniones: similar, notificar nuevas reuniones y programaciones
      final meetingsStream = sb.from('meetings').stream(primaryKey: ['id']);
      final subMeetings = meetingsStream.listen((List<Map<String, dynamic>> payload) {
        try {
          for (final record in payload) {
            final rawId = record['id'] ?? record['room_id'];
            final int idHash = rawId != null ? rawId.hashCode : DateTime.now().millisecondsSinceEpoch;
            if (_seenMeetingIds.contains(idHash)) {
              continue;
            }
            _seenMeetingIds.add(idHash);

            final subject = record['subject'] ?? 'Reunión';
            final scheduledRaw = record['scheduled_at'] as String?;
            if (scheduledRaw != null) {
              try {
                final scheduledUtc = DateTime.parse(scheduledRaw).toUtc();
                final localTime = DateFormat('dd/MM/yyyy – HH:mm').format(scheduledUtc.toLocal());
                showNotification(idHash, 'Reunión programada', '$subject • $localTime', payload: record['room_id']?.toString());
              } catch (e) {
                debugPrint('Error parseando scheduled_at: $e');
                showNotification(idHash, 'Reunión', subject, payload: record['room_id']?.toString());
              }
            } else {
              showNotification(idHash, 'Reunión creada', subject, payload: record['room_id']?.toString());
            }
          }
        } catch (e, st) {
          debugPrint('Error procesando stream de reuniones: $e\n$st');
        }
      }, onError: (err) {
        debugPrint('Error en stream de reuniones: $err');
      });

      _subscriptions.add(subMeetings);
    } catch (e, st) {
      debugPrint('Error suscribiendo listeners Supabase (stream): $e\n$st');
    }
  }

  /// Opcional: cancelar las subscripciones (si en algún momento lo necesitas)
  static Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    _seenMessageIds.clear();
    _seenMeetingIds.clear();
    _initialized = false;
  }
}