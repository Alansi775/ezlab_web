// ezlab_frontend/lib/models/order_item.dart
class OrderItem {
  final int? id; // This is the order_item_id, not product_id
  final int orderId;
  final int productId;
  int quantity; // Quantity can be updated
  final double priceAtOrder;

  // Optional: If you want to display product name/image directly from order item,
  // you might include it here or fetch product details separately.
  String? productName;
  String? productImageUrl;

  OrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.priceAtOrder,
    this.productName,
    this.productImageUrl,
  });

  // Factory constructor to create an OrderItem object from a JSON map (from API)
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as int?,
      orderId: json['order_id'] as int,
      productId: json['product_id'] as int,
      quantity: json['quantity'] as int,
      priceAtOrder: (json['price_at_order'] as num).toDouble(),
      // These might come from a JOIN in your backend if you fetch detailed order items
      productName: json['product_name'] as String?,
      productImageUrl: json['product_image_url'] as String?,
    );
  }

  // Method to convert an OrderItem object to a JSON map (to send to API)
  Map<String, dynamic> toJson() {
    return {
      'id': id, // Include ID for updates, null for creation
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'price_at_order': priceAtOrder,
      // Do NOT send productName/productImageUrl to backend for item creation/update
      // as they are usually derived or for display purposes.
    };
  }

  // Method specifically for adding a new item or updating an existing one (without item ID for add)
  Map<String, dynamic> toAddItemJson() {
    return {
      'product_id': productId,
      'quantity': quantity,
      'price_at_order': priceAtOrder,
    };
  }
}