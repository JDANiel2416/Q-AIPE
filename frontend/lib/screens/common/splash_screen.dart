import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/session_service.dart';
import '../user/home_screen.dart';
import 'login_screen.dart';
import '../bodeguero/dashboard_screen.dart';

// REPLICANDO PALETA DE COLORES (COPIA DE HOME_SCREEN PARA CONSISTENCIA)
class AppColors {
  // Fondos
  static const Color background = Color(0xFFF9FAFB);        
  static const Color surface = Color(0xFFFFFFFF);           
  
  // Color primario (azul vibrante #0062ff)
  static const Color primary = Color(0xFF0062FF);           
  static const Color primaryLight = Color(0xFFE6F0FF);      
  
  // Textos
  static const Color textPrimary = Color(0xFF111827);       
  static const Color textSecondary = Color(0xFF6B7280);     
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
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
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Animaciones de entrada
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
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
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                color: AppColors.primaryLight.withOpacity(0.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
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
                                AppColors.primaryLight,
                                Colors.white,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // TEXTO MARCA
                        const Text(
                          "Chek",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Tu bodega favorita, al toque.",
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
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
                            color: AppColors.primary,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Text(
                          _status,
                          style: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.8),
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
            child: Center(
              child: Text(
                "v1.0.0",
                style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}