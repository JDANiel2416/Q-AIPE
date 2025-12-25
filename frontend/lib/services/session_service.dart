import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';

  // Guardar sesión al entrar
  Future<void> saveSession(String userId, {String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
    if (name != null) {
      await prefs.setString(_keyUserName, name);
    }
  }

  // Obtener ID (para saber si está logueado)
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  // Cerrar sesión (Borrar datos)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}