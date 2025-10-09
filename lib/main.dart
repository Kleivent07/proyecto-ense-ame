import 'package:flutter/material.dart';
import 'package:my_app/src/custom/configuration.dart';
import 'package:my_app/src/custom/constants.dart';
import 'package:my_app/src/pages/splash_page.dart';
import 'package:my_app/src/providers/global_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: Configuration.mSupabaseUrl,
    anonKey: Configuration.mSupabaseKey,
  );
  
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
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('es', 'ES'),
      ],
    );
  }
}

