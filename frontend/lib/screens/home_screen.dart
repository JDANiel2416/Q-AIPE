import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart'; // <--- 1. IMPORTANTE: GPS
import '../models/search_models.dart';
import '../services/api_service.dart';
import '../services/session_service.dart'; // <--- IMPORTANTE: Para Logout
import 'login_screen.dart'; // <--- Para redirigir al salir
import 'ticket_screen.dart'; // <--- IMPORTANTE: Importar TicketScreen

// --- MODELOS ---
enum MessageType { user, botThinking, botResponse }

class ChatMessage {
  final MessageType type;
  final String? text;
  final List<BodegaSearchResult>? results;
  
  ChatMessage({required this.type, this.text, this.results});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- 1. NUEVO: Key para controlar el menú lateral ---
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  final List<ChatMessage> _messages = [];
  
  bool _isChatStarted = false;
  bool _isTyping = false;
  bool _isLoading = false; 

  // --- VARIABLES DEL MAPA Y GPS ---
  YandexMapController? _mapController; // Nullable porque se inicializa al abrir el modal
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
  BodegaSearchResult? _selectedBodega; // Para centrar el mapa en una bodega específica

  // --- NUEVO: ID del usuario para persistencia ---
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
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
        desiredAccuracy: LocationAccuracy.high
      );

      // 4. Actualizar estado y mapa
      setState(() {
        _userLocation = Point(latitude: position.latitude, longitude: position.longitude);
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
            animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1.5),
          );
        } catch (e) {
          // Si hay error, no pasa nada
        }
      }

    } catch (e) {
      print("Error obteniendo GPS: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateMapMarkers(List<BodegaSearchResult> bodegas) {
    List<MapObject> newMarkers = [];

    // 1. EL USUARIO (Punto Azul Brillante)
    newMarkers.add(CircleMapObject(
      mapId: const MapObjectId('user_location'),
      circle: Circle(center: _userLocation, radius: 20),
      strokeColor: Colors.white,
      strokeWidth: 2,
      // Si ya tenemos GPS real usamos cyan, si no un gris indicando "esperando"
      fillColor: _hasLocation 
          ? const Color(0xFF00D9FF).withOpacity(0.9) 
          : Colors.grey.withOpacity(0.9),
      zIndex: 10,
    ));

    // 2. LAS BODEGAS (Puntos Rojos)
    for (var bodega in bodegas) {
      newMarkers.add(CircleMapObject(
        mapId: MapObjectId(bodega.bodegaId),
        circle: Circle(
          center: Point(latitude: bodega.latitude, longitude: bodega.longitude), 
          radius: 15
        ),
        strokeColor: Colors.white,
        strokeWidth: 2,
        fillColor: Colors.redAccent.withOpacity(0.9),
        consumeTapEvents: true,
        onTap: (obj, point) {
           // Feedback táctil al tocar
        }
      ));
    }

    setState(() {
      _mapObjects = newMarkers;
    });
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
      animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1.0),
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
      animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1.0),
    );
  }

  List<Map<String, String>> _buildHistoryPayload() {
    return _messages
        .where((m) => m.type == MessageType.user || m.type == MessageType.botResponse)
        .map((m) => {
              "role": m.type == MessageType.user ? "user" : "assistant",
              "content": m.text ?? ""
            })
        .toList();
  }

  void _handleSubmitted() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Verificar si tenemos ubicación antes de buscar
    if (!_hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Espera, obteniendo tu ubicación... 📍"))
      );
      await _getUserLocation(); // Intentar obtenerla de nuevo rápido
    }

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
        _currentUserId // <--- NUEVO: Pasamos el ID para historial
      );
      
      _updateMapMarkers(response.results);
      _moveCameraToFit(response.results);

      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(
          type: MessageType.botResponse,
          text: response.message, 
          results: response.results.isEmpty ? null : response.results,
        ));
      });
    } catch (e) {
      print("Error UI: $e");
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(
          type: MessageType.botResponse,
          text: "Tuve un problema buscando bodegas cercanas. ($e)",
          results: null,
        ));
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

  // --- 2. NUEVO: WIDGET DEL DRAWER (Menú Lateral) ---
  Widget _buildModernDrawer() {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.75, // Ocupa el 75% del ancho
        height: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E1A).withOpacity(0.98),
          border: const Border(right: BorderSide(color: Colors.white10)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER DEL PERFIL
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00D9FF)),
                      child: const CircleAvatar(
                        radius: 30,
                        backgroundColor: Color(0xFF0A0E1A),
                        child: Icon(Icons.person, color: Colors.white, size: 30),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text("Usuario Cliente", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const Text("Verificado RENIEC ✅", style: TextStyle(color: Color(0xFFA0A8B8), fontSize: 12)),
                  ],
                ),
              ),
              const Divider(color: Colors.white10),
              
              // OPCIONES DEL MENÚ
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _buildDrawerItem(Icons.history, "Historial de Pedidos", () {}),
                    _buildDrawerItem(Icons.chat_bubble_outline, "Mis Chats", () {}),
                    _buildDrawerItem(Icons.favorite_border, "Favoritos", () {}),
                    _buildDrawerItem(Icons.place_outlined, "Mis Direcciones", () {}),
                    const Divider(color: Colors.white10, height: 30),
                    _buildDrawerItem(Icons.settings_outlined, "Configuración", () {}),
                    _buildDrawerItem(Icons.help_outline, "Ayuda y Soporte", () {}),
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
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3))
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.logout, color: Colors.redAccent, size: 20),
                        SizedBox(width: 10),
                        Text("Cerrar Sesión", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 22),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      hoverColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey, // <--- 3. ASIGNAR LA KEY AQUÍ
      drawer: _buildModernDrawer(), // <--- 4. ASIGNAR EL DRAWER AQUÍ
      backgroundColor: const Color(0xFF0A0E1A),
      resizeToAvoidBottomInset: false, 
      body: Stack(
        children: [
          const MinimalistBackground(),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: Stack(
                    children: [
                      !_isChatStarted ? _buildWelcomeView() : _buildChatList(),
                      
                      // Botón flotante para bajar al final
                      if (_showScrollDownButton)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: RepaintBoundary(
                            child: GestureDetector(
                              onTap: () => _scrollToBottom(),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D9FF),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00D9FF).withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
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
                    ],
                  ),
                ),
                _buildInputAreaWrapper(context),
              ],
            ),
          ),
          
          // Modal del mapa expandido
          if (_isMapExpanded)
            _buildMapOverlay(),
        ],
      ),
    );
  }

  Widget _buildInputAreaWrapper(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    // Auto-scroll cuando el teclado se abre (igual que WhatsApp/Telegram)
    if (keyboardHeight > 0 && _lastKeyboardHeight == 0 && _isChatStarted) {
      // Primer frame: esperar que el layout se actualice
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Segundo frame: ahora sí hacer el scroll con el nuevo maxScrollExtent
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && _scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      });
    }
    _lastKeyboardHeight = keyboardHeight;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        left: 16, 
        right: 16, 
        bottom: keyboardHeight > 0 ? keyboardHeight + 10 : 20,
        top: 10,
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
          color: Colors.black.withOpacity(0.7),
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
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      )
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
                                Future.delayed(const Duration(milliseconds: 300), () {
                                  _centerMapOnLocation(
                                    _selectedBodega!.latitude,
                                    _selectedBodega!.longitude,
                                  );
                                });
                              } else if (_hasLocation) {
                                _mapController?.moveCamera(
                                  CameraUpdate.newCameraPosition(
                                    CameraPosition(target: _userLocation, zoom: 16),
                                  ),
                                );
                              }
                            },
                            mapObjects: _mapObjects,
                            nightModeEnabled: true,
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
                                color: const Color(0xFF1A1F2E),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                        
                        // Botón de GPS
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: FloatingActionButton.small(
                            backgroundColor: const Color(0xFF1A1F2E),
                            child: const Icon(Icons.my_location, color: Color(0xFF00D9FF)),
                            onPressed: _getUserLocation,
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

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 5. MODIFICADO: EL BOTÓN AHORA ABRE EL DRAWER
          _buildCircleBtn(Icons.grid_view_rounded, () {
            _scaffoldKey.currentState?.openDrawer();
          }),
          
          const Text(
            "Q-AIPE",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 2.0, fontSize: 13),
          ),
          
          Row(
            children: [
              // Botón de mapa flotante
              _buildCircleBtn(Icons.map_outlined, () {
                setState(() {
                  _selectedBodega = null; // Reset selección al abrir mapa general
                  _isMapExpanded = true;
                });
              }),
              const SizedBox(width: 8),
              _buildCircleBtn(Icons.refresh_rounded, () {
                setState(() { 
                  _messages.clear(); 
                  _isChatStarted = false; 
                  _isLoading = false;
                  _updateMapMarkers([]); 
                });
                _getUserLocation();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
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
                  colors: [Colors.blueAccent.withOpacity(0.2), Colors.purpleAccent.withOpacity(0.2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight
                ),
                 boxShadow: [
                   BoxShadow(color: const Color(0xFF00D9FF).withOpacity(0.2), blurRadius: 40, spreadRadius: 0)
                 ]
              ),
              child: const Icon(Icons.auto_awesome, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 30),
            // Texto dinámico según si tenemos ubicación
            Text(_hasLocation ? "¡Ubicación detectada!" : "Buscando satélites...",
                style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w300)),
            const SizedBox(height: 8),
            const Text("¿Qué pedimos hoy?",
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return RepaintBoundary(
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
          return Opacity(
            opacity: value.clamp(0.0, 1.0), 
            child: child
          );
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
            color: const Color(0xFF1A1F2E),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3), width: 1),
          ),
          child: Text(msg.text ?? "", style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
      );
    } else if (msg.type == MessageType.botThinking) {
      return Row(
        children: [
          const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D9FF))),
          const SizedBox(width: 12),
          Text("Consultando bodegas cercanas...", style: TextStyle(color: Colors.white.withOpacity(0.5), fontStyle: FontStyle.italic)),
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
                  color: const Color(0xFF1A1F2E).withOpacity(0.7), // Glassmorphism base
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.1))
               ),
               child: Text(
                 msg.text!, 
                 style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)
               ),
             ),
           
           if (msg.results != null && msg.results!.isNotEmpty)
             ...msg.results!.map((b) => _buildBodegaCard(b)),
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
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text("Confirmar Reserva", style: TextStyle(color: Colors.white)),
        content: const Text(
          "¿Estás seguro de que deseas reservar estos productos? Se generará un ticket para que pases a recogerlo.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Seguir comprando", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _processReservation(bodega);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.black,
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
      builder: (_) => const Center(child: CircularProgressIndicator()),
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
            SnackBar(content: Text("Error: ${response['message']}"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Cerrar loading si falla
      print("Error reservando: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error de conexión: $e"), backgroundColor: Colors.red),
          );
      }
    }
  }

  Widget _buildBodegaCard(BodegaSearchResult bodega) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E).withOpacity(0.7), // Glassmorphism base
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
        ]
      ),
      child: Column(
        children: [
          // CABECERA DE LA BODEGA (Igual que antes)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF00D9FF).withOpacity(0.2),
                  child: const Icon(Icons.store, color: Color(0xFF00D9FF), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bodega.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("A ${bodega.distanceMeters}m • ${bodega.isOpen ? 'ABIERTO' : 'CERRADO'}", 
                        style: TextStyle(color: bodega.isOpen ? Colors.greenAccent : Colors.redAccent, fontSize: 12)),
                    ],
                  ),
                ),
                // Precio Total Resaltado
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Total", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    Text("S/ ${bodega.totalPrice.toStringAsFixed(2)}", 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.map, color: Color(0xFF00D9FF), size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Ver ubicación",
                          style: TextStyle(
                            color: Color(0xFF00D9FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
              // Botón "Reservar" (NUEVO)
              Expanded(
                child: InkWell(
                  onTap: () => _confirmReservation(bodega),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    color: const Color(0xFF00D9FF).withOpacity(0.1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                         Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 18),
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

          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          
          // --- LISTA DE PRODUCTOS DETALLADA ---
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: bodega.foundItems.map((item) {
                final displayName = _formatItemName(item); 
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- COLUMNA IZQUIERDA: CANTIDAD ---
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D9FF),
                            borderRadius: BorderRadius.circular(6)
                          ),
                          child: Text(
                            "x${item.requestedQuantity}", 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
                          ),
                        ),
                      ),
                      
                      // --- COLUMNA CENTRAL: NOMBRE ---
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName, 
                              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)
                            ),
                          ],
                        ),
                      ),
                      
                      // --- COLUMNA DERECHA: PRECIO ---
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Mostramos precio unitario
                          Text("S/ ${item.price.toStringAsFixed(2)}", 
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          
                          // Si quieres mostrar el subtotal (2 * 2.50 = 5.00) opcionalmente:
                          if (item.requestedQuantity > 1)
                            Text(
                              "Total: S/ ${(item.price * item.requestedQuantity).toStringAsFixed(2)}",
                              style: TextStyle(color: Colors.grey[500], fontSize: 10)
                            ),
                        ],
                      )
                    ],
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildModernInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E).withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
        ]
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isLoading,
              style: TextStyle(color: _isLoading ? Colors.white38 : Colors.white),
              cursorColor: const Color(0xFF00D9FF),
              decoration: InputDecoration(
                hintText: _isLoading ? "Buscando..." : "Escribe tu pedido...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              ),
              onSubmitted: (_) => _handleSubmitted(),
            ),
          ),
          
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: (_isTyping || _isLoading) ? const Color(0xFF00D9FF) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isLoading 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  )
                : Icon(
                    Icons.arrow_upward_rounded, 
                    color: _isTyping ? Colors.white : Colors.white24
                  ),
              onPressed: _isLoading ? null : _handleSubmitted,
            ),
          )
        ],
      ),
    );
  }
}

// --- FONDO MINIMALISTA ESTÁTICO ---
class MinimalistBackground extends StatelessWidget {
  const MinimalistBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0E1A), // Negro azulado oscuro
            Color(0xFF0F1419), // Negro con tinte gris
            Color(0xFF0A0E1A), // Negro azulado oscuro
          ],
          stops: [0.0, 0.5, 1.0],
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
                  colors: [
                    const Color(0xFF00D9FF).withOpacity(0.05),
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
                  colors: [
                    const Color(0xFF00D9FF).withOpacity(0.03),
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