// lib/basket.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ezlab_frontend/constants.dart';
import 'package:ezlab_frontend/customer_orders_page.dart';

class BasketPage extends StatefulWidget {
  final int cartId;
  final VoidCallback onOrderSuccess;

  const BasketPage({
    Key? key,
    required this.cartId,
    required this.onOrderSuccess,
  }) : super(key: key);

  @override
  _BasketPageState createState() => _BasketPageState();
}

class _BasketPageState extends State<BasketPage> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  List<Map<String, dynamic>> _basketItems = [];
  double _displayTotalPrice = 0.0;
  bool _isLoading = false;
  bool _isFetchingCart = true;

  @override
  void initState() {
    super.initState();
    _fetchBasketItems();
  }

  Future<void> _fetchBasketItems() async {
    setState(() {
      _isFetchingCart = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      _showSnackBar('User not logged in.', isError: true);
      setState(() { _isFetchingCart = false; });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/cart'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        setState(() {
          _basketItems = List<Map<String, dynamic>>.from(responseBody['items'].map((item) {
            List<String> imageUrlsList = [];
            if (item['imageUrls'] is List) {
              imageUrlsList = List<String>.from(item['imageUrls'].map((url) => url.toString()));
            } else if (item['imageUrls'] is String && (item['imageUrls'] as String).isNotEmpty) {
              imageUrlsList = (item['imageUrls'] as String)
                  .split(',')
                  .where((s) => s.isNotEmpty)
                  .toList();
            }
            print('Fetched item: ${item['product_name']}, Image URLs: $imageUrlsList');

            return {
              'id': item['product_id'],
              'itemId': item['item_id'],
              'name': item['product_name'],
              'description': item['product_description'],
              'price': double.parse(item['price_at_add'].toString()),
              'quantity': item['product_stock'],
              'cartQuantity': item['cart_quantity'],
              'imageUrls': imageUrlsList,
            };
          }));
          _recalculateDisplayTotal();
        });
      } else {
        _showSnackBar('Failed to load basket: ${response.statusCode} - ${response.body}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error fetching basket: $e', isError: true);
    } finally {
      setState(() {
        _isFetchingCart = false;
      });
    }
  }

  void _recalculateDisplayTotal() {
    _displayTotalPrice = 0.0;
    for (var item in _basketItems) {
      _displayTotalPrice += (item['price'] ?? 0.0) * (item['cartQuantity'] ?? 0);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _updateCartItemQuantity(Map<String, dynamic> product, int newQuantity) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      _showSnackBar('User not logged in.', isError: true);
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/cart/update/${product['itemId']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'quantity': newQuantity}),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Item quantity updated!');
        await _fetchBasketItems();
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(errorData['message'] ?? 'Failed to update quantity.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error updating quantity: $e', isError: true);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _removeFromCart(Map<String, dynamic> product) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      _showSnackBar('User not logged in.', isError: true);
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/cart/remove/${product['itemId']}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _showSnackBar('${product['name']} removed from cart!');
        await _fetchBasketItems();
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(errorData['message'] ?? 'Failed to remove item.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error removing item: $e', isError: true);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _clearCartOnBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) return;

    try {
      await http.delete(
        Uri.parse('$baseUrl/api/cart/clear'),
        headers: {'Authorization': 'Bearer $token'},
      );
      print('Cart cleared on backend after order creation.');
    } catch (e) {
      print('Error clearing cart on backend: $e');
    }
  }

  Future<void> _handleCheckout() async {
    if (_basketItems.isEmpty) {
      _showSnackBar('Your order is empty. Add items to proceed.', isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill in all customer details.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userId = prefs.getInt('user_id');

    if (token == null || userId == null) {
      setState(() { _isLoading = false; });
      _showSnackBar('User not logged in. Please log in to create an order.', isError: true);
      return;
    }

    try {
      final orderPayload = {
        'userId': userId,
        'customerName': _customerNameController.text.trim(),
        'companyName': _companyNameController.text.trim(),
        'customerEmail': _emailController.text.trim(),
        'customerPhone': _phoneController.text.trim(),
        'orderDate': DateTime.now().toIso8601String(),
        'status': 'Pending',
        'totalAmount': _displayTotalPrice,
      };

      final createOrderResponse = await http.post(
        Uri.parse('$baseUrl/api/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(orderPayload),
      );

      if (createOrderResponse.statusCode == 201) {
        final orderData = json.decode(createOrderResponse.body);
        final orderId = orderData['orderId'];

        for (var item in _basketItems) {
          final addOrderItemResponse = await http.post(
            Uri.parse('$baseUrl/api/orders/$orderId/items'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'productId': item['id'],
              'quantity': item['cartQuantity'],
              'priceAtOrder': item['price'],
            }),
          );

          if (addOrderItemResponse.statusCode != 200) {
            print('Error adding item ${item['name']} to order: ${addOrderItemResponse.statusCode} - ${addOrderItemResponse.body}');
            _showSnackBar('Failed to add all items to the order. Some stock might not be reserved.', isError: true);
          }
        }

        _showSnackBar('Order created successfully!');
        await _clearCartOnBackend();
        widget.onOrderSuccess();
        _customerNameController.clear();
        _companyNameController.clear();
        _emailController.clear();
        _phoneController.clear();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CustomerOrdersPage()),
        );

      } else {
        final errorMessage = 'Failed to create order: ${createOrderResponse.statusCode} - ${createOrderResponse.body}';
        print('Error creating order: $errorMessage');
        _showSnackBar(errorMessage, isError: true);
      }
    } catch (e) {
      final errorMessage = 'Error during order creation: $e';
      print(errorMessage);
      _showSnackBar(errorMessage, isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Customer Order'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isFetchingCart
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
        children: [
          Expanded(
            child: _basketItems.isEmpty
                ? Center(
              child: Text(
                'Add products to create a new customer order.',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _basketItems.length,
              itemBuilder: (context, index) {
                final item = _basketItems[index];
                final availableStock = (item['quantity'] ?? 0);
                final inCartQuantity = (item['cartQuantity'] ?? 0);

                final List<String> imageUrls = (item['imageUrls'] as List<String>?) ?? [];
                String? displayImageUrl;

                if (imageUrls.isNotEmpty) {
                  final String rawImageUrl = imageUrls.first;
                  if (rawImageUrl.startsWith('http://') || rawImageUrl.startsWith('https://')) {
                    displayImageUrl = rawImageUrl;
                  } else {
                    displayImageUrl = '$baseUrl/$rawImageUrl';
                  }
                }

                print('Item: ${item['name']}, Display Image URL: $displayImageUrl');

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: AppColors.cardBackground,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (displayImageUrl != null && displayImageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              displayImageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('Image load error for ${item['name']}: $error');
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: AppColors.background,
                                  child: Icon(Icons.broken_image_rounded, color: AppColors.textSecondary),
                                );
                              },
                            ),
                          )
                        else
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.image_not_supported, color: AppColors.textSecondary),
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] ?? 'N/A',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${(item['price'] as num).toStringAsFixed(2)} per unit',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (inCartQuantity > availableStock)
                                Text(
                                  'Warning: Only $availableStock in stock!',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline, color: AppColors.accent),
                              onPressed: inCartQuantity > 1 && !_isLoading
                                  ? () => _updateCartItemQuantity(item, inCartQuantity - 1)
                                  : null,
                            ),
                            Text(
                              '$inCartQuantity',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add_circle_outline, color: AppColors.accent),
                              onPressed: inCartQuantity < availableStock && !_isLoading
                                  ? () => _updateCartItemQuantity(item, inCartQuantity + 1)
                                  : null,
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_forever_rounded, color: AppColors.danger),
                          onPressed: _isLoading ? null : () => _removeFromCart(item),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(
                    controller: _companyNameController,
                    label: 'Company Name',
                    icon: Icons.business_outlined,
                    validator: (value) => value!.isEmpty ? 'Company name is required' : null,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _customerNameController,
                    label: 'Customer Name',
                    icon: Icons.person_outline_rounded,
                    validator: (value) => value!.isEmpty ? 'Customer name is required' : null,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Customer Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value!.isEmpty ? 'Email is required' : null,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Customer Phone Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (value) => value!.isEmpty ? 'Phone number is required' : null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: \$${_displayTotalPrice.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading || _basketItems.isEmpty ? null : _handleCheckout,
                        icon: _isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.shopping_cart_checkout_rounded),
                        label: Text(_isLoading ? 'Processing...' : 'Proceed Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          elevation: 6,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.primary,
          selectionColor: AppColors.primary.withOpacity(0.3),
          selectionHandleColor: AppColors.primary,
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        cursorColor: AppColors.primary,
        style: TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textSecondary),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.textSecondary),
          ),
          prefixIcon: Icon(icon, color: AppColors.primary),
          floatingLabelStyle: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}