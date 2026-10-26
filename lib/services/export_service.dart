import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Print / export helpers that work on both web and the Android build.
///
/// The screens previously used `dart:html` Blob + AnchorElement directly,
/// which silently does nothing inside the APK. `printing` handles the
/// platform differences for PDFs; CSV falls back to a share sheet on mobile.
class ExportService {
  static const PdfColor blue = PdfColor.fromInt(0xFF1D428A);
  static const PdfColor gold = PdfColor.fromInt(0xFFD4AF37);
  static const PdfColor ink = PdfColor.fromInt(0xFF111827);
  static const PdfColor muted = PdfColor.fromInt(0xFF4B5563);

  /// Opens the OS print dialog (web: the browser's print preview).
  static Future<void> printDocument(pw.Document doc, {String? name}) async {
    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: name ?? 'document',
    );
  }

  /// Saves / shares the PDF. On web this downloads it; on Android it opens
  /// the share sheet so the file can be saved or sent.
  static Future<void> savePdf(pw.Document doc, String fileName) async {
    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  /// CSV export that works in the APK as well as the browser.
  static Future<void> saveCsv(String csv, String fileName) async {
    final bytes = Uint8List.fromList(csv.codeUnits);

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = fileName;
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
      return;
    }

    // XFile.fromData keeps this off dart:io, which the web build cannot use.
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, name: fileName, mimeType: 'text/csv'),
        ],
        subject: fileName,
      ),
    );
  }

  /// Best-effort load of the bundled logo for PDF headers.
  static Future<pw.ImageProvider?> logo() async {
    try {
      final data = await rootBundle.load('assets/images/horizontal_logo.jpeg');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}
