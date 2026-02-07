import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

/// Handler para mensajes en background (debe ser top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📩 [BACKGROUND] Mensaje recibido: ${message.notification?.title}');
  // Las notificaciones se muestran automáticamente por el sistema
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // --- NUEVO: StreamController para notificar eventos de pedidos al Dashboard ---
  final StreamController<Map<String, dynamic>> _orderEventController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream que el Dashboard puede escuchar para actualizarse en tiempo real
  Stream<Map<String, dynamic>> get onOrderEvent => _orderEventController.stream;

  // NUEVO: Almacenar navegación pendiente cuando la app se abre desde notificación
  String? _pendingOrderId;
  String? get pendingOrderId => _pendingOrderId;

  /// Establecer navegación pendiente (llamado desde main.dart)
  void setPendingNavigation(String orderId) {
    _pendingOrderId = orderId;
    print('📌 Navegación pendiente guardada: $orderId');
  }

  /// Limpiar navegación pendiente después de procesarla
  void clearPendingNavigation() {
    _pendingOrderId = null;
  }

  /// Inicializar el servicio de notificaciones
  Future<void> init() async {
    // 1. Solicitar permisos
    await _requestPermission();

    // 2. Configurar notificaciones locales (para mostrar en foreground)
    await _initLocalNotifications();

    // 3. Configurar handlers de mensajes
    _setupMessageHandlers();

    // 4. Obtener token FCM
    await _getToken();
  }

  /// Solicitar permisos de notificación
  Future<void> _requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('🔔 Permiso de notificaciones: ${settings.authorizationStatus}');
  }

  /// Inicializar notificaciones locales
  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    // NUEVO: Configurar handler para cuando el usuario toca la notificación local
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('📲 Usuario tocó notificación local: ${response.payload}');
        // El payload contiene el reservation_id
        if (response.payload != null && response.payload!.isNotEmpty) {
          _handleNotificationPayload(response.payload!);
        }
      },
    );

    // Crear canal de alta importancia
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'Notificaciones Importantes',
      description: 'Canal para alertas de pedidos en tiempo real',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Manejar el payload de una notificación local
  void _handleNotificationPayload(String payload) {
    print('🧭 Navegando desde notificación local: $payload');
    _orderEventController.add({
      'type': 'NAVIGATE_TO_ORDER',
      'reservation_id': payload,
    });
  }

  /// Configurar handlers para mensajes entrantes
  void _setupMessageHandlers() {
    // Mensajes cuando la app está en PRIMER PLANO
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 [FOREGROUND] Mensaje recibido: ${message.notification?.title}');
      _showLocalNotification(message);

      // Emitir evento para que el Dashboard se actualice (pero NO navegar)
      final dataType = message.data['type'];
      if (dataType == 'NEW_ORDER') {
        print('🔔 Emitiendo evento NEW_ORDER al Dashboard');
        _orderEventController.add({
          'type': 'NEW_ORDER',
          'reservation_id': message.data['reservation_id'],
          'total': message.data['total'],
        });
      }
    });

    // Cuando el usuario toca la notificación (app en background/foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print(
        '📲 Usuario abrió la app desde notificación (background): ${message.data}',
      );
      _handleNotificationTap(message);
    });

    // NUEVO: Verificar si la app se abrió desde notificación estando completamente cerrada
    _checkInitialMessage();
  }

  /// Verificar si la app se abrió desde notificación estando CERRADA
  Future<void> _checkInitialMessage() async {
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        print(
          '📲 App se abrió desde notificación (terminated): ${initialMessage.data}',
        );
        // Esperar un momento para que la app termine de inicializarse
        await Future.delayed(const Duration(milliseconds: 500));
        _handleNotificationTap(initialMessage);
      }
    } catch (e) {
      print('⚠️ Error checking initial message: $e');
    }
  }

  /// Manejar el tap en una notificación (centralizado para todos los estados)
  void _handleNotificationTap(RemoteMessage message) {
    final dataType = message.data['type'];

    if (dataType == 'NEW_ORDER') {
      final reservationId = message.data['reservation_id'];
      if (reservationId != null) {
        print('🧭 Navegando a pedido desde notificación: $reservationId');

        // NUEVO: Guardar como navegación pendiente para que DashboardScreen lo procese
        _pendingOrderId = reservationId;

        // Emitir evento para navegación directa
        _orderEventController.add({
          'type': 'NAVIGATE_TO_ORDER',
          'reservation_id': reservationId,
        });
      }
    }
  }

  /// Mostrar notificación local (para cuando la app está en foreground)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    final reservationId =
        message.data['reservation_id']; // Extraer ID del pedido

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'Notificaciones Importantes',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload:
            reservationId, // NUEVO: Incluir reservation_id como payload para navegación
      );
    }
  }

  /// Obtener y guardar el token FCM
  Future<String?> _getToken() async {
    _fcmToken = await _messaging.getToken();
    print('🔑 FCM Token: $_fcmToken');

    // Escuchar cambios de token
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      print('🔄 Token FCM actualizado: $newToken');
    });

    return _fcmToken;
  }

  /// Registrar el token en el backend para un usuario específico
  Future<void> registerTokenForUser(String userId) async {
    if (_fcmToken == null) {
      await _getToken();
    }

    if (_fcmToken != null) {
      try {
        await ApiService().registerFcmToken(userId, _fcmToken!);
        print('✅ Token FCM registrado en el servidor para usuario: $userId');
      } catch (e) {
        print('❌ Error registrando token FCM: $e');
      }
    }
  }

  /// Manejar notificación de OneSignal (Click o Foreground)
  void handleOneSignalNotification(Map<String, dynamic> data) {
    final type = data['type'];
    final reservationId = data['reservation_id'];

    if (type == 'NEW_ORDER' && reservationId != null) {
      print('🔔 [OneSignal] Evento NEW_ORDER procesado para navegación');
      _orderEventController.add({
        'type': 'NAVIGATE_TO_ORDER',
        'reservation_id': reservationId,
      });
    } else if (type == 'STOCK_ALERT') {
      print('🔔 [OneSignal] Evento STOCK_ALERT procesado para navegación');
      _orderEventController.add({
        'type': 'NAVIGATE_TO_PRODUCT',
        'product_id': data['product_id'],
        'product_name': data['product_name'],
      });
    }
  }

  /// Manejar evento de Foreground de OneSignal (solo actualizar datos)
  void handleOneSignalForegroundEvent(Map<String, dynamic> data) {
    final type = data['type'];
    if (type == 'NEW_ORDER') {
      print(
        '🔔 [OneSignal] Evento NEW_ORDER en Foreground -> Actualizando Dashboard',
      );
      _orderEventController.add({
        'type': 'NEW_ORDER',
        'reservation_id': data['reservation_id'],
        'total': data['total'],
      });
    } else if (type == 'STOCK_ALERT') {
      print(
        '🔔 [OneSignal] Evento STOCK_ALERT en Foreground -> Actualizando Dashboard',
      );
      _orderEventController.add({
        'type': 'STOCK_ALERT',
        'product_id': data['product_id'],
        'product_name': data['product_name'],
      });
    }
  }

  /// Limpiar recursos
  void dispose() {
    _orderEventController.close();
  }
}
