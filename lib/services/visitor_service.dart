import 'api_client.dart';

class VisitorService {
  static Future<List<Map<String, dynamic>>> getVisitors() async {
    try {
      final userId = await ApiClient.getUserId();
      final response = await ApiClient.get(
        'visitors.php',
        queryParams: {'user_id': userId},
        baseOverride: ApiClient.flutterBaseUrl,
      );

      if (response is Map && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch visitors: $e');
    }
  }

  static Future<Map<String, dynamic>> inviteVisitor({
    required String visitorName,
    required String visitorMobile,
    required String visitorEmail,
    String visitorCompany = '',
    String visitorCategory = '',
  }) async {
    try {
      final userId = await ApiClient.getUserId();

      final response = await ApiClient.postFormData(
        'visitors.php',
        {
          'user_id': userId,
          'action': 'add',
          'name': visitorName,
          'mobile': visitorMobile,
          'email': visitorEmail,
          'company': visitorCompany,
          'business_category': visitorCategory,
          'visitor_name': visitorName,
          'visitor_mobile': visitorMobile,
          'visitor_email': visitorEmail,
          'visitor_company': visitorCompany,
          'visitor_category': visitorCategory,
        },
        baseOverride: ApiClient.flutterBaseUrl,
      );

      return response is Map
          ? Map<String, dynamic>.from(response)
          : {'success': true};
    } catch (e) {
      throw Exception('Failed to invite visitor: $e');
    }
  }
}
