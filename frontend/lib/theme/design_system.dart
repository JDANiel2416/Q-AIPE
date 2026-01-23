import 'package:flutter/material.dart';

/// Sistema de Diseño Central de Chek
/// Define todos los valores de diseño: colores, espaciado, bordes, sombras, animaciones
class AppDesign {
  // ==================== COLORES ====================
  
  // Azul Principal (Basado en #0062ff)
  static const Color primaryBlue = Color(0xFF0062FF);
  static const Color primaryBlueDark = Color(0xFF0052D9);
  static const Color primaryBlueLight = Color(0xFF3D89FF);
  static const Color primaryBlueUltraLight = Color(0xFFE6F0FF);
  
  // Fondos (Light Mode)
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceVariantLight = Color(0xFFF1F5F9);
  static const Color borderLight = Color(0xFFE2E8F0);
  
  // Fondos (Dark Mode - AMOLED Pure Black)
  static const Color backgroundDark = Color(0xFF000000);  // Negro puro AMOLED
  static const Color surfaceDark = Color(0xFF0D0D0D);     // Casi negro para cards
  static const Color surfaceVariantDark = Color(0xFF1A1A1A); // Gris muy oscuro
  static const Color surfaceElevatedDark = Color(0xFF242424); // Para modales/overlays
  static const Color borderDark = Color(0xFF2A2A2A);      // Borde sutil
  
  // Textos (Light Mode)
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textTertiaryLight = Color(0xFF94A3B8);
  static const Color textDisabledLight = Color(0xFFCBD5E1);
  
  // Textos (Dark Mode)
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textTertiaryDark = Color(0xFF94A3B8);
  static const Color textDisabledDark = Color(0xFF64748B);
  
  // Estados Semánticos
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF0062FF);
  
  // ==================== GRADIENTES ====================
  
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0062FF), Color(0xFF00C6FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient subtleGradient = LinearGradient(
    colors: [Color(0xFFE6F0FF), Color(0xFFFFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // ==================== ESPACIADO (8pt Grid) ====================
  
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;
  static const double spaceXXL = 48.0;
  
  // ==================== BORDER RADIUS ====================
  
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;
  static const double radiusFull = 9999.0; // Para círculos perfectos
  
  // ==================== ELEVACIONES (SOMBRAS) ====================
  
  static List<BoxShadow> elevation1 = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];
  
  static List<BoxShadow> elevation2 = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> elevation3 = [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> elevation4 = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
  
  // Sombra con color primario (para botones)
  static List<BoxShadow> elevationPrimary = [
    BoxShadow(
      color: primaryBlue.withOpacity(0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  // ==================== DURACIONES DE ANIMACIÓN ====================
  
  static const Duration durationInstant = Duration(milliseconds: 100);
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 400);
  
  // ==================== CURVAS DE ANIMACIÓN ====================
  
  static const Curve curveSpring = Curves.easeOutCubic;
  static const Curve curveBounce = Curves.elasticOut;
  static const Curve curveSmooth = Curves.easeInOutCubic;
  static const Curve curveEmphasized = Curves.easeOutQuart;
}
