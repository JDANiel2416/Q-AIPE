// lib/models/inventory_models.dart
class ProductCreateRequest {
  final String name;
  final String category;
  final double price;
  final int stock;
  final Map<String, dynamic> attributes;

  ProductCreateRequest({
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.attributes,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'price': price,
      'stock': stock,
      'attributes': attributes,
    };
  }
}