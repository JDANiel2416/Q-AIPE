import 'package:flutter/material.dart';

/// Helper de colores dinámicos para las pantallas del Bodeguero.
/// Los colores se resuelven automáticamente según el tema actual (Light/Dark).
/// 
/// Uso: BColors.background(context), BColors.primary(context), etc.
class BColors {
  BColors._(); // Prevenir instanciación
  
  // ==================== FONDOS ====================
  
  /// Fondo principal de la pantalla
  static Color background(BuildContext ctx) => 
    Theme.of(ctx).scaffoldBackgroundColor;
  
  /// Superficie para cards y contenedores
  static Color surface(BuildContext ctx) => 
    Theme.of(ctx).colorScheme.surface;
  
  /// Variante de superficie (para inputs, badges secundarios)
  static Color surfaceVariant(BuildContext ctx) => 
    Theme.of(ctx).colorScheme.surfaceContainerHighest;
  
  // ==================== COLOR PRIMARIO ====================
  
  /// Color primario (azul)
  static Color primary(BuildContext ctx) => 
    Theme.of(ctx).colorScheme.primary;
  
  /// Variante clara del primario (para fondos con tinte azul)
  static Color primaryLight(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return isDark 
      ? const Color(0xFF1A3A5C) // Azul oscuro para dark mode
      : const Color(0xFFE6F0FF); // Azul claro para light mode
  }
  
  /// Variante oscura del primario
  static Color primaryDark(BuildContext ctx) => 
    Theme.of(ctx).colorScheme.secondary;
  
  // ==================== TEXTOS ====================
  
  /// Texto principal (títulos, contenido importante)
  static Color textPrimary(BuildContext ctx) => 
    Theme.of(ctx).colorScheme.onSurface;
  
  /// Texto secundario (subtítulos, descripciones)
  static Color textSecondary(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return isDark 
      ? const Color(0xFFB0B0B0) 
      : const Color(0xFF6B7280);
  }
  
  /// Texto muted/terciario (hints, placeholders)
  static Color textMuted(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return isDark 
      ? const Color(0xFF707070) 
      : const Color(0xFF9CA3AF);
  }
  
  // ==================== BORDES Y DIVISORES ====================
  
  /// Color de bordes
  static Color border(BuildContext ctx) => 
    Theme.of(ctx).colorScheme.outline;
  
  /// Color de divisores
  static Color divider(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return isDark 
      ? const Color(0xFF1F1F1F) 
      : const Color(0xFFF3F4F6);
  }
  
  // ==================== ESTADOS SEMÁNTICOS ====================
  
  /// Color de éxito (verde)
  static const Color success = Color(0xFF10B981);
  
  /// Color de error (rojo)
  static const Color error = Color(0xFFEF4444);
  
  /// Color de advertencia (amarillo/naranja)
  static const Color warning = Color(0xFFF59E0B);
  
  // ==================== SOMBRAS ====================
  
  /// Sombra ligera
  static Color shadowLight(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return isDark 
      ? Colors.black.withOpacity(0.3) 
      : Colors.black.withOpacity(0.04);
  }
  
  /// Sombra media
  static Color shadowMedium(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return isDark 
      ? Colors.black.withOpacity(0.5) 
      : Colors.black.withOpacity(0.08);
  }
  
  // ==================== HELPERS ====================
  
  /// Retorna true si el tema actual es oscuro
  static bool isDark(BuildContext ctx) => 
    Theme.of(ctx).brightness == Brightness.dark;
  
  /// Gradiente primario (para botones, badges destacados)
  static LinearGradient primaryGradient(BuildContext ctx) {
    return LinearGradient(
      colors: [primary(ctx), primaryDark(ctx)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// Color de overlay para glassmorphism
  static Color glassOverlay(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return isDark 
      ? Colors.white.withOpacity(0.05) 
      : Colors.white.withOpacity(0.7);
  }
  
  /// Borde para glassmorphism
  static Color glassBorder(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return isDark 
      ? Colors.white.withOpacity(0.1) 
      : Colors.white.withOpacity(0.5);
  }
}
