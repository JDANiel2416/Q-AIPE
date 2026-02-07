import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/search_models.dart';
import '../models/inventory_models.dart';
import '../models/notification_model.dart';

class ApiService {
  static String get baseUrl {
    //if (kIsWeb) return "http://127.0.0.1:8000/api/v1";

    // OJO: Cambia los X por tu IP real, ejemplo: 192.168.1.15
    //if (Platform.isAndroid) return "http://192.168.0.103:8000/api/v1";

    //return "http://127.0.0.1:8000/api/v1";
    const String publicUrl =
        "https://ayden-applicatory-untremblingly.ngrok-free.dev";
    return "$publicUrl/api/v1";
  }

  static String get host {
    return baseUrl.replaceAll("/api/v1", "");
  }

  Future<Map<String, dynamic>> addProduct(
    String userId,
    ProductCreateRequest product,
  ) async {
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
        return {
          "success": false,
          "status": 409,
          "message": data['detail'],
          "product_id": data['product_id'],
        };
      } else {
        return {
          "success": false,
          "message": data['detail'] ?? "Error desconocido",
        };
      }
    } catch (e) {
      print("Error de conexión: $e");
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }

  // Bodeguero: Buscar productos en master (Autocomplete)
  Future<List<Map<String, dynamic>>> searchMasterProducts(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/bodeguero/master-products/search?q=$query'),
      headers: {"Content-Type": "application/json; charset=utf-8"},
    );

    if (response.statusCode == 200) {
      // Decode with UTF8
      final List<dynamic> list = json.decode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(list);
    } else {
      return [];
    }
  }

  Future<Map<String, dynamic>> updateProduct(
    String userId,
    String productName,
    String category,
    double price,
    int stock,
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
        return {
          "success": true,
          "message": data['message'] ?? "Producto actualizado",
        };
      } else {
        return {
          "success": false,
          "message": data['detail'] ?? "Error al actualizar",
        };
      }
    } catch (e) {
      print("Error de conexión: $e");
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }

  // NUEVO: Obtener categorías completas (Dynamic Frontend)
  Future<List<CategoryModel>> getCategories() async {
    final url = Uri.parse('$baseUrl/bodeguero/categories');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((e) => CategoryModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching categories: $e");
      return [];
    }
  }

  // NUEVO: Obtener subcategorías
  Future<List<SubCategoryModel>> getSubCategories(int categoryId) async {
    final url = Uri.parse(
      '$baseUrl/bodeguero/categories/$categoryId/subcategories',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((e) => SubCategoryModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching subcategories: $e");
      return [];
    }
  }

  // NUEVO: Actualizar producto por ID con suma de stock
  Future<Map<String, dynamic>> updateProductStock(
    String userId,
    int productId,
    double price,
    int stockToAdd,
  ) async {
    final url = Uri.parse(
      '$baseUrl/bodeguero/update-product-by-id?user_id=$userId',
    );

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
        return {
          "success": true,
          "message": data['message'] ?? "Producto actualizado",
        };
      } else {
        return {
          "success": false,
          "message": data['detail'] ?? "Error al actualizar",
        };
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
        return {
          "success": true,
          "message": data['message'] ?? "Perfil actualizado",
        };
      } else {
        return {
          "success": false,
          "message": data['detail'] ?? "Error al actualizar",
        };
      }
    } catch (e) {
      print("Error updating profile: $e");
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }

  // Subir foto de perfil
  Future<Map<String, dynamic>> uploadProfilePhoto(
    String userId,
    File imageFile,
  ) async {
    final url = Uri.parse('$baseUrl/bodeguero/upload-photo?user_id=$userId');

    try {
      final request = http.MultipartRequest('POST', url);
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": data['message'] ?? "Foto actualizada",
          "photo_url": data['photo_url'],
        };
      } else {
        return {
          "success": false,
          "message": data['detail'] ?? "Error al subir foto",
        };
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

  // NUEVO: Obtener un pedido específico por ID (para navegación desde notificaciones)
  Future<Map<String, dynamic>> getOrderById(String orderId) async {
    final url = Uri.parse('$baseUrl/bodeguero/orders/$orderId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {};
    } catch (e) {
      print("Error fetching order by id: $e");
      return {};
    }
  }

  // Actualizar estado de pedido
  Future<Map<String, dynamic>> updateOrderStatus(
    String orderId,
    String status,
  ) async {
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

  // Cancelar pedido (Cliente)
  Future<bool> cancelOrder(String orderId, String userId) async {
    final url = Uri.parse(
      '$baseUrl/client/orders/$orderId/cancel?user_id=$userId',
    );
    try {
      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json"},
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error cancelling order: $e");
      return false;
    }
  }

  // NUEVO: Escaneo Mágico con IA
  Future<Map<String, dynamic>> scanMagicProduct(File imageFile) async {
    final url = Uri.parse('$baseUrl/bodeguero/scan-magic');

    try {
      final request = http.MultipartRequest('POST', url);
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          "success": true,
          "ai_data": data['ai_data'],
          "found_master_id": data['found_master_id'],
        };
      } else {
        return {
          "success": false,
          "message": data['detail'] ?? "Error al analizar imagen",
        };
      }
    } catch (e) {
      print("Error scanning product: $e");
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }

  // NUEVO: Escaneo Masivo
  Future<Map<String, dynamic>> scanBulkProducts(File imageFile) async {
    final url = Uri.parse('$baseUrl/bodeguero/scan-bulk');

    try {
      final request = http.MultipartRequest('POST', url);
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return data; // Retorna {"products":List}
      } else {
        return {
          "error": true,
          "message": data['detail'] ?? "Error desconocido",
        };
      }
    } catch (e) {
      return {"error": true, "message": "Error de conexión: $e"};
    }
  }

  // Ahora aceptamos latitud y longitud dinámicas
  Future<SmartSearchResponse> searchSmart(
    String query,
    double userLat,
    double userLon, [
    String? userId,
    List<Map<String, String>> history = const [],
    String? sessionId, // <--- Added sessionId
  ]) async {
    final url = Uri.parse('$baseUrl/search/smart');

    final body = {
      "query": query,
      "user_lat": userLat,
      "user_lon": userLon,
      if (userId != null) "user_id": userId,
      if (sessionId != null) "session_id": sessionId, // <--- Send it
      "conversation_history": history,
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

  Future<SmartSearchResponse> searchSmartVoice({
    required File audioFile,
    String? sessionId,
    String? userId,
    double? userLat,
    double? userLon,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/search/smart/voice');

      Map<String, String> queryParams = {};
      if (sessionId != null) queryParams['session_id'] = sessionId;
      if (userId != null) queryParams['user_id'] = userId;
      if (userLat != null) queryParams['user_lat'] = userLat.toString();
      if (userLon != null) queryParams['user_lon'] = userLon.toString();

      if (queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      var request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('file', audioFile.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return SmartSearchResponse.fromJson(
          json.decode(utf8.decode(response.bodyBytes)),
        );
      } else {
        throw Exception('Failed to send voice: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error sending voice: $e');
    }
  }

  // --- NUEVO: Actualizar mensaje del chat (Persistencia) ---
  Future<bool> updateChatMessage(
    String messageId,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('$baseUrl/chat/messages/$messageId');
    try {
      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error updating chat message: $e");
      return false;
    }
  }

  // --- NUEVO: AUTH ---

  Future<Map<String, dynamic>> consultDni(
    String dni, {
    String? firstName,
    String? lastName,
  }) async {
    final url = Uri.parse('$baseUrl/auth/consult_dni');
    try {
      print("🔵 Enviando DNI a: $url");

      final Map<String, dynamic> body = {"dni": dni};
      if (firstName != null) body["first_name"] = firstName;
      if (lastName != null) body["last_name"] = lastName;

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      print("🟢 Respuesta Backend (${response.statusCode}): ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {"success": false, "message": "Error de conexión"};
      }
    } catch (e) {
      print("🔴 Error en ApiService: $e");
      return {"success": false, "message": "Error: $e"};
    }
  }

  Future<Map<String, dynamic>> registerUser(
    String dni,
    String password,
    String phone,
    String role, {
    String? bodegaName,
    double? lat,
    double? lon, // Parámetros opcionales
  }) async {
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
          "role": data["role"], // <--- ¡No dejes que se pierda!
        };
      } else {
        return {
          "success": false,
          "message": data["detail"] ?? "Error al registrar",
        };
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
        body: jsonEncode({"product_id": productId, "in_stock": inStock}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateBodegaStatus(String userId, bool isOpen) async {
    final url = Uri.parse('$baseUrl/bodeguero/status?user_id=$userId');
    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"is_open": isOpen}),
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
        return {
          "success": false,
          "message": data["detail"] ?? "Error de acceso",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Error: $e"};
    }
  }

  Future<Map<String, dynamic>> createReservation(
    String userId,
    String bodegaId,
    List<dynamic> items, {
    String deliveryType = "PICKUP",
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    bool isManual = false,
  }) async {
    final url = Uri.parse('$baseUrl/reservations/create');

    // Transformamos los items al formato que espera el backend
    final formattedItems = items.map((item) {
      // Handle both Map<String, dynamic> (from ManualSaleScreen) and objects (from HomeScreen)
      if (item is Map<String, dynamic>) {
        return {
          "product_id": item['productId'] ?? item['product_id'],
          "product_name": item['name'] ?? item['product_name'],
          "quantity": item['requestedQuantity'] ?? item['quantity'],
          "unit_price": item['price'] ?? item['unit_price'],
        };
      } else {
        // Object with properties (ProductItem from HomeScreen)
        return {
          "product_id": (item as dynamic).productId,
          "product_name": (item as dynamic).name,
          "quantity": (item as dynamic).requestedQuantity,
          "unit_price": (item as dynamic).price,
        };
      }
    }).toList();

    // Construir body con campos de delivery
    final body = {
      "user_id": userId,
      "bodega_id": bodegaId,
      "items": formattedItems,
      "delivery_type": deliveryType,
      "is_manual": isManual,
    };

    if (deliveryAddress != null) body["delivery_address"] = deliveryAddress;
    if (deliveryLat != null) body["delivery_lat"] = deliveryLat;
    if (deliveryLng != null) body["delivery_lng"] = deliveryLng;

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return data;
      } else {
        return {
          "success": false,
          "message": data["detail"] ?? "Error al reservar",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }

  // Eliminar producto por ID
  Future<bool> deleteProduct(String userId, int productId) async {
    final url = Uri.parse(
      '$baseUrl/bodeguero/delete-product?user_id=$userId&product_id=$productId',
    );

    try {
      final response = await http.delete(url);
      return response.statusCode == 200;
    } catch (e) {
      print("Error deleting product: $e");
      return false;
    }
  }

  // Registrar token Push (OneSignal Player ID)
  Future<bool> registerOneSignalToken(String userId, String oneSignalId) async {
    // Reutilizamos el endpoint existente de FCM para guardar el ID de OneSignal
    // ya que la estructura en BD es la misma (un string en User.fcm_token)
    final url = Uri.parse('$baseUrl/auth/register-fcm-token');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "fcm_token": oneSignalId, // Enviamos el OneSignal ID aquí
        }),
      );

      if (response.statusCode == 200) {
        print("✅ OneSignal ID registered successfully: $oneSignalId");
        return true;
      } else {
        print("❌ Failed to register OneSignal ID: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error registering OneSignal ID: $e");
      return false;
    }
  }

  // Registrar token FCM para notificaciones push (LEGADO)
  Future<bool> registerFcmToken(String userId, String fcmToken) async {
    return registerOneSignalToken(userId, fcmToken);
  }

  // NUEVO: Obtener estadísticas del dashboard
  Future<Map<String, dynamic>> getDashboardStats(String userId) async {
    final url = Uri.parse('$baseUrl/bodeguero/dashboard-stats?user_id=$userId');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {};
    } catch (e) {
      print("Error fetching dashboard stats: $e");
      return {};
    }
  }

  // --- CLIENTE: Perfil, Chats, Pedidos ---

  /// Obtener perfil del usuario (nombre, email, etc.)
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final url = Uri.parse('$baseUrl/client/profile?user_id=$userId');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {};
    } catch (e) {
      print("Error fetching user profile: $e");
      return {};
    }
  }

  /// Obtener lista de chats del usuario
  Future<List<dynamic>> getUserChats(String userId) async {
    final url = Uri.parse('$baseUrl/client/chats?user_id=$userId');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return [];
    } catch (e) {
      print("Error fetching user chats: $e");
      return [];
    }
  }

  /// Crear nueva sesión de chat (para recargar)
  Future<Map<String, dynamic>> createNewChatSession(String userId) async {
    final url = Uri.parse('$baseUrl/client/chats/new?user_id=$userId');

    try {
      final response = await http.post(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {};
    } catch (e) {
      print("Error creating new chat session: $e");
      return {};
    }
  }

  /// Obtener mensajes de un chat específico
  Future<Map<String, dynamic>> getChatMessages(
    String userId,
    String sessionId,
  ) async {
    final url = Uri.parse(
      '$baseUrl/client/chats/$sessionId/messages?user_id=$userId',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {};
    } catch (e) {
      print("Error fetching chat messages: $e");
      return {};
    }
  }

  /// Obtener historial de pedidos pagados
  Future<List<dynamic>> getUserOrders(String userId) async {
    final url = Uri.parse('$baseUrl/client/orders?user_id=$userId');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return [];
    } catch (e) {
      print("Error fetching user orders: $e");
      return [];
    }
  }

  // Validar reserva con QR
  Future<Map<String, dynamic>> validateReservation(
    String qrData,
    String bodegaId,
  ) async {
    final url = Uri.parse('$baseUrl/reservations/validate');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"qr_data": qrData, "bodega_id": bodegaId}),
      );

      // Manejar códigos de error 4xx como respuestas válidas (ej: "ya validado")
      if (response.statusCode == 200 ||
          response.statusCode == 400 ||
          response.statusCode == 403 ||
          response.statusCode == 404) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {
          "success": false,
          "message": "Error del servidor (${response.statusCode})",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Error de conexión: $e"};
    }
  }

  /// Activar un chat específico (marcarlo como actual)
  Future<Map<String, dynamic>> activateChatSession(
    String userId,
    String sessionId,
  ) async {
    final url = Uri.parse(
      '$baseUrl/client/chats/$sessionId/activate?user_id=$userId',
    );

    try {
      final response = await http.put(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {};
    } catch (e) {
      print("Error activating chat session: $e");
      return {};
    }
  }

  /// Eliminar un chat específico
  Future<Map<String, dynamic>> deleteChatSession(
    String userId,
    String sessionId,
  ) async {
    final url = Uri.parse('$baseUrl/client/chats/$sessionId?user_id=$userId');

    try {
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {"deleted": false};
    } catch (e) {
      print("Error deleting chat session: $e");
      return {"deleted": false};
    }
  }

  /// Obtener el chat activo actual (o crear uno nuevo si no existe)
  Future<Map<String, dynamic>> getCurrentChatSession(String userId) async {
    final url = Uri.parse('$baseUrl/client/chats/current?user_id=$userId');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {};
    } catch (e) {
      print("Error getting current chat: $e");
      return {};
    }
  }

  /// Eliminar token FCM al cerrar sesión (evita notificaciones cruzadas)
  Future<bool> unregisterFcmToken(String userId) async {
    final url = Uri.parse('$baseUrl/auth/unregister-fcm-token');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error unregistering FCM token: $e");
      return false;
    }
  }

  /// Validar si un número de teléfono ya está registrado
  Future<Map<String, dynamic>> validatePhone(String phone) async {
    final url = Uri.parse('$baseUrl/auth/validate-phone');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": phone}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {"available": false, "message": "Error al validar teléfono"};
      }
    } catch (e) {
      print("Error validating phone: $e");
      return {"available": false, "message": "Error de conexión: $e"};
    }
  }

  /// Obtener lista de deudores (clientes con fiado)
  Future<Map<String, dynamic>> getDebtors(String userId) async {
    final url = Uri.parse('$baseUrl/bodeguero/debtors?user_id=$userId');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {"total_credit": 0.0, "debtors_count": 0, "debtors": []};
    } catch (e) {
      print("Error fetching debtors: $e");
      return {"total_credit": 0.0, "debtors_count": 0, "debtors": []};
    }
  }

  /// Obtener detalle de pedidos fiados de un cliente específico
  Future<Map<String, dynamic>> getDebtorOrders(
    String userId,
    String debtorId,
  ) async {
    final url = Uri.parse(
      '$baseUrl/bodeguero/debtors/$debtorId/orders?user_id=$userId',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {"orders": []};
    } catch (e) {
      print("Error fetching debtor orders: $e");
      return {"orders": []};
    }
  }

  // --- NUEVO: Tienda Visual ---
  Future<List<Map<String, dynamic>>> getVisualStoreProducts({
    required String category,
    required double lat,
    required double lon,
    double radiusKm = 1.0,
  }) async {
    final url = Uri.parse(
      '$baseUrl/search/visual-store?category=$category&lat=$lat&lon=$lon&radius_km=$radiusKm',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print("Error fetching visual store products: $e");
      return [];
    }
  }

  // Nueva API para Categorías en Tienda
  Future<List<Map<String, dynamic>>> getSearchCategories() async {
    final url = Uri.parse('$baseUrl/search/categories');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print("Error fetching search categories: $e");
      return [];
    }
  }

  // ============================================================
  // DELIVERY SETTINGS API
  // ============================================================

  /// Obtener configuración de delivery de una bodega
  Future<Map<String, dynamic>> getDeliverySettings(String bodegaId) async {
    final url = Uri.parse(
      '$baseUrl/bodeguero/bodega/$bodegaId/delivery-settings',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {
        'has_delivery': false,
        'delivery_fee': 3.00,
        'delivery_radius_km': 2.0,
      };
    } catch (e) {
      print("Error fetching delivery settings: $e");
      return {
        'has_delivery': false,
        'delivery_fee': 3.00,
        'delivery_radius_km': 2.0,
      };
    }
  }

  /// Actualizar configuración de delivery de una bodega
  Future<Map<String, dynamic>> updateDeliverySettings(
    String bodegaId,
    bool hasDelivery,
    double deliveryFee,
    double deliveryRadiusKm,
  ) async {
    final url = Uri.parse(
      '$baseUrl/bodeguero/bodega/$bodegaId/delivery-settings',
    );
    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'has_delivery': hasDelivery,
          'delivery_fee': deliveryFee,
          'delivery_radius_km': deliveryRadiusKm,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'success': false, 'message': 'Error updating settings'};
    } catch (e) {
      print("Error updating delivery settings: $e");
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Verificar si una ubicación está en el rango de delivery
  Future<Map<String, dynamic>> checkDeliveryCoverage(
    String bodegaId,
    double userLat,
    double userLng,
  ) async {
    final url = Uri.parse(
      '$baseUrl/bodeguero/delivery/check-coverage?bodega_id=$bodegaId&user_lat=$userLat&user_lng=$userLng',
    );
    try {
      final response = await http.post(url);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {'in_range': false, 'reason': 'Error checking coverage'};
    } catch (e) {
      print("Error checking delivery coverage: $e");
      return {'in_range': false, 'reason': e.toString()};
    }
  }

  // --- NOTIFICATION ENDPOINTS ---

  Future<List<NotificationModel>> getNotifications(String userId) async {
    final url = Uri.parse('$baseUrl/notifications/?user_id=$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((e) => NotificationModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching notifications: $e");
      return [];
    }
  }

  Future<bool> markNotificationRead(String userId, int notificationId) async {
    final url = Uri.parse(
      '$baseUrl/notifications/$notificationId/read?user_id=$userId',
    );
    try {
      final response = await http.post(url);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markAllNotificationsRead(String userId) async {
    final url = Uri.parse('$baseUrl/notifications/read-all?user_id=$userId');
    try {
      final response = await http.post(url);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Get product by ID (for stock alert navigation)
  Future<Map<String, dynamic>?> getProductById(
    String userId,
    int productId,
  ) async {
    final url = Uri.parse(
      '$baseUrl/bodeguero/get-product/$productId?user_id=$userId',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['product'];
      }
      return null;
    } catch (e) {
      print("Error fetching product: $e");
      return null;
    }
  }
}
