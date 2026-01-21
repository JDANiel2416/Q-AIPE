import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // <--- GPS
import 'package:permission_handler/permission_handler.dart'; // <--- Permisos
import '../services/push_notification_service.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'product_management_screen.dart';
import 'dashboard_screen.dart';
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
  
  final List<Map<String, dynamic>> _messages = [
    {"role": "bot", "text": "¡Habla, vecino! 👋 Soy Chek.\nPara empezar, ¿me dictas tu número de DNI?"}
  ];

  // Pasos: 0=DNI, 1=Nombre, 2=Celular, 3=Password, 4=ROL, 5=BodegaData
  int _step = 0; 
  bool _isLoading = false;
  bool _isLoginMode = false;

  // Datos temporales
  String _tempDni = "";
  String _tempPhone = "";
  String _tempPass = "";
  String _tempRole = "CLIENT"; // Por defecto
  
  // Datos de Bodega
  String? _tempBodegaName;
  double? _tempLat;
  double? _tempLon;

  void _handleInput(String text) async {
    if (text.isEmpty && _step != 5) return; // En paso 5 permitimos botones sin texto
    
    // Si no es un botón de acción (GPS/Rol), agregamos el mensaje del usuario
    if (_step != 4 && _step != 5) {
      setState(() {
        // Ocultar contraseña en el chat (mostrar asteriscos)
        final displayText = (_step == 3) ? "••••••••" : text;
        _messages.add({"role": "user", "text": displayText});
        _isLoading = true;
      });
      _controller.clear();
      _scrollToBottom();
    }

    try {
      if (_step == 0) { // DNI
        if (text.length != 8) {
           _botSay("El DNI debe tener 8 dígitos."); return;
        }
        _botSay("Verificando...", isThinking: true);
        final res = await _apiService.consultDni(text);
        _removeThinking();

        if (res["success"] == true) {
          _tempDni = text;
          bool exists = res['exists'] == true;
          String name = (res['masked_name'] ?? "Vecino").toString();

          if (exists) {
            _isLoginMode = true; 
            _step = 3; 
            _botSay("¡Hola $name! 👋 Ingresa tu contraseña.");
          } else {
            _isLoginMode = false;
            _step = 1;
            _botSay("Encontré a $name. ¿Eres tú? (Sí/No)");
          }
        } else {
          _botSay("Error al consultar DNI.");
        }

      } else if (_step == 1) { // Confirmar Nombre
        if (text.toLowerCase().contains("si") || text.toLowerCase().contains("sí")) {
          _step = 2;
          _botSay("Chévere. Pásame tu número de celular.");
        } else {
          _step = 0;
          _botSay("Uy. ¿Cuál es el DNI correcto?");
        }
        setState(() => _isLoading = false);

      } else if (_step == 2) { // Celular
        _tempPhone = text;
        _step = 3;
        _botSay("Crea una contraseña segura.");
        setState(() => _isLoading = false);

      } else if (_step == 3) { // Password
        _tempPass = text;
        
        if (_isLoginMode) {
          // --- LOGIN DIRECTO ---
          _botSay("Validando...", isThinking: true);
          final res = await _apiService.loginUser(_tempDni, _tempPass);
          _removeThinking();
          if (res["success"] == true) _loginSuccess(res);
          else _botSay("Contraseña incorrecta 🚫.");
        } else {
          // --- SELECCIÓN DE ROL ---
          _step = 4;
          // Mostramos botones especiales (no texto)
          _botSay("Una última cosa: ¿Cómo vas a usar la app?");
          setState(() => _isLoading = false); // Habilitamos para que vea botones
        }

      } else if (_step == 5) { // Nombre de Bodega
        _tempBodegaName = text;
        _step = 6; // Paso final oculto (GPS)
        _botSay("Perfecto, **$_tempBodegaName**. Ahora necesito verificar tu ubicación exacta para evitar fraudes.");
        setState(() => _isLoading = false);
      }

    } catch (e) {
      _removeThinking();
      _botSay("Error: $e");
    }
  }

  // Selección de Rol
  void _selectRole(String role) {
    setState(() {
      _messages.add({"role": "user", "text": role == "BODEGUERO" ? "Quiero Vender" : "Quiero Comprar"});
      _tempRole = role;
    });

    if (role == "CLIENT") {
      // Registrar Cliente
      _finalizeRegister();
    } else {
      // Flujo Bodeguero
      _step = 5;
      _botSay("¡Excelente emprendedor! 🏪\n¿Cuál es el nombre de tu Bodega?");
    }
  }

  // Obtener GPS
  Future<void> _getGpsLocation() async {
    setState(() => _isLoading = true);
    _messages.add({"role": "user", "text": "📍 Enviando mi ubicación..."});
    
    // 1. Pedir permiso
    var status = await Permission.location.request();
    if (status.isDenied) {
      _botSay("Necesito permiso de GPS para registrar tu bodega.");
      return;
    }

    try {
      // 2. Obtener posición
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _tempLat = position.latitude;
      _tempLon = position.longitude;

      _botSay("Ubicación capturada: $_tempLat, $_tempLon ✅");
      
      // 3. Registrar Bodeguero
      _finalizeRegister();

    } catch (e) {
      _botSay("Error obteniendo GPS: $e. Asegúrate de tenerlo prendido.");
    }
  }

  void _finalizeRegister() async {
    _botSay("Creando cuenta...", isThinking: true);
    final res = await _apiService.registerUser(
      _tempDni, _tempPass, _tempPhone, _tempRole,
      bodegaName: _tempBodegaName, lat: _tempLat, lon: _tempLon
    );
    _removeThinking();

    if (res["success"] == true) {
      _loginSuccess(res);
    } else {
      _botSay("Error: ${res['message']}");
    }
  }

  void _botSay(String text, {bool isThinking = false}) {
    setState(() {
      _messages.add({"role": isThinking ? "thinking" : "bot", "text": text});
      if (!isThinking) _isLoading = false;
    });
    _scrollToBottom();
  }

  void _removeThinking() {
    setState(() => _messages.removeWhere((m) => m["role"] == "thinking"));
  }


  void _loginSuccess(Map<String, dynamic> res) async {
    // Guardar ID y ROL
    await SessionService().saveSession(
      (res["user_id"] ?? "").toString(),
      role: res["role"], // Guardamos el rol que viene del backend
    );
    
    // REGISTRAR TOKEN FCM PARA NOTIFICACIONES
    if (res['role'] == 'BODEGUERO') {
      await PushNotificationService().registerTokenForUser((res["user_id"] ?? "").toString());
    }
    
    _botSay("¡Bienvenido! 🚀");
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      if (res['role'] == "BODEGUERO" || _tempDni == "22222222") { 
         Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      } else {
         Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _messages.length,
                itemBuilder: (ctx, i) => _buildMsg(_messages[i]),
              ),
            ),
            
            // ÁREA DE INPUTS DINÁMICA
            if (_step == 4) ...[
              // BOTONES DE ROL
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(child: ElevatedButton(onPressed: () => _selectRole("CLIENT"), child: const Text("Soy Comprador"))),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), onPressed: () => _selectRole("BODEGUERO"), child: const Text("Soy Bodeguero"))),
                  ],
                ),
              )
            ] else if (_step == 6) ...[
              // BOTÓN DE GPS
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)),
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text("Validar Ubicación GPS"),
                  onPressed: _getGpsLocation,
                ),
              )
            ] else ...[
              // INPUT DE TEXTO NORMAL
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black12,
                child: TextField(
                  controller: _controller,
                  enabled: !_isLoading,
                  obscureText: _step == 3, 
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: _step == 5 ? "Nombre de tu bodega..." : "Escribe aquí...",
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
            ]
          ],
        ),
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
          color: isBot ? Colors.white.withOpacity(0.1) : (msg["role"] == "user" && msg["text"].contains("Vender") ? Colors.orange : const Color(0xFF4D6FFF).withOpacity(0.8)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: msg["role"] == "thinking"
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(msg["text"], style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}