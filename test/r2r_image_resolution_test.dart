import 'package:flutter_test/flutter_test.dart';
import 'package:rmb_connect_app/widgets/image_viewer.dart';

void main() {
  group('ImageViewer URL Resolution & Extraction Tests', () {
    test('Absolute URL from Web is preserved untouched', () {
      const webUrl = 'https://example.com/uploads/meeting.jpg';
      expect(ImageViewer.resolveUrl(webUrl), equals(webUrl));
    });

    test('HTTP rmbconnect.in URL is upgraded to HTTPS for mobile security', () {
      const httpUrl = 'http://rmbconnect.in/uploads/meeting.jpg';
      expect(ImageViewer.resolveUrl(httpUrl), equals('https://rmbconnect.in/uploads/meeting.jpg'));
    });

    test('Protocol-relative URL is resolved to HTTPS', () {
      const protoUrl = '//example.com/uploads/meeting.jpg';
      expect(ImageViewer.resolveUrl(protoUrl), equals('https://example.com/uploads/meeting.jpg'));
    });

    test('Relative path with uploads/ is resolved to origin', () {
      expect(ImageViewer.resolveUrl('uploads/meeting.jpg'), equals('https://rmbconnect.in/uploads/meeting.jpg'));
      expect(ImageViewer.resolveUrl('/uploads/meeting.jpg'), equals('https://rmbconnect.in/uploads/meeting.jpg'));
    });

    test('Bare filename is resolved to uploads directory', () {
      expect(ImageViewer.resolveUrl('meeting.jpg'), equals('https://rmbconnect.in/uploads/meeting.jpg'));
    });

    test('Duplicate uploads prefix is cleaned', () {
      expect(ImageViewer.resolveUrl('uploads/uploads/meeting.jpg'), equals('https://rmbconnect.in/uploads/meeting.jpg'));
      expect(ImageViewer.resolveUrl('/uploads/uploads/meeting.jpg'), equals('https://rmbconnect.in/uploads/meeting.jpg'));
    });

    test('Quoted strings and JSON escaped slashes are unescaped', () {
      expect(ImageViewer.resolveUrl(r'"https:\/\/example.com\/uploads\/meeting.jpg"'), equals('https://example.com/uploads/meeting.jpg'));
      expect(ImageViewer.resolveUrl(r"'meeting.jpg'"), equals('https://rmbconnect.in/uploads/meeting.jpg'));
    });

    test('Spaces in URLs are safely URI encoded', () {
      expect(ImageViewer.resolveUrl('https://rmbconnect.in/uploads/r2r meeting 2026.jpg'), equals('https://rmbconnect.in/uploads/r2r%20meeting%202026.jpg'));
    });

    test('Null, none, and empty strings return empty', () {
      expect(ImageViewer.resolveUrl(''), equals(''));
      expect(ImageViewer.resolveUrl('null'), equals(''));
      expect(ImageViewer.resolveUrl('None'), equals(''));
      expect(ImageViewer.resolveUrl('undefined'), equals(''));
    });

    test('extractImageUrls parses JSON array of URLs', () {
      const jsonArr = '["https://example.com/uploads/meeting1.jpg", "meeting2.jpg"]';
      final list = ImageViewer.extractImageUrls(jsonArr);
      expect(list.length, equals(2));
      expect(list[0], equals('https://example.com/uploads/meeting1.jpg'));
      expect(list[1], equals('https://rmbconnect.in/uploads/meeting2.jpg'));
    });

    test('extractImageUrls parses comma-separated URLs', () {
      const commaList = 'https://example.com/m1.jpg, m2.jpg';
      final list = ImageViewer.extractImageUrls(commaList);
      expect(list.length, equals(2));
      expect(list[0], equals('https://example.com/m1.jpg'));
      expect(list[1], equals('https://rmbconnect.in/uploads/m2.jpg'));
    });

    test('extractImageUrls parses Dart List and Maps', () {
      final input = [
        'https://example.com/a.jpg',
        {'proof_image': 'b.jpg'}
      ];
      final list = ImageViewer.extractImageUrls(input);
      expect(list.length, equals(2));
      expect(list[0], equals('https://example.com/a.jpg'));
      expect(list[1], equals('https://rmbconnect.in/uploads/b.jpg'));
    });

    test('isBase64Image identifies data URIs and raw image base64', () {
      const dataUri = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP...';
      const rawJpegB64 = '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP...';
      const rawPngB64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      expect(ImageViewer.isBase64Image(dataUri), isTrue);
      expect(ImageViewer.isBase64Image(rawJpegB64), isTrue);
      expect(ImageViewer.isBase64Image(rawPngB64), isTrue);
      expect(ImageViewer.isBase64Image('https://example.com/photo.jpg'), isFalse);
      expect(ImageViewer.isBase64Image('meeting.jpg'), isFalse);
    });

    test('decodeBase64Image converts base64 string to Uint8List bytes', () {
      // 1x1 transparent PNG in base64
      const b64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      final bytes = ImageViewer.decodeBase64Image(b64);
      expect(bytes, isNotNull);
      expect(bytes!.isNotEmpty, isTrue);
      expect(bytes.first, equals(0x89)); // PNG header byte
      expect(bytes[1], equals(0x50)); // 'P'
    });

    test('resolveUrl preserves base64 and data URI without prepending origin', () {
      const dataUri = 'data:image/jpeg;base64,/9j/4AAQSkZJRg==';
      const rawJpegB64 = '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP...';
      expect(ImageViewer.resolveUrl(dataUri), equals(dataUri));
      expect(ImageViewer.resolveUrl(rawJpegB64), equals(rawJpegB64));
    });

    test('extractImageUrls extracts base64 image strings without mutilation', () {
      const b64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      final list = ImageViewer.extractImageUrls({'image_base64': b64});
      expect(list.length, equals(1));
      expect(list.first, equals(b64));
    });
  });
}
