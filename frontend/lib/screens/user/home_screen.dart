import 'dart:async';
import 'dart:io';
import 'dart:convert'; // JsonEncode
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'ticket_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/search_models.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';

import 'home_colors.dart';
import '../../services/theme_provider.dart';

// --- NUEVOS IMPORTS ---
import 'models/home_models.dart';
import '../../widgets/common/minimalist_background.dart';
import 'shared_drawer.dart'; // Import SharedDrawer
import 'widgets/home_input_area.dart';
import 'widgets/home_chat_view.dart';
import 'widgets/visual_store_view.dart';

class HomeScreen extends StatefulWidget {
  final String? initialSessionId;
  final String? initialTitle;

  const HomeScreen({super.key, this.initialSessionId, this.initialTitle});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, UserDrawerMixin {
  // ... (State variables) ...
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _textFieldScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ApiService _apiService = ApiService();
  final List<ChatMessage> _messages = [];

  // Variables de Estado
  bool _isChatStarted = false;
  bool _isTyping = false;
  bool _isLoading = false;

  // Mapa y GPS
  YandexMapController? _mapController;
  List<MapObject> _storeMarkers = [];
  PlacemarkMapObject? _userLocationMarker;
  Point _userLocation = const Point(latitude: -8.0783, longitude: -79.1180);
  bool _hasLocation = false;

  // Scroll y UI
  bool _showScrollDownButton = false;
  bool _isAtBottom = true;
  double _lastKeyboardHeight = 0;

  // Mapa Flotante
  bool _isMapExpanded = false;
  BodegaSearchResult? _selectedBodega;
  MapType _mapType = MapType.vector;
  List<MapObject> _routeObjects = [];

  String? _currentUserId;
  // String _userFirstName = "Usuario"; // Managed by SharedDrawer
  String? _chatSessionId;

  // Drawer
  // Drawer managed by Mixin

  // Tema
  late ThemeProvider _themeProvider;
  bool _isDarkMode = false;

  // Modo App
  AppMode _appMode = AppMode.chat;

  @override
  void initState() {
    super.initState();
    initDrawer(); // Initialize SharedDrawer
    _themeProvider = ThemeProvider();
    _isDarkMode = _themeProvider.themeMode.value == ThemeMode.dark;

    // Listen to theme changes
    _themeProvider.themeMode.addListener(_onThemeChanged);

    // Initialize session ID from widget args
    _chatSessionId = widget.initialSessionId;

    _loadUserSession(); // This will trigger chat load if session ID is set

    _controller.addListener(() {
      final isTyping = _controller.text.trim().isNotEmpty;
      if (_isTyping != isTyping) {
        setState(() => _isTyping = isTyping);
      }
    });

    _scrollController.addListener(_onScroll);
    _getUserLocation();
  }

  Future<void> _loadUserSession() async {
    final userId = await SessionService().getUserId();
    if (mounted) {
      setState(() => _currentUserId = userId);

      // If we have both user ID and an initial session, load it!
      if (userId != null && _chatSessionId != null) {
        _loadChatSession(_chatSessionId!);
      }
    }
  }

  void _startNewChat() {
    setState(() {
      _chatSessionId = null;
      _messages.clear();
      _isChatStarted = false;
      _showScrollDownButton = false;
    });
  }

  Future<void> _loadChatSession(String sessionId) async {
    if (_currentUserId == null) return;
    setState(() => _isLoading = true);
    _chatSessionId = sessionId;

    // Keep title logic if needed? For now we just load messages

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
          for (var msg in messages) {
            if (msg['role'] == 'user') {
              _messages.add(
                ChatMessage(text: msg['content'], type: MessageType.user),
              );
            } else if (msg['role'] == 'assistant') {
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
                  id: msg['id'], // ID del mensaje para updates
                  // Recuperar estado persistido
                  isReserved: msg['attachment_data']?['is_reserved'] ?? false,
                  selectedBodegaId:
                      msg['attachment_data']?['selected_bodega_id'],
                  ticketData: msg['attachment_data']?['ticket_data'],
                ),
              );
            }
          }
          _isLoading = false;
          _showScrollDownButton = false;
          _isAtBottom = true;
        });
        // No scrollear al cargar historial - dejar en posición natural
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error loading chat: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = 100.0;
    final isNearBottom = (maxScroll - currentScroll) < threshold;
    if (_isAtBottom != isNearBottom) {
      _isAtBottom = isNearBottom;
      final shouldShow = !isNearBottom && _isChatStarted;
      if (_showScrollDownButton != shouldShow) {
        setState(() => _showScrollDownButton = shouldShow);
      }
    }
  }

  Future<void> _getUserLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _userLocation = Point(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        _hasLocation = true;
        _updateUserMarker();
      });
    } catch (e) {
      print("Error obteniendo ubicación: $e");
    }
  }

  void _updateUserMarker() {
    _userLocationMarker = PlacemarkMapObject(
      mapId: const MapObjectId('user_location'),
      point: _userLocation,
      icon: PlacemarkIcon.single(
        PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage(
            'assets/images/user_marker.png',
          ),
          scale: 0.15,
        ),
      ),
      opacity: 1.0,
    );
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _isDarkMode = _themeProvider.themeMode.value == ThemeMode.dark;
      });
    }
  }

  // --- LOGICA DE RESERVA Y MAPA ---

  Future<void> _processReservation(BodegaSearchResult bodega) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(color: HomeColors.primary(context)),
      ),
    );

    // 1. Verificar si ya está reservado (Re-click en "Ver Ticket")
    if (_messages.isNotEmpty &&
        _messages.last.isReserved &&
        _messages.last.selectedBodegaId == bodega.bodegaId &&
        _messages.last.ticketData != null) {
      if (mounted)
        Navigator.of(
          context,
        ).pop(); // Cerrar loading si se abrió por error (o evitar abrirlo antes)

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TicketScreen(ticketData: _messages.last.ticketData!),
        ),
      );
      return;
    }

    try {
      final response = await _apiService.createReservation(
        _currentUserId ?? "",
        bodega.bodegaId,
        bodega.foundItems,
      );
      if (mounted) Navigator.of(context).pop();
      if (response['success'] == true && mounted) {
        // Normalizar datos para TicketScreen
        response['id'] = response['reservation_id'];
        response['status'] = 'PENDING';

        // ACTUALIZAR UI DEL CHAT: Marcar como reservado
        if (_messages.isNotEmpty &&
            _messages.last.type == MessageType.botResponse) {
          setState(() {
            _messages.last.isReserved = true;
            _messages.last.selectedBodegaId = bodega.bodegaId;
            _messages.last.ticketData = response;
          });

          // PERSISTENCIA BACKEND
          if (_messages.last.id != null) {
            await _apiService.updateChatMessage(_messages.last.id!, {
              "is_reserved": true,
              "selected_bodega_id": bodega.bodegaId,
              "ticket_data": response,
            });
          }
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TicketScreen(ticketData: response)),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${response['message']}"),
            backgroundColor: HomeColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error de conexión: $e"),
            backgroundColor: HomeColors.error,
          ),
        );
    }
  }

  Future<void> _processUnifiedReservation(
    List<BodegaSearchResult> bodegas,
  ) async {
    // 1. Validar login y user ID
    if (_currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Error: No hay usuario autenticado"),
            backgroundColor: HomeColors.error,
          ),
        );
      }
      return;
    }

    // 2. Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: HomeColors.primary(context)),
            const SizedBox(height: 16),
            const Text(
              "Procesando pedido...",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );

    List<Map<String, dynamic>> allItems = [];
    double grandTotal = 0.0;
    List<String> reservationIds = [];
    bool allSuccess = true;
    String? firstError;
    String userName = "Usuario";

    // 1. Verificar si este intento viene de un mensaje YA reservado (Re-click en "Ver Ticket")
    // Esto es un poco hacky: verificamos si el último mensaje ya tiene datos
    if (_messages.isNotEmpty &&
        _messages.last.isReserved &&
        bodegas.length == 1 &&
        _messages.last.selectedBodegaId == bodegas.first.bodegaId &&
        _messages.last.ticketData != null) {
      // Navegación directa
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TicketScreen(ticketData: _messages.last.ticketData!),
          ),
        );
      }
      return;
    }

    try {
      // 3. Loop: Crear reserva por cada bodega
      for (var bodega in bodegas) {
        final response = await _apiService.createReservation(
          _currentUserId!,
          bodega.bodegaId,
          bodega.foundItems,
        );

        if (response['success'] == true) {
          // Extraer datos del ticket de esta reserva
          final items = response['items'] as List<dynamic>? ?? [];
          final total = (response['total'] is int)
              ? (response['total'] as int).toDouble()
              : (response['total'] as double? ?? 0.0);
          final qrData = response['qr_data'] as String? ?? "";
          if (response['formatted_name'] != null) {
            userName = response['formatted_name'];
          }

          // Inyectar nombre de la bodega en cada item para el ticket
          final itemsWithBodega = items.map((item) {
            final Map<String, dynamic> itemMap = Map<String, dynamic>.from(
              item,
            );
            itemMap['bodega_name'] = bodega.name;
            return itemMap;
          }).toList();

          allItems.addAll(itemsWithBodega);
          grandTotal += total;
          reservationIds.add(qrData);
        } else {
          allSuccess = false;
          firstError =
              response['message'] ?? "Error desconocido en ${bodega.name}";
          break;
        }
      }

      if (mounted) Navigator.of(context).pop(); // Cerrar loading

      if (allSuccess && reservationIds.isNotEmpty) {
        final combinedTicketData = {
          'items': allItems,
          'total': grandTotal,
          'formatted_name': userName,
          'qr_data': jsonEncode(
            reservationIds,
          ), // Lista JSON unificada: ["RES...","RES..."]
          'success': true,
        };

        // ACTUALIZAR ESTADO DEL MENSAJE (Para UI "Reservado")
        if (_messages.isNotEmpty &&
            _messages.last.type == MessageType.botResponse) {
          final lastMsg = _messages.last;

          setState(() {
            lastMsg.isReserved = true;
            // Si es única, guardamos el ID para filtro visual
            if (bodegas.length == 1) {
              lastMsg.selectedBodegaId = bodegas.first.bodegaId;
            }
            lastMsg.ticketData = combinedTicketData;
          });

          // PERSISTENCIA BACKEND
          if (lastMsg.id != null) {
            await _apiService.updateChatMessage(lastMsg.id!, {
              "is_reserved": true,
              "selected_bodega_id": bodegas.length == 1
                  ? bodegas.first.bodegaId
                  : null,
              "ticket_data": combinedTicketData,
            });
          }
        }

        // Navegar al ticket
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TicketScreen(ticketData: combinedTicketData),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Error al reservar: ${firstError ?? 'Falló una reserva'}",
              ),
              backgroundColor: HomeColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
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

  void _navigateToTicket(Map<String, dynamic> ticketData) {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TicketScreen(ticketData: ticketData)),
      );
    }
  }

  // --- MAPA ---

  Future<void> _updateMapMarkers(List<BodegaSearchResult> results) async {
    final List<MapObject> newObjects = [];

    for (var bodega in results) {
      newObjects.add(
        PlacemarkMapObject(
          mapId: MapObjectId('bodega_${bodega.bodegaId}'),
          point: Point(latitude: bodega.latitude, longitude: bodega.longitude),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage(
                'assets/images/store_marker.png',
              ),
              scale: 0.25,
            ),
          ),
          onTap: (msg, point) => setState(() {
            _selectedBodega = bodega;
            _isMapExpanded = true;
          }),
        ),
      );
    }
    setState(() => _storeMarkers = newObjects);
  }

  void _centerMapOnLocation(double lat, double lon) {
    if (_mapController != null) {
      _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: Point(latitude: lat, longitude: lon),
            zoom: 18,
          ),
        ),
      );
    }
  }

  void _moveCameraToFit(List<BodegaSearchResult> results) {
    if (_mapController == null || results.isEmpty) return;
    // Lógica simplificada de zoom
    _mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: Point(
            latitude: results.first.latitude,
            longitude: results.first.longitude,
          ),
          zoom: 15,
        ),
      ),
    );
  }

  // --- CHAT LOGIC ---
  Future<void> _handleSubmitted([String? explicitText]) async {
    if (!await _checkGPSAndPermissions()) return;

    final text = explicitText ?? _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, type: MessageType.user));
      _messages.add(ChatMessage(type: MessageType.botThinking));
      _isChatStarted = true;
      _isLoading = true;
    });

    if (explicitText == null) _controller.clear();
    _scrollToBottom(); // Anclar mensaje del usuario arriba inmediatamente

    try {
      final response = await _apiService.searchSmart(
        text,
        _userLocation.latitude,
        _userLocation.longitude,
        _currentUserId,
        [],
        _chatSessionId,
      );
      if (response.sessionId != null) _chatSessionId = response.sessionId;

      await _updateMapMarkers(response.results);
      _moveCameraToFit(response.results);

      setState(() {
        _messages.removeLast();
        _messages.add(
          ChatMessage(
            type: response.isOrderSummary
                ? MessageType.orderSummary
                : MessageType.botResponse,
            text: response.message,
            results: response.results.isEmpty ? null : response.results,
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom(); // Mantener vista en posición 0 (mensaje usuario arriba)
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(
          ChatMessage(type: MessageType.botResponse, text: "Error: $e"),
        );
        _isLoading = false;
      });
    }
    // No scrollear después de la respuesta - mantener mensaje del usuario anclado
  }

  Future<bool> _checkGPSAndPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Verificar si el GPS está prendido
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "El GPS está desactivado. Actívalo para continuar.",
            ),
            backgroundColor: HomeColors.error,
            action: SnackBarAction(
              label: 'ACTIVAR',
              textColor: Colors.white,
              onPressed: () {
                Geolocator.openLocationSettings();
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return false;
    }

    // 2. Verificar permisos
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Necesitamos tu ubicación para sugerirte bodegas.",
              ),
              backgroundColor: HomeColors.error,
            ),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Permisos de ubicación denegados permanentemente. Habilítalos en configuración.",
            ),
            backgroundColor: HomeColors.error,
            action: SnackBarAction(
              label: 'CONFIGURAR',
              textColor: Colors.white,
              onPressed: () {
                Geolocator.openAppSettings();
              },
            ),
          ),
        );
      }
      return false;
    }

    // 3. Si todo ok, asegurar que tenemos la ubicación actual
    if (!_hasLocation) {
      await _getUserLocation();
      return _hasLocation;
    }

    return true;
  }

  void _scrollToBottom() {
    // Con lista invertida, posición 0 = mensajes más recientes (arriba visualmente)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(
            milliseconds: 800,
          ), // Velocidad estándar y fluida
          curve: Curves.easeOutQuart, // Curva premium muy suave
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Drawer Logic
    final drawerWidth = MediaQuery.of(context).size.width * 0.80;

    return WillPopScope(
      onWillPop: () async {
        if (isDrawerOpen) {
          closeDrawer();
          return false;
        }
        if (_isMapExpanded) {
          setState(() => _isMapExpanded = false);
          return false;
        }
        return true;
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: _isDarkMode
              ? Brightness.light
              : Brightness.dark,
        ),
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: HomeColors.background(context),
          resizeToAvoidBottomInset: true,
          body: GestureDetector(
            onHorizontalDragStart: _isMapExpanded
                ? null
                : (d) => onHorizontalDragStart(d, drawerWidth),
            onHorizontalDragUpdate: _isMapExpanded
                ? null
                : (d) => onHorizontalDragUpdate(d, drawerWidth),
            onHorizontalDragEnd: _isMapExpanded ? null : onHorizontalDragEnd,
            child: Stack(
              children: [
                const MinimalistBackground(),

                // --- CONTENIDO PRINCIPAL ---
                Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _appMode == AppMode.chat
                            ? HomeChatView(
                                messages: _messages,
                                isChatStarted: _isChatStarted,
                                hasLocation: _hasLocation,
                                isLoading: _isLoading,
                                scrollController: _scrollController,
                                onViewMap: (bodega) {
                                  setState(() {
                                    _selectedBodega = bodega;
                                    _isMapExpanded = true;
                                  });
                                },
                                onReserve: _processReservation,
                                onConfirmOrder: _processUnifiedReservation,
                                onCompleteTyping: (msg) {
                                  setState(() => msg.isAnimated = true);
                                },
                                onViewTicket: _navigateToTicket,
                              )
                            : VisualStoreView(
                                userLocation: _userLocation,
                                apiService: _apiService,
                                onSendToChat: (message) {
                                  setState(() => _appMode = AppMode.chat);
                                  _handleSubmitted(message);
                                },
                              ),
                      ),
                    ),

                    // AppBar
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildCustomAppBar(),
                    ),

                    if (_appMode == AppMode.chat)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _buildInputWrapper(),
                      ),
                  ],
                ),

                if (_isMapExpanded) _buildMapOverlay(),

                // Drawer
                buildDrawerOverlay(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return ClipRRect(
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
            color: HomeColors.background(context).withOpacity(0.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCircleBtn(Icons.menu_rounded, openDrawer),
              Expanded(
                child: Center(
                  child: CupertinoSlidingSegmentedControl<AppMode>(
                    groupValue: _appMode,
                    thumbColor: HomeColors.primary(context),
                    backgroundColor: HomeColors.surface(
                      context,
                    ).withOpacity(0.5),
                    children: {
                      AppMode.chat: _buildSegmentText("Chat", AppMode.chat),
                      AppMode.store: _buildSegmentText("Tienda", AppMode.store),
                    },
                    onValueChanged: (v) =>
                        setState(() => _appMode = v ?? AppMode.chat),
                  ),
                ),
              ),
              Row(
                children: [
                  _buildCircleBtn(
                    Icons.map_outlined,
                    () => setState(() => _isMapExpanded = true),
                  ),
                  const SizedBox(width: 8),
                  if (_appMode == AppMode.chat)
                    _buildCircleBtn(Icons.add, () async {
                      // Changed to Add
                      if (_currentUserId != null)
                        await _apiService.createNewChatSession(_currentUserId!);
                      _startNewChat();
                      _getUserLocation();
                    }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentText(String text, AppMode mode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        text,
        style: TextStyle(
          color: _appMode == mode
              ? Colors.white
              : HomeColors.textPrimary(context),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
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

  Widget _buildInputWrapper() {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight > 0 && _lastKeyboardHeight == 0 && _isChatStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isAtBottom) _scrollToBottom();
      });
    }
    _lastKeyboardHeight = keyboardHeight;
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24, top: 12),
      child: HomeInputArea(
        controller: _controller,
        focusNode: _focusNode,
        scrollController: _textFieldScrollController,
        isLoading: _isLoading,
        isTyping: _isTyping,
        onSubmitted: _handleSubmitted,
        onVoiceRecorded: _handleVoiceRecorded,
      ),
    );
  }

  Future<void> _handleVoiceRecorded(String path) async {
    setState(() {
      _isLoading = true;
      _isChatStarted = true;
      _messages.add(
        ChatMessage(
          type: MessageType.user,
          text: null,
          audioPath: path,
          results: null,
        ),
      );
      _messages.add(
        ChatMessage(
          type: MessageType.botThinking,
          text: "Procesando nota de voz...",
        ),
      );
      print(
        "DEBUG: Added user voice msg + thinking. Total messages: ${_messages.length}",
      );
    });

    try {
      final response = await _apiService.searchSmartVoice(
        audioFile: File(path),
        sessionId: _chatSessionId,
        userId: _currentUserId,
        userLat: _userLocation.latitude,
        userLon: _userLocation.longitude,
      );
      print("DEBUG: searchSmartVoice response received: ${response.message}");

      if (response.sessionId != null) {
        _chatSessionId = response.sessionId;
      }

      setState(() {
        _messages.removeLast(); // Remove thinking
        _messages.add(
          ChatMessage(
            type: response.isOrderSummary
                ? MessageType.orderSummary
                : MessageType.botResponse,
            text: response.message,
            results: response.results.isEmpty ? null : response.results,
          ),
        );
        _isLoading = false;
        print("DEBUG: Added bot response. Total messages: ${_messages.length}");
      });
      _scrollToBottom();
    } catch (e) {
      print("DEBUG: Error in _handleVoiceRecorded: $e");
      setState(() {
        _isLoading = false;
        _messages.removeLast(); // Remove thinking
        _messages.add(
          ChatMessage(
            type: MessageType.botResponse,
            text: "Error enviando audio. Intenta de nuevo.",
          ),
        );
      });
      _scrollToBottom();
    }
  }

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
              child: Container(
                margin: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        width: double.infinity,
                        child: YandexMap(
                          onMapCreated: (controller) {
                            _mapController = controller;
                            if (_selectedBodega != null)
                              _centerMapOnLocation(
                                _selectedBodega!.latitude,
                                _selectedBodega!.longitude,
                              );
                            else if (_hasLocation)
                              _centerMapOnLocation(
                                _userLocation.latitude,
                                _userLocation.longitude,
                              );
                          },
                          mapObjects: [
                            if (_userLocationMarker != null)
                              _userLocationMarker!,
                            ..._storeMarkers,
                            ..._routeObjects,
                          ],
                          nightModeEnabled: _isDarkMode,
                          mapType: _mapType,
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _isMapExpanded = false),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: HomeColors.surface(context),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
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
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () {
                                if (_hasLocation) {
                                  _centerMapOnLocation(
                                    _userLocation.latitude,
                                    _userLocation.longitude,
                                  );
                                } else {
                                  _getUserLocation();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: HomeColors.surface(context),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.my_location,
                                  color: HomeColors.primary(context),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeOutBack,
                          switchOutCurve: Curves.easeInBack,
                          transitionBuilder: (child, animation) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 1),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            );
                          },
                          child: _selectedBodega != null
                              ? _buildBodegaDetailsCard(_selectedBodega!)
                              : const SizedBox.shrink(),
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
    );
  }

  Widget _buildBodegaDetailsCard(BodegaSearchResult bodega) {
    final double rawScore = bodega.completenessScore;
    final int percentage = rawScore <= 1.0
        ? (rawScore * 100).toInt()
        : rawScore.toInt();
    final double progressValue = rawScore <= 1.0 ? rawScore : rawScore / 100.0;

    Color scoreColor;
    if (percentage < 30) {
      scoreColor = HomeColors.error;
    } else if (percentage < 70) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = HomeColors.success;
    }

    return Container(
      key: ValueKey(bodega.bodegaId),
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  bodega.name,
                  style: TextStyle(
                    color: HomeColors.textPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${bodega.distanceMeters} m",
                style: TextStyle(
                  color: HomeColors.textSecondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                "Disponibilidad:",
                style: TextStyle(
                  color: HomeColors.textSecondary(context),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                "$percentage%",
                style: TextStyle(
                  color: scoreColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: HomeColors.surfaceVariant(context),
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _processReservation(bodega),
            style: ElevatedButton.styleFrom(
              backgroundColor: HomeColors.primary(context),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Reservar Aquí",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
