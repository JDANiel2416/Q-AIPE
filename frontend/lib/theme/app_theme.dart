import 'package:flutter/material.dart';
import 'design_system.dart';

/// Tema de la aplicación Chek
/// Define ThemeData completo para Light y Dark mode
class AppTheme {
  // ==================== LIGHT THEME ====================

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Color Scheme
    colorScheme: ColorScheme.light(
      primary: AppDesign.primaryBlue,
      primaryContainer: AppDesign.primaryBlueLight,
      secondary: AppDesign.primaryBlueDark,
      secondaryContainer: AppDesign.primaryBlueUltraLight,
      surface: AppDesign.surfaceLight,
      surfaceContainerHighest: AppDesign.surfaceVariantLight,
      error: AppDesign.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppDesign.textPrimaryLight,
      onError: Colors.white,
      outline: AppDesign.borderLight,
    ),

    // Scaffold
    scaffoldBackgroundColor: AppDesign.backgroundLight,

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 2,
      surfaceTintColor: AppDesign.surfaceLight,
      iconTheme: const IconThemeData(color: AppDesign.textPrimaryLight),
      titleTextStyle: const TextStyle(
        color: AppDesign.textPrimaryLight,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),

    // Card
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppDesign.surfaceLight,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusLG),
        side: BorderSide(color: AppDesign.borderLight, width: 1),
      ),
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppDesign.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: AppDesign.primaryBlue.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.spaceLG,
          vertical: AppDesign.spaceMD,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),

    // Outlined Button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppDesign.primaryBlue,
        side: const BorderSide(color: AppDesign.primaryBlue, width: 1.5),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.spaceLG,
          vertical: AppDesign.spaceMD,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        ),
      ),
    ),

    // Text Button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppDesign.primaryBlue,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.spaceMD,
          vertical: AppDesign.spaceSM,
        ),
      ),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppDesign.surfaceVariantLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        borderSide: const BorderSide(color: AppDesign.primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        borderSide: const BorderSide(color: AppDesign.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        borderSide: const BorderSide(color: AppDesign.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDesign.spaceMD,
        vertical: AppDesign.spaceMD,
      ),
      hintStyle: TextStyle(color: AppDesign.textTertiaryLight, fontSize: 14),
      labelStyle: TextStyle(color: AppDesign.textSecondaryLight, fontSize: 14),
      floatingLabelStyle: const TextStyle(
        color: AppDesign.primaryBlue,
        fontSize: 14,
      ),
    ),

    // Text Theme
    textTheme: const TextTheme(
      // Display - Para títulos muy grandes
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: AppDesign.textPrimaryLight,
      ),

      // Title - Títulos de sección
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: AppDesign.textPrimaryLight,
      ),

      // Heading - Subtítulos
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppDesign.textPrimaryLight,
      ),

      // Subheading
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppDesign.textPrimaryLight,
      ),

      // Body - Texto normal
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: AppDesign.textPrimaryLight,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: AppDesign.textSecondaryLight,
      ),

      // Caption - Texto pequeño
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: AppDesign.textTertiaryLight,
      ),

      // Label - Para botones
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppDesign.textPrimaryLight,
      ),
    ),

    // Floating Action Button
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppDesign.primaryBlue,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusLG),
      ),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppDesign.borderLight,
      thickness: 1,
      space: 1,
    ),

    // Bottom Sheet
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppDesign.surfaceLight,
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDesign.radiusXXL),
        ),
      ),
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: AppDesign.surfaceLight,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusXL),
      ),
    ),
  );

  // ==================== DARK THEME ====================

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Color Scheme
    colorScheme: ColorScheme.dark(
      primary: AppDesign.primaryBlue,
      primaryContainer: AppDesign.primaryBlueDark,
      secondary: AppDesign.primaryBlue,
      secondaryContainer: AppDesign.primaryBlueDark,
      surface: AppDesign.surfaceDark,
      surfaceContainerHighest: AppDesign.surfaceVariantDark,
      error: AppDesign.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppDesign.textPrimaryDark,
      onError: Colors.white,
      outline: AppDesign.borderDark,
    ),

    // Scaffold
    scaffoldBackgroundColor: AppDesign.backgroundDark,

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 2,
      surfaceTintColor: AppDesign.surfaceDark,
      iconTheme: const IconThemeData(color: AppDesign.textPrimaryDark),
      titleTextStyle: const TextStyle(
        color: AppDesign.textPrimaryDark,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),

    // Card
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppDesign.surfaceDark,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusLG),
        side: BorderSide(color: AppDesign.borderDark, width: 1),
      ),
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppDesign.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: AppDesign.primaryBlue.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.spaceLG,
          vertical: AppDesign.spaceMD,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),

    // Outlined Button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppDesign.primaryBlueLight,
        side: const BorderSide(color: AppDesign.primaryBlueLight, width: 1.5),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.spaceLG,
          vertical: AppDesign.spaceMD,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        ),
      ),
    ),

    // Text Button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppDesign.primaryBlueLight,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.spaceMD,
          vertical: AppDesign.spaceSM,
        ),
      ),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppDesign.surfaceVariantDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        borderSide: const BorderSide(
          color: AppDesign.primaryBlueLight,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        borderSide: const BorderSide(color: AppDesign.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusMD),
        borderSide: const BorderSide(color: AppDesign.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDesign.spaceMD,
        vertical: AppDesign.spaceMD,
      ),
      hintStyle: TextStyle(color: AppDesign.textTertiaryDark, fontSize: 14),
      labelStyle: TextStyle(color: AppDesign.textSecondaryDark, fontSize: 14),
      floatingLabelStyle: const TextStyle(
        color: AppDesign.primaryBlueLight,
        fontSize: 14,
      ),
    ),

    // Text Theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: AppDesign.textPrimaryDark,
      ),
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: AppDesign.textPrimaryDark,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppDesign.textPrimaryDark,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppDesign.textPrimaryDark,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: AppDesign.textPrimaryDark,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: AppDesign.textSecondaryDark,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: AppDesign.textTertiaryDark,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppDesign.textPrimaryDark,
      ),
    ),

    // Floating Action Button
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppDesign.primaryBlue,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusLG),
      ),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppDesign.borderDark,
      thickness: 1,
      space: 1,
    ),

    // Bottom Sheet
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppDesign.surfaceDark,
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDesign.radiusXXL),
        ),
      ),
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: AppDesign.surfaceDark,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusXL),
      ),
    ),
  );
}
