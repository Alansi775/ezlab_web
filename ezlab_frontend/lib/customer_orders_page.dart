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

 class CustomerOrdersPage extends StatefulWidget {
   const CustomerOrdersPage({Key? key}) : super(key: key);

   @override
   State<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
 }

 class _CustomerOrdersPageState extends State<CustomerOrdersPage> {
   List<Map<String, dynamic>> _orders = [];
   bool _isLoading = true;
   String? _errorMessage;

   final List<String> _orderStatuses = [
     'Draft',
     'Pending',
     'Confirmed',
     'Shipped',
     'Cancelled',
   ];

   @override
   void initState() {
     super.initState();
     _fetchOrders();
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
                 style: GoogleFonts.lato(
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
       // Close the bottom sheet if the status is the same
       if (mounted) {
         Navigator.pop(context);
         _showSnackBar('Order status is already $newStatus.');
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
         _showSnackBar('Order status updated to $newStatus!');

         if (newStatus == 'Confirmed') {
           _showLoadingDialog();

           try {
             final order = _orders.firstWhere((o) => o['id'] == orderId);

             // This is the correct way to await the compute function
             await compute(
               generateAndSaveInvoiceCompute,
               {
                 'order': order,
                 'products': List<Map<String, dynamic>>.from(order['items'] ?? []),
               },
             );
           } catch (e) {
             _showSnackBar('Failed to generate invoice: $e', isError: true);
             print('Error generating invoice: $e');
           } finally {
             // This closes the loading dialog
             if (mounted) {
               Navigator.pop(context);
             }
           }
         }

         // This closes the bottom sheet after the whole process
         if (mounted) {
           Navigator.pop(context);
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

   Future<void> _confirmAndDeleteOrderItem(int orderId, int itemId, String productName) async {
     final bool? confirm = await showDialog<bool>(
       context: context,
       builder: (BuildContext context) {
         return AlertDialog(
           backgroundColor: AppColors.cardBackground,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           title: Text(
             'Confirm Deletion',
             style: GoogleFonts.lato(color: AppColors.textPrimary),
           ),
           content: Text(
             'Are you sure you want to remove "$productName" from this order? This will also return the quantity to stock.',
             style: GoogleFonts.lato(color: AppColors.textSecondary),
           ),
           actions: <Widget>[
             TextButton(
               onPressed: () => Navigator.of(context).pop(false),
               child: Text('Cancel', style: GoogleFonts.lato(color: AppColors.textPrimary)),
             ),
             ElevatedButton(
               onPressed: () => Navigator.of(context).pop(true),
               style: ElevatedButton.styleFrom(
                 backgroundColor: AppColors.danger,
                 foregroundColor: Colors.white,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
               ),
               child: Text('Delete', style: GoogleFonts.lato()),
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

   Future<void> _confirmDeleteOrder(int orderId, String customerName) async {
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
               child: Text('Cancel', style: GoogleFonts.lato(color: AppColors.textPrimary)),
             ),
             ElevatedButton(
               onPressed: () => Navigator.of(context).pop(true),
               style: ElevatedButton.styleFrom(
                 backgroundColor: AppColors.danger,
                 foregroundColor: Colors.white,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
               ),
               child: Text('Delete Order', style: GoogleFonts.lato()),
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
         content: Text(message, style: GoogleFonts.lato()),
         backgroundColor: isError ? AppColors.danger : AppColors.primary,
         duration: const Duration(seconds: 2),
       ),
     );
   }

   Future<void> _launchEmail(String email) async {
     final Uri uri = Uri(
       scheme: 'mailto',
       path: email,
     );
     if (await canLaunchUrl(uri)) {
       await launchUrl(uri);
     } else {
       _showSnackBar('Could not launch email app.', isError: true);
     }
   }

   Future<void> _launchPhone(String phone) async {
     final Uri uri = Uri(
       scheme: 'tel',
       path: phone,
     );
     if (await canLaunchUrl(uri)) {
       await launchUrl(uri);
     } else {
       _showSnackBar('Could not launch phone app.', isError: true);
     }
   }

   void _showStatusSelectionSheet(int orderId, String currentStatus) {
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
                     'Update Order Status',
                     style: GoogleFonts.lato(
                       fontWeight: FontWeight.bold,
                       color: AppColors.textPrimary,
                       fontSize: 20,
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

   Widget _buildGlassmorphismStatusTag(String status, Color color, bool isSelected, VoidCallback onTap) {
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
           status,
           style: GoogleFonts.lato(
             color: isSelected ? Colors.white : color,
             fontWeight: FontWeight.bold,
             fontSize: 14,
           ),
         ),
       ),
     );
   }

   @override
   Widget build(BuildContext context) {
     return Scaffold(
       backgroundColor: AppColors.background,
       appBar: AppBar(
         title: Text(
           'Customer Orders',
           style: GoogleFonts.lato(
             color: Colors.white,
             fontWeight: FontWeight.bold,
           ),
         ),
         backgroundColor: AppColors.primary.withOpacity(0.7),
         iconTheme: const IconThemeData(color: Colors.white),
         elevation: 0,
         centerTitle: true,
       ),
       body: _isLoading
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
                       style: GoogleFonts.lato(color: AppColors.danger, fontSize: 16),
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
                                 'No customer orders found yet.',
                                 style: GoogleFonts.lato(
                                       color: AppColors.textSecondary,
                                       fontSize: 20,
                                     ),
                               ),
                             ],
                           ),
                         )
                       : ListView.builder(
                           padding: const EdgeInsets.all(16.0),
                           itemCount: _orders.length,
                           itemBuilder: (context, index) {
                             final order = _orders[_orders.indexOf(_orders.firstWhere((o) => o['id'] == _orders.elementAt(index)['id']))];
                             return _buildOrderCard(order, index);
                           },
                         ),
                 ),
     );
   }

   Widget _buildOrderCard(Map<String, dynamic> order, int index) {
     final cardColor = index.isEven ? AppColors.cardBackground : AppColors.cardAlternateBackground;
     final orderId = order['id'] as int;

     return Card(
       margin: const EdgeInsets.only(bottom: 12),
       elevation: 5,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       color: cardColor,
       child: ExpansionTile(
         title: Text(
           order['companyName'] ?? 'N/A',
           textAlign: TextAlign.center,
           style: GoogleFonts.lato(
             fontSize: 20,
             fontWeight: FontWeight.bold,
             color: AppColors.textPrimary,
             shadows: [
               Shadow(
                 blurRadius: 2.0,
                 color: Colors.black.withOpacity(0.1),
                 offset: const Offset(1.0, 1.0),
               ),
             ],
           ),
         ),
         subtitle: Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Text(
               'Order Date: ${order['orderDate'] != null ? DateTime.parse(order['orderDate']).toLocal().toShortDateString() : 'N/A'}',
               style: GoogleFonts.lato(color: AppColors.textSecondary),
             ),
           ],
         ),
         trailing: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             GestureDetector(
               onTap: () => _showStatusSelectionSheet(orderId, order['status'] ?? _orderStatuses.first),
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
                       order['status'] ?? _orderStatuses.first,
                       style: GoogleFonts.lato(
                         color: _getStatusColor(order['status'] ?? _orderStatuses.first),
                         fontWeight: FontWeight.bold,
                         fontSize: 14,
                       ),
                     ),
                     const SizedBox(width: 4),
                     Icon(Icons.edit, size: 16, color: _getStatusColor(order['status'] ?? _orderStatuses.first)),
                   ],
                 ),
               ),
             ),
             const SizedBox(width: 8),
             IconButton(
               icon: Icon(Icons.delete_sweep_rounded, color: AppColors.danger, size: 24),
               onPressed: () {
                 _confirmDeleteOrder(
                   orderId,
                   order['customerName'] ?? 'this order',
                 );
               },
               tooltip: 'Delete entire order',
             ),
           ],
         ),
         children: [
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 _buildTotalTag(order['totalAmount']),
                 const SizedBox(height: 8),
                 _buildCustomerTag(order['customerName']),
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
                   _buildProductList(order, order['items'])
                 else
                   Text(
                     'No products found for this order.',
                     style: GoogleFonts.lato(color: AppColors.textSecondary),
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
       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
       decoration: BoxDecoration(
         color: AppColors.customerTagBackground,
         borderRadius: BorderRadius.circular(12),
       ),
       child: Text(
         customerName,
         style: GoogleFonts.lato(
           color: AppColors.customerTagText,
           fontWeight: FontWeight.bold,
           fontSize: 12,
         ),
       ),
     );
   }

   Widget _buildTotalTag(String? totalAmount) {
     if (totalAmount == null) {
       return const SizedBox.shrink();
     }
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
       decoration: BoxDecoration(
         color: AppColors.primary.withOpacity(0.7),
         borderRadius: BorderRadius.circular(12),
       ),
       child: Text(
         'Total: \$${double.tryParse(totalAmount)?.toStringAsFixed(2) ?? '0.00'}',
         style: GoogleFonts.lato(
           color: Colors.white,
           fontWeight: FontWeight.bold,
           fontSize: 12,
         ),
       ),
     );
   }

   Widget _buildProductList(Map<String, dynamic> order, List items) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(
           'Products:',
           style: GoogleFonts.lato(
                 fontWeight: FontWeight.bold,
                 color: AppColors.textPrimary,
                 fontSize: 14,
               ),
         ),
         const SizedBox(height: 8),
         ...items.map((item) => _buildProductItem(context, order['id'] as int, item, (orderId, itemId, name) {
               _confirmAndDeleteOrderItem(orderId, itemId, name);
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
           if (displayImageUrl != null)
             GestureDetector(
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
               child: Padding(
                 padding: const EdgeInsets.only(right: 8.0),
                 child: Hero(
                   tag: 'productImage-$orderId-${item['productId']}',
                   child: ClipRRect(
                     borderRadius: BorderRadius.circular(8.0),
                     child: Image.network(
                       displayImageUrl,
                       width: 50,
                       height: 50,
                       fit: BoxFit.cover,
                       errorBuilder: (context, error, stackTrace) {
                         return Icon(Icons.image_not_supported, size: 50, color: AppColors.textSecondary.withOpacity(0.5));
                       },
                     ),
                   ),
                 ),
               ),
             )
           else
             Padding(
               padding: const EdgeInsets.only(right: 8.0),
               child: Icon(Icons.image_not_supported, size: 50, color: AppColors.textSecondary.withOpacity(0.5)),
             ),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(
                   '${item['name'] ?? 'Unknown Product'}',
                   style: GoogleFonts.lato(
                         color: AppColors.textPrimary,
                         fontWeight: FontWeight.w600,
                       ),
                   overflow: TextOverflow.ellipsis,
                 ),
                 Text(
                   'Qty: ${int.tryParse(item['quantity']?.toString() ?? '0') ?? 0}',
                   style: GoogleFonts.lato(
                         color: AppColors.textSecondary,
                         fontSize: 12,
                       ),
                 ),
                 Text(
                   'Price: \$${double.tryParse(item['priceAtOrder']?.toString() ?? '0.0')?.toStringAsFixed(2) ?? '0.00'}',
                   style: GoogleFonts.lato(
                         color: AppColors.textSecondary,
                         fontSize: 12,
                       ),
                 ),
               ],
             ),
           ),
           IconButton(
             icon: Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 24),
             onPressed: () {
               onDelete(orderId, item['itemId'] as int, item['name'] ?? 'this product');
             },
             tooltip: 'Remove from order',
           ),
         ],
       ),
     );
   }

   Color _getStatusColor(String status) {
     switch (status) {
       case 'Confirmed':
         return Colors.lightBlue;
       case 'Shipped':
         return Colors.deepPurple;
       case 'Cancelled':
         return AppColors.danger;
       case 'Draft':
         return Colors.grey;
       case 'Pending':
       default:
         return AppColors.textSecondary;
     }
   }
 }

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
           style: GoogleFonts.lato(color: Colors.white),
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
                       style: GoogleFonts.lato(color: AppColors.textSecondary, fontSize: 16),
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
             style: GoogleFonts.lato(
               color: AppColors.primary,
               decoration: TextDecoration.underline,
             ),
           ),
         ],
       ),
     ),
   );
 }