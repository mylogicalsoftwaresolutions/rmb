import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmb_connect_app/screens/testimonial_certificate_screen.dart';
import 'package:rmb_connect_app/services/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('certificate pdf carries logo and centre content', () async {
    final logo = await ExportService.logo();
    expect(logo, isNotNull, reason: 'bundled logo asset should load');

    final doc = buildCertificatePdf(
      memberName: 'KAYALVIZHI',
      memberCompany: 'KAYAL TEXTILES',
      authorName: 'A.KARTHIKEYAN',
      authorCompany: 'HASHTAG CLOTHINGS',
      // Deliberately long - this is the exact scenario that pushed the
      // signature row off the bottom of a fixed-size Page.
      content:
          'Excellent service and very reliable business partner. Always '
          'delivers on time, communicates clearly at every step, and goes '
          'far beyond what was promised. Highly recommended to anyone in '
          'the chapter looking for a dependable, professional vendor who '
          'treats every referral with genuine care and follow-through.',
      date: '01 Sep 2026',
      chapter: 'RMB SALEM CHAMPIONS',
      logo: logo,
    );

    final bytes = await doc.save();
    final tempDir = Directory.systemTemp.createTempSync('rmb_cert_test');
    final outputFile = File('${tempDir.path}/cert_out.pdf');
    outputFile.writeAsBytesSync(bytes);

    addTearDown(() => tempDir.deleteSync(recursive: true));
    expect(outputFile.existsSync(), isTrue);
    expect(bytes.length, greaterThan(1000));
  });
}
