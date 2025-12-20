import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/search_models.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) return "http://127.0.0.1:8000/api/v1";
    if (Platform.isAndroid) return "http://10.0.2.2:8000/api/v1"; 
    return "http://127.0.0.1:8000/api/v1";
  }

  // Ahora pedimos el historial (history) como parámetro
  static Future<SmartSearchResponse> searchSmart(String query, List<Map<String, String>> history) async {
    final url = Uri.parse('$baseUrl/search/smart');
    
    final body = {
      "query": query,
      "user_lat": -8.0783,
      "user_lon": -79.1180,
      "conversation_history": history // <--- Enviamos historial al backend
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
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
}