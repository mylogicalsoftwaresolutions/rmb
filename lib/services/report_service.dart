import 'api_client.dart';
import 'api_endpoints.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportService {
  /// Maps the period labels used in the UI onto the values reports.php accepts.
  static const Map<String, String> periodParams = {
    'This Week': 'weekly',
    'This Month': 'monthly',
    'This Quarter': 'quarterly',
    'This Year': 'yearly',
    'This Term': 'term',
    'Lifetime': 'lifetime',
  };

  /// Metrics supported by leaderboard.php.
  ///
  /// Verified against the live endpoint: anything outside this set is
  /// silently ignored and the response falls back to referrals_given, so
  /// only these are offered as filters. Attendance, testimonials, visitors
  /// and c-notes are NOT supported by the endpoint.
  static const Map<String, String> leaderboardMetrics = {
    'Referrals Given': 'referrals_given',
    'Referrals Received': 'referrals_received',
    'R2R Meetings': 'r2r_count',
    'Business Given': 'business_given_amount',
    'Business Received': 'business_received_amount',
  };

  /// Periods the leaderboard endpoint honours.
  static const Map<String, String> leaderboardPeriods = {
    'This Week': 'weekly',
    'This Month': 'monthly',
    'This Year': 'yearly',
  };

  /// Chapter leaderboard, ranked by [metric] over [period].
  static Future<List<Map<String, dynamic>>> getChapterLeaderboard({
    String period = 'monthly',
    String metric = 'referrals_given',
  }) async {
    final userId = await ApiClient.getUserId();
    final prefs = await SharedPreferences.getInstance();
    final chapterId = prefs.getString('chapter_id') ?? '';
    if (chapterId.isEmpty) return const [];
    final res = await ApiClient.get(
      ApiEndpoints.leaderboard,
      queryParams: {
        'user_id': userId,
        'chapter_id': chapterId,
        'period': period,
        'metric': metric,
      },
      baseOverride: ApiClient.flutterBaseUrl,
    );
    return parseChapterLeaderboard(res);
  }

  /// Fallback when the ranking endpoint is temporarily unavailable. The
  /// directory endpoint keeps the member list visible; activity scores are 0.
  static Future<List<Map<String, dynamic>>> getChapterMembers({
    String? chapterName,
  }) async {
    final userId = await ApiClient.getUserId();
    final res = await ApiClient.get(
      ApiEndpoints.directory,
      queryParams: {'user_id': userId},
      baseOverride: ApiClient.flutterBaseUrl,
    );
    return parseDirectoryMembers(
      res,
      userId: userId,
      chapterName: chapterName,
    );
  }

  /// The live endpoint has existed in more than one response format:
  /// `{leaderboard: [...]}`, `{data: [...]}`, and
  /// `{data: {leaderboard: [...]}}`.  The previous reader only accepted the
  /// last form, so a valid response looked like an empty chapter board in the
  /// app. Keep this parsing intentionally tolerant while normalising every
  /// row into the shape the performance page renders.
  static List<Map<String, dynamic>> parseChapterLeaderboard(dynamic response) {
    dynamic board;
    if (response is List) {
      board = response;
    } else if (response is Map) {
      final data = response['data'];
      board = response['leaderboard'] ??
          (data is Map ? data['leaderboard'] ?? data['data'] : data);
    }
    if (board is! List) return const [];

    return board.whereType<Map>().map((row) {
      final normalized = Map<String, dynamic>.from(row);
      // Older versions return the selected metric under its own key rather
      // than the generic `score` the UI consumes.
      normalized['score'] ??= normalized['value'] ??
          normalized['referrals_given'] ??
          normalized['referrals_received'] ??
          normalized['r2r_count'] ??
          normalized['business_given_amount'] ??
          normalized['business_received_amount'] ??
          0;
      normalized['id'] ??= normalized['user_id'] ?? normalized['member_id'];
      return normalized;
    }).toList();
  }

  static List<Map<String, dynamic>> parseDirectoryMembers(
    dynamic response, {
    required String userId,
    String? chapterName,
  }) {
    if (response is! Map) return const [];
    final data = response['data'];
    final members = data is Map ? data['members'] : response['members'];
    if (members is! List) return const [];

    final rows = members.whereType<Map>().map((member) {
      final row = Map<String, dynamic>.from(member);
      row['score'] ??= 0;
      return row;
    }).toList();
    final preferredChapter = chapterName?.trim() ?? '';
    final ownChapter = preferredChapter.isNotEmpty
        ? preferredChapter
        : rows
                .firstWhere(
                  (row) => row['id']?.toString() == userId,
                  orElse: () => const <String, dynamic>{},
                )['chapter_name']
                ?.toString()
                .trim() ??
            '';
    if (ownChapter.isEmpty) return const [];
    return rows
        .where((row) =>
            row['chapter_name']?.toString().trim().toLowerCase() ==
            ownChapter.toLowerCase())
        .toList();
  }

  static Future<Map<String, dynamic>> getReports({String? period}) async {
    try {
      final userId = await ApiClient.getUserId();
      final response = await ApiClient.get('reports.php', queryParams: {
        'user_id': userId,
        if (period != null) 'period': period,
      }, baseOverride: ApiClient.flutterBaseUrl);

      if (response is Map) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          if (data['performance'] is Map || data['leaderboard'] is List) {
            return data;
          }
          return {'performance': data, 'leaderboard': <dynamic>[]};
        }
        if (data is Map) {
          final normalized = Map<String, dynamic>.from(data);
          if (normalized['performance'] is Map ||
              normalized['leaderboard'] is List) {
            return normalized;
          }
          return {'performance': normalized, 'leaderboard': <dynamic>[]};
        }
        return Map<String, dynamic>.from(response);
      }
      return {'performance': {}, 'leaderboard': []};
    } catch (e) {
      // reports.php sometimes returns an HTML page (session expired / login
      // redirect) instead of JSON. _processResponse throws
      // "Unexpected response from server: <!DOCTYPE html>..." in that case.
      // Return empty data so the stats page shows zeros with a Retry button
      // rather than a raw HTML dump in the error message.
      final msg = e.toString();
      final isHtmlResponse = msg.contains('<!DOCTYPE') ||
          msg.contains('<html') ||
          msg.contains('Unexpected response from server');
      if (isHtmlResponse) {
        return {'performance': {}, 'leaderboard': []};
      }
      throw Exception('Failed to fetch reports: $e');
    }
  }

  static Future<Map<String, dynamic>> getPerformance({String? period}) async {
    try {
      final reports = await getReports(period: period);
      return reports['performance'] ?? {};
    } catch (e) {
      // Swallow HTML/unexpected responses — return empty so UI shows zeros.
      final msg = e.toString();
      if (msg.contains('<!DOCTYPE') || msg.contains('Unexpected response')) {
        return {};
      }
      throw Exception('Failed to fetch performance: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getLeaderboard() async {
    try {
      final reports = await getReports();
      final leaderboard = reports['leaderboard'];
      if (leaderboard is List) {
        return List<Map<String, dynamic>>.from(leaderboard);
      }
      return [];
    } catch (e) {
      // Swallow HTML/unexpected responses — return empty leaderboard.
      return [];
    }
  }
}
