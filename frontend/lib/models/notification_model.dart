class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  bool isRead;
  final int? productId; // For STOCK_ALERT notifications
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.productId,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      type: json['type'],
      isRead: json['is_read'],
      productId: json['product_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
