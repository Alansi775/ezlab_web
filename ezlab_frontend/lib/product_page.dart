// lib/product_page.dart
import 'package:ezlab_frontend/widgets/sidebar.dart'; 
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ezlab_frontend/constants.dart';
import 'package:ezlab_frontend/basket.dart';
import 'package:ezlab_frontend/product_detail_page.dart';
import 'package:image_picker/image_picker.dart'; 
import 'dart:typed_data';

// (إزالة الاستيرادات غير المستخدمة مثل customer_orders_page.dart من هنا)

class ProductPage extends StatefulWidget {
  final String? userRole;
  const ProductPage({Key? key, this.userRole}) : super(key: key);

  @override
  _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _userRole = '';
  String _userName = 'User'; 
  final Map<int, AnimationController> _cardAnimationControllers = {};

  List<Map<String, dynamic>> _selectedImages = []; 
  final ImagePicker _picker = ImagePicker(); 

  List<Map<String, dynamic>> _cartItems = [];
  double _cartTotalPrice = 0.0;
  int _cartId = 0;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndCart();
    _fetchProducts();
    _searchController.addListener(_onSearchChanged);
  }

  PageRouteBuilder _fadePageRoute(Widget targetPage) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => targetPage,
    // مدة قصيرة للانتقال (مثل 300 مللي ثانية)
    transitionDuration: const Duration(milliseconds: 300), 
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // استخدام FadeTransition لتطبيق تأثير التلاشي
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}

  Future<void> _loadUserDataAndCart() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('username') ?? 'User';
      _userRole = prefs.getString('role') ?? '';
    });
    await _fetchCart();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _productNameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _disposeCardAnimationControllers();
    super.dispose();
  }

  // --- الدوال المفقودة أو المضمنة في البناء ---
  void _onSearchChanged() => _searchProducts(_searchController.text);

  Future<void> _fetchCart() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/cart'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        setState(() {
          _cartId = responseBody['cartId'] as int;
          _cartItems = List<Map<String, dynamic>>.from(responseBody['items'].map((item) {
            return {
              'id': item['product_id'],
              'itemId': item['item_id'],
              'name': item['product_name'],
              'price': double.parse(item['price_at_add'].toString()),
              'quantity': item['product_stock'],
              'cartQuantity': item['cart_quantity'],
            };
          }));
          _calculateCartTotal();
        });
      } else {
        // لا تظهر رسالة خطأ، فقط افترض أن العربة فارغة
      }
    } catch (e) {
      // لا تظهر رسالة خطأ
    }
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _products = [];
      _filteredProducts = [];
      _disposeCardAnimationControllers();
    });

    try {
      final response = await http.get(Uri.parse('$baseUrl/api/products'));
      if (response.statusCode == 200) {
        final productsData = json.decode(response.body) as List<dynamic>;
        final products = productsData.map((item) {
          List<String> imageUrlsList = [];
          if (item['imageUrls'] is List) {
            imageUrlsList = List<String>.from(item['imageUrls'].map((url) => url.toString()));
          } else if (item['imageUrls'] is String) {
            imageUrlsList = (item['imageUrls'] as String)
                .split(',')
                .where((s) => s.isNotEmpty)
                .map((url) => '$baseUrl/$url') 
                .toList();
          }

          return {
            'id': item['id'],
            'name': item['name'],
            'description': item['description'],
            'price': double.tryParse(item['price'].toString()) ?? 0.0,
            'quantity': item['quantity'],
            'imageUrls': imageUrlsList, 
          };
        }).toList();

        setState(() {
          _products = products;
          _filteredProducts = products;
          _isLoading = false;
        });
        _initCardAnimations();
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to fetch products: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error fetching products: $e', isError: true);
    }
  }
  
  void _disposeCardAnimationControllers() {
    _cardAnimationControllers.values.forEach((controller) => controller.dispose());
    _cardAnimationControllers.clear();
  }

  void _initCardAnimations() {
    if (_filteredProducts.isNotEmpty) {
      _disposeCardAnimationControllers();
      for (int i = 0; i < _filteredProducts.length; i++) {
        final productId = _filteredProducts[i]['id'] as int;
        if (!_cardAnimationControllers.containsKey(productId)) {
          final controller = AnimationController(
            vsync: this,
            duration: Duration(milliseconds: 300 + i * 50),
          );
          _cardAnimationControllers[productId] = controller;
          Future.delayed(Duration(milliseconds: 50 * i), () {
            if (mounted && controller.status == AnimationStatus.dismissed) {
              controller.forward();
            }
          });
        }
      }
    }
  }

  void _searchProducts(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredProducts = _products.where((product) {
        final name = product['name']?.toLowerCase() ?? '';
        final description = product['description']?.toLowerCase() ?? '';
        return name.contains(lowerQuery) || description.contains(lowerQuery);
      }).toList();
    });
  }

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage(imageQuality: 70);
    // ... (logic for image picking remains the same) ...
    if (pickedFiles.isNotEmpty) {
      final filesToProcess = pickedFiles.take(5 - _selectedImages.length);
      for (var pickedFile in filesToProcess) {
        try {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _selectedImages.add({
              'bytes': bytes,
              'name': pickedFile.name,
            });
          });
        } catch (e) {
          print('Error reading image bytes: $e');
        }
      }
      if (pickedFiles.length > 5 && _selectedImages.length < 5) {
        _showSnackBar('Only 5 images are allowed. The rest were ignored.', isError: true);
      }
    }
  }

  void _removeSelectedImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate() || _selectedImages.isEmpty) {
      if (_selectedImages.isEmpty) _showSnackBar('Please select at least one image.', isError: true);
      return;
    }
    // ... (logic for adding product remains the same) ...
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/products'));
      request.fields['name'] = _productNameController.text;
      request.fields['description'] = _descriptionController.text;
      request.fields['price'] = _priceController.text;
      request.fields['quantity'] = _quantityController.text;

      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        request.files.add(
          http.MultipartFile.fromBytes(
            'images', 
            image['bytes'] as Uint8List,
            filename: image['name'] as String,
          ),
        );
      }

      request.headers['Authorization'] = 'Bearer $token';
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar('Product added successfully!');
        _fetchProducts();
        if (mounted) Navigator.pop(context);
        _clearForm();
      } else {
        _handleErrorResponse(response, 'add product');
      }
    } catch (e) {
      _showSnackBar('Error adding product: $e', isError: true);
    }
  }

  Future<void> _deleteProduct(int id) async {
    // ... (logic for deleting product remains the same) ...
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this product?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      final controller = _cardAnimationControllers[id];
      if (controller != null && controller.status != AnimationStatus.dismissed) {
        controller.reverse().then((_) async {
          _cardAnimationControllers.remove(id);
          await _performDeleteRequest(id);
        });
      } else {
        await _performDeleteRequest(id);
      }
    }
  }

  Future<void> _performDeleteRequest(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.delete(
        Uri.parse('$baseUrl/api/products/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showSnackBar('Product deleted successfully');
        _fetchProducts();
      } else {
        _handleErrorResponse(response, 'delete product');
      }
    } catch (e) {
      _showSnackBar('Error deleting product: $e', isError: true);
    }
  }

  void _handleErrorResponse(http.Response response, String operation) {
    String errorMessage = 'Failed to $operation';
    if (response.body.isNotEmpty) {
      try {
        final errorData = json.decode(response.body);
        errorMessage = errorData['message'] ?? errorMessage;
      } catch (_) {}
    }
    _showSnackBar(errorMessage, isError: true);
  }

  void _clearForm() {
    _productNameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _quantityController.clear();
    setState(() {
      _selectedImages.clear(); 
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ⭐ دالة إضافة المنتج
  void _showAddProductDialog() {
    setState(() {
      _selectedImages.clear(); 
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24, right: 24, top: 32,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add New Product',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _pickImages, 
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
                  ),
                  child: _selectedImages.isNotEmpty
                      ? GridView.builder( 
                    padding: const EdgeInsets.all(8.0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, 
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1, 
                    ),
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      final image = _selectedImages[index];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              image['bytes'] as Uint8List,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          Positioned(
                            top: 4, right: 4,
                            child: GestureDetector(
                              onTap: () => _removeSelectedImage(index),
                              child: Container(
                                decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  )
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_rounded, size: 40, color: AppColors.primary.withOpacity(0.7)),
                      const SizedBox(height: 8),
                      Text('Tap to select images (max 5)', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(controller: _productNameController, label: 'Product Name'),
              const SizedBox(height: 16),
              _buildTextField(controller: _descriptionController, label: 'Description', maxLines: 3),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField(controller: _priceController, label: 'Price', isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(controller: _quantityController, label: 'Quantity', isNumber: true)),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _addProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                ),
                child: const Text('Add Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ⭐ دالة إضافة مستخدم (لتمريرها إلى الشريط الجانبي)
  void _showAddUserDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add New User', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(controller: usernameController, label: 'Username'),
            const SizedBox(height: 16),
            _buildTextField(controller: passwordController, label: 'Password'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('auth_token') ?? '';

                final response = await http.post(
                  Uri.parse('$baseUrl/auth/register'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: json.encode({
                    'username': usernameController.text,
                    'password': passwordController.text,
                  }),
                );

                if (response.statusCode == 200) {
                  if(mounted) Navigator.pop(context);
                  _showSnackBar('User added successfully');
                } else {
                  _handleErrorResponse(response, 'add user');
                }
              } catch (e) {
                _showSnackBar('Error adding user: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add User'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    bool isNumber = false,
  }) {
    // ... (logic for building text field remains the same) ...
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3), width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.danger, width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.danger, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: (value) => value!.isEmpty ? 'This field is required' : null,
      style: TextStyle(color: AppColors.textPrimary),
    );
  }

  void _addToCart(Map<String, dynamic> product) async {
    // ... (logic for adding to cart remains the same) ...
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      _showSnackBar('You must be logged in to add items to cart.', isError: true);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/cart/add'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: json.encode({'productId': product['id'], 'quantity': 1}),
      );

      if (response.statusCode == 200) {
        _showSnackBar('${product['name']} added to cart!');
        await _fetchCart();
      } else {
        final errorData = json.decode(response.body);
        _showSnackBar(errorData['message'] ?? 'Failed to add to cart.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error adding to cart: $e', isError: true);
    }
  }

  void _calculateCartTotal() {
    _cartTotalPrice = 0.0;
    for (var item in _cartItems) {
      _cartTotalPrice += (item['price'] ?? 0.0) * (item['cartQuantity'] ?? 0);
    }
  }

  void _navigateToCartPage() {
  Navigator.push(
    context,
    // ⭐ التعديل هنا: استخدام دالة التلاشي
    _fadePageRoute( 
      BasketPage(
        cartId: _cartId,
        onOrderSuccess: () {
          // يتم تحديث العربة والمنتجات بعد نجاح الطلب
          _fetchCart();
          _fetchProducts();
        },
      ),
    ),
  ).then((_) {
    // يتم تحديث المنتجات والعربة عند العودة من سلة المشتريات
    _fetchProducts();
    _fetchCart();
  });
}

  Widget _buildEmptyState(bool canManageProducts) {
    // ... (logic for building empty state remains the same) ...
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sentiment_dissatisfied_rounded, size: 80, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            _products.isEmpty ? 'No products available. Add some!' : 'No matching products found.',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (_products.isEmpty && canManageProducts)
            ElevatedButton.icon(
              onPressed: _showAddProductDialog,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Add First Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, {required bool canManageProducts}) {
    final bool isOutOfStock = (product['quantity'] ?? 0) <= 0;
    final cartItem = _cartItems.firstWhere((item) => item['id'] == product['id'], orElse: () => {});
    final int cartQuantity = cartItem['cartQuantity'] ?? 0;
    final int remainingStock = (product['quantity'] ?? 0) - cartQuantity;
    final bool canAddToCart = remainingStock > 0;
    final List<String> imageUrls = (product['imageUrls'] as List<String>?) ?? [];
    final String? primaryImageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;

    final controller = _cardAnimationControllers[product['id']] as AnimationController?;
    if (controller == null) return const SizedBox.shrink(); 

    return ScaleTransition(
      scale: Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      ),
      child: FadeTransition(
        opacity: controller,
        child: Card(
          margin: EdgeInsets.zero, 
          elevation: 8, 
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isOutOfStock
                ? const BorderSide(color: AppColors.danger, width: 2)
                : BorderSide.none,
          ),
          color: AppColors.cardBackground,
          child: InkWell(
            onTap: () {
              if (mounted) {
                Navigator.push(
                  context,
                  // ⭐ التعديل هنا: استخدام دالة التلاشي الجديدة
                  _fadePageRoute(
                    ProductDetailPage(
                      product: product,
                      onAddToCart: _addToCart,
                      onProductUpdated: _fetchProducts, 
                      loggedInUsername: _userName, 
                      loggedInUserRole: _userRole, 
                    ),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(16),
            splashColor: AppColors.primary.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. Image and Stock/Delete Button
                Stack(
                  children: [
                    Container( 
                      height: 160, 
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.background, 
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: primaryImageUrl != null && primaryImageUrl.isNotEmpty
                            ? Image.network(
                          primaryImageUrl,
                          height: 160, 
                          width: double.infinity,
                          fit: BoxFit.contain, 
                          errorBuilder: (context, error, stackTrace) {
                            return Center(child: Icon(Icons.broken_image_rounded, color: AppColors.textSecondary, size: 40));
                          },
                        )
                            : Center(child: Icon(Icons.image_not_supported_rounded, color: AppColors.textSecondary, size: 40)),
                      ),
                    ),
                    if (isOutOfStock)
                      Positioned(
                        top: 10, left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(6)),
                          child: Text('Out of Stock', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    if (canManageProducts)
                      Positioned(
                        top: 4, right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
                          onPressed: () => _deleteProduct(product['id'] as int),
                          tooltip: 'Delete Product',
                        ),
                      ),
                  ],
                ),

                // 2. Product Details and Price/Stock Stats
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product['name'] ?? 'N/A',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product['description'] ?? 'No description.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Price Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), 
                              child: Row(
                                children: [
                                  const Icon(Icons.sell_rounded, size: 16, color: AppColors.accent), 
                                  const SizedBox(width: 4),
                                  Text(
                                    '\$${(product['price'] is num ? product['price'] as num : 0.0).toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.accent),
                                  ),
                                ],
                              ),
                            ),
                            // Quantity Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: isOutOfStock ? AppColors.danger.withOpacity(0.1) : AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                              child: Row(
                                children: [
                                  Icon(Icons.storage_rounded, size: 16, color: isOutOfStock ? AppColors.danger : AppColors.primary), 
                                  const SizedBox(width: 4),
                                  Text(
                                    'Qty: ${(product['quantity'] is int ? product['quantity'] as int : 0).toString()}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: isOutOfStock ? AppColors.danger : AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Add to Cart Button 
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ElevatedButton.icon(
                    onPressed: !canAddToCart ? null : () => _addToCart(product),
                    icon: Icon(Icons.add_shopping_cart_rounded, size: 20, color: canAddToCart ? Colors.white : Colors.grey[600]),
                    label: Text(isOutOfStock ? 'Out of Stock' : (cartQuantity > 0 ? 'Add (${cartQuantity})' : 'Add')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !canAddToCart ? Colors.grey[400] : AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // **BUILD METHOD** (باستخدام AppSidebar)
  @override
  Widget build(BuildContext context) {
    final canManageProducts = _userRole == 'admin' || _userRole == 'super_admin';
    final canManageUsers = _userRole == 'admin' || _userRole == 'super_admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // 1. **Sidebar (Fixed Width)** - استخدام الكومبوننت المنفصل
          AppSidebar(
            activePage: 'Products', 
            userName: _userName,    
            userRole: _userRole,    
            onAddUser: canManageUsers ? _showAddUserDialog : null, 
          ),

          // 2. **Main Content (Expanded Area)**
          Expanded(
            child: Column(
              children: [
                // Top Bar (Header/Search/Actions)
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Product Catalog', 
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          // Search Field 
                          SizedBox(
                            width: 300,
                            child: TextField(
                              controller: _searchController,
                              onChanged: _searchProducts,
                              decoration: InputDecoration(
                                hintText: 'Search products...',
                                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                                filled: true,
                                fillColor: AppColors.cardBackground,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Cart Button
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.shopping_cart_rounded, size: 28, color: AppColors.textPrimary),
                                onPressed: _navigateToCartPage,
                                tooltip: 'View Cart',
                              ),
                              if (_cartItems.isNotEmpty)
                                Positioned(
                                  right: 8, top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                                    constraints: const BoxConstraints(minWidth: 18, maxHeight: 18),
                                    child: Text(
                                      '${_cartItems.fold<int>(0, (sum, item) => sum + (item['cartQuantity'] as int? ?? 0))}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Add Product Button 
                          if (canManageProducts)
                            ElevatedButton.icon(
                              onPressed: _showAddProductDialog,
                              icon: const Icon(Icons.add_shopping_cart_rounded),
                              label: const Text('Add New Product'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary, 
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 4,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Product Grid Area 
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchProducts,
                    color: AppColors.primary.withOpacity(0.7),
                    backgroundColor: AppColors.background,
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                      child: _filteredProducts.isEmpty
                          ? _buildEmptyState(canManageProducts)
                          : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400, 
                          mainAxisSpacing: 20, 
                          crossAxisSpacing: 20, 
                          childAspectRatio: 1.0, 
                        ),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return _buildProductCard(
                            product,
                            canManageProducts: canManageProducts,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}