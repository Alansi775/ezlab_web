// lib/customer_orders_page.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ezlab_frontend/constants.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ezlab_frontend/invoice_generator.dart';
import 'utils/date_extensions.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ezlab_frontend/login.dart';
import 'package:provider/provider.dart';
import 'package:ezlab_frontend/providers/language_provider.dart';
import 'widgets/sidebar.dart';

class CustomerOrdersPage extends StatefulWidget {
  const CustomerOrdersPage({Key? key}) : super(key: key);

  @override
  State<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends State<CustomerOrdersPage> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  //  NEW STATE VARIABLES FOR SIDEBAR
  String _userName = 'User'; 
  String _userRole = ''; 

  final List<String> _orderStatuses = [
    'Draft',
    'Pending',
    'Confirmed',
    'Shipped',
    'Cancelled',
  ];

  // Helper function for dynamic font based on language
  TextStyle _getTextStyle(bool isRTL, {double fontSize = 14, FontWeight fontWeight = FontWeight.w400, Color? color}) {
    if (isRTL) {
      return GoogleFonts.tajawal(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? AppColors.textPrimary,
      );
    }
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.textPrimary,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserData(); 
    _fetchOrders();
  }

  //  Load user data and role 
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('username') ?? 'User';
      _userRole = prefs.getString('role') ?? '';
    });
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      setState(() {
        _errorMessage = 'Authentication token not found. Please log in.';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> rawOrders = json.decode(response.body);
        setState(() {
          _orders = rawOrders.map((order) {
            return {
              'id': order['id'],
              'customerName': order['customerName'],
              'companyName': order['companyName'],
              'customerEmail': order['customerEmail'],
              'customerPhone': order['customerPhone'],
              'orderDate': order['orderDate'],
              'status': order['status'],
              'totalAmount': order['totalAmount'],
              'items': order['items'],
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to fetch orders: ${response.statusCode} - ${response.body}';
          _isLoading = false;
        });
        print('Failed to fetch orders: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching orders: $e';
        _isLoading = false;
      });
      print('Error fetching orders: $e');
    }
  }

  // --- Missing / Page-specific functions ---
  void _showLoadingDialog() {
     showDialog(
       context: context,
       barrierDismissible: false,
       builder: (BuildContext context) {
         return AlertDialog(
           backgroundColor: AppColors.cardBackground,
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               const CircularProgressIndicator(color: AppColors.primary),
               const SizedBox(height: 20),
               Text(
                 'Generating Invoice...',
                 style: _getTextStyle(
                   context.read<LanguageProvider>().isRTL,
                   color: AppColors.textPrimary,
                   fontWeight: FontWeight.bold,
                 ),
               ),
             ],
           ),
         );
       },
     );
   }

   Future<void> _updateOrderStatus(int orderId, String newStatus) async {
     final prefs = await SharedPreferences.getInstance();
     final token = prefs.getString('auth_token');

     if (token == null) {
       _showSnackBar('Authentication token not found. Cannot update order.', isError: true);
       return;
     }

     final orderIndex = _orders.indexWhere((order) => order['id'] == orderId);
     if (orderIndex != -1 && _orders[_orders.indexWhere((o) => o['id'] == orderId)]['status'] == newStatus) {
       if (mounted) {
         Navigator.pop(context);
         //_showSnackBar('Order status is already $newStatus.');
       }
       return;
     }

     try {
       final response = await http.patch(
         Uri.parse('$baseUrl/api/orders/$orderId'),
         headers: {
           'Content-Type': 'application/json',
           'Authorization': 'Bearer $token',
         },
         body: json.encode({'status': newStatus}),
       );

       if (response.statusCode == 200) {
         setState(() {
           if (orderIndex != -1) {
             _orders[_orders.indexWhere((o) => o['id'] == orderId)]['status'] = newStatus;
           }
         });
         //_showSnackBar('Order status updated to $newStatus!');

         if (newStatus == 'Confirmed') {
           _showLoadingDialog();

            try {
             final order = _orders.firstWhere((o) => o['id'] == orderId);
             // Ensure compute function is correctly imported and defined elsewhere (invoice_generator.dart)
             await compute(
               generateAndSaveInvoiceCompute,
               {
                 'order': order,
                 'products': List<Map<String, dynamic>>.from(order['items'] ?? []),
                 'locale': context.read<LanguageProvider>().locale.toString(),
               },
             );
           } catch (e) {
             _showSnackBar('Failed to generate invoice: $e', isError: true);
             print('Error generating invoice: $e');
           } finally {
             if (mounted) {
               Navigator.pop(context);
             }
           }
         }

         if (mounted) {
           // Close the status sheet if it was open
           if(Navigator.canPop(context)) Navigator.pop(context);
         }

       } else {
         final errorMessage = 'Failed to update status: ${response.statusCode} - ${response.body}';
         _showSnackBar(errorMessage, isError: true);
         print('Failed to update order status: $errorMessage');
       }
     } catch (e) {
       final errorMessage = 'Error updating order status: $e';
       _showSnackBar(errorMessage, isError: true);
       print('Error updating order status: $e');
     }
   }

   Future<void> _confirmAndDeleteOrderItem(int orderId, int itemId, String productName, LanguageProvider languageProvider) async {
     final bool? confirm = await showDialog<bool>(
       context: context,
       builder: (BuildContext context) {
         return AlertDialog(
           backgroundColor: AppColors.cardBackground,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           title: Text(
             'Confirm Deletion',
             style: _getTextStyle(
               context.read<LanguageProvider>().isRTL,
               fontSize: 16,
               fontWeight: FontWeight.bold,
               color: AppColors.textPrimary,
             ),
           ),
           content: Text(
             'Are you sure you want to remove "$productName" from this order? This will also return the quantity to stock.',
             style: GoogleFonts.lato(color: AppColors.textSecondary),
           ),
           actions: <Widget>[
             TextButton(
               onPressed: () => Navigator.of(context).pop(false),
               child: Text(languageProvider.getString('cancel'), style: GoogleFonts.lato(color: AppColors.textPrimary)),
             ),
             ElevatedButton(
               onPressed: () => Navigator.of(context).pop(true),
               style: ElevatedButton.styleFrom(
                 backgroundColor: AppColors.danger,
                 foregroundColor: Colors.white,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
               ),
               child: Text(
                 languageProvider.getString('delete'),
                 style: _getTextStyle(
                   languageProvider.isRTL,
                   fontWeight: FontWeight.bold,
                   color: Colors.white,
                 ),
               ),
             ),
           ],
         );
       },
     );

     if (confirm == true) {
       await _deleteOrderItem(orderId, itemId);
     }
   }

   Future<void> _deleteOrderItem(int orderId, int itemId) async {
     final prefs = await SharedPreferences.getInstance();
     final token = prefs.getString('auth_token');

     if (token == null) {
       _showSnackBar('Authentication token not found. Cannot delete order item.', isError: true);
       return;
     }

     try {
       final response = await http.delete(
         Uri.parse('$baseUrl/api/orders/$orderId/items/$itemId'),
         headers: {
           'Authorization': 'Bearer $token',
         },
       );

       if (response.statusCode == 200) {
         _showSnackBar('Product removed from order and stock reverted!');
         await _fetchOrders();
       } else {
         final errorMessage = 'Failed to delete item: ${response.statusCode} - ${response.body}';
         _showSnackBar(errorMessage, isError: true);
         print('Failed to delete order item: $errorMessage');
       }
     } catch (e) {
       final errorMessage = 'Error deleting order item: $e';
       _showSnackBar(errorMessage, isError: true);
       print('Error deleting order item: $e');
     }
   }

   Future<void> _confirmDeleteOrder(int orderId, String customerName, LanguageProvider languageProvider) async {
     final bool? confirm = await showDialog<bool>(
       context: context,
       builder: (BuildContext context) {
         return AlertDialog(
           backgroundColor: AppColors.cardBackground,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           title: Text(
             'Confirm Order Deletion',
             style: GoogleFonts.lato(color: AppColors.danger),
           ),
           content: Text(
             'Are you sure you want to delete the entire order for "$customerName"? All products will be returned to stock.',
             style: GoogleFonts.lato(color: AppColors.textSecondary),
           ),
           actions: <Widget>[
             TextButton(
               onPressed: () => Navigator.of(context).pop(false),
               child: Text(languageProvider.getString('cancel'), style: GoogleFonts.lato(color: AppColors.textPrimary)),
             ),
             ElevatedButton(
               onPressed: () => Navigator.of(context).pop(true),
               style: ElevatedButton.styleFrom(
                 backgroundColor: AppColors.danger,
                 foregroundColor: Colors.white,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
               ),
               child: Text(languageProvider.getString('delete_order'), style: GoogleFonts.lato()),
             ),
           ],
         );
       },
     );

     if (confirm == true) {
       await _deleteOrder(orderId);
     }
   }

   Future<void> _deleteOrder(int orderId) async {
     final prefs = await SharedPreferences.getInstance();
     final token = prefs.getString('auth_token');

     if (token == null) {
       _showSnackBar('Authentication token not found. Cannot delete order.', isError: true);
       return;
     }

     try {
       final response = await http.delete(
         Uri.parse('$baseUrl/api/orders/$orderId'),
         headers: {
           'Authorization': 'Bearer $token',
         },
       );

       if (response.statusCode == 200) {
         _showSnackBar('Order deleted successfully and stock reverted!');
         await _fetchOrders();
       } else {
         final errorMessage = 'Failed to delete order: ${response.statusCode} - ${response.body}';
         _showSnackBar(errorMessage, isError: true);
         print('Failed to delete order: $errorMessage');
       }
     } catch (e) {
       final errorMessage = 'Error deleting order: $e';
       _showSnackBar(errorMessage, isError: true);
       print('Error deleting order: $e');
     }
   }

   void _showSnackBar(String message, {bool isError = false}) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text(
           message,
           style: _getTextStyle(
             context.read<LanguageProvider>().isRTL,
           ),
         ),
         backgroundColor: isError ? AppColors.danger : AppColors.primary,
         duration: const Duration(seconds: 2),
         behavior: SnackBarBehavior.floating,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
         margin: const EdgeInsets.all(16),
       ),
     );
   }

   Future<void> _launchEmail(String email) async {
     final Uri uri = Uri(scheme: 'mailto', path: email);
     if (await canLaunchUrl(uri)) {
       await launchUrl(uri);
     } else {
       _showSnackBar('Could not launch email app.', isError: true);
     }
   }

   Future<void> _launchPhone(String phone) async {
     final Uri uri = Uri(scheme: 'tel', path: phone);
     if (await canLaunchUrl(uri)) {
       await launchUrl(uri);
     } else {
       _showSnackBar('Could not launch phone app.', isError: true);
     }
   }

   void _showStatusSelectionSheet(int orderId, String currentStatus, LanguageProvider languageProvider) {
     showModalBottomSheet(
       context: context,
       backgroundColor: Colors.transparent,
       builder: (BuildContext context) {
         return ClipRRect(
           borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
           child: BackdropFilter(
             filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
             child: Container(
               padding: const EdgeInsets.all(24),
               decoration: BoxDecoration(
                 color: AppColors.cardBackground.withOpacity(0.8),
                 borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
                 border: Border.all(color: AppColors.primary.withOpacity(0.2)),
               ),
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Text(
                     languageProvider.getString('update_order_status'),
                     style: _getTextStyle(
                       languageProvider.isRTL,
                       fontSize: 20,
                       fontWeight: FontWeight.bold,
                       color: AppColors.textPrimary,
                     ),
                   ),
                   const SizedBox(height: 16),
                   Wrap(
                     spacing: 12,
                     runSpacing: 12,
                     alignment: WrapAlignment.center,
                     children: _orderStatuses.map((status) {
                       return _buildGlassmorphismStatusTag(
                         status,
                         _getStatusColor(status),
                         status == currentStatus,
                         () {
                           _updateOrderStatus(orderId, status);
                         },
                         languageProvider,
                       );
                     }).toList(),
                   ),
                 ],
               ),
             ),
           ),
         );
       },
     );
   }

   Widget _buildGlassmorphismStatusTag(String status, Color color, bool isSelected, VoidCallback onTap, LanguageProvider languageProvider) {
     return InkWell(
       onTap: onTap,
       child: Container(
         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
         decoration: BoxDecoration(
           color: isSelected ? color.withOpacity(0.7) : AppColors.cardBackground.withOpacity(0.7),
           borderRadius: BorderRadius.circular(20),
           border: Border.all(
             color: isSelected ? color : color.withOpacity(0.3),
             width: 2,
           ),
           boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(0.1),
               blurRadius: 10,
               offset: const Offset(0, 5),
             ),
           ],
         ),
         child: Text(
           _getTranslatedStatus(status, languageProvider),
           style: _getTextStyle(
             languageProvider.isRTL,
             fontSize: 14,
             fontWeight: FontWeight.bold,
             color: isSelected ? Colors.white : color,
           ),
         ),
       ),
     );
   }

  //  function to show add user dialog
  void _showAddUserDialog(LanguageProvider languageProvider) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          languageProvider.getString('add_user'),
          style: _getTextStyle(
            languageProvider.isRTL,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: usernameController,
              style: _getTextStyle(languageProvider.isRTL, color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: languageProvider.getString('username'),
                labelStyle: _getTextStyle(languageProvider.isRTL, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordController,
              obscureText: true,
              style: _getTextStyle(languageProvider.isRTL, color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: languageProvider.getString('password'),
                labelStyle: _getTextStyle(languageProvider.isRTL, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: Text(
              languageProvider.getString('cancel'),
              style: _getTextStyle(languageProvider.isRTL, color: AppColors.textSecondary),
            ),
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
                  if(mounted) Navigator.pop(context);
                  _showSnackBar('User added successfully');
                } else {
                   String errorMessage = 'Failed to add user';
                    if (response.body.isNotEmpty) {
                      try {
                        final errorData = json.decode(response.body);
                        errorMessage = errorData['message'] ?? errorMessage;
                      } catch (_) {}
                    }
                  _showSnackBar(errorMessage, isError: true);
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
            child: Text(
              languageProvider.getString('add_user_button'),
              style: _getTextStyle(
                languageProvider.isRTL,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManageUsers = _userRole == 'admin' || _userRole == 'super_admin';

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            children: [
              // 1. **Sidebar (Fixed Width) - Using the Reusable Component**
              AppSidebar(
                activePage: 'Orders',
                userName: _userName,
                userRole: _userRole,
                onAddUser: canManageUsers ? () => _showAddUserDialog(languageProvider) : null,
              ),
              
              // 2. **Main Content (Expanded Area)**
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Header/Title
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        languageProvider.getString('customer_orders'),
                        style: _getTextStyle(
                          languageProvider.isRTL,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),

                    // Content Area
                    Expanded(
                       child: _isLoading
                           ? const Center(
                               child: CircularProgressIndicator(color: AppColors.primary),
                             )
                           : _errorMessage != null
                               ? Center(
                                   child: Padding(
                                     padding: const EdgeInsets.all(16.0),
                                     child: Text(
                                       _errorMessage!,
                                       textAlign: TextAlign.center,
                                       style: _getTextStyle(
                                         languageProvider.isRTL,
                                         fontSize: 16,
                                         color: AppColors.danger,
                                       ),
                                     ),
                                   ),
                                 )
                               : RefreshIndicator(
                                   onRefresh: _fetchOrders,
                                   color: AppColors.primary,
                                   backgroundColor: AppColors.background,
                                   child: _orders.isEmpty
                                       ? Center(
                                           child: Column(
                                             mainAxisAlignment: MainAxisAlignment.center,
                                             children: [
                                               Icon(Icons.assignment_turned_in_rounded,
                                                   size: 80, color: AppColors.textSecondary.withOpacity(0.5)),
                                               const SizedBox(height: 16),
                                               Text(
                                                 languageProvider.getString('no_products'),
                                                 style: _getTextStyle(
                                                   languageProvider.isRTL,
                                                   fontSize: 18,
                                                   color: AppColors.textSecondary,
                                                 ),
                                               ),
                                             ],
                                           ),
                                     )
                                   : ListView.builder(
                                       padding: const EdgeInsets.all(24.0),
                                       itemCount: _orders.length,
                                       itemBuilder: (context, index) {
                                         final order = _orders[index];
                                         return _buildOrderCard(order, index, languageProvider);
                                       },
                                     ),
                             ),
                 ),
              ],
            ),
          ),
        ],
      ),
        );
      },
    );
  }

   Widget _buildOrderCard(Map<String, dynamic> order, int index, LanguageProvider languageProvider) {
     final cardColor = AppColors.cardBackground; // Uniform card color for better style
     final orderId = order['id'] as int;

     return Card(
       margin: const EdgeInsets.only(bottom: 16), // Increased margin
       elevation: 8, // Increased elevation for a richer look
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       color: cardColor,
       child: ExpansionTile(
         tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
         title: Text(
           order['companyName'] ?? 'N/A',
           textAlign: TextAlign.start,
           style: _getTextStyle(
             languageProvider.isRTL,
             fontSize: 18,
             fontWeight: FontWeight.bold,
             color: AppColors.textPrimary,
           ),
         ),
         subtitle: Text(
           '${languageProvider.getString('order_date_label')} ${order['orderDate'] != null ? DateTime.parse(order['orderDate']).toLocal().toShortDateString() : 'N/A'}',
           style: _getTextStyle(
             languageProvider.isRTL,
             color: AppColors.textSecondary,
           ),
         ),
         trailing: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             // Status Tag & Edit Button
             GestureDetector(
               onTap: () => _showStatusSelectionSheet(orderId, order['status'] ?? _orderStatuses.first, languageProvider),
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                 decoration: BoxDecoration(
                   color: _getStatusColor(order['status'] ?? _orderStatuses.first).withOpacity(0.1),
                   borderRadius: BorderRadius.circular(20),
                   border: Border.all(color: _getStatusColor(order['status'] ?? _orderStatuses.first)),
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Text(
                       _getTranslatedStatus(order['status'] ?? _orderStatuses.first, languageProvider),
                       style: _getTextStyle(
                         languageProvider.isRTL,
                         fontSize: 14,
                         fontWeight: FontWeight.bold,
                         color: _getStatusColor(order['status'] ?? _orderStatuses.first),
                       ),
                     ),
                     const SizedBox(width: 4),
                     Icon(Icons.edit, size: 16, color: _getStatusColor(order['status'] ?? _orderStatuses.first)),
                   ],
                 ),
               ),
             ),
             const SizedBox(width: 8),
             // Delete Order Button
             IconButton(
               icon: Icon(Icons.delete_sweep_rounded, color: AppColors.danger, size: 24),
               onPressed: () {
                 _confirmDeleteOrder(
                   orderId,
                   order['companyName'] ?? 'this order',
                   languageProvider,
                 );
               },
               tooltip: 'Delete entire order',
             ),
           ],
         ),
         children: [
           Padding(
             padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 const Divider(height: 1, thickness: 1, color: AppColors.background), // Separator
                 const SizedBox(height: 16),
                 // Tags and Contact Info Row
                 Wrap(
                   spacing: 12,
                   runSpacing: 8,
                   children: [
                     _buildTotalTag(order['totalAmount'], languageProvider),
                     _buildCustomerTag(order['customerName']),
                   ],
                 ),
                 const SizedBox(height: 12),
                 if (order['customerEmail'] != null && order['customerEmail'].isNotEmpty)
                   _buildContactLink(
                     icon: Icons.email_outlined,
                     text: order['customerEmail'],
                     onTap: () => _launchEmail(order['customerEmail']),
                   ),
                 if (order['customerPhone'] != null && order['customerPhone'].isNotEmpty)
                   _buildContactLink(
                     icon: Icons.phone_outlined,
                     text: order['customerPhone'],
                     onTap: () => _launchPhone(order['customerPhone']),
                   ),
                 const Divider(height: 24, thickness: 1),
                 if (order['items'] != null && order['items'].isNotEmpty)
                   _buildProductList(order, order['items'], languageProvider)
                 else
                   Text(
                     languageProvider.getString('no_products'),
                     style: _getTextStyle(languageProvider.isRTL, color: AppColors.textSecondary),
                   ),
                 const SizedBox(height: 12),
               ],
             ),
           ),
         ],
       ),
     );
   }

   Widget _buildCustomerTag(String? customerName) {
     if (customerName == null || customerName.isEmpty) {
       return const SizedBox.shrink();
     }
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
       decoration: BoxDecoration(
         color: AppColors.customerTagBackground,
         borderRadius: BorderRadius.circular(15),
       ),
       child: Text(
         customerName,
         style: _getTextStyle(
           context.read<LanguageProvider>().isRTL,
           fontSize: 12,
           fontWeight: FontWeight.bold,
           color: AppColors.customerTagText,
         ),
       ),
     );
   }

   Widget _buildTotalTag(String? totalAmount, LanguageProvider languageProvider) {
     if (totalAmount == null) {
       return const SizedBox.shrink();
     }
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
       decoration: BoxDecoration(
         color: AppColors.primary.withOpacity(0.9), // Darker primary for better visibility
         borderRadius: BorderRadius.circular(15),
       ),
       child: Text(
         '${languageProvider.getString('total_label')} \$${double.tryParse(totalAmount)?.toStringAsFixed(2) ?? '0.00'}',
         style: _getTextStyle(
           languageProvider.isRTL,
           fontSize: 12,
           fontWeight: FontWeight.bold,
           color: Colors.white,
         ),
       ),
     );
   }

   Widget _buildProductList(Map<String, dynamic> order, List items, LanguageProvider languageProvider) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(
           languageProvider.getString('products'),
           style: _getTextStyle(
             languageProvider.isRTL,
             fontSize: 16,
             fontWeight: FontWeight.bold,
             color: AppColors.textPrimary,
           ),
         ),
         const SizedBox(height: 8),
         ...items.map((item) => _buildProductItem(context, order['id'] as int, item, (orderId, itemId, name) {
               _confirmAndDeleteOrderItem(orderId, itemId, name, languageProvider);
             })).toList(),
       ],
     );
   }

   Widget _buildProductItem(BuildContext context, int orderId, Map<String, dynamic> item, Function(int, int, String) onDelete) {
     final List<dynamic> imageUrls = item['imageUrls'] ?? [];
     final String? displayImageUrl = imageUrls.isNotEmpty ? '$baseUrl/${imageUrls.first}' : null;

     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 8.0),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
           // Image/Thumbnail
           Container(
             width: 60,
             height: 60,
             decoration: BoxDecoration(
               color: AppColors.background,
               borderRadius: BorderRadius.circular(10),
               boxShadow: [
                 BoxShadow(
                   color: Colors.black.withOpacity(0.05),
                   blurRadius: 4,
                 ),
               ],
             ),
             child: displayImageUrl != null
                 ? GestureDetector(
                     onTap: () {
                       Navigator.push(
                         context,
                         MaterialPageRoute(
                           builder: (context) => ImageViewerPage(
                             imageUrl: displayImageUrl,
                             productName: item['name'] ?? 'Product Image',
                           ),
                         ),
                       );
                     },
                     child: Hero(
                       tag: 'productImage-$orderId-${item['productId']}',
                       child: ClipRRect(
                         borderRadius: BorderRadius.circular(10),
                         child: Image.network(
                           displayImageUrl,
                           fit: BoxFit.cover,
                           errorBuilder: (context, error, stackTrace) {
                             return Center(child: Icon(Icons.image_not_supported, size: 30, color: AppColors.textSecondary.withOpacity(0.5)));
                           },
                         ),
                       ),
                     ),
                   )
                 : Center(child: Icon(Icons.image_not_supported, size: 30, color: AppColors.textSecondary.withOpacity(0.5))),
           ),
           const SizedBox(width: 12),
           // Product Details
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(
                   '${item['name'] ?? 'Unknown Product'}',
                   style: _getTextStyle(
                     context.read<LanguageProvider>().isRTL,
                     fontWeight: FontWeight.bold,
                     color: AppColors.textPrimary,
                   ),
                   overflow: TextOverflow.ellipsis,
                 ),
                 Text(
                   'Qty: ${int.tryParse(item['quantity']?.toString() ?? '0') ?? 0} | Price: \$${double.tryParse(item['priceAtOrder']?.toString() ?? '0.0')?.toStringAsFixed(2) ?? '0.00'}',
                   style: _getTextStyle(
                     context.read<LanguageProvider>().isRTL,
                     fontSize: 12,
                     color: AppColors.textSecondary,
                   ),
                 ),
               ],
             ),
           ),
           // Delete Item Button
           IconButton(
             icon: Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger, size: 24), // Cleaner delete icon
             onPressed: () {
               onDelete(orderId, item['itemId'] as int, item['name'] ?? 'this product');
             },
             tooltip: 'Remove from order and revert stock',
           ),
         ],
       ),
     );
   }

   Color _getStatusColor(String status) {
     switch (status) {
       case 'Confirmed':
         return AppColors.success; // Use success color for confirmed
       case 'Shipped':
         return Colors.deepPurple;
       case 'Cancelled':
         return AppColors.danger;
       case 'Draft':
         return Colors.grey;
       case 'Pending':
       default:
         return Colors.amber; // Brighter color for pending
     }
   }

   String _getTranslatedStatus(String status, LanguageProvider languageProvider) {
     switch (status) {
       case 'Draft':
         return languageProvider.getString('draft');
       case 'Pending':
         return languageProvider.getString('pending');
       case 'Confirmed':
         return languageProvider.getString('confirmed');
       case 'Shipped':
         return languageProvider.getString('shipped');
       case 'Cancelled':
         return languageProvider.getString('cancelled');
       default:
         return status;
     }
   }
 }

 // Helper Widgets
 class ImageViewerPage extends StatelessWidget {
   final String imageUrl;
   final String productName;

   const ImageViewerPage({Key? key, required this.imageUrl, required this.productName}) : super(key: key);

   @override
   Widget build(BuildContext context) {
     return Scaffold(
       appBar: AppBar(
         title: Text(
           productName,
           style: GoogleFonts.poppins(
             color: Colors.white,
             fontSize: 16,
             fontWeight: FontWeight.bold,
           ),
         ),
         backgroundColor: AppColors.primary,
         iconTheme: const IconThemeData(color: Colors.white),
       ),
       body: Container(
         color: Colors.black,
         child: Center(
           child: PhotoView(
             imageProvider: NetworkImage(imageUrl),
             minScale: PhotoViewComputedScale.contained * 0.8,
             maxScale: PhotoViewComputedScale.covered * 2,
             initialScale: PhotoViewComputedScale.contained,
             heroAttributes: PhotoViewHeroAttributes(tag: 'productImage-${productName.hashCode}'),
             loadingBuilder: (context, event) => Center(
               child: SizedBox(
                 width: 20.0,
                 height: 20.0,
                 child: CircularProgressIndicator(
                   value: event == null
                       ? 0
                       : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                 ),
               ),
             ),
             errorBuilder: (context, object, stacktrace) {
               return Center(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Icon(Icons.error, color: AppColors.danger, size: 60),
                     const SizedBox(height: 10),
                     Text(
                       'Failed to load image',
                       style: GoogleFonts.poppins(
                         color: AppColors.textSecondary,
                         fontSize: 16,
                       ),
                     ),
                   ],
                 ),
               );
             },
           ),
         ),
       ),
     );
   }
 }

 Widget _buildContactLink({required IconData icon, required String text, required VoidCallback onTap}) {
   return Padding(
     padding: const EdgeInsets.symmetric(vertical: 4.0),
     child: InkWell(
       onTap: onTap,
       child: Row(
         children: [
           Icon(icon, size: 20, color: AppColors.primary),
           const SizedBox(width: 8),
           Text(
             text,
             style: GoogleFonts.poppins(
               color: AppColors.primary,
               decoration: TextDecoration.underline,
             ),
           ),
         ],
       ),
     ),
   );
 }