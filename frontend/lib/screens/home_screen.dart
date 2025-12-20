import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final List<ChatMessage> _messages = [];
  
  bool _isChatStarted = false;
  bool _isTyping = false;
  bool _isLoading = false; // Variable para bloquear la UI mientras carga

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
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- FUNCIÓN PARA CONSTRUIR EL HISTORIAL ---
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
    if (text.isEmpty || _isLoading) return; // Bloqueo si está cargando

    HapticFeedback.lightImpact();

    // 1. Capturamos el historial ANTES de agregar el nuevo mensaje (para no duplicarlo)
    final history = _buildHistoryPayload();

    setState(() {
      _isChatStarted = true;
      _isLoading = true; // Activamos bloqueo
      _messages.add(ChatMessage(type: MessageType.user, text: text));
      _messages.add(ChatMessage(type: MessageType.botThinking));
      _isTyping = false;
    });
    
    _controller.clear();
    _scrollToBottom();

    try {
      // 2. Enviamos query + historial al Backend
      final response = await ApiService.searchSmart(text, history);

      setState(() {
        _messages.removeLast(); // Quitamos "Pensando..."

        // Agregamos la respuesta completa (Mensaje + Resultados)
        _messages.add(ChatMessage(
          type: MessageType.botResponse,
          text: response.message, 
          results: response.results.isEmpty ? null : response.results,
        ));
      });
    } catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(
          type: MessageType.botResponse,
          text: "Tuve un problema de conexión con las bodegas. Intenta de nuevo por favor.",
          results: null,
        ));
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Desbloqueamos UI
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
      resizeToAvoidBottomInset: false, // Evita que el fondo se mueva con el teclado
      body: Stack(
        children: [
          // 1. FONDO AMBIENTAL
          const RepaintBoundary(child: AmbientBackground()),

          // 2. CONTENIDO
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
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
            });
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
            const Text("Hola Vecino,",
                style: TextStyle(color: Colors.white54, fontSize: 20, fontWeight: FontWeight.w300)),
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
      // --- MENSAJE DE USUARIO ---
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
      // --- ESTADO PENSANDO ---
      return Row(
        children: [
          const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4D6FFF))),
          const SizedBox(width: 12),
          Text("Consultando en el barrio...", style: TextStyle(color: Colors.white.withOpacity(0.5), fontStyle: FontStyle.italic)),
        ],
      );
    } else {
      // --- RESPUESTA DEL BOT (TEXTO + RESULTADOS) ---
       return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           // 1. Burbuja de texto (El mensaje humano de Q-AIPE)
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
           
           // 2. Tarjetas de productos (Si existen resultados)
           if (msg.results != null && msg.results!.isNotEmpty)
             ...msg.results!.map((b) => _buildBodegaCard(b)),
        ],
      );
    }
  }

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
          // Header Bodega
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
                      Text("A 100m • ⭐ 4.8", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
                Text("S/ ${bodega.totalPrice.toStringAsFixed(2)}", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          
          // Items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: bodega.foundItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.greenAccent.withOpacity(0.7), size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.name, style: TextStyle(color: Colors.grey[400], fontSize: 14))),
                    Text("x1", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              )).toList(),
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
              // BLOQUEO: Deshabilitar input si está cargando
              enabled: !_isLoading,
              style: TextStyle(color: _isLoading ? Colors.white38 : Colors.white),
              cursorColor: const Color(0xFF4D6FFF),
              decoration: InputDecoration(
                hintText: _isLoading ? "Buscando, dame un momento..." : "Escribe tu pedido...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              ),
              onSubmitted: (_) => _handleSubmitted(),
            ),
          ),
          
          // Botón de Enviar con Estado de Carga
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              // El color cambia para indicar estado activo/inactivo
              color: (_isTyping || _isLoading) ? const Color(0xFF4D6FFF) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isLoading 
                // Spinner giratorio si está cargando
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