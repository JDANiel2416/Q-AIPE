import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart'; // Import para limpiar FCM token

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

  // Cerrar sesión (Borrar datos y limpiar FCM token)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    
    // IMPORTANTE: Limpiar FCM token ANTES de borrar el userId
    final userId = prefs.getString(_keyUserId);
    if (userId != null && userId.isNotEmpty) {
      try {
        await ApiService().unregisterFcmToken(userId);
        print("🔓 FCM Token eliminado del servidor");
      } catch (e) {
        print("⚠️ Error limpiando FCM token: $e");
      }
    }
    
    await prefs.clear();
  }
}