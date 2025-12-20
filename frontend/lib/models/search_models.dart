import 'dart:convert';

class ProductItem {
  final int productId;
  final String name;
  final double price;
  final double stock;
  final String unit;

  ProductItem({required this.productId, required this.name, required this.price, required this.stock, required this.unit});

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      productId: json['product_id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      stock: (json['stock'] as num).toDouble(),
      unit: json['unit'],
    );
  }
}

class BodegaSearchResult {
  final String bodegaId;
  final String name;
  final double completenessScore;
  final double totalPrice;
  final List<ProductItem> foundItems;

  BodegaSearchResult({
    required this.bodegaId, required this.name, required this.completenessScore,
    required this.totalPrice, required this.foundItems
  });

  factory BodegaSearchResult.fromJson(Map<String, dynamic> json) {
    return BodegaSearchResult(
      bodegaId: json['bodega_id'],
      name: json['name'],
      completenessScore: (json['completeness_score'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
      foundItems: (json['found_items'] as List).map((i) => ProductItem.fromJson(i)).toList(),
    );
  }
}

// --- NUEVO MODELO DE RESPUESTA ---
class SmartSearchResponse {
  final String message; // El mensaje humano de Gemini
  final List<BodegaSearchResult> results;

  SmartSearchResponse({required this.message, required this.results});

  factory SmartSearchResponse.fromJson(Map<String, dynamic> json) {
    return SmartSearchResponse(
      message: json['message'] ?? "Aquí tienes los resultados.",
      results: (json['results'] as List).map((i) => BodegaSearchResult.fromJson(i)).toList(),
    );
  }
}