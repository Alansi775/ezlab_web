import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:universal_html/html.dart' as html;

void saveAndLaunchFile(Uint8List bytes, String fileName) {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}