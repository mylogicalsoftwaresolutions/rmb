import 'api_client.dart';

class TestimonialService {
  static Future<List<Map<String, dynamic>>> getTestimonials() async {
    try {
      final userId = await ApiClient.getUserId();
      final response = await ApiClient.get(
        'testimonials.php',
        queryParams: {'user_id': userId},
        baseOverride: ApiClient.flutterBaseUrl,
      );

      if (response is Map && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch testimonials: $e');
    }
  }

  static Future<Map<String, dynamic>> createTestimonial({
    required String title,
    required String content,
    required String receivedBy,
    String mediaType = 'text',
    String mediaFile = '',
  }) async {
    try {
      final userId = await ApiClient.getUserId();

      final response = await ApiClient.postFormData(
        'testimonials.php',
        {
          'user_id': userId,
          'action': 'add',
          'received_by': receivedBy,
          'title': title,
          'content': content,
          'media_type': mediaType,
          'media_file': mediaFile,
        },
        baseOverride: ApiClient.flutterBaseUrl,
      );

      return response is Map
          ? Map<String, dynamic>.from(response)
          : {'success': true};
    } catch (e) {
      throw Exception('Failed to create testimonial: $e');
    }
  }
}
