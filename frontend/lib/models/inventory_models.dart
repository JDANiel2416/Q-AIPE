// lib/models/inventory_models.dart
class ProductCreateRequest {
  final String name;
  final String category;
  final int? subCategoryId; // NUEVO
  final double price;
  final int stock;
  final Map<String, dynamic> attributes;

  ProductCreateRequest({
    required this.name,
    required this.category,
    this.subCategoryId,
    required this.price,
    required this.stock,
    required this.attributes,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'subcategory_id': subCategoryId,
      'price': price,
      'stock': stock,
      'attributes': attributes,
    };
  }
}

class CategoryModel {
  final int id;
  final String name;
  final String? icon;

  CategoryModel({required this.id, required this.name, this.icon});

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
    );
  }
}

class SubCategoryModel {
  final int id;
  final String name;

  SubCategoryModel({required this.id, required this.name});

  factory SubCategoryModel.fromJson(Map<String, dynamic> json) {
    return SubCategoryModel(id: json['id'], name: json['name']);
  }
}
