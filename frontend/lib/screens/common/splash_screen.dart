import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/session_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../user/home_screen.dart';
import 'login_screen.dart';
import '../bodeguero/dashboard_screen.dart';

import '../../theme/design_system.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  String _status = "Iniciando...";
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Configurar Status Bar Transparente
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            Brightness.dark, // Se ajustará automáticamente en real
        systemNavigationBarColor:
            Colors.transparent, // Transparente para edge-to-edge
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Animaciones de entrada
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
    _checkFirstTimeAndPermissions();
  }

  Future<void> _checkFirstTimeAndPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Usamos una key única para verificar si ya pedimos permisos
      final bool hasRequested =
          prefs.getBool('initial_permissions_requested_v1') ?? false;

      if (!hasRequested) {
        setState(() => _status = "Configurando permisos...");

        // Pedimos todos los permisos de una vez
        await [
          Permission.locationWhenInUse,
          Permission.microphone,
          Permission.notification,
          Permission.camera,
        ].request();

        // Marcar como solicitados para no pedir de nuevo en cada inicio
        await prefs.setBool('initial_permissions_requested_v1', true);
      }
    } catch (e) {
      print("⚠️ Error solicitando permisos iniciales: $e");
    }

    // Continuar con el flujo normal
    _checkSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkSession() async {
    try {
      setState(() => _status = "Verificando sesión...");

      // Delay estético para ver la animación
      await Future.delayed(const Duration(milliseconds: 1500));

      String? userId;
      String? role;

      try {
        final session = SessionService();
        userId = await session.getUserId().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );

        if (userId != null) {
          role = await session.getUserRole().timeout(
            const Duration(seconds: 2),
            onTimeout: () => null,
          );
        }
      } catch (e) {
        print("⚠️ Error en SessionService: $e");
      }

      if (!mounted) return;

      setState(() => _status = "Redirigiendo...");
      await Future.delayed(const Duration(milliseconds: 300));

      // Navegación con animación suave (Fade)
      Widget nextScreen;
      if (userId != null && userId.isNotEmpty) {
        if (role == "BODEGUERO") {
          nextScreen = const DashboardScreen();
        } else {
          nextScreen = const HomeScreen();
        }
      } else {
        nextScreen = const LoginScreen();
      }

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => nextScreen,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _status = "Error: $e");
        await Future.delayed(const Duration(seconds: 2));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppDesign.backgroundDark
          : AppDesign.backgroundLight,
      body: Stack(
        children: [
          // Fondo decorativo sutil
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? AppDesign.primaryBlueDark.withOpacity(0.1)
                    : AppDesign.primaryBlueUltraLight.withOpacity(0.5),
                boxShadow: [
                  BoxShadow(
                    color: AppDesign.primaryBlue.withOpacity(0.1),
                    blurRadius: 50,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // LOGO ICONO
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                isDark
                                    ? AppDesign.primaryBlueDark
                                    : AppDesign.primaryBlueUltraLight,
                                isDark
                                    ? AppDesign.surfaceVariantDark
                                    : Colors.white,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppDesign.primaryBlue.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 48,
                            color: AppDesign.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // TEXTO MARCA
                        Text(
                          "Chek",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppDesign.textPrimaryDark
                                : AppDesign.textPrimaryLight,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Tu bodega favorita, al toque.",
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark
                                ? AppDesign.textSecondaryDark
                                : AppDesign.textSecondaryLight,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        const SizedBox(height: 48),

                        // INDICADOR DE CARGA
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppDesign.primaryBlue,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          _status,
                          style: TextStyle(
                            color:
                                (isDark
                                        ? AppDesign.textSecondaryDark
                                        : AppDesign.textSecondaryLight)
                                    .withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Versión o footer
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  isDark
                      ? "assets/images/Background_Dark.png"
                      : "assets/images/Background_Ligth.png",
                  height: 60,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                Text(
                  "v2.8.0",
                  style: TextStyle(
                    color:
                        (isDark
                                ? AppDesign.textSecondaryDark
                                : AppDesign.textSecondaryLight)
                            .withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
