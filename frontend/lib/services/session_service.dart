import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserRole = 'user_role';

  // Guardar sesión al entrar
  Future<void> saveSession(String userId, {String? name, String? role}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
    if (name != null) {
      await prefs.setString(_keyUserName, name);
    }
    if (role != null) {
      await prefs.setString(_keyUserRole, role);
    }
  }

  // Obtener ID (para saber si está logueado)
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  // Obtener Rol
  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole);
  }

  // Cerrar sesión (Borrar datos)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}