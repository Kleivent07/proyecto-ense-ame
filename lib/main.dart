import 'package:flutter/material.dart';
import 'package:my_app/src/BackEnd/custom/configuration.dart';
import 'package:my_app/src/BackEnd/custom/notifications_service.dart';
import 'package:my_app/src/BackEnd/util/constants.dart';
import 'package:my_app/src/pages/splash_page.dart';
import 'package:my_app/src/BackEnd/providers/global_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Configuration.mSupabaseUrl,
    anonKey: Configuration.mSupabaseKey,
  );
  
  await NotificationsService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GlobalProvider()),
      ],
      child: const MyApp(),
    )
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Constants.colorBackground),
      ),
      home: const SplashPage(),
      locale: const Locale('es'),
      supportedLocales: const [
        Locale('es'),
        /* otros si hace falta */
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}


