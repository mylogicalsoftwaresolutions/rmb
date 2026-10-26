import 'api_client.dart';

class EventMeetingService {
  static Future<List<Map<String, dynamic>>> getEvents() async {
    try {
      final userId = await ApiClient.getUserId();
      final response = await ApiClient.get(
        'events.php',
        queryParams: {'user_id': userId},
        baseOverride: ApiClient.flutterBaseUrl,
      );

      if (response is Map && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch events: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getMeetings() async {
    try {
      final userId = await ApiClient.getUserId();
      final response = await ApiClient.get(
        'meetings.php',
        queryParams: {'user_id': userId},
        baseOverride: ApiClient.flutterBaseUrl,
      );

      if (response is Map && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch meetings: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllEventsAndMeetings() async {
    try {
      final events = await getEvents();
      final meetings = await getMeetings();

      // Combine and sort by date
      final combined = [...events, ...meetings];
      combined.sort((a, b) {
        final dateA = DateTime.tryParse(a['date']?.toString() ?? a['event_date']?.toString() ?? '');
        final dateB = DateTime.tryParse(b['date']?.toString() ?? b['event_date']?.toString() ?? '');

        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });

      return combined;
    } catch (e) {
      throw Exception('Failed to fetch events and meetings: $e');
    }
  }
}
