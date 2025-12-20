import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Q-AIPE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F111A), // Fondo base muy oscuro
        primaryColor: const Color(0xFF4D6FFF),
        useMaterial3: true,
        // Definimos la fuente por defecto si quisieras cambiarla luego
        fontFamily: 'Roboto', 
      ),
      home: const HomeScreen(),
    );
  }
}