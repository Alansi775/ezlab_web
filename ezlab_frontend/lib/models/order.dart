// ezlab_frontend/lib/models/order.dart
import 'order_item.dart'; // We will create this next

enum OrderStatus {
  draft,
  pending,
  confirmed,
  shipped,
  cancelled,
  unknown, // For handling unexpected status values
}

class Order {
  final int? id;
  final int userId;
  final String customerName;
  final DateTime orderDate;
  final OrderStatus status;
  final double totalAmount;
  final String? notes;
  List<OrderItem>? items; // List of items in this order

  Order({
    this.id,
    required this.userId,
    required this.customerName,
    required this.orderDate,
    this.status = OrderStatus.draft, // Default status
    this.totalAmount = 0.0,
    this.notes,
    this.items,
  });

  // Factory constructor to create an Order object from a JSON map (from API)
  factory Order.fromJson(Map<String, dynamic> json) {
    // Convert status string from backend to OrderStatus enum
    OrderStatus parsedStatus;
    try {
      parsedStatus = OrderStatus.values.firstWhere(
            (e) => e.toString().split('.').last.toLowerCase() == (json['status'] as String).toLowerCase(),
        orElse: () => OrderStatus.unknown,
      );
    } catch (e) {
      parsedStatus = OrderStatus.unknown;
      print('Warning: Unknown order status received: ${json['status']}');
    }

    return Order(
      id: json['id'] as int?,
      userId: json['user_id'] as int,
      customerName: json['customer_name'] as String,
      orderDate: DateTime.parse(json['order_date'] as String),
      status: parsedStatus,
      totalAmount: (json['total_amount'] as num).toDouble(),
      notes: json['notes'] as String?,
      // Recursively parse order items if they exist
      items: json['items'] != null
          ? (json['items'] as List)
          .map((itemJson) => OrderItem.fromJson(itemJson))
          .toList()
          : null,
    );
  }

  // Method to convert an Order object to a JSON map (to send to API)
  Map<String, dynamic> toJson() {
    return {
      'id': id, // Include ID for updates, null for creation
      'user_id': userId,
      'customer_name': customerName,
      'order_date': orderDate.toIso8601String(),
      'status': status.toString().split('.').last.toLowerCase(), // Convert enum back to string
      'total_amount': totalAmount,
      'notes': notes,
      'items': items?.map((item) => item.toJson()).toList(), // Convert items to JSON
    };
  }

  // Method to convert an Order object to a JSON map for creating/updating the main order data (without items, if needed)
  Map<String, dynamic> toCreateUpdateJson() {
    return {
      'user_id': userId,
      'customer_name': customerName,
      'order_date': orderDate.toIso8601String(),
      'status': status.toString().split('.').last.toLowerCase(),
      'total_amount': totalAmount,
      'notes': notes,
    };
  }
}