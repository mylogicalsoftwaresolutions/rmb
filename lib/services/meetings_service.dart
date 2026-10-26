import 'package:shared_preferences/shared_preferences.dart';
import '../models/meeting_model.dart';
import 'api_client.dart';

class MeetingsService {
  static Future<String> _userId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? '';
  }

  /// GET meetings.php?user_id=X
  static Future<List<MeetingModel>> getMeetings() async {
    final response = await ApiClient.get(
      'meetings.php',
      queryParams: {'user_id': await _userId()},
      baseOverride: ApiClient.flutterBaseUrl,
    );
    return _parse(response);
  }

  /// GET events.php?user_id=X
  static Future<List<MeetingModel>> getEvents() async {
    final response = await ApiClient.get(
      'events.php',
      queryParams: {'user_id': await _userId()},
      baseOverride: ApiClient.flutterBaseUrl,
    );
    return _parse(response);
  }

  static List<MeetingModel> _parse(dynamic response) {
    List<dynamic> rawList = [];
    if (response is Map && response['data'] is List) {
      rawList = response['data'] as List<dynamic>;
    } else if (response is Map && response['meetings'] is List) {
      rawList = response['meetings'] as List<dynamic>;
    } else if (response is Map && response['events'] is List) {
      rawList = response['events'] as List<dynamic>;
    } else if (response is List) {
      rawList = response;
    }
    final meetings = <MeetingModel>[];
    for (final json in rawList) {
      if (json is! Map) continue;
      try {
        meetings.add(MeetingModel.fromJson(Map<String, dynamic>.from(json)));
      } catch (_) {
        // Ignore malformed rows and keep the list visible.
      }
    }
    return meetings;
  }
}
