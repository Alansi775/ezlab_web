// lib/product_detail_page.dart - الكود المصحح
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:ezlab_frontend/constants.dart';
import 'widgets/sidebar.dart'; 

class ProductDetailPage extends StatelessWidget {
  final Map<String, dynamic> product;
  final Function(Map<String, dynamic>) onAddToCart;
  final Function() onProductUpdated;

  final String loggedInUsername; 
  final String loggedInUserRole;

  const ProductDetailPage({
    Key? key,
    required this.product,
    required this.onAddToCart,
    required this.onProductUpdated,
    // تم تمرير المتغيرات المطلوبة
    required this.loggedInUsername, 
    required this.loggedInUserRole, 
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isOutOfStock = (product['quantity'] ?? 0) <= 0;

    final List<String> imageUrls = (product['imageUrls'] as List<dynamic>?)
        ?.map((url) => url.toString())
        .where((s) => s.isNotEmpty)
        .toList() ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // الشريط الجانبي (Sidebar)
          AppSidebar(
            activePage: 'Products', 
            userName: loggedInUsername,
            userRole: loggedInUserRole,
            isDetailPage: true, 
            onAddUser: null, // لا يوجد منطق لإضافة مستخدم هنا
          ),

          // منطقة المحتوى الرئيسية
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 30),
                  _buildProductLayout(context, imageUrls, isOutOfStock),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // --- الويدجت المساعدة (Helper Widgets) ---

  Widget _buildHeader(BuildContext context) {
    return Column( // ⭐ تغيير من Row إلى Column لاحتواء العناصر بشكل أفضل
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row( // هذا Row سيحتوي زر الرجوع فقط
          children: [
            // زر الرجوع
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Back to Products List',
            ),
            const SizedBox(width: 8),
            // ⭐ إزالة العنوان من هنا
            const Spacer(),
          ],
        ),
        
        // ⭐ إضافة عنوان المنتج بشكل منفصل لضمان ظهوره في سطر واحد
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0), // إزاحة العنوان قليلاً
          child: Text(
            product['name'] ?? 'Product Details',
            maxLines: 1, // ⭐ تحديد سطر واحد
            overflow: TextOverflow.ellipsis, // ⭐ إضافة علامة ... إذا لم يتسع
            style: GoogleFonts.lato(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 22, // ⭐ تقليل حجم الخط (كان 28)
            ),
          ),
        ),
      ],
    );
}

  // (بقية الدوال المساعدة _buildProductLayout, _buildImageGallery, _buildInfoTile, _showSnackBar تبقى كما هي...)
  Widget _buildProductLayout(BuildContext context, List<String> imageUrls, bool isOutOfStock) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 450, 
          child: _buildImageGallery(imageUrls),
        ),
        const SizedBox(width: 40),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product['description'] ?? 'No detailed description provided for this product.',
                style: GoogleFonts.lato(
                  color: AppColors.textSecondary,
                  fontSize: 18,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildInfoTile(
                    icon: Icons.monetization_on_rounded,
                    label: 'Price',
                    value: '\$${(product['price'] is num ? product['price'] as num : 0.0).toStringAsFixed(2)}',
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 40),
                  _buildInfoTile(
                    icon: Icons.inventory_2_rounded,
                    label: 'In Stock',
                    value: (product['quantity'] is int ? product['quantity'] as int : 0).toString(),
                    color: isOutOfStock ? AppColors.danger : AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: 350, 
                child: ElevatedButton.icon(
                  onPressed: isOutOfStock
                      ? () {
                          _showSnackBar(context, 'This product is currently out of stock.', AppColors.danger);
                        }
                      : () {
                          onAddToCart(product);
                          _showSnackBar(context, 'Product "${product['name']}" added to cart.', AppColors.primary);
                        },
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 28),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      isOutOfStock ? 'Out of Stock' : 'Add to Cart',
                      style: GoogleFonts.lato(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOutOfStock ? Colors.grey[400] : AppColors.primary.withOpacity(0.9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageGallery(List<String> imageUrls) {
    if (imageUrls.isNotEmpty) {
      return Container(
        height: 400, 
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: PageView.builder(
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              final imageUrl = imageUrls[index];
              return Padding(
                padding: const EdgeInsets.all(8.0), 
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain, 
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.background,
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 100,
                        color: AppColors.textSecondary.withOpacity(0.6),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      );
    } else {
      return Container(
        width: 400,
        height: 400,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_rounded,
              size: 100,
              color: AppColors.primary.withOpacity(0.6),
            ),
            const SizedBox(height: 10),
            Text('No Images Available', style: GoogleFonts.lato(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.lato(
            fontSize: 28, 
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.lato(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}