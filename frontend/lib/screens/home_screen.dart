import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart'; // <--- 1. IMPORTANTE: GPS
import '../models/search_models.dart';
import '../services/api_service.dart';

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
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  final List<ChatMessage> _messages = [];
  
  bool _isChatStarted = false;
  bool _isTyping = false;
  bool _isLoading = false; 

  // --- VARIABLES DEL MAPA Y GPS ---
  late YandexMapController _mapController;
  List<MapObject> _mapObjects = [];
  
  // 2. CAMBIO: Ya no es 'const', ahora es variable para actualizarla con el GPS
  // Default: Huanchaco (mientras carga el GPS)
  Point _userLocation = const Point(latitude: -8.0783, longitude: -79.1180);
  bool _hasLocation = false; // Para saber si ya tenemos la ubicación real

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final isTyping = _controller.text.trim().isNotEmpty;
      if (_isTyping != isTyping) {
        setState(() {
          _isTyping = isTyping;
        });
      }
    });
    
    // 3. CAMBIO: Llamamos a la función de obtener ubicación al iniciar
    _getUserLocation();
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
      try {
        _mapController.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _userLocation, zoom: 16),
          ),
          animation: const MapAnimation(type: MapAnimationType.smooth, duration: 1.5),
        );
      } catch (e) {
        // Si el mapa aún no carga, no pasa nada
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
      // Si ya tenemos GPS real usamos azul, si no un gris indicando "esperando"
      fillColor: _hasLocation 
          ? const Color(0xFF4D6FFF).withOpacity(0.9) 
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
    if (bodegas.isEmpty) return;

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

    _mapController.moveCamera(
      CameraUpdate.newBounds(
        BoundingBox(
          northEast: Point(latitude: maxLat + 0.002, longitude: maxLon + 0.002),
          southWest: Point(latitude: minLat - 0.002, longitude: minLon - 0.002),
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
      // 4. CAMBIO: Ahora se envían las coordenadas reales (_userLocation)
      final response = await _apiService.searchSmart(text, _userLocation.latitude, _userLocation.longitude);
      
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      resizeToAvoidBottomInset: false, 
      body: Stack(
        children: [
          const RepaintBoundary(child: AmbientBackground()),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                _buildMapSection(), 
                Expanded(
                  child: !_isChatStarted ? _buildWelcomeView() : _buildChatList(),
                ),
                _buildInputAreaWrapper(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            YandexMap(
              onMapCreated: (controller) {
                _mapController = controller;
                // Si ya tenemos ubicación al crear el mapa, nos movemos ahí
                if (_hasLocation) {
                   _mapController.moveCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(target: _userLocation, zoom: 16),
                    ),
                  );
                }
              },
              mapObjects: _mapObjects,
              nightModeEnabled: true,
            ),
            // Botón flotante para recentrar mapa (Opcional pero útil)
            Positioned(
              right: 10,
              bottom: 10,
              child: FloatingActionButton.small(
                backgroundColor: const Color(0xFF2E335A),
                child: const Icon(Icons.my_location, color: Colors.white),
                onPressed: () {
                   _getUserLocation();
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInputAreaWrapper(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
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

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleBtn(Icons.grid_view_rounded, () {}),
          const Text(
            "Q-AIPE",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                fontSize: 13),
          ),
          _buildCircleBtn(Icons.refresh_rounded, () {
            setState(() { 
              _messages.clear(); 
              _isChatStarted = false; 
              _isLoading = false;
              _updateMapMarkers([]); 
            });
            _getUserLocation(); // Recargar ubicación al refrescar
          }),
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
                  BoxShadow(color: const Color(0xFF4D6FFF).withOpacity(0.3), blurRadius: 50, spreadRadius: 1)
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
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageItem(_messages[index]),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0), 
            child: child
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _contentForMessage(msg),
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
            gradient: const LinearGradient(
              colors: [Color(0xFF2E335A), Color(0xFF1C1F33)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Text(msg.text ?? "", style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
      );
    } else if (msg.type == MessageType.botThinking) {
      return Row(
        children: [
          const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4D6FFF))),
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
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.05))
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
  Widget _buildBodegaCard(BodegaSearchResult bodega) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161822),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          // CABECERA DE LA BODEGA (Igual que antes)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF4D6FFF).withOpacity(0.2),
                  child: const Icon(Icons.store, color: Color(0xFF4D6FFF), size: 18),
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
          
          // --- LISTA DE PRODUCTOS DETALLADA ---
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: bodega.foundItems.map((item) {
                // Usamos la nueva función para el nombre
                final displayName = _formatItemName(item); 
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icono Check
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle_rounded, color: Colors.greenAccent.withOpacity(0.7), size: 16),
                      ),
                      const SizedBox(width: 10),
                      
                      // Nombre Formateado (Agua San Luis sin gas 1L)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName, 
                              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)
                            ),
                            // Si quieres mostrar la unidad original pequeña abajo
                            if (item.unit != 'UND')
                              Text("Unidad: ${item.unit}", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                          ],
                        ),
                      ),
                      
                      // Precio Individual
                      Text(
                        "S/ ${item.price.toStringAsFixed(2)}", 
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)
                      ),
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
        color: const Color(0xFF1A1D2D).withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
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
              cursorColor: const Color(0xFF4D6FFF),
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
              color: (_isTyping || _isLoading) ? const Color(0xFF4D6FFF) : Colors.transparent,
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

// --- FONDO ANIMADO ---
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key});
  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, duration: const Duration(seconds: 15))..repeat();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60), 
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 2 * math.pi;
          
          return Stack(
            children: [
              Container(color: const Color(0xFF0F111A)),
              Positioned(
                top: 100 + math.sin(t) * 50,
                left: -50 + math.cos(t * 0.5) * 50,
                child: const Orb(color: Color(0xFF1E88E5), radius: 300),
              ),
              Positioned(
                bottom: 100 + math.cos(t) * 60,
                right: -50 + math.sin(t * 0.8) * 50,
                child: const Orb(color: Color(0xFF7B1FA2), radius: 320),
              ),
              Positioned(
                top: MediaQuery.of(context).size.height / 2 - 100,
                left: MediaQuery.of(context).size.width / 2 - 100 + math.sin(t + 2) * 80,
                child: Opacity(
                  opacity: 0.4,
                  child: const Orb(color: Color(0xFF009688), radius: 200),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class Orb extends StatelessWidget {
  final Color color;
  final double radius;
  const Orb({super.key, required this.color, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius,
      height: radius,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.5),
      ),
    );
  }
}