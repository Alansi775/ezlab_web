import 'package:ezlab_frontend/users_page.dart';
import 'package:ezlab_frontend/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ezlab_frontend/constants.dart';
import 'package:ezlab_frontend/basket.dart';
import 'package:ezlab_frontend/product_detail_page.dart';
import 'package:ezlab_frontend/customer_orders_page.dart';
import 'package:image_picker/image_picker.dart'; // Import for image selection
import 'dart:typed_data';
import 'dart:ui';

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
  final Map<int, AnimationController> _cardAnimationControllers = {};

  // ⭐ MODIFIED: Use a List of Map<String, Uint8List> to store multiple selected images
  List<Map<String, dynamic>> _selectedImages = []; // Each map: {'bytes': Uint8List, 'name': String}

  final ImagePicker _picker = ImagePicker(); // ImagePicker instance

  // Cart state variables (now managed by backend)
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

  Future<void> _loadUserDataAndCart() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('role') ?? widget.userRole ?? '';
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

  void _onSearchChanged() => _searchProducts(_searchController.text);

  Future<void> _fetchCart() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      print('No token found, cannot fetch cart.');
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
          _cartId = responseBody['cartId'] as int;
          _cartItems = List<Map<String, dynamic>>.from(responseBody['items'].map((item) {
            return {
              'id': item['product_id'],
              'itemId': item['item_id'],
              'name': item['product_name'],
              'description': item['product_description'],
              'price': double.parse(item['price_at_add'].toString()),
              'quantity': item['product_stock'],
              'cartQuantity': item['cart_quantity'],
            };
          }));
          _calculateCartTotal();
        });
        print('Cart fetched: $_cartItems');
      } else {
        print('Failed to fetch cart: ${response.statusCode} - ${response.body}');
        _showSnackBar('Failed to load cart.', isError: true);
      }
    } catch (e) {
      print('Error fetching cart: $e');
      _showSnackBar('Error connecting to server for cart.', isError: true);
    }
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _searchController.clear();
      _products = [];
      _filteredProducts = [];
      _disposeCardAnimationControllers();
    });

    try {
      final response = await http.get(Uri.parse('$baseUrl/api/products'));
      if (response.statusCode == 200) {
        final productsData = json.decode(response.body) as List<dynamic>;
        final products = productsData.map((item) {
          // ⭐ MODIFIED: Handle imageUrls coming as a List<dynamic> (from backend)
          List<String> imageUrlsList = [];
          if (item['imageUrls'] is List) {
            imageUrlsList = List<String>.from(item['imageUrls'].map((url) => url.toString()));
          } else if (item['imageUrls'] is String) { // Fallback for comma-separated string
            imageUrlsList = (item['imageUrls'] as String)
                .split(',')
                .where((s) => s.isNotEmpty)
                .toList();
          }

          return {
            'id': item['id'],
            'name': item['name'],
            'description': item['description'],
            'price': double.tryParse(item['price'].toString()) ?? 0.0,
            'quantity': item['quantity'],
            'imageUrls': imageUrlsList, // Ensure this is a List<String>
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

  // ⭐ MODIFIED: Method to pick MULTIPLE images
  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage(imageQuality: 70);

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages.clear(); // Clear previous selection, add new ones
        for (var pickedFile in pickedFiles) {
          pickedFile.readAsBytes().then((bytes) {
            setState(() {
              _selectedImages.add({
                'bytes': bytes,
                'name': pickedFile.name,
              });
            });
          }).catchError((e) {
            print('Error reading image bytes: $e');
          });
        }
      });
    } else {
      print('No images selected.');
    }
  }

  // ⭐ NEW: Method to remove an image from the selected list
  void _removeSelectedImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // ⭐ MODIFIED: _addProduct to handle MULTIPLE image uploads
  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImages.isEmpty) {
      _showSnackBar('Please select at least one image for the product.', isError: true);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/products'),
      );

      request.fields['name'] = _productNameController.text;
      request.fields['description'] = _descriptionController.text;
      request.fields['price'] = _priceController.text;
      request.fields['quantity'] = _quantityController.text;

      // ⭐ MODIFIED: Add multiple image files
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        request.files.add(
          http.MultipartFile.fromBytes(
            'images', // This must match the name expected by your backend for the array of files
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
        Navigator.pop(context);
        _clearForm();
      } else {
        _handleErrorResponse(response, 'add product');
      }
    } catch (e) {
      _showSnackBar('Error adding product: $e', isError: true);
      print('Error adding product: $e');
    }
  }

  Future<void> _deleteProduct(int id) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this product?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
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
      _selectedImages.clear(); // Clear selected images list
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ⭐ MODIFIED: _showAddProductDialog to include MULTIPLE image selection and display
  void _showAddProductDialog() {
    setState(() {
      _selectedImages.clear(); // Reset selected images when dialog opens
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
          left: 24,
          right: 24,
          top: 32,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add New Product',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // ⭐ MODIFIED: Image selection section for multiple images
              GestureDetector(
                onTap: _pickImages, // Call _pickImages for multiple selection
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
                  ),
                  child: _selectedImages.isNotEmpty
                      ? GridView.builder( // Use GridView to display multiple selected images
                    padding: const EdgeInsets.all(8.0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // Display 3 images per row
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1, // Make images square
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
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: AppColors.background,
                                  child: Icon(
                                    Icons.broken_image_rounded,
                                    size: 30,
                                    color: AppColors.textSecondary,
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeSelectedImage(index), // Option to remove image
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
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
                      Text(
                        'Tap to select images (max 5)', // Updated text
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
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
                  backgroundColor: AppColors.primary.withOpacity(0.7),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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

  void _showAddUserDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add New User',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(controller: usernameController, label: 'Username'),
            const SizedBox(height: 16),
            _buildTextField(controller: passwordController, label: 'Password'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Cancel'),
          ),
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
                  Navigator.pop(context);
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

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    await prefs.clear();

    if (token != null) {
      try {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } catch (e) {
        print('Logout error: $e');
      }
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
            (Route<dynamic> route) => false,
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: (value) => value!.isEmpty ? 'This field is required' : null,
      style: TextStyle(color: AppColors.textPrimary),
    );
  }

  Widget _buildDrawerHeader() {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        final username = snapshot.data?.getString('username') ?? 'User';
        final role = snapshot.data?.getString('role') ?? 'user';

        return UserAccountsDrawerHeader(
          accountName: Text(
            username,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
          ),
          accountEmail: Text(
            "Role: ${role.toUpperCase()}",
            style: TextStyle(color: Colors.black87.withOpacity(0.8)),
          ),
          currentAccountPicture: CircleAvatar(
            backgroundColor: AppColors.accent,
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          decoration: BoxDecoration(
            color: AppColors.background,
            gradient: LinearGradient(
                colors: [AppColors.background, AppColors.background],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManageProducts = _userRole == 'admin' || _userRole == 'super_admin';
    final canManageUsers = _userRole == 'admin' || _userRole == 'super_admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 16.0),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: AppColors.primary.withOpacity(0.7),
              iconTheme: const IconThemeData(color: Colors.white),
              elevation: 0,
              centerTitle: true,
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'EZLAB',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'CRM Dashboard',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              actions: [
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_rounded, size: 28),
                      onPressed: _navigateToCartPage,
                      tooltip: 'View Cart',
                    ),
                    if (_cartItems.isNotEmpty)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            maxHeight: 18,
                          ),
                          child: Text(
                            '${_cartItems.fold<int>(0, (sum, item) => sum + (item['cartQuantity'] as int? ?? 0))}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: AppColors.cardBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _buildDrawerHeader(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (canManageProducts) ...[
                    _buildDrawerTile(
                      icon: Icons.add_box_rounded,
                      title: 'Add Product',
                      onTap: () {
                        Navigator.pop(context);
                        _showAddProductDialog();
                      },
                    ),
                  ],
                  if (canManageUsers) ...[
                    _buildDrawerTile(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Add User',
                      onTap: () {
                        Navigator.pop(context);
                        _showAddUserDialog();
                      },
                    ),
                    _buildDrawerTile(
                      icon: Icons.people_alt_rounded,
                      title: 'Manage Users',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UsersPage()),
                        );
                      },
                    ),
                  ],
                  _buildDrawerTile(
                      icon: Icons.receipt_long,
                      title: 'Customer Orders',
                      onTap: (){
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CustomerOrdersPage()),
                        );
                      }
                  ),
                  const Divider(height: 1, color: AppColors.background),
                  _buildDrawerTile(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    textColor: AppColors.danger,
                    iconColor: AppColors.danger,
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: canManageProducts
          ? FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Add Product'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: AppColors.primary.withOpacity(0.7),
          strokeWidth: 4,
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchProducts,
        color: AppColors.primary.withOpacity(0.7),
        backgroundColor: AppColors.background,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: _searchProducts,
                decoration: InputDecoration(
                  hintText: 'Search products by name or description...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon: Icon(
                      Icons.search_rounded, color: AppColors.primary.withOpacity(0.7)),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 15.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.primary.withOpacity(0.7), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: AppColors.primary.withOpacity(0.3), width: 1),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(
                        Icons.clear_rounded, color: AppColors.textSecondary),
                    onPressed: () {
                      _searchController.clear();
                      _searchProducts('');
                    },
                  )
                      : null,
                ),
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
            Expanded(
              child: _filteredProducts.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sentiment_dissatisfied_rounded, size: 80,
                        color: AppColors.textSecondary.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text(
                      _products.isEmpty
                          ? 'No products available. Add some!'
                          : 'No matching products found.',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 24,
                              vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
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
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(
      Map<String, dynamic> product,
      {required bool canManageProducts}
      ) {
    final bool isOutOfStock = (product['quantity'] ?? 0) <= 0;
    final cartItem = _cartItems.firstWhere(
            (item) => item['id'] == product['id'],
        orElse: () => {});
    final int cartQuantity = cartItem['cartQuantity'] ?? 0;
    final int remainingStock = (product['quantity'] ?? 0) - cartQuantity;
    final bool canAddToCart = remainingStock > 0;

    // ⭐ MODIFIED: Get imageUrls as a List<String> directly from product map
    // This expects 'imageUrls' to already be a List<String> due to _fetchProducts
    final List<String> imageUrls = (product['imageUrls'] as List<String>?) ?? [];
    final String? primaryImageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isOutOfStock
            ? const BorderSide(color: AppColors.danger, width: 2.5)
            : BorderSide.none,
      ),
      color: AppColors.cardBackground,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailPage(
                product: product,
                onAddToCart: _addToCart,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.primary.withOpacity(0.1),
        highlightColor: AppColors.primary.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: primaryImageUrl != null && primaryImageUrl.isNotEmpty
                        ? Image.network(
                      primaryImageUrl, // ⭐ MODIFIED: Use primaryImageUrl
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 80,
                          height: 80,
                          color: AppColors.background,
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: AppColors.textSecondary,
                            size: 40,
                          ),
                        );
                      },
                    )
                        : Container(
                      width: 80,
                      height: 80,
                      color: AppColors.background,
                      child: Icon(
                        Icons.image_not_supported_rounded,
                        color: AppColors.textSecondary,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'] ?? 'N/A',
                          style: Theme
                              .of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product['description'] ?? 'No description.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Out of Stock Badge
                  if (isOutOfStock)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Out of Stock',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (canManageProducts)
                    IconButton(
                      icon: const Icon(Icons.delete_forever_rounded,
                          color: AppColors.danger),
                      onPressed: () =>
                          _deleteProduct(product['id'] as int),
                      tooltip: 'Delete Product',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.monetization_on_rounded, size: 20,
                          color: AppColors.primary.withOpacity(0.7)),
                      const SizedBox(width: 8),
                      Text(
                        '\$${(product['price'] is num
                            ? product['price'] as num
                            : 0.0).toStringAsFixed(2)}',
                        style: Theme
                            .of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.inventory_2_rounded, size: 20,
                          color: AppColors.primary.withOpacity(0.7)),
                      const SizedBox(width: 8),
                      Text(
                        'Qty: ${(product['quantity'] is int
                            ? product['quantity'] as int
                            : 0).toString()}',
                        style: Theme
                            .of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isOutOfStock ? AppColors.danger : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: !canAddToCart ? null : () => _addToCart(product),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                    label: Text(
                        isOutOfStock
                            ? 'Out of Stock'
                            : (cartQuantity > 0 ? 'Add (${cartQuantity})' : 'Add')
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !canAddToCart ? Colors.grey[400] : AppColors.primary.withOpacity(0.7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      elevation: 4,
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

  void _addToCart(Map<String, dynamic> product) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      _showSnackBar('You must be logged in to add items to cart.', isError: true);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/cart/add'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'productId': product['id'],
          'quantity': 1,
        }),
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
      MaterialPageRoute(
        builder: (context) => BasketPage(
          cartId: _cartId,
          onOrderSuccess: () {
            _fetchCart();
            _fetchProducts();
          },
        ),
      ),
    ).then((_) {
      _fetchProducts();
      _fetchCart();
    });
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Color iconColor = AppColors.textPrimary,
    Color textColor = AppColors.textPrimary,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: textColor, fontSize: 16)),
      onTap: onTap,
      hoverColor: AppColors.primary.withOpacity(0.1),
      focusColor: AppColors.primary.withOpacity(0.15),
    );
  }
}