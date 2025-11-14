import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6E00)),
        useMaterial3: true,
        fontFamily: 'Fira Sans Condensed',
      ),
      home: const SplashScreen(),
    );
  }
}