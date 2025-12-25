class ProductItem {
  final int productId;
  final String name;
  final double price;
  final double stock;
  final String unit;

  ProductItem({
    required this.productId, 
    required this.name, 
    required this.price, 
    required this.stock, 
    required this.unit
  });

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
  
  // --- CAMPOS NECESARIOS PARA EL MAPA ---
  final double latitude;
  final double longitude;
  final int distanceMeters;
  final bool isOpen;

  BodegaSearchResult({
    required this.bodegaId, 
    required this.name, 
    required this.completenessScore,
    required this.totalPrice, 
    required this.foundItems,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.isOpen,
  });

  factory BodegaSearchResult.fromJson(Map<String, dynamic> json) {
    return BodegaSearchResult(
      bodegaId: json['bodega_id'] ?? '',
      name: json['name'] ?? 'Bodega',
      completenessScore: (json['completeness_score'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      foundItems: (json['found_items'] as List?)
          ?.map((i) => ProductItem.fromJson(i))
          .toList() ?? [],
          
      // Lectura segura de coordenadas
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: json['distance_meters'] ?? 0,
      isOpen: json['is_open'] ?? false,
    );
  }
}

class SmartSearchResponse {
  final String message;
  final List<BodegaSearchResult> results;

  SmartSearchResponse({required this.message, required this.results});

  factory SmartSearchResponse.fromJson(Map<String, dynamic> json) {
    return SmartSearchResponse(
      message: json['message'] ?? "Resultados:",
      results: (json['results'] as List?)
          ?.map((i) => BodegaSearchResult.fromJson(i))
          .toList() ?? [],
    );
  }
}