// ezlab_frontend/lib/product_detail_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:ezlab_frontend/constants.dart';
import 'package:provider/provider.dart';
import 'package:ezlab_frontend/providers/language_provider.dart';
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
    // passing user info
    required this.loggedInUsername, 
    required this.loggedInUserRole, 
  }) : super(key: key);

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
  Widget build(BuildContext context) {
    final bool isOutOfStock = (product['quantity'] ?? 0) <= 0;

    final List<String> imageUrls = (product['imageUrls'] as List<dynamic>?)
        ?.map((url) => url.toString())
        .where((s) => s.isNotEmpty)
        .toList() ?? [];

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            // Sidebar with user info
            AppSidebar(
              activePage: 'Products', 
              userName: loggedInUsername,
              userRole: loggedInUserRole,
              isDetailPage: true, 
              onAddUser: null, 
            ),

            // region for the main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, languageProvider),
                    const SizedBox(height: 30),
                    _buildProductLayout(context, imageUrls, isOutOfStock, languageProvider),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // --- Helper Widgets ---

  Widget _buildHeader(BuildContext context, LanguageProvider languageProvider) {
    return Column( //  change to Column is better for layout
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row( // this row only for back button and spacing
          children: [
            // this is the back button
            Directionality(
              textDirection: TextDirection.ltr,
              child: IconButton(
                icon: Icon(
                  languageProvider.isRTL 
                    ? Icons.arrow_forward_ios_rounded 
                    : Icons.arrow_back_ios_new_rounded, 
                  color: AppColors.primary
                ),
                onPressed: () => Navigator.pop(context),
                tooltip: languageProvider.getString('back'),
              ),
            ),
            const SizedBox(width: 8),
            //  removing title from here
            const Spacer(),
          ],
        ),
        
        //  adding product title separately to ensure it appears in one line
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0), // Slightly offset the title
          child: Text(
            product['name'] ?? 'Product Details',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _getTextStyle(
              languageProvider.isRTL,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
}

  // this builds the main product layout with images and details
  Widget _buildProductLayout(BuildContext context, List<String> imageUrls, bool isOutOfStock, LanguageProvider languageProvider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 450, 
          child: _buildImageGallery(imageUrls, languageProvider),
        ),
        const SizedBox(width: 40),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product['description'] ?? 'No detailed description provided for this product.',
                style: _getTextStyle(
                  languageProvider.isRTL,
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ).copyWith(height: 1.5),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildInfoTile(
                    icon: Icons.monetization_on_rounded,
                    label: languageProvider.getString('price'),
                    value: '\$${(product['price'] is num ? product['price'] as num : 0.0).toStringAsFixed(2)}',
                    color: AppColors.accent,
                    isRTL: languageProvider.isRTL,
                  ),
                  const SizedBox(width: 40),
                  _buildInfoTile(
                    icon: Icons.inventory_2_rounded,
                    label: languageProvider.getString('in_stock'),
                    value: (product['quantity'] is int ? product['quantity'] as int : 0).toString(),
                    color: isOutOfStock ? AppColors.danger : AppColors.primary,
                    isRTL: languageProvider.isRTL,
                  ),
                ],
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: 350, 
                child: ElevatedButton.icon(
                  onPressed: isOutOfStock
                      ? () {
                          _showSnackBar(context, languageProvider.getString('out_of_stock'), AppColors.danger);
                        }
                      : () {
                          onAddToCart(product);
                          _showSnackBar(context, '${product['name']} ' + languageProvider.getString('add_to_cart'), AppColors.primary);
                        },
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 28),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      isOutOfStock ? languageProvider.getString('out_of_stock') : languageProvider.getString('add_to_cart'),
                      style: _getTextStyle(
                        languageProvider.isRTL,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  Widget _buildImageGallery(List<String> imageUrls, LanguageProvider languageProvider) {
    if (imageUrls.isNotEmpty) {
      return StatefulBuilder(
        builder: (context, setGalleryState) {
          final pageController = PageController();
          
          return ValueListenableBuilder<int>(
            valueListenable: ValueNotifier<int>(0),
            builder: (context, currentPage, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 400,
                    child: Container(
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
                          controller: pageController,
                          onPageChanged: (int page) {
                            setGalleryState(() {});
                            // Rebuild after page change
                          },
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Photo indicator dots
                  if (imageUrls.length > 1)
                    AnimatedBuilder(
                      animation: pageController,
                      builder: (context, child) {
                        final currentPage = pageController.page?.round() ?? 0;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            imageUrls.length,
                            (index) => GestureDetector(
                              onTap: () => pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: currentPage == index ? 32 : 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: currentPage == index ? AppColors.primary : AppColors.primary.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          );
        },
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
            Text(
              'No Images Available',
              style: _getTextStyle(
                languageProvider.isRTL,
                color: AppColors.textSecondary,
              ),
            ),
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
    required bool isRTL,
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
              style: _getTextStyle(
                isRTL,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: _getTextStyle(
            isRTL,
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
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}