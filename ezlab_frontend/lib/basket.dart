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

  @override
  void dispose() {
    _customerNameController.dispose();
    _companyNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
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
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? AppColors.danger : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
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
    } catch (e) {
      print('Error clearing cart on backend: $e');
    }
  }

  // ⭐ دالة مخصصة لتأثير الانتقال (Fade)
  PageRouteBuilder _fadePageRoute(Widget targetPage) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => targetPage,
      transitionDuration: const Duration(milliseconds: 300), 
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
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

        _showSnackBar('Order created successfully! Redirecting to Orders List.');
        await _clearCartOnBackend();
        widget.onOrderSuccess();
        _customerNameController.clear();
        _companyNameController.clear();
        _emailController.clear();
        _phoneController.clear();

        // ⭐ استخدام Fade Transition عند الانتقال إلى صفحة الطلبات
        Navigator.pushReplacement(
          context,
          _fadePageRoute(const CustomerOrdersPage()),
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


  // --- الدوال المساعدة للتنسيق الجديد ---

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // زر الرجوع
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back to Products',
        ),
        const SizedBox(width: 8),
        Text(
          'Create New Customer Order',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 28,
          ),
        ),
      ],
    );
  }

  Widget _buildBasketItemCard(Map<String, dynamic> item) {
    final availableStock = (item['quantity'] ?? 0);
    final inCartQuantity = (item['cartQuantity'] ?? 0);
    final List<String> imageUrls = (item['imageUrls'] as List<String>?) ?? [];
    String? displayImageUrl;

    if (imageUrls.isNotEmpty) {
      final String rawImageUrl = imageUrls.first;
      // التحقق من URL الكامل أو إضافته
      if (rawImageUrl.startsWith('http://') || rawImageUrl.startsWith('https://')) {
        displayImageUrl = rawImageUrl;
      } else {
        displayImageUrl = '$baseUrl/$rawImageUrl'; 
      }
    }

    final bool stockWarning = inCartQuantity > availableStock;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stockWarning ? AppColors.danger.withOpacity(0.5) : AppColors.primary.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // الصورة
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 80,
              height: 80,
              color: AppColors.cardBackground,
              child: displayImageUrl != null && displayImageUrl.isNotEmpty
                  ? Image.network(
                      displayImageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(child: Icon(Icons.broken_image_rounded, color: AppColors.textSecondary));
                      },
                    )
                  : Center(child: Icon(Icons.image_not_supported, color: AppColors.textSecondary)),
            ),
          ),
          const SizedBox(width: 16),

          // التفاصيل
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'N/A',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Unit Price: \$${(item['price'] as num).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                if (stockWarning)
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

          // التحكم بالكمية
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: inCartQuantity > 1 ? AppColors.accent : AppColors.textSecondary.withOpacity(0.4)),
                onPressed: inCartQuantity > 1 && !_isLoading
                    ? () => _updateCartItemQuantity(item, inCartQuantity - 1)
                    : null,
              ),
              Text(
                '$inCartQuantity',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: inCartQuantity < availableStock ? AppColors.accent : AppColors.textSecondary.withOpacity(0.4)),
                onPressed: inCartQuantity < availableStock && !_isLoading
                    ? () => _updateCartItemQuantity(item, inCartQuantity + 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(width: 16),
          
          // الإجمالي الفرعي والحذف
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${((item['price'] ?? 0.0) * inCartQuantity).toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 4),
              IconButton(
                icon: Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 24),
                onPressed: _isLoading ? null : () => _removeFromCart(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBasketList() {
    if (_isFetchingCart) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_basketItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 80, color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Your Order is Empty. Add products to start.',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: _basketItems.length,
        itemBuilder: (context, index) {
          return _buildBasketItemCard(_basketItems[index]);
        },
      ),
    );
  }

  Widget _buildCheckoutSummary(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Customer Details & Checkout',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Divider(height: 30, color: AppColors.background),
              
              // حقول النموذج
              _buildTextField(
                controller: _companyNameController,
                label: 'Company Name',
                icon: Icons.business_outlined,
                validator: (value) => value!.isEmpty ? 'Company name is required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _customerNameController,
                label: 'Contact Name',
                icon: Icons.person_outline_rounded,
                validator: (value) => value!.isEmpty ? 'Contact name is required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value!.isEmpty ? 'Email is required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Phone number is required' : null,
              ),
              const SizedBox(height: 30),

              // ملخص الإجمالي وزر الدفع
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grand Total',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                      Text(
                        '\$${_displayTotalPrice.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent, // لون مميز للإجمالي
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoading || _basketItems.isEmpty ? null : _handleCheckout,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.shopping_cart_checkout_rounded, size: 28),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(_isLoading ? 'Processing...' : 'Proceed Order', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      elevation: 8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          cursorColor: AppColors.primary.withOpacity(0.7),
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
            borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7), width: 2),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.5)),
          ),
          prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.7)),
          floatingLabelStyle: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // لون الخلفية العام
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. العنوان الرئيسي وزر الرجوع
            _buildHeader(context),
            const SizedBox(height: 30),

            // 2. المحتوى الرئيسي (سلة المشتريات + نموذج العميل)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الجانب الأيسر: قائمة المنتجات
                  Expanded(
                    flex: 3,
                    child: _buildBasketList(),
                  ),
                  const SizedBox(width: 40),

                  // الجانب الأيمن: نموذج العميل وملخص الطلب
                  Expanded(
                    flex: 2,
                    child: _buildCheckoutSummary(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}