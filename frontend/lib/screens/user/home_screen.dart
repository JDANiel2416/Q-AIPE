import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart'; // <--- 1. IMPORTANTE: GPS
import '../../models/search_models.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart'; // <--- IMPORTANTE: Para Logout
import '../common/login_screen.dart'; // <--- Para redirigir al salir
import 'ticket_screen.dart'; // <--- IMPORTANTE: Importar TicketScreen
import 'my_chats_screen.dart'; // <--- Para Mis Chats
import 'orders_history_screen.dart'; // <--- Para Historial de Pedidos
import '../../theme/design_system.dart'; // <--- NUEVO: Sistema de diseño
import '../../theme/animations.dart'; // <--- NUEVO: Animaciones
import 'home_colors.dart'; // <--- NUEVO: Helper de colores dinámicos para modo oscuro
import '../../services/theme_provider.dart'; // <--- NUEVO: Para controlar el tema global

// =============================================================================
// PALETA DE COLORES - TEMA DINÁMICO (LIGHT/DARK)
// =============================================================================
// NOTA: Usar HomeColors.background(context) en lugar de AppColors.background
// HomeColors proporciona colores dinámicos que se adaptan al tema actual

// --- MODELOS ---
enum MessageType { user, botThinking, botResponse }

class ChatMessage {
  final MessageType type;
  final String? text;
  final List<BodegaSearchResult>? results;
  bool isAnimated; // Nuevo: Para controlar estado de animación

  ChatMessage({
    required this.type,
    this.text,
    this.results,
    this.isAnimated = false,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // --- 1. NUEVO: Key para controlar el menú lateral ---
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _textFieldScrollController =
      ScrollController(); // NUEVO: Para el TextField
  final FocusNode _focusNode = FocusNode(); // NUEVO: FocusNode explícito
  final ApiService _apiService = ApiService();
  final List<ChatMessage> _messages = [];
  List<BodegaSearchResult> _lastSearchResults =
      []; // Para refrescar mapa al mover usuario

  bool _isChatStarted = false;
  bool _isTyping = false;
  bool _isLoading = false;

  // --- VARIABLES DEL MAPA Y GPS ---
  YandexMapController?
  _mapController; // Nullable porque se inicializa al abrir el modal
  List<MapObject> _mapObjects = [];

  // 2. CAMBIO: Ya no es 'const', ahora es variable para actualizarla con el GPS
  // Default: Huanchaco (mientras carga el GPS)
  Point _userLocation = const Point(latitude: -8.0783, longitude: -79.1180);
  bool _hasLocation = false; // Para saber si ya tenemos la ubicación real

  // --- NUEVO: Variables para control de scroll ---
  bool _showScrollDownButton = false;
  bool _isAtBottom = true;
  double _lastKeyboardHeight = 0;

  // --- NUEVO: Variable para controlar el mapa flotante ---
  bool _isMapExpanded = false;
  BodegaSearchResult?
  _selectedBodega; // Para centrar el mapa en una bodega específica
  MapType _mapType = MapType.vector; // Tipo de mapa (Vector vs Satélite)

  // --- NUEVO: Rutas Peatonales ---
  List<MapObject> _routeObjects = []; // Capa para la línea de ruta
  String? _routeDistance; // Texto: "500 m"
  String? _routeTime; // Texto: "5 min"
  // PedestrianSession? _pedestrianSession; // Sesión de ruta (lo definiremos dinámicamente)

  // --- NUEVO: ID del usuario para persistencia ---
  String? _currentUserId;
  String _userFirstName = "Usuario"; // Nombre para mostrar en drawer
  String? _chatSessionId; // <--- NUEVO: ID de la sesión de chat actual

  // --- NUEVO: Drawer interactivo con animación ---
  late AnimationController _drawerController;
  bool _isDrawerOpen = false;
  double _drawerDragStart = 0;

  // --- NUEVO: Stream para ubicación en tiempo real ---
  StreamSubscription<Position>? _positionStreamSubscription;

  // --- NUEVO: Control del tema oscuro ---
  late ThemeProvider _themeProvider;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();

    // Inicializar ThemeProvider
    _themeProvider = ThemeProvider();
    _isDarkMode = _themeProvider.themeMode.value == ThemeMode.dark;

    // Configurar la barra de estado según el tema
    // _updateSystemUIOverlayStyle(); // Eliminado: Usaremos AnnotatedRegion

    // Inicializar controlador de animación del drawer
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _loadUserSession(); // <--- Cargar ID
    _controller.addListener(() {
      final isTyping = _controller.text.trim().isNotEmpty;
      if (_isTyping != isTyping) {
        setState(() {
          _isTyping = isTyping;
        });
      }
    });

    // Listener para detectar posición del scroll
    _scrollController.addListener(_onScroll);

    // 3. CAMBIO: Llamamos a la función de obtener ubicación al iniciar
    _getUserLocation();
  }

  Future<void> _loadUserSession() async {
    final userId = await SessionService().getUserId();
    if (mounted) {
      setState(() {
        _currentUserId = userId;
      });
      print("👤 User ID cargado: $_currentUserId");

      // Cargar perfil del usuario
      if (userId != null) {
        final profile = await _apiService.getUserProfile(userId);
        if (mounted && profile.isNotEmpty) {
          setState(() {
            _userFirstName = profile['first_name'] ?? "Usuario";
          });
        }
      }
    }
  }

  /// Iniciar un nuevo chat limpio (para el botón de recarga o "nuevo chat")
  void _startNewChat() {
    setState(() {
      _chatSessionId =
          null; // Reset session ID - backend creará uno nuevo al enviar mensaje
      _messages.clear(); // Limpiar mensajes
      _isChatStarted = false;
      _showScrollDownButton = false;
    });
    print("🆕 Nuevo chat iniciado (session_id reseteado a null)");
  }

  /// Cargar un chat específico por su ID
  Future<void> _loadChatSession(String sessionId) async {
    if (_currentUserId == null) return;

    setState(() => _isLoading = true);

    // IMPORTANTE: Guardar el session_id para que los mensajes posteriores vayan a este chat
    _chatSessionId = sessionId;
    print("📂 Cargando chat con session_id: $_chatSessionId");

    try {
      final chatData = await _apiService.getChatMessages(
        _currentUserId!,
        sessionId,
      );

      if (chatData.isNotEmpty && mounted) {
        final messages = chatData['messages'] as List<dynamic>? ?? [];

        setState(() {
          _messages.clear();
          _isChatStarted = messages.isNotEmpty;

          // Convertir mensajes del backend al formato local
          for (var msg in messages) {
            if (msg['role'] == 'user') {
              _messages.add(
                ChatMessage(text: msg['content'], type: MessageType.user),
              );
            } else if (msg['role'] == 'assistant') {
              // Deserializar resultados adjuntos si existen
              List<BodegaSearchResult>? results;
              if (msg['attachment'] != null) {
                try {
                  final List<dynamic> attachmentList = msg['attachment'];
                  results = attachmentList
                      .map((item) => BodegaSearchResult.fromJson(item))
                      .toList();
                } catch (e) {
                  print("Error parsing attachment: $e");
                }
              }

              _messages.add(
                ChatMessage(
                  text: msg['content'],
                  type: MessageType.botResponse,
                  results: results,
                  isAnimated: true,
                ),
              );
            }
          }

          _isLoading = false;
          _showScrollDownButton = false;
          _isAtBottom = true;
        });

        // Scroll al final después de cargar
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error cargando chat: $e");
      setState(() => _isLoading = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = 100.0;

    final isNearBottom = (maxScroll - currentScroll) < threshold;

    // Solo actualizar si cambia el estado para evitar rebuilds innecesarios
    if (_isAtBottom != isNearBottom) {
      _isAtBottom = isNearBottom;
      final shouldShow = !isNearBottom && _isChatStarted;

      if (_showScrollDownButton != shouldShow) {
        setState(() {
          _showScrollDownButton = shouldShow;
        });
      }
    }
  }

  // --- NUEVA LÓGICA DE GEOLOCALIZACIÓN ---
  Future<void> _getUserLocation() async {
    try {
      // 1. Verificar si el GPS está prendido
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Podrías mostrar un aviso aquí para que activen el GPS
        return;
      }

      // 2. Pedir permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      // 3. Obtener posición actual
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 4. Actualizar estado y mapa
      setState(() {
        _userLocation = Point(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        _hasLocation = true;
      });

      // Actualizar el marcador del usuario en el mapa
      _updateMapMarkers([]);

      // Mover la cámara a la ubicación real
      if (_mapController != null) {
        try {
          _mapController!.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: _userLocation, zoom: 16),
            ),
            animation: const MapAnimation(
              type: MapAnimationType.smooth,
              duration: 1.5,
            ),
          );
        } catch (e) {
          // Si hay error, no pasa nada
        }
      }
    } catch (e) {
      print("Error obteniendo GPS: $e");
    }
  }

  /* 
    // MÉTODO ELIMINADO: Usamos AnnotatedRegion en el build
    void _updateSystemUIOverlayStyle() {
      final isDark = _isDarkMode;
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: isDark ? Colors.black : Colors.white,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
      );
    } 
    */

  /// Cambiar el tema entre claro y oscuro
  void _toggleDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
    });

    // Cambiar el tema global
    _themeProvider.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);

    // Actualizar la barra de estado
    // _updateSystemUIOverlayStyle(); // Eliminado: Usaremos AnnotatedRegion
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel(); // Cancelar stream
    _controller.dispose();
    _scrollController.dispose();
    _textFieldScrollController.dispose();
    _focusNode.dispose();
    _drawerController.dispose();
    super.dispose();
  }

  // Iniciar seguimiento en tiempo real
  void _startLocationStream() {
    if (_positionStreamSubscription != null) return; // Ya está escuchando

    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation, // Máxima precisión
      distanceFilter: 0, // Notificar cualquier movimiento (fluido)
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (mounted) {
              setState(() {
                _userLocation = Point(
                  latitude: position.latitude,
                  longitude: position.longitude,
                );
                _hasLocation = true;
              });

              // Actualizar markers para mover el punto del usuario
              _updateMapMarkers(_lastSearchResults);
            }
          },
          onError: (e) => print("Error stream ubicación: $e"),
        );
  }

  Future<void> _updateMapMarkers(List<BodegaSearchResult> bodegas) async {
    _lastSearchResults = bodegas; // Guardar para actualizaciones de ubicación
    List<MapObject> newMarkers = [];

    // 1. EL USUARIO (Pin Azul Pequeño)
    if (_hasLocation) {
      // Generar icono de usuario (más pequeño, color primario)
      final userIcon = await _buildPinIcon(HomeColors.primary(context), 30.0);

      newMarkers.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('user_location'),
          point: _userLocation,
          opacity: 1.0,
          zIndex: 100, // Encima de todo
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromBytes(userIcon),
              scale: 1.0,
            ),
          ),
        ),
      );
    }

    // 2. LAS BODEGAS (Pines BITMAP - Tamaño fijo normal)
    // Generamos los iconos una vez (Tamaño 40.0)
    final openIcon = await _buildPinIcon(HomeColors.success, 40.0);
    final closedIcon = await _buildPinIcon(HomeColors.error, 40.0);

    for (var bodega in bodegas) {
      newMarkers.add(
        PlacemarkMapObject(
          mapId: MapObjectId(bodega.bodegaId),
          point: Point(latitude: bodega.latitude, longitude: bodega.longitude),
          opacity: 1.0,
          zIndex: 50,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromBytes(
                bodega.isOpen ? openIcon : closedIcon,
              ),
              scale: 1.0,
            ),
          ),
          consumeTapEvents: true,
          onTap: (obj, point) {
            setState(() {
              _selectedBodega = bodega;
              _centerMapOnLocation(bodega.latitude, bodega.longitude);
            });
            // Calcular ruta al seleccionar
            _requestRoute(
              Point(latitude: bodega.latitude, longitude: bodega.longitude),
            );
          },
        ),
      );
    }

    if (mounted) {
      setState(() {
        _mapObjects = newMarkers;
      });
    }
  }

  // Helper para generar Pin simple (Círculo con borde)
  Future<Uint8List> _buildPinIcon(Color color, double size) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final double radius = size / 2;

    final Paint paint = Paint()..color = color;
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.1; // Borde proporcional (10%)

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.1);

    // Dibujar sombra
    canvas.drawCircle(
      Offset(radius, radius + (size * 0.05)),
      radius,
      shadowPaint,
    );

    // Dibujar círculo principal
    canvas.drawCircle(Offset(radius, radius), radius, paint);

    // Dibujar borde blanco
    canvas.drawCircle(
      Offset(radius, radius),
      radius - (size * 0.05),
      borderPaint,
    );

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      (size * 1.1).toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  void _moveCameraToFit(List<BodegaSearchResult> bodegas) {
    if (bodegas.isEmpty || _mapController == null) return;

    double minLat = _userLocation.latitude;
    double maxLat = _userLocation.latitude;
    double minLon = _userLocation.longitude;
    double maxLon = _userLocation.longitude;

    for (var b in bodegas) {
      if (b.latitude < minLat) minLat = b.latitude;
      if (b.latitude > maxLat) maxLat = b.latitude;
      if (b.longitude < minLon) minLon = b.longitude;
      if (b.longitude > maxLon) maxLon = b.longitude;
    }

    _mapController!.moveCamera(
      CameraUpdate.newBounds(
        BoundingBox(
          northEast: Point(latitude: maxLat + 0.002, longitude: maxLon + 0.002),
          southWest: Point(latitude: minLat - 0.002, longitude: minLon - 0.002),
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 1.0,
      ),
    );
  }

  // Nuevo método para centrar el mapa en una ubicación específica
  void _centerMapOnLocation(double lat, double lon) {
    if (_mapController == null) return;

    _mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: Point(latitude: lat, longitude: lon),
          zoom: 17, // Zoom más cercano para ver la bodega
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 1.0,
      ),
    );
  }

  List<Map<String, String>> _buildHistoryPayload() {
    return _messages
        .where(
          (m) =>
              m.type == MessageType.user || m.type == MessageType.botResponse,
        )
        .map(
          (m) => {
            "role": m.type == MessageType.user ? "user" : "assistant",
            "content": m.text ?? "",
          },
        )
        .toList();
  }

  void _handleSubmitted() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    // 0. VERIFICACIÓN ESTRICTA DE UBICACIÓN
    final hasAccess = await _checkLocationAndPermissions();
    if (!hasAccess) return; // Si no hay permisos/GPS, no continuar

    /* LÓGICA ANTERIOR ELIMINADA:
    if (!_hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(...);
      await _getUserLocation(); 
    }
    */

    HapticFeedback.lightImpact();

    setState(() {
      _isChatStarted = true;
      _isLoading = true;
      _messages.add(ChatMessage(type: MessageType.user, text: text));
      _messages.add(ChatMessage(type: MessageType.botThinking));
      _isTyping = false;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      // 4. CAMBIO: Ahora se envían las coordenadas reales (_userLocation) y el ID del usuario
      final response = await _apiService.searchSmart(
        text,
        _userLocation.latitude,
        _userLocation.longitude,
        _currentUserId, // <--- Pasamos el ID para historial
        [], // history (vacío por ahora)
        _chatSessionId, // <--- NUEVO: Pasamos la sesión específica
      );

      await _updateMapMarkers(response.results);
      _moveCameraToFit(response.results);

      // --- NUEVO: Guardar ID de sesión para persistencia ---
      if (response.sessionId != null) {
        _chatSessionId = response.sessionId;
        print("🔗 Sesión vinculada: $_chatSessionId");
      }

      setState(() {
        _messages.removeLast();
        _messages.add(
          ChatMessage(
            type: MessageType.botResponse,
            text: response.message,
            results: response.results.isEmpty ? null : response.results,
          ),
        );
      });
    } catch (e) {
      print("Error UI: $e");
      setState(() {
        _messages.removeLast();
        _messages.add(
          ChatMessage(
            type: MessageType.botResponse,
            text: "Tuve un problema buscando bodegas cercanas. ($e)",
            results: null,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _scrollToBottom();
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutQuad,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  // Helper para verificar ubicación y permisos antes de enviar mensaje
  Future<bool> _checkLocationAndPermissions() async {
    // 1. Verificar si el servicio GPS está habilitado (En el dispositivo)
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Mostrar diálogo explicativo antes de mandar a configuración
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false, // Obligar a decidir
          builder: (context) => AlertDialog(
            backgroundColor: HomeColors.surface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.location_off_rounded,
                  color: HomeColors.error,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Ubicación Requerida",
                    style: TextStyle(
                      color: HomeColors.textPrimary(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              "Para encontrar las mejores ofertas y bodegas cerca de ti, necesitamos que actives tu ubicación (GPS).",
              style: TextStyle(
                color: HomeColors.textSecondary(context),
                fontSize: 15,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), // Cancelar
                child: Text(
                  "Cancelar",
                  style: TextStyle(color: HomeColors.textMuted(context)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Geolocator.openLocationSettings(); // Abrir configuración
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomeColors.primary(context),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Activar Ubicación"),
              ),
            ],
          ),
        );
      }
      // Re-verificar después del diálogo para ver si el usuario lo activó
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
    }

    // 2. Verificar Permisos de la App
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Solicitar permisos en el momento (Dialogo del sistema)
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Si vuelven a denegar, mostrar mensaje
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Necesitamos permisos de ubicación para funcionar. 🔒",
              ),
              backgroundColor: HomeColors.error,
            ),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Si denegaron permanentemente, guiar a configuración de app
      if (mounted) {
        _showPermissionDialog(); // Método auxiliar para permisos permanentes
      }
      return false;
    }

    // Si todo está bien, actualizar location si es necesario
    if (!_hasLocation) {
      await _getUserLocation();
    }

    // Iniciar seguimiento en tiempo real
    _startLocationStream();

    return true;
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HomeColors.surface(context),
        title: const Text("Permisos de Ubicación"),
        content: const Text(
          "Has denegado los permisos de ubicación permanentemente. Por favor, habilítalos en la configuración de la aplicación.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text("Abrir Configuración"),
          ),
        ],
      ),
    );
  }

  // --- 2. NUEVO: WIDGET DEL DRAWER (Menú Lateral) - TEMA DINÁMICO ---
  Widget _buildModernDrawer() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.80, // Ocupa el 80% del ancho
      height: double.infinity,
      decoration: BoxDecoration(
        color: HomeColors.surface(context),
        boxShadow: [
          BoxShadow(
            color: HomeColors.shadowMedium(context),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER DEL PERFIL
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HomeColors.primaryLight(context).withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HomeColors.primary(context),
                      boxShadow: [
                        BoxShadow(
                          color: HomeColors.primary(context).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: HomeColors.surface(context),
                      child: Icon(
                        Icons.person,
                        color: HomeColors.primary(context),
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userFirstName,
                    style: TextStyle(
                      color: HomeColors.textPrimary(context),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.verified,
                        color: HomeColors.primary(context),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Verificado RENIEC",
                        style: TextStyle(
                          color: HomeColors.textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // OPCIONES DEL MENÚ
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildDrawerItem(
                    Icons.history_rounded,
                    "Historial de Pedidos",
                    () {
                      _closeDrawer();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OrdersHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    Icons.chat_bubble_outline_rounded,
                    "Mis Chats",
                    () async {
                      _closeDrawer();
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyChatsScreen(),
                        ),
                      );

                      // Manejar resultado de MyChatsScreen
                      if (result != null && result is Map<String, dynamic>) {
                        final action = result['action'];
                        final sessionId =
                            result['session_id'] ?? result['new_session_id'];

                        if (action == 'selected' && sessionId != null) {
                          // Cargar el chat seleccionado
                          await _loadChatSession(sessionId);
                        } else if (action == 'new' ||
                            action == 'deleted_current') {
                          // Nuevo chat vacío - IMPORTANTE: resetear session_id a null
                          setState(() {
                            _chatSessionId =
                                null; // <-- NUEVO: Para que el siguiente mensaje cree nueva sesión
                            _messages.clear();
                            _isChatStarted = false;
                            _isLoading = false;
                            _showScrollDownButton = false;
                            _isAtBottom = true;
                            _updateMapMarkers([]);
                          });
                          print(
                            "🆕 Nuevo chat iniciado desde MyChatsScreen (session_id = null)",
                          );
                        }
                      }
                    },
                  ),
                  _buildDrawerItem(
                    Icons.favorite_outline_rounded,
                    "Favoritos",
                    () {},
                  ),
                  _buildDrawerItem(
                    Icons.place_outlined,
                    "Mis Direcciones",
                    () {},
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      color: HomeColors.divider(context),
                      height: 30,
                    ),
                  ),
                  // Switch de Modo Oscuro
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: HomeColors.primaryLight(
                            context,
                          ).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                          color: HomeColors.primary(context),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        "Modo Oscuro",
                        style: TextStyle(
                          color: HomeColors.textPrimary(context),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Switch(
                        value: _isDarkMode,
                        onChanged: _toggleDarkMode,
                        activeColor: HomeColors.primary(context),
                        activeTrackColor: HomeColors.primaryLight(context),
                      ),
                      onTap: () {
                        _toggleDarkMode(!_isDarkMode);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      hoverColor: HomeColors.primaryLight(
                        context,
                      ).withOpacity(0.3),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 30),
                  ),

                  _buildDrawerItem(
                    Icons.settings_outlined,
                    "Configuración",
                    () {},
                  ),
                  _buildDrawerItem(
                    Icons.help_outline_rounded,
                    "Ayuda y Soporte",
                    () {},
                  ),
                ],
              ),
            ),

            // BOTÓN CERRAR SESIÓN
            Padding(
              padding: const EdgeInsets.all(24),
              child: InkWell(
                onTap: () async {
                  await SessionService().logout();
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: HomeColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: HomeColors.error.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: HomeColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Cerrar Sesión",
                        style: TextStyle(
                          color: HomeColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: HomeColors.primaryLight(context).withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: HomeColors.primary(context), size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: HomeColors.textPrimary(context),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hoverColor: HomeColors.primaryLight(context).withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drawerWidth = MediaQuery.of(context).size.width * 0.80;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeProvider.themeMode,
      builder: (context, themeMode, child) {
        // Sincronizar el estado local con el tema global
        if (_isDarkMode != (themeMode == ThemeMode.dark)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isDarkMode = themeMode == ThemeMode.dark;
              });
            }
          });
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: _isDarkMode
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarColor: _isDarkMode ? Colors.black : Colors.white,
            systemNavigationBarIconBrightness: _isDarkMode
                ? Brightness.light
                : Brightness.dark,
          ),
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: HomeColors.background(context),
            resizeToAvoidBottomInset: true,
            body: GestureDetector(
              // Detectar inicio del swipe horizontal
              onHorizontalDragStart: _isMapExpanded
                  ? null
                  : (details) {
                      _drawerDragStart = details.globalPosition.dx;
                    },
              // Actualizar posición del drawer según el movimiento del dedo
              onHorizontalDragUpdate: _isMapExpanded
                  ? null
                  : (details) {
                      final delta =
                          details.globalPosition.dx - _drawerDragStart;

                      if (_isDrawerOpen) {
                        // Si está abierto, permitir cerrar arrastrando hacia la izquierda
                        final newValue = 1.0 + (delta / drawerWidth);
                        _drawerController.value = newValue.clamp(0.0, 1.0);
                      } else {
                        // Si está cerrado, permitir abrir arrastrando hacia la derecha
                        final newValue = delta / drawerWidth;
                        _drawerController.value = newValue.clamp(0.0, 1.0);
                      }
                    },
              // Al soltar, decidir si abrir o cerrar según la posición
              onHorizontalDragEnd: _isMapExpanded
                  ? null
                  : (details) {
                      final velocity = details.velocity.pixelsPerSecond.dx;

                      // Si hay velocidad significativa, usar esa para decidir
                      if (velocity > 500) {
                        _openDrawer();
                      } else if (velocity < -500) {
                        _closeDrawer();
                      } else {
                        // Si no hay velocidad, usar la posición actual
                        if (_drawerController.value > 0.5) {
                          _openDrawer();
                        } else {
                          _closeDrawer();
                        }
                      }
                    },
              child: Stack(
                children: [
                  const MinimalistBackground(),

                  Stack(
                    children: [
                      // 1. Contenido principal (Chat/Welcome)
                      Positioned.fill(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollUpdateNotification) {
                              _onScroll();
                            }
                            return false;
                          },
                          child: !_isChatStarted
                              ? _buildWelcomeView()
                              : _buildChatList(),
                        ),
                      ),

                      // 2. AppBar con efecto blur/liquid glass (Top)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: EdgeInsets.only(
                                top: MediaQuery.of(context).padding.top + 16,
                                bottom: 16,
                                left: 20,
                                right: 20,
                              ),
                              decoration: BoxDecoration(
                                color: HomeColors.background(
                                  context,
                                ).withOpacity(0.4),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(24),
                                  bottomRight: Radius.circular(24),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildCircleBtn(Icons.menu_rounded, () {
                                    _openDrawer();
                                  }),

                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: HomeColors.primaryLight(
                                            context,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.auto_awesome,
                                          color: HomeColors.primary(context),
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Chek",
                                        style: TextStyle(
                                          color: HomeColors.textPrimary(
                                            context,
                                          ),
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.0,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),

                                  Row(
                                    children: [
                                      _buildCircleBtn(Icons.map_outlined, () {
                                        setState(() {
                                          _selectedBodega = null;
                                          _isMapExpanded = true;
                                        });
                                      }),
                                      const SizedBox(width: 8),
                                      _buildCircleBtn(
                                        Icons.refresh_rounded,
                                        () async {
                                          if (_currentUserId != null) {
                                            await _apiService
                                                .createNewChatSession(
                                                  _currentUserId!,
                                                );
                                          }

                                          setState(() {
                                            _messages.clear();
                                            _isChatStarted = false;
                                            _isLoading = false;
                                            _showScrollDownButton = false;
                                            _isAtBottom = true;
                                            _updateMapMarkers([]);
                                          });
                                          _getUserLocation();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Botón flotante para bajar al final
                      if (_showScrollDownButton)
                        Positioned(
                          bottom: 100,
                          right: 16,
                          child: RepaintBoundary(
                            child: GestureDetector(
                              onTap: () => _scrollToBottom(),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: HomeColors.primary(context),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: HomeColors.primary(
                                        context,
                                      ).withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 3. Input Area Flotante
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _buildInputAreaWrapper(context),
                      ),
                    ],
                  ),

                  // Modal del mapa expandido
                  if (_isMapExpanded) _buildMapOverlay(),

                  // Drawer interactivo con animación
                  AnimatedBuilder(
                    animation: _drawerController,
                    builder: (context, child) {
                      if (_drawerController.value == 0)
                        return const SizedBox.shrink();

                      return Stack(
                        children: [
                          // Fondo oscuro que se desvanece
                          GestureDetector(
                            onTap: _closeDrawer,
                            child: Container(
                              color: Colors.black.withOpacity(
                                0.5 * _drawerController.value,
                              ),
                            ),
                          ),
                          // El drawer que se desliza
                          Transform.translate(
                            offset: Offset(
                              -drawerWidth +
                                  (drawerWidth * _drawerController.value),
                              0,
                            ),
                            child: _buildModernDrawer(),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openDrawer() {
    _drawerController.animateTo(1.0, curve: Curves.easeOutCubic);
    _isDrawerOpen = true;
  }

  void _closeDrawer() {
    _drawerController.animateTo(0.0, curve: Curves.easeOutCubic);
    _isDrawerOpen = false;
  }

  Widget _buildInputAreaWrapper(BuildContext context) {
    // Detectar si el teclado se abre para hacer scroll al fondo si es necesario
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight > 0 && _lastKeyboardHeight == 0 && _isChatStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isAtBottom) {
          _scrollToBottom();
        }
      });
    }
    _lastKeyboardHeight = keyboardHeight;

    return Container(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: 24, // Padding fijo inferior seguro
        top: 12,
      ),
      child: _buildModernInputArea(),
    );
  }

  // Nuevo widget: Overlay del mapa en pantalla completa
  Widget _buildMapOverlay() {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: () => setState(() => _isMapExpanded = false),
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: SafeArea(
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Evitar que el tap cierre cuando tocas el mapa
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // El mapa
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          width: double.infinity,
                          child: YandexMap(
                            onMapCreated: (controller) {
                              _mapController = controller;

                              // Si hay una bodega seleccionada, centrar en ella
                              if (_selectedBodega != null) {
                                Future.delayed(
                                  const Duration(milliseconds: 300),
                                  () {
                                    _centerMapOnLocation(
                                      _selectedBodega!.latitude,
                                      _selectedBodega!.longitude,
                                    );
                                  },
                                );
                              } else if (_hasLocation) {
                                _mapController?.moveCamera(
                                  CameraUpdate.newCameraPosition(
                                    CameraPosition(
                                      target: _userLocation,
                                      zoom: 16,
                                    ),
                                  ),
                                );
                              }
                            },
                            mapObjects: [
                              ..._mapObjects,
                              ..._routeObjects,
                            ], // Capa de rutas debajo/encima de marcadores
                            nightModeEnabled: _isDarkMode,
                            mapType: _mapType,
                          ),
                        ),

                        // Botón de cerrar
                        Positioned(
                          top: 16,
                          right: 16,
                          child: GestureDetector(
                            onTap: () => setState(() => _isMapExpanded = false),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: HomeColors.surface(context),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: HomeColors.border(context),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: HomeColors.shadowMedium(context),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.close,
                                color: HomeColors.textPrimary(context),
                                size: 20,
                              ),
                            ),
                          ),
                        ),

                        // Botón de GPS
                        Positioned(
                          right: 16,
                          bottom: _selectedBodega != null
                              ? 180
                              : 16, // Subir si hay tarjeta
                          child: FloatingActionButton.small(
                            backgroundColor: HomeColors.surface(context),
                            child: Icon(
                              Icons.my_location,
                              color: HomeColors.primary(context),
                            ),
                            onPressed: _getUserLocation,
                          ),
                        ),

                        // TARJETA DE INFORMACIÓN (Si hay bodega seleccionada)
                        if (_selectedBodega != null)
                          Positioned(
                            bottom: 20,
                            left: 20,
                            right: 20,
                            child: GestureDetector(
                              onTap: () {
                                // Opcional: Ir al detalle o cerrar
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: HomeColors.surface(context),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: HomeColors.border(context),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // NOMBRE Y ESTADO
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _selectedBodega!.name,
                                                style: TextStyle(
                                                  color: HomeColors.textPrimary(
                                                    context,
                                                  ),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          _selectedBodega!
                                                              .isOpen
                                                          ? HomeColors.success
                                                          : HomeColors.error,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _selectedBodega!.isOpen
                                                        ? "Abierto ahora"
                                                        : "Cerrado",
                                                    style: TextStyle(
                                                      color:
                                                          _selectedBodega!
                                                              .isOpen
                                                          ? HomeColors.success
                                                          : HomeColors.error,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // PRECIO TOTAL
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: HomeColors.primaryLight(
                                              context,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            "S/ ${_selectedBodega!.totalPrice.toStringAsFixed(2)}",
                                            style: TextStyle(
                                              color: HomeColors.primary(
                                                context,
                                              ),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // INFO RUTA (Si existe)
                                    if (_routeDistance != null &&
                                        _routeTime != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.directions_walk,
                                              size: 16,
                                              color: HomeColors.primary(
                                                context,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "$_routeTime • $_routeDistance",
                                              style: TextStyle(
                                                color: HomeColors.primary(
                                                  context,
                                                ),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    // COMPLETITUD DE PEDIDO
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    "Completitud del pedido",
                                                    style: TextStyle(
                                                      color:
                                                          HomeColors.textSecondary(
                                                            context,
                                                          ),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  Text(
                                                    "${_selectedBodega!.completenessScore.toInt()}%",
                                                    style: TextStyle(
                                                      color:
                                                          HomeColors.textPrimary(
                                                            context,
                                                          ),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value:
                                                      _selectedBodega!
                                                          .completenessScore /
                                                      100.0,
                                                  backgroundColor:
                                                      HomeColors.surfaceVariant(
                                                        context,
                                                      ),
                                                  color: _getCompletionColor(
                                                    _selectedBodega!
                                                        .completenessScore,
                                                  ),
                                                  minHeight: 6,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // BOTÓN RESERVAR MINI
                                        ElevatedButton(
                                          onPressed: () => _confirmReservation(
                                            _selectedBodega!,
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: HomeColors.primary(
                                              context,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 0,
                                            ),
                                            minimumSize: const Size(0, 36),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            elevation: 0,
                                          ),
                                          child: const Text("Reservar"),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getCompletionColor(double score) {
    if (score >= 80.0)
      return const Color(0xFF2E7D32); // Verde Tradicional (Darker success)
    if (score >= 60.0) return Colors.lightGreen; // Verde Claro
    if (score >= 40.0) return Colors.amber; // Ámbar
    return const Color(0xFFD32F2F); // Rojo
  }

  // Calcular ruta peatonal
  Future<void> _requestRoute(Point destination) async {
    if (!_hasLocation) return;

    // Limpiar ruta anterior
    setState(() {
      _routeObjects = [];
      _routeDistance = null;
      _routeTime = null;
    });

    try {
      // 1. Solicitar ruta (Devuelve un Record con Sesión y Future del Resultado)
      final resultRecord = await YandexPedestrian.requestRoutes(
        points: [
          RequestPoint(
            point: _userLocation,
            requestPointType: RequestPointType.wayPoint,
          ),
          RequestPoint(
            point: destination,
            requestPointType: RequestPointType.wayPoint,
          ),
        ],
        timeOptions: const TimeOptions(),
        fitnessOptions: const FitnessOptions(
          avoidSteep: false,
          avoidStairs: false,
        ),
      );

      // 2. Esperar el resultado de la sesión
      final session = await resultRecord.$2;

      if (session.routes != null && session.routes!.isNotEmpty) {
        final route = session.routes!.first;

        // Extraer metadatos
        // MasstransitWeight usa 'walkingDistance' NO 'distance'
        final distanceVal = route.metadata.weight.walkingDistance.value;
        final timeVal = route.metadata.weight.time.value;

        // Crear Polyline
        final polyline = PolylineMapObject(
          mapId: const MapObjectId('route_polyline'),
          polyline: route.geometry, // geometry es ya un Polyline
          strokeColor: HomeColors.primary(context),
          strokeWidth: 4.0,
          outlineColor: Colors.white,
          outlineWidth: 1.0,
        );

        if (mounted) {
          setState(() {
            _routeObjects = [polyline];

            // Formatear distancia
            if (distanceVal != null) {
              if (distanceVal < 1000) {
                _routeDistance = "${distanceVal.toInt()} m";
              } else {
                _routeDistance =
                    "${(distanceVal / 1000).toStringAsFixed(1)} km";
              }
            }

            // Formatear tiempo
            if (timeVal != null) {
              final min = (timeVal / 60).ceil();
              _routeTime = "$min min";
            }
          });
        }
      }
    } catch (e) {
      print("Error calculando ruta: $e");
    }
  }

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: HomeColors.surfaceVariant(context),
          shape: BoxShape.circle,
          border: Border.all(
            color: HomeColors.border(context).withOpacity(0.5),
          ),
        ),
        child: Icon(icon, color: HomeColors.textSecondary(context), size: 20),
      ),
    );
  }

  Widget _buildWelcomeView() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    HomeColors.primaryLight(context),
                    HomeColors.primary(context).withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: HomeColors.primary(context).withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 40,
                color: HomeColors.primary(context),
              ),
            ),
            const SizedBox(height: 30),
            // Texto dinámico según si tenemos ubicación
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _hasLocation ? Icons.location_on : Icons.location_searching,
                  color: _hasLocation
                      ? HomeColors.primary(context)
                      : HomeColors.textMuted(context),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _hasLocation
                      ? "¡Ubicación detectada!"
                      : "Buscando satélites...",
                  style: TextStyle(
                    color: HomeColors.textSecondary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "¿Qué pedimos hoy?",
              style: TextStyle(
                color: HomeColors.textPrimary(context),
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Método _buildChatList corregido
  Widget _buildChatList() {
    return RepaintBoundary(
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top:
              MediaQuery.of(context).padding.top +
              80, // Espacio para el AppBar con blur
          bottom:
              100, // Espacio FIJO para el Input Area (ya no depende del teclado)
        ),
        itemCount: _messages.length,
        itemBuilder: (context, index) => _buildMessageItem(_messages[index]),
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    return RepaintBoundary(
      child: TweenAnimationBuilder(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        tween: Tween<double>(begin: 0, end: 1),
        builder: (context, double value, child) {
          return Opacity(opacity: value.clamp(0.0, 1.0), child: child);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _contentForMessage(msg),
        ),
      ),
    );
  }

  Widget _contentForMessage(ChatMessage msg) {
    if (msg.type == MessageType.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: HomeColors.primary(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: HomeColors.primary(context).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            msg.text ?? "",
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    } else if (msg.type == MessageType.botThinking) {
      return Row(
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: HomeColors.primary(context),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "Consultando bodegas cercanas...",
            style: TextStyle(
              color: HomeColors.textMuted(context),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (msg.text != null && msg.text!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HomeColors.surface(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: HomeColors.border(context)),
                boxShadow: [
                  BoxShadow(
                    color: HomeColors.shadowLight(context),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: msg.isAnimated
                  ? Text(
                      msg.text!,
                      style: TextStyle(
                        color: HomeColors.textPrimary(context),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    )
                  : TypingMessage(
                      text: msg.text!,
                      style: TextStyle(
                        color: HomeColors.textPrimary(context),
                        fontSize: 15,
                        height: 1.4,
                      ),
                      onComplete: () {
                        if (mounted) {
                          setState(() {
                            msg.isAnimated = true;
                          });
                        }
                      },
                    ),
            ),

          if (msg.isAnimated && msg.results != null && msg.results!.isNotEmpty)
            ...msg.results!.asMap().entries.map((entry) {
              return StaggeredItem(
                index: entry.key,
                child: _buildBodegaCard(entry.value),
              );
            }),
        ],
      );
    }
  }

  // --- NUEVA FUNCIÓN AUXILIAR: ARMA EL NOMBRE COMPLETO ---
  String _formatItemName(ProductItem item) {
    String fullName = item.name; // Ej: "Agua"
    final attrs = item.attributes;

    // 1. Marca
    if (attrs.containsKey('marca')) {
      fullName += ' ${attrs['marca']}'; // Ej: "Agua San Luis"
    }

    // 2. Gas (Lógica específica para bebidas)
    if (attrs.containsKey('gas')) {
      final val = attrs['gas'];
      // Maneja si viene como bool (true) o string ("true")
      bool hasGas = val == true || val.toString().toLowerCase() == 'true';
      fullName += hasGas ? ' con gas' : ' sin gas';
    }

    // 3. Capacidad / Volumen / Peso
    if (attrs.containsKey('capacidad')) {
      fullName += ' ${attrs['capacidad']}'; // Ej: "Agua San Luis sin gas 1L"
    } else if (attrs.containsKey('volumen')) {
      fullName += ' ${attrs['volumen']}';
    } else if (attrs.containsKey('peso')) {
      fullName += ' ${attrs['peso']}';
    }

    // 4. Otros detalles (Opcional: Color, Talla, etc.)
    attrs.forEach((key, value) {
      if (!['marca', 'gas', 'capacidad', 'volumen', 'peso'].contains(key)) {
        fullName += ' $value';
      }
    });

    return fullName;
  }

  // --- REEMPLAZA ESTE WIDGET COMPLETO ---
  // --- LÓGICA DE RESERVA ---
  void _confirmReservation(BodegaSearchResult bodega) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Confirmar Reserva",
          style: TextStyle(
            color: HomeColors.textPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "¿Estás seguro de que deseas reservar estos productos? Se generará un ticket para que pases a recogerlo.",
          style: TextStyle(color: HomeColors.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              "Seguir comprando",
              style: TextStyle(color: HomeColors.textMuted(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _processReservation(bodega);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HomeColors.primary(context),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text("Sí, reservar"),
          ),
        ],
      ),
    );
  }

  Future<void> _processReservation(BodegaSearchResult bodega) async {
    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(color: HomeColors.primary(context)),
      ),
    );

    try {
      final response = await _apiService.createReservation(
        _currentUserId ?? "", // Asegúrate de manejar si es null
        bodega.bodegaId,
        bodega.foundItems,
      );

      // Cerrar loading
      if (mounted) Navigator.of(context).pop();

      if (response['success'] == true) {
        // Navegar al TicketScreen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TicketScreen(ticketData: response),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: ${response['message']}"),
              backgroundColor: HomeColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Cerrar loading si falla
      print("Error reservando: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error de conexión: $e"),
            backgroundColor: HomeColors.error,
          ),
        );
      }
    }
  }

  Widget _buildBodegaCard(BodegaSearchResult bodega) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: HomeColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HomeColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: HomeColors.shadowMedium(context),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // CABECERA DE LA BODEGA
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HomeColors.primaryLight(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    color: HomeColors.primary(context),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bodega.name,
                        style: TextStyle(
                          color: HomeColors.textPrimary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: HomeColors.textMuted(context),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            "A ${bodega.distanceMeters}m",
                            style: TextStyle(
                              color: HomeColors.textSecondary(context),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: bodega.isOpen
                                  ? HomeColors.success.withOpacity(0.1)
                                  : HomeColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              bodega.isOpen ? 'ABIERTO' : 'CERRADO',
                              style: TextStyle(
                                color: bodega.isOpen
                                    ? HomeColors.success
                                    : HomeColors.error,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Precio Total Resaltado
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Total",
                      style: TextStyle(
                        color: HomeColors.textMuted(context),
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      "S/ ${bodega.totalPrice.toStringAsFixed(2)}",
                      style: TextStyle(
                        color: HomeColors.primary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 1, color: HomeColors.divider(context)),

          // BOTONERAS DE ACCIÓN
          Row(
            children: [
              // Botón "Ver en el mapa"
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedBodega = bodega;
                      _isMapExpanded = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          color: HomeColors.textSecondary(context),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Ver ubicación",
                          style: TextStyle(
                            color: HomeColors.textSecondary(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: HomeColors.divider(context),
              ),
              // Botón "Reservar" (NUEVO)
              Expanded(
                child: InkWell(
                  onTap: () => _confirmReservation(bodega),
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: HomeColors.primary(context),
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Reservar",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          Container(height: 1, color: HomeColors.divider(context)),

          // --- LISTA DE PRODUCTOS DETALLADA ---
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: bodega.foundItems.map((item) {
                final displayName = _formatItemName(item);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HomeColors.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- COLUMNA IZQUIERDA: CANTIDAD ---
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: HomeColors.primary(context),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "x${item.requestedQuantity}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // --- COLUMNA CENTRAL: NOMBRE ---
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                color: HomeColors.textPrimary(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // --- COLUMNA DERECHA: PRECIO ---
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Mostramos precio unitario
                          Text(
                            "S/ ${item.price.toStringAsFixed(2)}",
                            style: TextStyle(
                              color: HomeColors.textPrimary(context),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          // Si quieres mostrar el subtotal (2 * 2.50 = 5.00) opcionalmente:
                          if (item.requestedQuantity > 1)
                            Text(
                              "Total: S/ ${(item.price * item.requestedQuantity).toStringAsFixed(2)}",
                              style: TextStyle(
                                color: HomeColors.textMuted(context),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInputArea() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            color: HomeColors.surface(
              context,
            ).withOpacity(0.7), // Semi-transparente
            borderRadius: BorderRadius.circular(26),
            // Sombra suave para delimitar
            boxShadow: [
              BoxShadow(
                color: HomeColors.shadowMedium(context).withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
                spreadRadius: 2,
              ),
            ],
            // Borde sutil opcional para reforzar el efecto vidrio
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 18),
              Expanded(
                child: Scrollbar(
                  controller: _textFieldScrollController,
                  thumbVisibility: false, // Solo se muestra cuando hay scroll
                  radius: const Radius.circular(8),
                  thickness: 4,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    scrollController: _textFieldScrollController,
                    enabled: !_isLoading,
                    maxLines: 5, // Máximo 5 líneas visibles
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      color: _isLoading
                          ? HomeColors.textMuted(context)
                          : HomeColors.textPrimary(context),
                      fontSize: 15,
                      height: 1.4,
                    ),
                    cursorColor: HomeColors.primary(context),
                    decoration: InputDecoration(
                      hintText: _isLoading
                          ? "Buscando..."
                          : "Escribe tu pedido...",
                      hintStyle: TextStyle(
                        color: HomeColors.textMuted(context).withOpacity(0.5),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 14,
                      ),
                      isDense: true,
                      fillColor: Colors.transparent,
                      filled: true,
                    ),
                    onSubmitted: null, // Enter hace salto de línea
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Botón de envío
              Container(
                margin: const EdgeInsets.only(right: 6, bottom: 6, top: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: (_isTyping || _isLoading)
                        ? HomeColors.primary(context)
                        : HomeColors.surfaceVariant(context),
                    shape: BoxShape.circle,
                    boxShadow: (_isTyping || _isLoading)
                        ? [
                            BoxShadow(
                              color: HomeColors.primary(
                                context,
                              ).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: IconButton(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.arrow_upward_rounded,
                            color: _isTyping
                                ? Colors.white
                                : HomeColors.textMuted(context),
                            size: 20,
                          ),
                    onPressed: _isLoading ? null : _handleSubmitted,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- FONDO MINIMALISTA DINÁMICO (LIGHT/DARK) ---
class MinimalistBackground extends StatelessWidget {
  const MinimalistBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = HomeColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  HomeColors.minimalistBackground(context), // Negro AMOLED
                  HomeColors.accentBackground(
                    context,
                  ), // Negro ligeramente más claro
                  HomeColors.minimalistBackground(context), // Negro AMOLED
                ]
              : [
                  const Color(0xFFF9FAFB), // Gris muy claro
                  const Color(0xFFFFFFFF), // Blanco
                  const Color(0xFFF3F4F6), // Gris suave
                ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Acento sutil en la esquina superior
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? [
                          HomeColors.primary(
                            context,
                          ).withOpacity(0.08), // Azul sutil para dark
                          Colors.transparent,
                        ]
                      : [
                          const Color(
                            0xFF10B981,
                          ).withOpacity(0.08), // Verde suave para light
                          Colors.transparent,
                        ],
                ),
              ),
            ),
          ),
          // Acento sutil en la esquina inferior
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? [
                          HomeColors.primary(
                            context,
                          ).withOpacity(0.05), // Azul más sutil
                          Colors.transparent,
                        ]
                      : [
                          const Color(
                            0xFF10B981,
                          ).withOpacity(0.05), // Verde más sutil
                          Colors.transparent,
                        ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TypingMessage extends StatefulWidget {
  final String text;
  final TextStyle style;
  final VoidCallback? onComplete;

  const TypingMessage({
    super.key,
    required this.text,
    required this.style,
    this.onComplete,
  });

  @override
  State<TypingMessage> createState() => _TypingMessageState();
}

class _TypingMessageState extends State<TypingMessage> {
  String _displayedText = "";
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    // Velocidad de tipeo: 20ms por caracter
    _timer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (_currentIndex < widget.text.length) {
        setState(() {
          _displayedText += widget.text[_currentIndex];
          _currentIndex++;
        });
      } else {
        _timer?.cancel();
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayedText, style: widget.style);
  }
}

class StaggeredItem extends StatefulWidget {
  final int index;
  final Widget child;

  const StaggeredItem({super.key, required this.index, required this.child});

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // Delay escalonado: 150ms * index
    Future.delayed(Duration(milliseconds: 150 * widget.index), () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.2),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
