import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'screens/user/home_screen.dart';
import 'screens/common/login_screen.dart';
import 'screens/common/splash_screen.dart';
import 'screens/bodeguero/order_detail_screen.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
    
    // Inicializar OneSignal
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.Debug.setAlertLevel(OSLogLevel.none);
    
    OneSignal.initialize("77b0726b-7a9a-42a4-9fc2-e7fd11c963cd");
    
    // --- NUEVO: Manejo de Notificaciones OneSignal ---
    
    // 1. Click Listener (Navegación)
    OneSignal.Notifications.addClickListener((event) {
      print("🔔 OneSignal Notification Clicked: ${event.notification.jsonRepresentation()}");
      
      final rawData = event.notification.additionalData;
      if (rawData != null) {
        // IMPORTANTE: Convertir explícitamente a Map<String, dynamic>
        final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);
        if (data['type'] == 'NEW_ORDER') {
          final reservationId = data['reservation_id'];
          if (reservationId != null) {
            print("🧭 Guardando navegación pendiente: $reservationId");
            // Solo guardar el ID - DashboardScreen manejará la navegación
            // después de que la app termine de inicializarse
            PushNotificationService().setPendingNavigation(reservationId);
          }
        }
      }
    });

    // 2. Foreground Listener (Badge Update)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
       print("🔔 OneSignal Foreground Notification: ${event.notification.title}");
       print("   📦 Additional Data: ${event.notification.additionalData}");
       
       // Trigger badge update via PushNotificationService stream
       final rawData = event.notification.additionalData;
       if (rawData != null) {
         // IMPORTANTE: Convertir explícitamente a Map<String, dynamic>
         final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);
         print("   🏷️ Data type: ${data['type']}");
         if (data['type'] == 'NEW_ORDER') {
           print("   ✅ Emitiendo evento NEW_ORDER al Dashboard");
           // Esto notificará a DashboardScreen para que actualice los contadores
           PushNotificationService().handleOneSignalForegroundEvent(data);
         }
       } else {
         print("   ⚠️ additionalData es null, no se puede actualizar badge");
       }
       
       // Mostrar alerta visual
       event.notification.display();
    });

    OneSignal.User.pushSubscription.addObserver((state) {
       // ... existing observer code ...
       print("🔔 OneSignal Subscription State Changed!");
       print("   ID: ${state.current.id}");
    });

    // Solicitar permiso de notificaciones
    OneSignal.Notifications.requestPermission(true);
    
    print("✅ OneSignal inicializado con logging VERBOSE");
    
  } catch (e) {
    print("🔴 ERROR CRÍTICO EN INICIALIZACIÓN: $e");
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
      navigatorKey: navigatorKey, // Asignar GlobalKey
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      
      home: SplashScreen(),
    );
  }
}