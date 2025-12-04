import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/src/BackEnd/custom/configuration.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/pages/login/login_page.dart';
import 'package:my_app/src/pages/splash_page.dart';
import 'package:my_app/src/pages/onboarding_page.dart';
import 'package:my_app/src/BackEnd/providers/global_provider.dart';
import 'package:my_app/src/pages/Reuniones/meeting_completion_handler.dart';
import 'package:my_app/src/BackEnd/custom/auth_guard.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest.dart' as tzdata;

// ✨ NUEVAS IMPORTACIONES
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:get_it/get_it.dart';
import 'dart:io';

// ✨ SERVICIOS DEL CHAT
import 'package:my_app/src/BackEnd/services/file_service.dart';
import 'package:my_app/src/BackEnd/services/download_service.dart';
import 'package:my_app/src/BackEnd/services/viewer_service.dart';
import 'package:my_app/src/BackEnd/services/notifications_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  
  // Configurar orientación
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // ✨ INICIALIZAR FLUTTER_DOWNLOADER
  try {
    await FlutterDownloader.initialize(debug: true);
    debugPrint('[MAIN] ✅ FlutterDownloader inicializado');
  } catch (e) {
    debugPrint('[MAIN] ⚠️ Error con FlutterDownloader: $e');
  }
  
  // ✨ CONFIGURAR SERVICIOS
  setupServiceLocator();
  
  // Inicializar Supabase
  await Supabase.initialize(
    url: Configuration.mSupabaseUrl,
    anonKey: Configuration.mSupabaseKey,
  );
  
  // Configurar renovación automática de tokens
  // Solo mostrar notificaciones no leídas al iniciar sesión o refrescar token
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final event = data.event;
    debugPrint('[MAIN] Auth state changed: $event');

    if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
      await _mostrarNoLeidasDelUsuario();
    }
    
  });

  // Callback para descargas (Android)
  if (Platform.isAndroid) {
    try {
      FlutterDownloader.registerCallback(downloadCallback);
    } catch (e) {
      debugPrint('[MAIN] ⚠️ Error registrando callback: $e');
    }
  }

  // Solicitar permiso de notificación en Android
  if (Platform.isAndroid) {
    final status = await Permission.notification.request();
    debugPrint('[MAIN] Permiso de notificación: $status');
  }

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@drawable/icono_color');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  await NotificationsService.init();
  _lifecycleObserver.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GlobalProvider()),
      ],
      child: const MyApp(),
    )
  );
}

// ✨ CONFIGURACIÓN DE SERVICIOS
void setupServiceLocator() {
  final getIt = GetIt.instance;
  
  try {
    // Registrar servicios para el chat
    getIt.registerLazySingleton<FileService>(() => FileService());
    getIt.registerLazySingleton<DownloadService>(() => DownloadService());
    getIt.registerLazySingleton<ViewerService>(() => ViewerService());
    
    debugPrint('[MAIN] ✅ Servicios de chat registrados');
  } catch (e) {
    debugPrint('[MAIN] ⚠️ Error registrando servicios: $e');
  }
}

// ✨ CALLBACK PARA DESCARGAS
@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  debugPrint('[DOWNLOADER] ID: $id, Status: $status, Progress: $progress%');
}

Future<void> _mostrarNoLeidasDelUsuario() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return;

  try {
    final rows = await client
        .from('notificaciones')
        .select('id,titulo,mensaje,leida')
        .eq('user_id', user.id)
        .eq('leida', false)
        .order('fecha', ascending: true);

    for (final n in rows as List<dynamic>) {
      final titulo = (n['titulo'] ?? 'Notificación').toString();
      final cuerpo = (n['mensaje'] ?? '').toString();

      await NotificationsService.showNotification(title: titulo, body: cuerpo);
      await client.from('notificaciones').update({'leida': true}).eq('id', n['id']);
    }

    if (rows.isNotEmpty) {
      debugPrint('[MAIN] Mostradas ${rows.length} notificaciones pendientes');
    }
  } catch (e) {
    debugPrint('[MAIN] Error cargando no leídas: $e');
  }
}

class _AppLifecycleObserver with WidgetsBindingObserver {
  void init() {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Elimina la llamada a _mostrarNoLeidasDelUsuario aquí para evitar duplicados
    // Solo se debe mostrar al iniciar sesión
  }
}

final _lifecycleObserver = _AppLifecycleObserver();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Enseñame',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Constants.colorBackground),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Constants.colorPrimary,
          foregroundColor: Constants.colorBackground,
        ),
      ),
      
      initialRoute: '/login',
      routes: {
        '/': (context) => SplashPage(),
        '/login': (context) => LoginPage(),
      },
      
      locale: const Locale('es'),
      supportedLocales: const [
        Locale('es'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2),
          ),
          child: child!,
        );
      },
    );
  }
}

class NotificationsService {
  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      debugPrint('[NOTIFICATIONS] Timezone inicializado (plugin se inicializa en main.dart)');
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Error iniciando timezone: $e');
    }
  }

  static Future<void> showNotification({required String title, required String body}) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'main_channel',
        'Notificaciones',
        channelDescription: 'Alertas de Enseñame',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@drawable/icono_color',
        playSound: true,
      );
      const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

      await flutterLocalNotificationsPlugin.show(
        0,
        title,
        body,
        platformChannelSpecifics,
        payload: 'data',
      );
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Error mostrando notificación: $e');
    }
  }
}




