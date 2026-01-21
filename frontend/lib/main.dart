import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Capturar errores de Flutter para diagnóstico
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    print("🔴 FLUTTER ERROR: ${details.exceptionAsString()}");
  };
  
  try {
    // Inicializar Firebase
    await Firebase.initializeApp();
    print("✅ Firebase inicializado correctamente");
    
    // Configurar handler para mensajes en background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    print("✅ Background message handler configurado");
    
    // Inicializar servicio de notificaciones (con try-catch interno)
    try {
      await PushNotificationService().init();
      print("✅ PushNotificationService inicializado");
    } catch (pushError) {
      // No bloquear la app si falla el servicio de push
      print("⚠️ Error en PushNotificationService (no crítico): $pushError");
    }
    
  } catch (e) {
    print("🔴 ERROR CRÍTICO EN INICIALIZACIÓN: $e");
    // Si falla Firebase, igual intentamos correr la app
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chek',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F111A), // Fondo base muy oscuro
        primaryColor: const Color(0xFF4D6FFF),
        useMaterial3: true,
        // Definimos la fuente por defecto si quisieras cambiarla luego
        fontFamily: 'Roboto', 
      ),
      home: SplashScreen(),
    );
  }
}