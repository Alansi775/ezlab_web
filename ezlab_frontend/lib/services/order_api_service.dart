// ezlab_frontend/lib/services/order_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart'; // Ensure this path is correct for your baseUrl
import '../models/order.dart';
import '../models/order_item.dart';

class OrderApiService {
  final String _baseUrl = baseUrl; // From constants.dart

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Helper for making authenticated requests
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Authentication token not found. Please log in.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Creates a new draft order.
  /// Expects a map like: {'customer_name': '...', 'notes': '...', 'user_id': ...}
  Future<Order> createOrder(Map<String, dynamic> orderData) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/orders'),
        headers: headers,
        body: json.encode(orderData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return Order.fromJson(responseData['order']); // Assuming backend returns {'order': {...}}
      } else {
        throw Exception('Failed to create order: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  /// Fetches a specific order by its ID, including its items.
  Future<Order> getOrderDetails(int orderId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/orders/$orderId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return Order.fromJson(responseData['order']); // Assuming backend returns {'order': {...}}
      } else {
        throw Exception('Failed to fetch order details: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching order details: $e');
      rethrow;
    }
  }

  /// Fetches all orders.
  Future<List<Order>> getAllOrders() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/orders'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> rawOrders = json.decode(response.body);
        return rawOrders.map((json) => Order.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch orders: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching all orders: $e');
      rethrow;
    }
  }

  /// Adds a new item to an existing order.
  /// Expects a map like: {'product_id': ..., 'quantity': ..., 'price_at_order': ...}
  Future<OrderItem> addItemToOrder(int orderId, Map<String, dynamic> itemData) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/orders/$orderId/items'),
        headers: headers,
        body: json.encode(itemData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return OrderItem.fromJson(responseData['orderItem']); // Assuming backend returns {'orderItem': {...}}
      } else {
        throw Exception('Failed to add item to order: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error adding item to order: $e');
      rethrow;
    }
  }

  /// Updates the quantity of an existing order item.
  /// Expects a map like: {'quantity': ...}
  Future<OrderItem> updateOrderItemQuantity(int orderId, int itemId, int quantity) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/api/orders/$orderId/items/$itemId'),
        headers: headers,
        body: json.encode({'quantity': quantity}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return OrderItem.fromJson(responseData['orderItem']);
      } else {
        throw Exception('Failed to update order item quantity: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error updating order item quantity: $e');
      rethrow;
    }
  }

  /// Removes an item from an order.
  Future<void> removeItemFromOrder(int orderId, int itemId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/orders/$orderId/items/$itemId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to remove order item: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error removing order item: $e');
      rethrow;
    }
  }

  /// Updates the status of an order.
  /// status must be one of: 'Draft', 'Pending', 'Confirmed', 'Shipped', 'Cancelled'
  Future<Order> updateOrderStatus(int orderId, OrderStatus newStatus) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/api/orders/$orderId/status'),
        headers: headers,
        body: json.encode({'status': newStatus.toString().split('.').last.toLowerCase()}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return Order.fromJson(responseData['order']);
      } else {
        throw Exception('Failed to update order status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error updating order status: $e');
      rethrow;
    }
  }
}