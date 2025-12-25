// Ubicación: lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import '../services/session_service.dart'; // Importamos el archivo 1
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget { // <--- ESTA ES LA CLASE QUE BUSCA MAIN
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  void _checkSession() async {
    // 1. Espera estética
    await Future.delayed(const Duration(seconds: 2));

    // 2. Consulta al servicio (Archivo 1)
    final session = SessionService();
    final userId = await session.getUserId();

    if (!mounted) return;

    // 3. Redirige
    if (userId != null && userId.isNotEmpty) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => const HomeScreen())
      );
    } else {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => const LoginScreen())
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.map_outlined, size: 80, color: Colors.blueAccent),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.blueAccent),
            SizedBox(height: 20),
            Text("Cargando el barrio...", style: TextStyle(color: Colors.white54))
          ],
        ),
      ),
    );
  }
}