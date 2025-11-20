import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/src/BackEnd/custom/configuration.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/pages/splash_page.dart';
import 'package:my_app/src/BackEnd/providers/global_provider.dart';
import 'package:my_app/src/pages/Reuniones/meeting_completion_handler.dart';
import 'package:my_app/src/BackEnd/custom/auth_guard.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ✨ NUEVAS IMPORTACIONES
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:get_it/get_it.dart';
import 'dart:io';

// ✨ SERVICIOS DEL CHAT
import 'package:my_app/src/BackEnd/services/file_service.dart';
import 'package:my_app/src/BackEnd/services/download_service.dart';
import 'package:my_app/src/BackEnd/services/viewer_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    debugPrint('[MAIN] Auth state changed: ${data.event}');
    if (data.event == AuthChangeEvent.tokenRefreshed) {
      debugPrint('[MAIN] Token refreshed automatically');
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
      
      home: AuthGuard(
        pageName: 'App Principal',
        shouldCheck: false,
        child: MeetingCompletionHandler(
          child: SplashPage(),
        ),
      ),
      
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


