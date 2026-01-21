// Ubicación: lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = "Iniciando...";
  
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  void _checkSession() async {
    try {
      setState(() => _status = "Verificando sesión...");
      
      // 1. Espera breve
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 2. Obtener datos de sesión con timeout
      String? userId;
      String? role;
      
      try {
        final session = SessionService();
        userId = await session.getUserId().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            print("⏰ Timeout obteniendo userId");
            return null;
          },
        );
        
        if (userId != null) {
          role = await session.getUserRole().timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              print("⏰ Timeout obteniendo role");
              return null;
            },
          );
        }
      } catch (e) {
        print("⚠️ Error en SessionService: $e");
      }
      
      if (!mounted) return;
      
      setState(() => _status = "Redirigiendo...");
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 3. Navegar según sesión
      if (userId != null && userId.isNotEmpty) {
        print("✅ Usuario encontrado: $userId, rol: $role");
        if (role == "BODEGUERO") {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => const DashboardScreen())
          );
        } else {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => const HomeScreen())
          );
        }
      } else {
        print("ℹ️ Sin sesión, ir a Login");
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const LoginScreen())
        );
      }
      
    } catch (e, stack) {
      print("🔴 Error en splash: $e");
      print("Stack: $stack");
      
      if (mounted) {
        setState(() => _status = "Error: $e");
        await Future.delayed(const Duration(seconds: 2));
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const LoginScreen())
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.blueAccent),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}