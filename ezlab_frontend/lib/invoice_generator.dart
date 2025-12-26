// ezlab_frontend/lib/invoice_generator.dart
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

Map<String, String> _localizedLabels(String languageCode) {
  switch (languageCode) {
    case 'ar':
      return {
        'title': 'فاتورة / إيصال',
        'orderId': 'رقم الطلب',
        'date': 'التاريخ',
        'customerInfo': 'معلومات العميل',
        'company': 'الشركة',
        'contactPerson': 'اسم المندوب',
        'email': 'البريد الإلكتروني',
        'phone': 'الهاتف',
        'product': 'المنتج',
        'qty': 'الكمية',
        'price': 'السعر',
        'total': 'الإجمالي',
        'totalAmount': 'المبلغ الإجمالي',
        'companyName': 'ايزلاب',
        'officialSeal': 'الختم الرسمي',
        'thankYou': 'شكراً لتعاملكم معنا!',
        'preparedBy': 'إعداد: فريق NBK TECHNOLOJY',
      };
    case 'tr':
      return {
        'title': 'Fatura / Makbuz',
        'orderId': 'Sipariş No',
        'date': 'Tarih',
        'customerInfo': 'Müşteri Bilgileri',
        'company': 'Şirket',
        'contactPerson': 'İlgili Kişi',
        'email': 'E-posta',
        'phone': 'Telefon',
        'product': 'Ürün',
        'qty': 'Adet',
        'price': 'Fiyat',
        'total': 'Toplam',
        'totalAmount': 'Toplam Tutar',
        'companyName': 'NBK TECHNOLOJY',
        'officialSeal': 'Resmi Mühür',
        'thankYou': 'İşiniz için teşekkürler!',
        'preparedBy': 'Hazırlayan: NBK TECHNOLOJY Ekibi',
      };
    default:
      return {
        'title': 'Invoice / Receipt',
        'orderId': 'Order ID',
        'date': 'Date',
        'customerInfo': 'Customer Information',
        'company': 'Company',
        'contactPerson': 'Contact Person',
        'email': 'Email',
        'phone': 'Phone',
        'product': 'Product',
        'qty': 'Qty',
        'price': 'Price',
        'total': 'Total',
        'totalAmount': 'Total Amount',
        'companyName': 'NBK TECHNOLOJY',
        'officialSeal': 'Official Seal',
        'thankYou': 'Thank you for your business!',
        'preparedBy': 'Prepared by NBK TECHNOLOJY Team',
      };
  }
}

Future<pw.Font> _loadFont(String path) async {
  final fontData = await rootBundle.load(path);
  return pw.Font.ttf(fontData);
}

String _formatNumber(double number, String locale) {
  final formatter = NumberFormat.currency(
    locale: locale,
    symbol: '',
    decimalDigits: 2,
  );
  return formatter.format(number);
}

// The main function to be run in the isolate
Future<void> generateAndSaveInvoiceCompute(Map<String, dynamic> data) async {
  final order = data['order'] as Map<String, dynamic>;
  final products = data['products'] as List<Map<String, dynamic>>;
  final locale = (data['locale'] as String?) ?? 'en_US';
  final languageCode = locale.split(RegExp('[_-]'))[0];
  final isRtl = languageCode == 'ar' || languageCode == 'fa' || languageCode == 'he';

  final pdf = pw.Document();

  final ByteData logoBytes = await rootBundle.load('lib/assets/images/ezlab.jpeg');
  final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

  // Choose fonts depending on locale; Tajawal works well for Arabic, Roboto for Latin
  final tajawalRegular = await _loadFont('lib/assets/fonts/Tajawal-Regular.ttf');
  final tajawalBold = await _loadFont('lib/assets/fonts/Tajawal-Bold.ttf');
  final robotoRegular = await _loadFont('lib/assets/fonts/Roboto-Regular.ttf');
  final robotoBold = robotoRegular; // no separate bold included here

  pw.Font primaryFont = robotoRegular;
  pw.Font primaryBold = robotoBold;
  pw.Font fallbackFont = tajawalRegular;
  if (isRtl) {
    primaryFont = tajawalRegular;
    primaryBold = tajawalBold;
    fallbackFont = robotoRegular;
  }

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
        productImg = pw.Text('No Image', style: pw.TextStyle(font: primaryFont, fontSize: 8, fontFallback: [fallbackFont]));
      }
    }
    
    final formattedPrice = '\$${_formatNumber(price, locale)}';
    final formattedTotal = '\$${_formatNumber(total, locale)}';

    return [
      pw.Text(item['name'] ?? 'N/A', style: pw.TextStyle(font: primaryFont, fontFallback: [fallbackFont])),
      pw.Center(child: productImg),
      pw.Text(quantity.toString(), style: pw.TextStyle(font: primaryFont, fontFallback: [fallbackFont]), textAlign: pw.TextAlign.center),
      pw.Text(formattedPrice, style: pw.TextStyle(font: primaryFont, fontFallback: [fallbackFont]), textAlign: pw.TextAlign.right),
      pw.Text(formattedTotal, style: pw.TextStyle(font: primaryFont, fontFallback: [fallbackFont]), textAlign: pw.TextAlign.right),
    ];
  }));

  // localized labels
  final labels = _localizedLabels(languageCode);

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
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
                      labels['title']!,
                      style: pw.TextStyle(
                        font: primaryBold,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                        fontFallback: [fallbackFont],
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('${labels['orderId']}: ${order['id']}', style: pw.TextStyle(font: primaryFont, fontSize: 12, color: PdfColors.grey700, fontFallback: [fallbackFont])),
                    pw.Text('${labels['date']}: ${DateFormat.yMd(locale).format(DateTime.parse(order['orderDate']).toLocal())}',
                        style: pw.TextStyle(font: primaryFont, fontSize: 12, color: PdfColors.grey700, fontFallback: [fallbackFont])),
                  ],
                ),
                pw.Image(logoImage, height: 40),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Divider(color: PdfColors.grey500),
            pw.SizedBox(height: 20),
            pw.Text(
              labels['customerInfo']!,
              style: pw.TextStyle(
                font: primaryBold,
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
                pw.Text('${labels['company']}: ${order['companyName'] ?? 'N/A'}', style: pw.TextStyle(font: primaryFont, fontSize: 12, fontFallback: [fallbackFont])),
                pw.Text('${labels['contactPerson']}: ${order['customerName'] ?? 'N/A'}', style: pw.TextStyle(font: primaryFont, fontSize: 12, fontFallback: [fallbackFont])),
                pw.Text('${labels['email']}: ${order['customerEmail'] ?? 'N/A'}', style: pw.TextStyle(font: primaryFont, fontSize: 12, fontFallback: [fallbackFont])),
                pw.Text('${labels['phone']}: ${order['customerPhone'] ?? 'N/A'}', style: pw.TextStyle(font: primaryFont, fontSize: 12, fontFallback: [fallbackFont])),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(font: primaryBold, fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.white, fontFallback: [fallbackFont]),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: pw.TextStyle(font: primaryFont, fontSize: 10, fontFallback: [fallbackFont]),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: isRtl
                  ? {
                      4: const pw.FlexColumnWidth(3),
                      3: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(1),
                      1: const pw.FlexColumnWidth(1.5),
                      0: const pw.FlexColumnWidth(1.5),
                    }
                  : {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(1),
                      3: const pw.FlexColumnWidth(1.5),
                      4: const pw.FlexColumnWidth(1.5),
                    },
              headers: isRtl ? [labels['total']!, labels['price']!, labels['qty']!, '', labels['product']!] : [labels['product']!, '', labels['qty']!, labels['price']!, labels['total']!],
              data: isRtl
                  ? tableData.map((row) => row.reversed.toList()).toList()
                  : tableData,
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey500),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  '${labels['totalAmount']}: \$${_formatNumber(double.tryParse(order['totalAmount']?.toString() ?? '0.0') ?? 0.0, locale)}',
                  style: pw.TextStyle(
                    font: primaryBold,
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
                    pw.Text(labels['companyName'] ?? 'EZLAB', style: pw.TextStyle(font: primaryBold, fontSize: 18, fontFallback: [fallbackFont])),
                    pw.Text(labels['officialSeal']!, style: pw.TextStyle(font: primaryFont, fontSize: 10, fontFallback: [fallbackFont])),
                    pw.SizedBox(height: 5),
                    pw.Text('${labels['date']}: ${DateFormat.yMd(locale).format(DateTime.now().toLocal())}', style: pw.TextStyle(font: primaryFont, fontSize: 8, fontFallback: [fallbackFont])),
                  ],
                ),
                pw.Text(
                  labels['thankYou']!,
                  style: pw.TextStyle(
                    font: primaryFont,
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
            pw.Text(labels['preparedBy']!, style: pw.TextStyle(font: primaryFont, fontSize: 10, color: PdfColors.grey500, fontFallback: [fallbackFont])),
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