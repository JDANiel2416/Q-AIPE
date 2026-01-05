import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'home_screen.dart'; // Para navegar al final
import '../services/session_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Historial del chat de registro
  final List<Map<String, dynamic>> _messages = [
    {"role": "bot", "text": "¡Habla, vecino! 👋 Soy Q-AIPE.\nPara empezar, ¿me dictas tu número de DNI?"}
  ];

  // Pasos: 0=DNI, 1=Confirmar Nombre, 2=Celular, 3=Password, 4=Listo
  int _step = 0; 
  bool _isLoading = false;
  String _tempDni = "";
  String _tempPhone = "";

  void _handleInput(String text) async {
    if (text.isEmpty) return;
    
    // Agregamos mensaje del usuario
    setState(() {
      _messages.add({"role": "user", "text": text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    // Lógica según el paso actual
    try {
      if (_step == 0) {
        // PASO 0: Validar DNI
        if (text.length != 8) {
          _botSay("El DNI debe tener 8 dígitos, intenta de nuevo.");
          setState(() => _isLoading = false);
          return;
        }
        
        _botSay("Buscando en Reniec...", isThinking: true);
        final res = await _apiService.consultDni(text);
        _removeThinking();

        if (res["success"] == true) {
          _tempDni = text;
          _step = 1;
          
          // --- CORRECCIÓN AQUÍ 👇 ---
          // 1. Extraemos el nombre de forma segura (si es null, pone "Vecino")
          String name = (res['masked_name'] ?? "Vecino").toString();
          
          // 2. Usamos esa variable segura
          _botSay("Encontré a **$name**. ¿Eres tú? (Escribe 'sí' o 'no')");
          // --------------------------
          
        } else {
          // --- CORRECCIÓN TAMBIÉN AQUÍ (Por seguridad) 👇 ---
          String errorMsg = (res["message"] ?? "No encontré ese DNI").toString();
          _botSay(errorMsg);
        }

      } else if (_step == 1) {
        // PASO 1: Confirmación
        if (text.toLowerCase().contains("si") || text.toLowerCase().contains("sí")) {
          _step = 2;
          _botSay("¡Chévere! 🤙 Ahora pásame tu número de celular para contactarte.");
        } else {
          _step = 0;
          _botSay("Uy, perdón. ¿Cuál es tu DNI correcto entonces?");
        }
        setState(() => _isLoading = false);

      } else if (_step == 2) {
        // PASO 2: Celular
        if (text.length < 9) {
           _botSay("Mmm, ese número parece corto. Intenta de nuevo.");
           setState(() => _isLoading = false);
           return;
        }
        _tempPhone = text;
        _step = 3;
        _botSay("Casi listos. Crea una contraseña segura para tu cuenta.");
        setState(() => _isLoading = false);

      } else if (_step == 3) {
        // PASO 3: Contraseña y Registro Final
        _botSay("Creando tu cuenta...", isThinking: true);
        final res = await _apiService.registerUser(_tempDni, text, _tempPhone); // password = text
        _removeThinking();

        if (res["success"] == true) {
          await SessionService().saveSession((res["user_id"] ?? "").toString());
          _botSay("¡Bienvenido al barrio! 🚀\nEntrando...");
          await Future.delayed(const Duration(seconds: 1));
          
          if (mounted) {
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (_) => const HomeScreen())
            );
          }
        } else {
           _botSay("Error: ${res['message']}. Intenta otra contraseña o empieza de nuevo.");
        }
      }
    } catch (e, stackTrace) { // <--- Agregamos stackTrace para ver más detalles
      _removeThinking();
      print("🔴 ERROR REAL: $e"); // <--- ¡Chismoso activado!
      print("📜 TRAZA: $stackTrace");
      _botSay("Error interno: $e"); // Muestra el error en el chat también
    }
  }

  void _botSay(String text, {bool isThinking = false}) {
    setState(() {
      _messages.add({
        "role": isThinking ? "thinking" : "bot", 
        "text": text
      });
      if (!isThinking) _isLoading = false;
    });
    _scrollToBottom();
  }

  void _removeThinking() {
    setState(() {
      _messages.removeWhere((m) => m["role"] == "thinking");
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      body: Stack(
        children: [
          // Reusamos el fondo animado del Home (asegúrate de que HomeScreen lo exporte o copia la clase)
          const RepaintBoundary(child: AmbientBackground()), 
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Logo simple
                const Icon(Icons.security, color: Colors.white24, size: 40),
                const SizedBox(height: 10),
                
                // Área de Chat
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => _buildMsg(_messages[i]),
                  ),
                ),

                // Input
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black12,
                  child: TextField(
                    controller: _controller,
                    enabled: !_isLoading,
                    obscureText: _step == 3, // Ocultar texto solo si pide contraseña
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _step == 3 ? "Tu contraseña..." : "Escribe aquí...",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send, color: Colors.blueAccent),
                        onPressed: () => _handleInput(_controller.text.trim()),
                      ),
                    ),
                    onSubmitted: (val) => _handleInput(val.trim()),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMsg(Map<String, dynamic> msg) {
    bool isBot = msg["role"] == "bot" || msg["role"] == "thinking";
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isBot ? Colors.white.withOpacity(0.1) : const Color(0xFF4D6FFF).withOpacity(0.8),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isBot ? Radius.zero : const Radius.circular(20),
            bottomRight: isBot ? const Radius.circular(20) : Radius.zero,
          ),
        ),
        child: msg["role"] == "thinking"
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(msg["text"], style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}