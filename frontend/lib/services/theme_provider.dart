import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton para gestionar el tema de la aplicación (Light/Dark).
/// Usa ValueNotifier para notificar cambios sin necesidad de Provider.
/// Persiste la preferencia del usuario en SharedPreferences.
class ThemeProvider {
  static final ThemeProvider _instance = ThemeProvider._internal();
  factory ThemeProvider() => _instance;
  ThemeProvider._internal();
  
  static const String _themeKey = 'theme_mode';
  
  /// ValueNotifier que emite el ThemeMode actual
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);
  
  bool get isDarkMode => themeMode.value == ThemeMode.dark;
  
  /// Inicializa cargando la preferencia guardada. Llamar en main().
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);
      
      if (savedTheme == 'dark') {
        themeMode.value = ThemeMode.dark;
      } else {
        themeMode.value = ThemeMode.light;
      }
    } catch (e) {
      print('Error loading theme preference: $e');
    }
  }
  
  /// Alterna entre Light y Dark mode
  Future<void> toggleTheme() async {
    themeMode.value = themeMode.value == ThemeMode.light 
      ? ThemeMode.dark 
      : ThemeMode.light;
    await _saveThemeToPrefs();
  }
  
  /// Establece un tema específico
  Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode.value == mode) return;
    themeMode.value = mode;
    await _saveThemeToPrefs();
  }
  
  /// Guarda la preferencia de tema
  Future<void> _saveThemeToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _themeKey, 
        themeMode.value == ThemeMode.dark ? 'dark' : 'light'
      );
    } catch (e) {
      print('Error saving theme preference: $e');
    }
  }
}
