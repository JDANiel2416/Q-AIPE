import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'home_screen.dart'; // Para navegar al final
import '../services/session_service.dart';
import 'bodeguero_screen.dart';

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

  bool _isLoginMode = false; 

  void _handleInput(String text) async {
    if (text.isEmpty) return;
    
    setState(() {
      _messages.add({"role": "user", "text": text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      if (_step == 0) {
        // PASO 0: DNI
        if (text.length != 8) {
           _botSay("El DNI debe tener 8 dígitos.");
           setState(() => _isLoading = false);
           return;
        }
        
        _botSay("Verificando...", isThinking: true);
        final res = await _apiService.consultDni(text);
        _removeThinking();

        if (res["success"] == true) {
          _tempDni = text;
          String name = (res['masked_name'] ?? "Vecino").toString();
          bool exists = res['exists'] == true; // <--- EL BACKEND NOS DICE SI EXISTE

          if (exists) {
            // --- MODO LOGIN (Usuario Antiguo) ---
            _isLoginMode = true; 
            _step = 3; // Saltamos directo a pedir contraseña
            _botSay("¡Hola de nuevo **$name**! 👋\nTe reconocí. Ingresa tu contraseña para entrar.");
          } else {
            // --- MODO REGISTRO (Usuario Nuevo) ---
            _isLoginMode = false;
            _step = 1;
            _botSay("Encontré a **$name**. ¿Eres tú? (Escribe 'sí' o 'no')");
          }
          
        } else {
          _botSay((res["message"] ?? "Error al consultar").toString());
        }

      } else if (_step == 1) {
        // Confirmar Nombre (Solo Registro)
        if (text.toLowerCase().contains("si") || text.toLowerCase().contains("sí")) {
          _step = 2;
          _botSay("Chévere. Pásame tu número de celular.");
        } else {
          _step = 0;
          _botSay("Uy. ¿Cuál es el DNI correcto?");
        }
        setState(() => _isLoading = false);

      } else if (_step == 2) {
        // Celular (Solo Registro)
        _tempPhone = text;
        _step = 3;
        _botSay("Casi listos. Crea una contraseña segura.");
        setState(() => _isLoading = false);

      } else if (_step == 3) {
        // PASO 3: CONTRASEÑA (Sirve para Login y Registro)
        
        if (_isLoginMode) {
          // >>> LÓGICA DE LOGIN <<<
          _botSay("Validando...", isThinking: true);
          final res = await _apiService.loginUser(_tempDni, text); // Usamos el nuevo endpoint
          _removeThinking();

          if (res["success"] == true) {
             _loginSuccess(res); // Función auxiliar para entrar
          } else {
             _botSay("Contraseña incorrecta 🚫. Intenta de nuevo.");
          }

        } else {
          // >>> LÓGICA DE REGISTRO <<<
          _botSay("Creando cuenta...", isThinking: true);
          final res = await _apiService.registerUser(_tempDni, text, _tempPhone);
          _removeThinking();

          if (res["success"] == true) {
             _loginSuccess(res);
          } else {
             _botSay("Error: ${res['message']}");
          }
        }
      }
    } catch (e) {
      _removeThinking();
      _botSay("Error interno: $e");
    }
  }

  // Función auxiliar para no repetir código al entrar
  void _loginSuccess(Map<String, dynamic> res) async {
    await SessionService().saveSession((res["user_id"] ?? "").toString());
    _botSay("¡Bienvenido! 🚀\nEntrando...");
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      // Redirección inteligente
      if (_tempDni == "11111111" || _tempDni == "22222222") {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BodegueroScreen()));
      } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
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