import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/search_models.dart';
import '../models/inventory_models.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) return "http://127.0.0.1:8000/api/v1";
    
    // OJO: Cambia los X por tu IP real, ejemplo: 192.168.1.15
    if (Platform.isAndroid) return "http://192.168.1.48:8000/api/v1"; 
    
    return "http://127.0.0.1:8000/api/v1";
  }

  Future<bool> addProduct(String userId, ProductCreateRequest product) async {
    final url = Uri.parse('$baseUrl/bodeguero/add-product?user_id=$userId');
    
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(product.toJson()),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print("Error al crear producto: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error de conexión: $e");
      return false;
    }
  }

  // Ahora aceptamos latitud y longitud dinámicas
  Future<SmartSearchResponse> searchSmart(
      String query, 
      double userLat, 
      double userLon, 
      [List<Map<String, String>> history = const []]
  ) async {
    final url = Uri.parse('$baseUrl/search/smart');
    
    final body = {
      "query": query,
      "user_lat": userLat, // Usamos las coordenadas reales del mapa
      "user_lon": userLon,
      "conversation_history": history 
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // Decodificamos utf8 para que las tildes y ñ se vean bien
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return SmartSearchResponse.fromJson(data);
      } else {
        throw Exception('Error API: ${response.statusCode}');
      }
    } catch (e) {
      print("Error: $e");
      rethrow;
    }
  }

  // --- NUEVO: AUTH ---

Future<Map<String, dynamic>> consultDni(String dni) async {
    final url = Uri.parse('$baseUrl/auth/consult_dni');
    try {
      print("🔵 Enviando DNI a: $url"); // <--- Debug
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"dni": dni}),
      );
      
      print("🟢 Respuesta Backend (${response.statusCode}): ${response.body}"); // <--- ¡AQUÍ VEREMOS EL JSON!

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {"success": false, "message": "Error de conexión"};
      }
    } catch (e) {
      print("🔴 Error en ApiService: $e"); // <--- Debug
      return {"success": false, "message": "Error: $e"};
    }
  }

  Future<Map<String, dynamic>> registerUser(
      String dni, 
      String password, 
      String phone, 
      String role, 
      {String? bodegaName, double? lat, double? lon} // Parámetros opcionales
  ) async {
    final url = Uri.parse('$baseUrl/auth/register');
    try {
      final body = {
        "dni": dni,
        "password": password,
        "phone": phone,
        "role": role,
        if (bodegaName != null) "bodega_name": bodegaName,
        if (lat != null) "latitude": lat,
        if (lon != null) "longitude": lon,
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      
      if (response.statusCode == 200) {
        return {
            "success": true, 
            "user_id": data["user_id"], 
            "role": data["role"] // <--- ¡No dejes que se pierda!
        };
      } else {
        return {"success": false, "message": data["detail"] ?? "Error al registrar"};
      }
    } catch (e) {
      return {"success": false, "message": "Error: $e"};
    }
  }


  Future<List<dynamic>> getMyInventory(String userId) async {
    final url = Uri.parse('$baseUrl/bodeguero/my-inventory?user_id=$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return [];
    } catch (e) {
      print("Error fetching inventory: $e");
      return [];
    }
  }

  Future<bool> toggleStock(String userId, int productId, bool inStock) async {
    final url = Uri.parse('$baseUrl/bodeguero/toggle-stock?user_id=$userId');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "product_id": productId,
          "in_stock": inStock
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> loginUser(String dni, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"dni": dni, "password": password}),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      
      if (response.statusCode == 200) {
        return data; // Retorna success: true, user_id, etc.
      } else {
        return {"success": false, "message": data["detail"] ?? "Error de acceso"};
      }
    } catch (e) {
      return {"success": false, "message": "Error: $e"};
    }
  }

}