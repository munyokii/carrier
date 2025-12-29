import 'package:flutter/material.dart';
import 'screens/logo_splash.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );
  
  runApp(const CarrierApp());
}

class CarrierApp extends StatelessWidget {
  const CarrierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carrier App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6E00),
          primary: const Color(0xFFFF6E00)
        ),
        useMaterial3: true,
        fontFamily: 'Fira Sans Condensed',
      ),
      home: const LogoSplash(),
    );
  }
}