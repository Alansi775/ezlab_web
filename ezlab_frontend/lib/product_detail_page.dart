import 'package:flutter/material.dart';
import 'package:ezlab_frontend/constants.dart';

class ProductDetailPage extends StatelessWidget {
  final Map<String, dynamic> product;
  final Function(Map<String, dynamic>) onAddToCart;

  const ProductDetailPage({
    Key? key,
    required this.product,
    required this.onAddToCart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isOutOfStock = (product['quantity'] ?? 0) <= 0;

    // ⭐ MODIFIED: Get product image URLs as a List<String>
    // This now expects imageUrls to be a List<dynamic> (which it should be after _fetchProducts)
    final List<String> imageUrls = (product['imageUrls'] as List<dynamic>?)
        ?.map((url) => url.toString()) // Ensure each element is a string
        .where((s) => s.isNotEmpty) // Remove any empty strings
        .toList() ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          product['name'] ?? 'Product Details',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary.withOpacity(0.7),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ⭐ MODIFIED: Product Image Gallery (using PageView.builder)
            if (imageUrls.isNotEmpty)
              SizedBox(
                height: 250, // Fixed height for the image carousel
                child: PageView.builder(
                  itemCount: imageUrls.length,
                  itemBuilder: (context, index) {
                    final imageUrl = imageUrls[index];
                    return Center( // Center each image in its page
                      child: Container(
                        width: 250, // Consistent size for detail page images
                        height: 250,
                        margin: const EdgeInsets.symmetric(horizontal: 8), // Add some spacing between images
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
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
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              // ⭐ Placeholder if no images are found for the product
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: Icon(
                    Icons.image_not_supported_rounded, // Placeholder if no image
                    size: 100,
                    color: AppColors.primary.withOpacity(0.6),
                  ),
                ),
              ),
            const SizedBox(height: 32),

            // Product Name
            Text(
              product['name'] ?? 'N/A',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              product['description'] ?? 'No detailed description provided for this product.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Price and Quantity
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoTile(
                  icon: Icons.monetization_on_rounded,
                  label: 'Price',
                  value: '\$${(product['price'] is num ? product['price'] as num : 0.0).toStringAsFixed(2)}',
                  color: AppColors.accent,
                ),
                _buildInfoTile(
                  icon: Icons.inventory_2_rounded,
                  label: 'In Stock',
                  value: (product['quantity'] is int ? product['quantity'] as int : 0).toString(),
                  color: isOutOfStock ? AppColors.danger : AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Add to Cart Button for Product Detail Page
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isOutOfStock
                    ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('This product is currently out of stock.'),
                      backgroundColor: AppColors.danger,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
                    : () {
                  onAddToCart(product);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 28),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    isOutOfStock ? 'Out of Stock' : 'Add to Cart',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOutOfStock ? Colors.grey[400] : AppColors.primary.withOpacity(0.7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
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
              style: TextStyle(
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
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}