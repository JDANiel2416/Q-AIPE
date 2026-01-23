import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart'; // <--- OneSignal Import
// import '../../services/push_notification_service.dart'; // Ya no se usa aquí
import '../../services/api_service.dart';
import '../user/home_screen.dart';
import '../bodeguero/product_management_screen.dart';
import '../bodeguero/dashboard_screen.dart';
import '../../services/session_service.dart';
import '../../theme/design_system.dart';
import '../../theme/animations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {

  final ApiService _apiService = ApiService();
  
  // Controllers
  final TextEditingController _dniController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bodegaNameController = TextEditingController();
  
  // Focus Nodes
  final FocusNode _dniFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  
  // Animation Controllers
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  
  // Estados
  int _step = 0; // 0=DNI, 1=Password(login), 2=Confirmar nombre, 3=Celular, 4=Password(registro), 5=Rol, 6=BodegaName, 7=GPS
  bool _isLoading = false;
  bool _isLoginMode = false;
  String? _errorMessage;
  String? _successMessage;
  
  // Datos temporales
  String _tempDni = "";
  String _maskedName = "";
  String _tempRole = "CLIENT";
  double? _tempLat;
  double? _tempLon;
  
  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: AppDesign.durationNormal,
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: AppDesign.curveEmphasized,
    ));
    _slideController.forward();
  }
  
  @override
  void dispose() {
    _dniController.dispose();
    _passController.dispose();
    _phoneController.dispose();
    _bodegaNameController.dispose();
    _dniFocus.dispose();
    _passFocus.dispose();
    _phoneFocus.dispose();
    _slideController.dispose();
    super.dispose();
  }
  
  void _clearMessages() {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });
  }
  
  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _successMessage = null;
      _isLoading = false;
    });
  }
  
  void _showSuccess(String message) {
    setState(() {
      _successMessage = message;
      _errorMessage = null;
    });
  }
  
  Future<void> _animateToNextStep(int nextStep) async {
    await _slideController.reverse();
    setState(() => _step = nextStep);
    _slideController.forward();
  }
  
  // PASO 1: Validar DNI
  Future<void> _validateDni() async {
    final dni = _dniController.text.trim();
    
    if (dni.length != 8) {
      _showError("El DNI debe tener 8 dígitos");
      return;
    }
    
    _clearMessages();
    setState(() => _isLoading = true);
    
    try {
      final res = await _apiService.consultDni(dni);
      
      if (res["success"] == true) {
        _tempDni = dni;
        bool exists = res['exists'] == true;
        _maskedName = (res['masked_name'] ?? "Usuario").toString();
        
        if (exists) {
          // Usuario existe -> Login
          _isLoginMode = true;
          _showSuccess("¡Hola, $_maskedName!");
          await _animateToNextStep(1);
          _passFocus.requestFocus();
        } else {
          // Usuario no existe -> Confirmar nombre para registro
          _isLoginMode = false;
          await _animateToNextStep(2);
        }
      } else {
        _showError("Error al consultar DNI. Intenta de nuevo.");
      }
    } catch (e) {
      _showError("Error de conexión: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  // PASO 2: Login con contraseña
  Future<void> _login() async {
    final password = _passController.text.trim();
    
    if (password.isEmpty) {
      _showError("Ingresa tu contraseña");
      return;
    }
    
    _clearMessages();
    setState(() => _isLoading = true);
    
    try {
      final res = await _apiService.loginUser(_tempDni, password);
      
      if (res["success"] == true) {
        _showSuccess("¡Bienvenido!");
        await Future.delayed(const Duration(milliseconds: 500));
        _loginSuccess(res);
      } else {
        _showError("Contraseña incorrecta");
        _passController.clear();
      }
    } catch (e) {
      _showError("Error de conexión");
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  // PASO 3: Confirmar nombre (registro)
  void _confirmName(bool isCorrect) async {
    if (isCorrect) {
      await _animateToNextStep(3);
      _phoneFocus.requestFocus();
    } else {
      _dniController.clear();
      _showError("Por favor, verifica tu número de DNI");
      await _animateToNextStep(0);
    }
  }
  
  // PASO 4: Guardar teléfono y pedir contraseña
  Future<void> _savePhone() async {
    final phone = _phoneController.text.trim();
    
    if (phone.length < 9) {
      _showError("Ingresa un número válido de 9 dígitos");
      return;
    }
    
    _clearMessages();
    setState(() => _isLoading = true);
    
    try {
      // Validar si el teléfono ya está registrado
      final res = await _apiService.validatePhone(phone);
      
      if (res["available"] == false) {
        _showError("Este número ya está asociado a otra cuenta");
        setState(() => _isLoading = false);
        return;
      }
      
      // Si está disponible, continuar
      setState(() => _isLoading = false);
      await _animateToNextStep(4);
      _passFocus.requestFocus();
    } catch (e) {
      _showError("Error al validar teléfono");
      setState(() => _isLoading = false);
    }
  }
  
  // PASO 5: Guardar contraseña y elegir rol
  Future<void> _savePasswordAndSelectRole() async {
    final password = _passController.text.trim();
    
    if (password.length < 6) {
      _showError("La contraseña debe tener al menos 6 caracteres");
      return;
    }
    
    _clearMessages();
    await _animateToNextStep(5);
  }
  
  // PASO 6: Seleccionar rol
  void _selectRole(String role) async {
    _tempRole = role;
    
    if (role == "CLIENT") {
      // Registrar cliente directamente
      _finalizeRegister();
    } else {
      // Pedir nombre de bodega
      await _animateToNextStep(6);
    }
  }
  
  // PASO 7: Guardar nombre de bodega y pedir GPS
  Future<void> _saveBodegaName() async {
    final name = _bodegaNameController.text.trim();
    
    if (name.isEmpty) {
      _showError("Ingresa el nombre de tu bodega");
      return;
    }
    
    _clearMessages();
    await _animateToNextStep(7);
  }
  
  // PASO 8: Obtener GPS y registrar
  Future<void> _getGpsAndRegister() async {
    setState(() => _isLoading = true);
    
    var status = await Permission.location.request();
    if (status.isDenied) {
      _showError("Necesitamos permiso de ubicación para registrar tu bodega");
      setState(() => _isLoading = false);
      return;
    }
    
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      _tempLat = position.latitude;
      _tempLon = position.longitude;
      
      _showSuccess("Ubicación capturada correctamente");
      await Future.delayed(const Duration(milliseconds: 300));
      _finalizeRegister();
    } catch (e) {
      _showError("Error obteniendo ubicación. Asegúrate de tener el GPS activado.");
      setState(() => _isLoading = false);
    }
  }
  
  // Finalizar registro
  Future<void> _finalizeRegister() async {
    setState(() => _isLoading = true);
    _showSuccess("Creando tu cuenta...");
    
    try {
      final res = await _apiService.registerUser(
        _tempDni,
        _passController.text.trim(),
        _phoneController.text.trim(),
        _tempRole,
        bodegaName: _bodegaNameController.text.trim().isEmpty ? null : _bodegaNameController.text.trim(),
        lat: _tempLat,
        lon: _tempLon,
      );
      
      if (res["success"] == true) {
        _showSuccess("¡Cuenta creada exitosamente!");
        await Future.delayed(const Duration(milliseconds: 500));
        _loginSuccess(res);
      } else {
        _showError(res['message'] ?? "Error al crear cuenta");
      }
    } catch (e) {
      _showError("Error de conexión");
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _loginSuccess(Map<String, dynamic> res) async {
    final userId = (res["user_id"] ?? "").toString();
    await SessionService().saveSession(
      userId,
      role: res["role"],
    );
    
    if (res['role'] == 'BODEGUERO') {
      try {
        // 1. Vincular usuario en OneSignal (para Dashboard)
        OneSignal.login(userId);
        
        // 2. Obtener Push Subscription ID con reintentos
        // OneSignal puede tardar en generar el ID después del login
        String? pushId;
        for (int attempt = 1; attempt <= 5; attempt++) {
          pushId = OneSignal.User.pushSubscription.id;
          if (pushId != null && pushId.isNotEmpty) {
            break;
          }
          print("⏳ Esperando OneSignal ID... intento $attempt/5");
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
        if (pushId != null && pushId.isNotEmpty) {
          print("📱 OneSignal Push ID registrado: $pushId");
          await _apiService.registerOneSignalToken(userId, pushId);
        } else {
          print("⚠️ OneSignal Push ID sigue null después de 5 intentos.");
          // Registrar un listener para cuando el ID esté disponible
          OneSignal.User.pushSubscription.addObserver((state) async {
            final newId = state.current.id;
            if (newId != null && newId.isNotEmpty) {
              print("📱 OneSignal Push ID disponible (observer): $newId");
              await _apiService.registerOneSignalToken(userId, newId);
            }
          });
        }
      } catch (e) {
        print("Error configurando OneSignal: $e");
      }
    }
    
    if (mounted) {
      if (res['role'] == "BODEGUERO") {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppDesign.backgroundDark : AppDesign.backgroundLight,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppDesign.darkGradient : AppDesign.subtleGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDesign.spaceLG),
            child: Column(
              children: [
                const SizedBox(height: AppDesign.spaceXXL),
                
                // Logo
                Text(
                  'Chek',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: AppDesign.primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 48,
                  ),
                ),
                
                const SizedBox(height: AppDesign.spaceSM),
                
                // Subtítulo
                Text(
                  _getSubtitle(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppDesign.textSecondaryDark : AppDesign.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: AppDesign.spaceXXL),
                
                // Contenedor principal animado
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _slideController,
                    child: _buildCurrentStep(isDark),
                  ),
                ),
                
                // Mensajes de error/éxito
                if (_errorMessage != null || _successMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppDesign.spaceMD),
                    child: _buildMessage(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  String _getSubtitle() {
    switch (_step) {
      case 0: return "Ingresa tu DNI para comenzar";
      case 1: return "¡Hola de nuevo, $_maskedName!";
      case 2: return "¿Eres $_maskedName?";
      case 3: return "Ingresa tu número de celular";
      case 4: return "Crea una contraseña segura";
      case 5: return "¿Cómo usarás Chek?";
      case 6: return "¿Cuál es el nombre de tu bodega?";
      case 7: return "Necesitamos verificar tu ubicación";
      default: return "";
    }
  }
  
  Widget _buildCurrentStep(bool isDark) {
    switch (_step) {
      case 0: return _buildDniStep(isDark);
      case 1: return _buildPasswordStep(isDark);
      case 2: return _buildConfirmNameStep(isDark);
      case 3: return _buildPhoneStep(isDark);
      case 4: return _buildCreatePasswordStep(isDark);
      case 5: return _buildRoleStep(isDark);
      case 6: return _buildBodegaNameStep(isDark);
      case 7: return _buildGpsStep(isDark);
      default: return const SizedBox();
    }
  }
  
  Widget _buildCard(Widget child, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesign.spaceLG),
      decoration: BoxDecoration(
        color: isDark ? AppDesign.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(AppDesign.radiusXL),
        boxShadow: AppDesign.elevation2,
      ),
      child: child,
    );
  }
  
  Widget _buildDniStep(bool isDark) {
    return _buildCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "DNI",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppDesign.textSecondaryDark : AppDesign.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDesign.spaceSM),
          TextField(
            controller: _dniController,
            focusNode: _dniFocus,
            keyboardType: TextInputType.number,
            maxLength: 8,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 4),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: "",
              hintText: "00000000",
              hintStyle: TextStyle(
                color: (isDark ? AppDesign.textTertiaryDark : AppDesign.textTertiaryLight).withOpacity(0.5),
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
              ),
            ),
            onSubmitted: (_) => _validateDni(),
          ),
          const SizedBox(height: AppDesign.spaceLG),
          _buildPrimaryButton(
            label: "Continuar",
            onPressed: _validateDni,
            isLoading: _isLoading,
          ),
        ],
      ),
      isDark,
    );
  }
  
  Widget _buildPasswordStep(bool isDark) {
    return _buildCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DNI mostrado como badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDesign.spaceMD, vertical: AppDesign.spaceSM),
            decoration: BoxDecoration(
              color: AppDesign.primaryBlueUltraLight,
              borderRadius: BorderRadius.circular(AppDesign.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.badge_outlined, size: 16, color: AppDesign.primaryBlue),
                const SizedBox(width: AppDesign.spaceSM),
                Text(
                  "DNI: $_tempDni",
                  style: const TextStyle(
                    color: AppDesign.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDesign.spaceLG),
          
          Text(
            "Contraseña",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppDesign.textSecondaryDark : AppDesign.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDesign.spaceSM),
          TextField(
            controller: _passController,
            focusNode: _passFocus,
            obscureText: true,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              hintText: "••••••••",
              prefixIcon: Icon(Icons.lock_outline),
            ),
            onSubmitted: (_) => _login(),
          ),
          const SizedBox(height: AppDesign.spaceLG),
          _buildPrimaryButton(
            label: "Ingresar",
            onPressed: _login,
            isLoading: _isLoading,
          ),
          const SizedBox(height: AppDesign.spaceMD),
          Center(
            child: TextButton(
              onPressed: () async {
                _dniController.clear();
                _passController.clear();
                await _animateToNextStep(0);
              },
              child: const Text("Usar otro DNI"),
            ),
          ),
        ],
      ),
      isDark,
    );
  }
  
  Widget _buildConfirmNameStep(bool isDark) {
    return _buildCard(
      Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDesign.spaceLG),
            decoration: BoxDecoration(
              color: AppDesign.primaryBlueUltraLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 48, color: AppDesign.primaryBlue),
          ),
          const SizedBox(height: AppDesign.spaceLG),
          Text(
            _maskedName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? AppDesign.textPrimaryDark : AppDesign.textPrimaryLight,
            ),
          ),
          const SizedBox(height: AppDesign.spaceSM),
          Text(
            "Encontramos este nombre en RENIEC",
            style: TextStyle(
              color: isDark ? AppDesign.textSecondaryDark : AppDesign.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDesign.spaceLG),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _confirmName(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppDesign.spaceMD),
                  ),
                  child: const Text("No soy yo"),
                ),
              ),
              const SizedBox(width: AppDesign.spaceMD),
              Expanded(
                child: _buildPrimaryButton(
                  label: "Sí, soy yo",
                  onPressed: () => _confirmName(true),
                ),
              ),
            ],
          ),
        ],
      ),
      isDark,
    );
  }
  
  Widget _buildPhoneStep(bool isDark) {
    return _buildCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Número de celular",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppDesign.textSecondaryDark : AppDesign.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDesign.spaceSM),
          TextField(
            controller: _phoneController,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            maxLength: 9,
            style: const TextStyle(fontSize: 20, letterSpacing: 2),
            decoration: InputDecoration(
              counterText: "",
              hintText: "999 999 999",
              prefixIcon: const Icon(Icons.phone_android),
              prefixText: "+51 ",
              prefixStyle: TextStyle(
                fontSize: 20,
                color: isDark ? AppDesign.textPrimaryDark : AppDesign.textPrimaryLight,
              ),
            ),
            onSubmitted: (_) => _savePhone(),
          ),
          const SizedBox(height: AppDesign.spaceLG),
          _buildPrimaryButton(
            label: "Continuar",
            onPressed: _savePhone,
            isLoading: _isLoading,
          ),
        ],
      ),
      isDark,
    );
  }
  
  Widget _buildCreatePasswordStep(bool isDark) {
    return _buildCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Crea tu contraseña",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppDesign.textSecondaryDark : AppDesign.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDesign.spaceSM),
          TextField(
            controller: _passController,
            focusNode: _passFocus,
            obscureText: true,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              hintText: "Mínimo 6 caracteres",
              prefixIcon: Icon(Icons.lock_outline),
            ),
            onSubmitted: (_) => _savePasswordAndSelectRole(),
          ),
          const SizedBox(height: AppDesign.spaceMD),
          Text(
            "• Mínimo 6 caracteres\n• Guárdala en un lugar seguro",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppDesign.textTertiaryDark : AppDesign.textTertiaryLight,
            ),
          ),
          const SizedBox(height: AppDesign.spaceLG),
          _buildPrimaryButton(
            label: "Continuar",
            onPressed: _savePasswordAndSelectRole,
            isLoading: _isLoading,
          ),
        ],
      ),
      isDark,
    );
  }
  
  Widget _buildRoleStep(bool isDark) {
    return Column(
      children: [
        _buildRoleCard(
          icon: Icons.shopping_bag_outlined,
          title: "Soy Comprador",
          subtitle: "Quiero buscar productos en bodegas cercanas",
          color: AppDesign.primaryBlue,
          onTap: () => _selectRole("CLIENT"),
          isDark: isDark,
        ),
        const SizedBox(height: AppDesign.spaceMD),
        _buildRoleCard(
          icon: Icons.store_outlined,
          title: "Soy Bodeguero",
          subtitle: "Tengo una bodega y quiero vender mis productos",
          color: AppDesign.warning,
          onTap: () => _selectRole("BODEGUERO"),
          isDark: isDark,
        ),
      ],
    );
  }
  
  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDesign.spaceLG),
        decoration: BoxDecoration(
          color: isDark ? AppDesign.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(AppDesign.radiusLG),
          boxShadow: AppDesign.elevation1,
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDesign.spaceMD),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDesign.radiusMD),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: AppDesign.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppDesign.textPrimaryDark : AppDesign.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: AppDesign.spaceXS),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppDesign.textSecondaryDark : AppDesign.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBodegaNameStep(bool isDark) {
    return _buildCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Nombre de tu bodega",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppDesign.textSecondaryDark : AppDesign.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDesign.spaceSM),
          TextField(
            controller: _bodegaNameController,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              hintText: "Ej: Bodega Don Pepe",
              prefixIcon: Icon(Icons.store_outlined),
            ),
            onSubmitted: (_) => _saveBodegaName(),
          ),
          const SizedBox(height: AppDesign.spaceLG),
          _buildPrimaryButton(
            label: "Continuar",
            onPressed: _saveBodegaName,
            isLoading: _isLoading,
          ),
        ],
      ),
      isDark,
    );
  }
  
  Widget _buildGpsStep(bool isDark) {
    return _buildCard(
      Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDesign.spaceLG),
            decoration: BoxDecoration(
              color: AppDesign.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on, size: 48, color: AppDesign.success),
          ),
          const SizedBox(height: AppDesign.spaceLG),
          Text(
            "Verificar ubicación",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppDesign.textPrimaryDark : AppDesign.textPrimaryLight,
            ),
          ),
          const SizedBox(height: AppDesign.spaceSM),
          Text(
            "Necesitamos tu ubicación exacta para registrar tu bodega y que los clientes puedan encontrarte.",
            style: TextStyle(
              color: isDark ? AppDesign.textSecondaryDark : AppDesign.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDesign.spaceLG),
          _buildPrimaryButton(
            label: "Activar GPS",
            onPressed: _getGpsAndRegister,
            isLoading: _isLoading,
            icon: Icons.gps_fixed,
            color: AppDesign.success,
          ),
        ],
      ),
      isDark,
    );
  }
  
  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
    bool isLoading = false,
    IconData? icon,
    Color? color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppDesign.primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: AppDesign.spaceMD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusMD),
          ),
        ),
        child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: AppDesign.spaceSM),
                ],
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
      ),
    );
  }
  
  Widget _buildMessage() {
    final isError = _errorMessage != null;
    return Container(
      padding: const EdgeInsets.all(AppDesign.spaceMD),
      decoration: BoxDecoration(
        color: (isError ? AppDesign.error : AppDesign.success).withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        border: Border.all(
          color: (isError ? AppDesign.error : AppDesign.success).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? AppDesign.error : AppDesign.success,
            size: 20,
          ),
          const SizedBox(width: AppDesign.spaceSM),
          Expanded(
            child: Text(
              isError ? _errorMessage! : _successMessage!,
              style: TextStyle(
                color: isError ? AppDesign.error : AppDesign.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}