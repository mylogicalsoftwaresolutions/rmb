import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../services/export_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';

/// The certificate rendered for print / PDF, mirroring the on-screen layout
/// so the exported file matches what the member sees.
pw.Document buildCertificatePdf({
  required String memberName,
  required String memberCompany,
  required String authorName,
  required String authorCompany,
  required String content,
  required String date,
  required String chapter,
  pw.ImageProvider? logo,
}) {
  final doc = pw.Document();
  doc.addPage(
    // MultiPage instead of Page: a fixed Page silently clips anything past
    // its bottom edge, and the Spacer() this certificate used to rely on
    // only behaves once the page's height is exactly known. Once the
    // recognition paragraph and quote box were added, the content grew
    // taller than one page and the signature row got pushed off the
    // bottom - "missing text" with no error. MultiPage flows onto a second
    // page instead of losing content, regardless of how long any of these
    // fields get in the future.
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: ExportService.gold, width: 4),
        ),
        padding: const pw.EdgeInsets.all(10),
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: ExportService.gold, width: 1),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 34),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) ...[
                pw.Image(logo, height: 44),
                pw.SizedBox(height: 12),
              ],
              pw.Text(chapter,
                  style: const pw.TextStyle(
                      color: ExportService.blue,
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 18),
              pw.Text('CERTIFICATE OF APPRECIATION',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                      color: ExportService.blue,
                      fontSize: 26,
                      letterSpacing: 1.2,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Text('This certificate is proudly presented to',
                  style: const pw.TextStyle(
                      color: ExportService.muted, fontSize: 12)),
              pw.SizedBox(height: 18),
              pw.Text(memberName,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                      color: ExportService.gold,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(memberCompany,
                  style: const pw.TextStyle(
                      color: ExportService.ink,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 26),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 34),
                child: pw.Text(
                  'In sincere recognition of outstanding professional '
                  'excellence, commitment to business networking, and '
                  'invaluable testimonial support provided to '
                  '$authorName ($authorCompany).',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                      color: ExportService.ink, fontSize: 11, lineSpacing: 3),
                ),
              ),
              if (content.trim().isNotEmpty) ...[
                pw.SizedBox(height: 22),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                        color: const PdfColor.fromInt(0xFFE0D8C3)),
                  ),
                  child: pw.Text('"$content"',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                          color: ExportService.muted,
                          fontSize: 12,
                          fontStyle: pw.FontStyle.italic)),
                ),
              ],
              pw.SizedBox(height: 30),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                      child: _pdfSignature(authorName, 'Testimonial Provider')),
                  pw.SizedBox(width: 16),
                  pw.Text('VERIFIED',
                      style: const pw.TextStyle(
                          color: ExportService.gold,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 16),
                  pw.Expanded(child: _pdfSignature(date, 'Date')),
                ],
              ),
            ],
          ),
        ),
      )],
    ),
  );
  return doc;
}

pw.Widget _pdfSignature(String value, String caption) {
  return pw.Column(
    children: [
      pw.Text(value,
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(
              color: ExportService.ink,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Container(height: 1, color: PdfColors.grey500),
      pw.SizedBox(height: 4),
      pw.Text(caption,
          style: const pw.TextStyle(color: ExportService.muted, fontSize: 9)),
    ],
  );
}

/// One signature column: value, rule, caption — sized to its parent so the
/// left and right blocks stay symmetric on any width.
Widget _signatureBlock(String value, String caption) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.bold,
              fontSize: 13)),
      Container(
        height: 1,
        color: Colors.black26,
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      Text(caption,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF4B5563), fontSize: 10)),
    ],
  );
}

class TestimonialCertificateScreen extends StatefulWidget {
  final Map<String, dynamic> testimonial;

  const TestimonialCertificateScreen({super.key, required this.testimonial});

  @override
  State<TestimonialCertificateScreen> createState() =>
      _TestimonialCertificateScreenState();
}

class _TestimonialCertificateScreenState
    extends State<TestimonialCertificateScreen> {
  String _myName = '';
  String _myChapter = '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _myName = p.getString('user_name') ?? '';
        _myChapter = p.getString('chapter_name') ?? '';
      });
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  /// "2026-08-27 09:24:55" -> "27 Aug 2026"
  String _fmtDate(String raw) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = AppColors.secondary;

    final t = widget.testimonial;

    // The row names the other party under display_name; the signed-in member
    // is the counterpart named in the citation and signature.
    final String memberName = (t['display_name'] ??
            t['to_member_name'] ??
            '${t['first_name'] ?? ''} ${t['last_name'] ?? ''}')
        .toString()
        .trim();
    final String memberCompany =
        (t['company_name'] ?? t['to_company'] ?? '').toString();
    final String authorName =
        (t['from_member_name'] ?? (_myName.isEmpty ? '' : _myName)).toString();
    final String authorCompany = (t['from_company'] ?? '').toString();
    final String content = (t['content'] ?? t['title'] ?? '').toString();
    final String date = _fmtDate(
        (t['testimonial_date'] ?? t['created_at'] ?? t['date'] ?? '').toString());
    final String chapterName = (t['chapter_name'] ??
            (_myChapter.isEmpty ? 'RMB CONNECT' : _myChapter))
        .toString();

    return Scaffold(
      backgroundColor: AppColors.card,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Testimonial Certificate', style: TextStyle(color: goldColor, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppUI.webShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Certificate of Appreciation',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Official Testimonial Certificate',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 14),
                  // Wrap so the buttons stack instead of overflowing on a phone.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: goldColor,
                          side: BorderSide(color: goldColor),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () async => ExportService.printDocument(
                            buildCertificatePdf(
                              memberName: memberName,
                              memberCompany: memberCompany,
                              authorName: authorName,
                              authorCompany: authorCompany,
                              content: content,
                              date: date,
                              chapter: chapterName,
                              logo: await ExportService.logo(),
                            ),
                            name: 'testimonial_certificate'),
                        icon: const Icon(Icons.print, size: 14),
                        label: const Text('Print',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: goldColor,
                          side: BorderSide(color: goldColor),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () async => ExportService.savePdf(
                            buildCertificatePdf(
                              memberName: memberName,
                              memberCompany: memberCompany,
                              authorName: authorName,
                              authorCompany: authorCompany,
                              content: content,
                              date: date,
                              chapter: chapterName,
                              logo: await ExportService.logo(),
                            ),
                            'testimonial_certificate.pdf'),
                        icon: const Icon(Icons.download, size: 14),
                        label: const Text('Download PDF',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Certificate Container
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white, // Certificate sheet
                border: Border.all(color: goldColor, width: 4),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5)),
                ]
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: goldColor, width: 1),
                ),
                child: Column(
                  children: [
                    // Logo - this was a gradient box with the plain text
                    // "RMB" in it, not the real Rotary/RMB logo the
                    // exported PDF already uses. The on-screen certificate
                    // and the printed one should show the same logo.
                    Image.asset(
                      'assets/images/horizontal_logo.jpeg',
                      height: 44,
                    ),
                    const SizedBox(height: 12),
                    Text(chapterName,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    
                    const SizedBox(height: 32),
                    Text('CERTIFICATE OF APPRECIATION',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    const Text('This certificate is proudly presented to',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
                    
                    const SizedBox(height: 24),
                    Text(memberName,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: goldColor, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(memberCompany,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF111827), fontSize: 14, fontWeight: FontWeight.w600)),
                    
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'In sincere recognition of outstanding professional excellence, commitment to business networking, and invaluable testimonial support provided to $authorName ($authorCompany).',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black87, fontSize: 12, height: 1.5),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0D8C3)),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      width: double.infinity,
                      child: Text('"$content"', style: const TextStyle(color: Colors.black54, fontStyle: FontStyle.italic, fontSize: 13)),
                    ),
                    
                    const SizedBox(height: 48),
                    // Three fixed 120px blocks could not fit a phone width,
                    // which pushed the date out of alignment. Flex instead.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: _signatureBlock(authorName, 'Testimonial Provider')),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.workspace_premium, color: goldColor, size: 34),
                            const SizedBox(height: 4),
                            Text('VERIFIED',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: goldColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: _signatureBlock(date, 'Date')),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
