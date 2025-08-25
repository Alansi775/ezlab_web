import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:universal_html/html.dart' as html;
import 'package:ezlab_frontend/constants.dart';
import 'package:intl/intl.dart';
import 'utils/date_extensions.dart';

// Helper functions (made public to be accessible by compute)
Future<Uint8List> _fetchImage(String url) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      print('Failed to load image from URL: $url. Status code: ${response.statusCode}');
      return Uint8List(0);
    }
  } catch (e) {
    print('Error fetching image from URL: $url. Exception: $e');
    return Uint8List(0);
  }
}

Future<pw.Font> _loadFont(String path) async {
  final fontData = await rootBundle.load(path);
  return pw.Font.ttf(fontData);
}

String _formatNumber(double number) {
  final formatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: '',
    decimalDigits: 2,
  );
  return formatter.format(number);
}

// The main function to be run in the isolate
Future<void> generateAndSaveInvoiceCompute(Map<String, dynamic> data) async {
  final order = data['order'] as Map<String, dynamic>;
  final products = data['products'] as List<Map<String, dynamic>>;

  final pdf = pw.Document();

  final ByteData logoBytes = await rootBundle.load('lib/assets/images/ezlab.jpeg');
  final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

  final regularFont = await _loadFont('lib/assets/fonts/Tajawal-Regular.ttf');
  final boldFont = await _loadFont('lib/assets/fonts/Tajawal-Bold.ttf');
  final fallbackFont = await _loadFont('lib/assets/fonts/Roboto-Regular.ttf');

  print('Products data received: $products');

  final List<List<pw.Widget>> tableData = await Future.wait(products.map((item) async {
    final quantity = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
    final price = double.tryParse(item['priceAtOrder']?.toString() ?? '0.0') ?? 0.0;
    final total = quantity * price;

    pw.Widget productImg = pw.SizedBox(width: 50, height: 50);
    if (item['imageUrls'] != null && (item['imageUrls'] as List).isNotEmpty) {
      final imageUrl = item['imageUrls'][0] as String;
      final fullImageUrl = '$baseUrl/$imageUrl';
      final imageData = await _fetchImage(fullImageUrl);
      if (imageData.isNotEmpty) {
        productImg = pw.Image(pw.MemoryImage(imageData), width: 50, height: 50);
      } else {
        productImg = pw.Text('No Image', style: pw.TextStyle(font: regularFont, fontSize: 8));
      }
    }
    
    final formattedPrice = '\$${_formatNumber(price)}';
    final formattedTotal = '\$${_formatNumber(total)}';

    return [
      pw.Text(item['name'] ?? 'N/A', style: pw.TextStyle(font: regularFont, fontFallback: [fallbackFont])),
      pw.Center(child: productImg),
      pw.Text(quantity.toString(), style: pw.TextStyle(font: regularFont, fontFallback: [fallbackFont]), textAlign: pw.TextAlign.center),
      pw.Text(formattedPrice, style: pw.TextStyle(font: regularFont, fontFallback: [fallbackFont]), textAlign: pw.TextAlign.right),
      pw.Text(formattedTotal, style: pw.TextStyle(font: regularFont, fontFallback: [fallbackFont]), textAlign: pw.TextAlign.right),
    ];
  }));

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.ltr,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Invoice / Receipt',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                        fontFallback: [fallbackFont],
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Order ID: ${order['id']}', style: pw.TextStyle(font: regularFont, fontSize: 12, color: PdfColors.grey700, fontFallback: [fallbackFont])),
                    pw.Text('Date: ${DateTime.parse(order['orderDate']).toLocal().toShortDateString()}',
                        style: pw.TextStyle(font: regularFont, fontSize: 12, color: PdfColors.grey700, fontFallback: [fallbackFont])),
                  ],
                ),
                pw.Image(logoImage, height: 40),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Divider(color: PdfColors.grey500),
            pw.SizedBox(height: 20),
            pw.Text(
              'Customer Information:',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
                fontFallback: [fallbackFont],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Company: ${order['companyName'] ?? 'N/A'}', style: pw.TextStyle(font: regularFont, fontSize: 12, fontFallback: [fallbackFont])),
                pw.Text('Contact Person: ${order['customerName'] ?? 'N/A'}', style: pw.TextStyle(font: regularFont, fontSize: 12, fontFallback: [fallbackFont])),
                pw.Text('Email: ${order['customerEmail'] ?? 'N/A'}', style: pw.TextStyle(font: regularFont, fontSize: 12, fontFallback: [fallbackFont])),
                pw.Text('Phone: ${order['customerPhone'] ?? 'N/A'}', style: pw.TextStyle(font: regularFont, fontSize: 12, fontFallback: [fallbackFont])),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.white, fontFallback: [fallbackFont]),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: pw.TextStyle(font: regularFont, fontSize: 10, fontFallback: [fallbackFont]),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
              },
              headers: ['Product', '', 'Qty', 'Price', 'Total'],
              data: tableData,
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey500),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total Amount: \$${_formatNumber(double.tryParse(order['totalAmount']?.toString() ?? '0.0') ?? 0.0)}',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                    fontFallback: [fallbackFont],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('EZLAB', style: pw.TextStyle(font: boldFont, fontSize: 18, fontFallback: [fallbackFont])),
                    pw.Text('Official Seal', style: pw.TextStyle(font: regularFont, fontSize: 10, fontFallback: [fallbackFont])),
                    pw.SizedBox(height: 5),
                    pw.Text('Date: ${DateTime.now().toLocal().toShortDateString()}', style: pw.TextStyle(font: regularFont, fontSize: 8, fontFallback: [fallbackFont])),
                  ],
                ),
                pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 14,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey700,
                    fontFallback: [fallbackFont],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Divider(color: PdfColors.grey500),
            pw.SizedBox(height: 10),
            pw.Text('Prepared by EZLAB Team', style: pw.TextStyle(font: regularFont, fontSize: 10, color: PdfColors.grey500, fontFallback: [fallbackFont])),
          ],
        );
      },
    ),
  );
  
  final pdfBytes = await pdf.save();
  final fileName = 'invoice_${order['id']}.pdf';

  if (kIsWeb) {
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  } else {
    final dir = await path_provider.getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);
    OpenFilex.open(file.path);
  }
}