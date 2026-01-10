import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/search_models.dart';
import '../models/inventory_models.dart';

class ApiService {
  static String get baseUrl {
    //if (kIsWeb) return "http://127.0.0.1:8000/api/v1";
    
    // OJO: Cambia los X por tu IP real, ejemplo: 192.168.1.15
    //if (Platform.isAndroid) return "http://192.168.0.103:8000/api/v1"; 
    
    //return "http://127.0.0.1:8000/api/v1";
    const String publicUrl = "https://fd46a89b6ce4.ngrok-free.app";
    return "$publicUrl/api/v1";
  }

  static String get host {
    return baseUrl.replaceAll("/api/v1", ""); 
  }

  Future<Map<String, dynamic>> addProduct(String userId, ProductCreateRequest product) async {
    final url = Uri.parse('$baseUrl/bodeguero/add-product?user_id=$userId');
    
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(product.toJson()),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {"success": true, "message": "Producto agregado correctamente"};
      } else if (response.statusCode == 409) {
        return {"success": false, "status": 409, "message": data['detail']};
      } else {
        return {"success": false, "message": data['detail'] ?? "Error desconocido"};
      }
    } catch (e) {
      print("Error de conexión: $e");
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }

  Future<Map<String, dynamic>> updateProduct(
    String userId, 
    String productName, 
    String category,
    double price, 
    int stock
  ) async {
    final url = Uri.parse('$baseUrl/bodeguero/update-product?user_id=$userId');
    
    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "product_name": productName,
          "category": category,
          "price": price,
          "stock": stock,
        }),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {"success": true, "message": data['message'] ?? "Producto actualizado"};
      } else {
        return {"success": false, "message": data['detail'] ?? "Error al actualizar"};
      }
    } catch (e) {
      print("Error de conexión: $e");
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }

  // NUEVO: Actualizar producto por ID con suma de stock
  Future<Map<String, dynamic>> updateProductStock(
    String userId,
    int productId,
    double price,
    int stockToAdd,
  ) async {
    final url = Uri.parse('$baseUrl/bodeguero/update-product-by-id?user_id=$userId');
    
    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "product_id": productId,
          "price": price,
          "stock_to_add": stockToAdd,
        }),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {"success": true, "message": data['message'] ?? "Producto actualizado"};
      } else {
        return {"success": false, "message": data['detail'] ?? "Error al actualizar"};
      }
    } catch (e) {
      print("Error de conexión: $e");
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }

  // Obtener perfil del bodeguero
  Future<Map<String, dynamic>> getProfile(String userId) async {
    final url = Uri.parse('$baseUrl/bodeguero/profile?user_id=$userId');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {};
    } catch (e) {
      print("Error fetching profile: $e");
      return {};
    }
  }

  // Actualizar perfil del bodeguero
  Future<Map<String, dynamic>> updateProfile(
    String userId,
    String email,
    String phone,
    String bodegaName,
  ) async {
    final url = Uri.parse('$baseUrl/bodeguero/update-profile?user_id=$userId');
    
    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "phone_number": phone,
          "bodega_name": bodegaName,
        }),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {"success": true, "message": data['message'] ?? "Perfil actualizado"};
      } else {
        return {"success": false, "message": data['detail'] ?? "Error al actualizar"};
      }
    } catch (e) {
      print("Error updating profile: $e");
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }

  // Subir foto de perfil
  Future<Map<String, dynamic>> uploadProfilePhoto(String userId, File imageFile) async {
    final url = Uri.parse('$baseUrl/bodeguero/upload-photo?user_id=$userId');
    
    try {
      final request = http.MultipartRequest('POST', url);
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          "success": true, 
          "message": data['message'] ?? "Foto actualizada",
          "photo_url": data['photo_url']
        };
      } else {
        return {"success": false, "message": data['detail'] ?? "Error al subir foto"};
      }
    } catch (e) {
      print("Error uploading photo: $e");
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }

  // Obtener pedidos
  Future<List<dynamic>> getOrders(String userId) async {
    final url = Uri.parse('$baseUrl/bodeguero/orders?user_id=$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return [];
    } catch (e) {
      print("Error fetching orders: $e");
      return [];
    }
  }

  // Actualizar estado de pedido
  Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) async {
    final url = Uri.parse('$baseUrl/bodeguero/orders/$orderId/status');
    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"status": status}),
      );
      
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      
      if (response.statusCode == 200) {
        return {"success": true, "message": data['message']};
      }
      return {"success": false, "message": "Error al actualizar"};
    } catch (e) {
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }

  // Ahora aceptamos latitud y longitud dinámicas
  Future<SmartSearchResponse> searchSmart(
      String query, 
      double userLat, 
      double userLon, 
      [String? userId, List<Map<String, String>> history = const []]
  ) async {
    final url = Uri.parse('$baseUrl/search/smart');
    
    final body = {
      "query": query,
      "user_lat": userLat,
      "user_lon": userLon,
      if (userId != null) "user_id": userId,
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


  Future<dynamic> getMyInventory(String userId) async {
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

  Future<Map<String, dynamic>> createReservation(
    String userId, 
    String bodegaId, 
    List<dynamic> items
  ) async {
    final url = Uri.parse('$baseUrl/reservations/create');
    
    // Transformamos los items al formato que espera el backend
    final formattedItems = items.map((item) {
      // Si es un mapa (por si acaso), usamos [], si es objeto usamos .propiedad
      // Pero como en Dart no podemos usar [] en objetos que no lo soportan sin error,
      // asumimos que es ProductItem ya que eso envía el home_screen.
      
      // Opcion segura: reflection o dynamic check, pero lo más simple es asumir objeto
      // dado que es lo que enviamos desde HomeScreen.
      return {
        "product_name": (item as dynamic).name, 
        "quantity": (item as dynamic).requestedQuantity,
        "unit_price": (item as dynamic).price,
      };
    }).toList();

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "bodega_id": bodegaId,
          "items": formattedItems
        }),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return data;
      } else {
        return {"success": false, "message": data["detail"] ?? "Error al reservar"};
      }
    } catch (e) {
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }

}