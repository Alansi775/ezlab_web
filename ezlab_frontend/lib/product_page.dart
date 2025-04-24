import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProductPage extends StatefulWidget {
  final String userRole;
  const ProductPage({Key? key, required this.userRole}) : super(key: key);

  @override
  _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  List<Map<String, dynamic>> _products = [];
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await http.get(Uri.parse('http://192.168.1.108:5050/api/products'));
      if (response.statusCode == 200) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(json.decode(response.body));
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error fetching products: $e');
    }
  }

  Future<void> _addProduct() async {
    if (_formKey.currentState!.validate()) {
      try {
        final response = await http.post(
          Uri.parse('http://192.168.1.108:5050/api/products'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'name': _productNameController.text,
            'description': _descriptionController.text,
            'price': double.parse(_priceController.text),
            'quantity': int.parse(_quantityController.text),
          }),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Product added successfully')),
          );
          _fetchProducts();
          Navigator.pop(context);
          _clearForm();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add product')),
          );
        }

        if (response.statusCode == 200) {
          _fetchProducts();
          Navigator.pop(context);
          _clearForm();
        }
      } catch (e) {
        print('Error adding product: $e');
      }
    }
  }

  Future<void> _deleteProduct(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('http://192.168.1.108:5050/api/products/$id'),
      );
      if (response.statusCode == 200) {
        _fetchProducts();
      }
    } catch (e) {
      print('Error deleting product: $e');
    }
  }

  void _clearForm() {
    _productNameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _quantityController.clear();
  }

  void _showAddProductDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _productNameController,
                decoration: InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: 'Price',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _addProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Add Product',
                    style: TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 16),
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
        title: Text('Add New User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final response = await http.post(
                  Uri.parse('http://192.168.1.108:5050/auth/register'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'username': usernameController.text,
                    'password': passwordController.text,
                  }),
                );
                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('User added successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add user: ${response.body}')),
                  );
                }
              } catch (e) {
                print('Error adding user: $e');
              }
            },
            child: Text('Add User'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ezlab Dashboard'),
        actions: widget.userRole == 'admin'
            ? [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => showMenu(
              context: context,
              position: RelativeRect.fromLTRB(100, 100, 0, 0),
              items: [
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(Icons.person_add),
                    title: Text('Add User'),
                    onTap: _showAddUserDialog,
                  ),
                ),
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(Icons.add_box),
                    title: Text('Add Product'),
                    onTap: _showAddProductDialog,
                  ),
                ),
              ],
            ),
          ),
        ]
            : null,
      ),
      floatingActionButton: widget.userRole == 'admin'
          ? FloatingActionButton(
        onPressed: _showAddProductDialog,
        child: Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      )
          : null,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchProducts,
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: _products.length,
          itemBuilder: (context, index) => Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text(_products[index]['name'],
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_products[index]['description']),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Chip(
                          label: Text('\$${_products[index]['price']?.toStringAsFixed(2) ?? '0.00'}'),
                          backgroundColor: Colors.blueAccent.withOpacity(0.1)),
                      SizedBox(width: 8),
                      Chip(
                          label: Text('Qty: ${_products[index]['quantity']?.toString() ?? '0'}'),
                          backgroundColor: Colors.green.withOpacity(0.1)),
                    ],
                  ),
                ],
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteProduct(_products[index]['id']),
              ),
            ),
          ),
        ),
      ),
    );
  }
}