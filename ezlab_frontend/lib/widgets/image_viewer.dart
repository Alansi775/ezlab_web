// lib/widgets/image_viewer.dart
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:ezlab_frontend/constants.dart';

class ImageViewerPage extends StatelessWidget {
  final String imageUrl;
  final String productName;

  const ImageViewerPage({Key? key, required this.imageUrl, required this.productName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(productName, style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Container(
        child: PhotoView(
          imageProvider: NetworkImage(imageUrl),
          backgroundDecoration: const BoxDecoration(
            color: AppColors.background,
          ),
          minScale: PhotoViewComputedScale.contained * 0.8,
          maxScale: PhotoViewComputedScale.covered * 2,
        ),
      ),
    );
  }
}