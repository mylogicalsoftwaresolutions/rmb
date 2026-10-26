import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_model.dart';
import 'activity_service.dart';
import 'api_client.dart';
import 'report_service.dart';

class DashboardService {
  static const String _cachedDashboardKeyPrefix = 'cached_dashboard_json_';
  static Future<Map<String, dynamic>>? _dashboardFuture;
  static Map<String, dynamic>? _dashboardCache;
  static String? _dashboardCacheUserId;

  /// Fetches the dashboard stats from dashboard.php.
  static Future<Map<String, dynamic>> getDashboardData(
      {bool refresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    if (!refresh &&
        _dashboardCache != null &&
        _dashboardCacheUserId == userId) {
      return _dashboardCache!;
    }
    // Return disk-cached data immediately if available so UI doesn't block on network
    if (!refresh && _dashboardCache == null && userId.isNotEmpty) {
      final diskJson = prefs.getString('$_cachedDashboardKeyPrefix$userId');
      if (diskJson != null && diskJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(diskJson);
          if (decoded is Map<String, dynamic>) {
            _dashboardCache = decoded;
            _dashboardCacheUserId = userId;
            // Silently refresh in background
            if (_dashboardFuture == null) {
              _fetchDashboardData().then((freshData) {
                _dashboardCache = freshData;
                _dashboardCacheUserId = userId;
                if (freshData.isNotEmpty) {
                  prefs.setString('$_cachedDashboardKeyPrefix$userId', jsonEncode(freshData));
                }
              }).catchError((_) {});
            }
            return decoded;
          }
        } catch (_) {}
      }
    }
    if (!refresh && _dashboardFuture != null) return _dashboardFuture!;
    final future = _fetchDashboardData().then((data) {
      _dashboardCache = data;
      _dashboardCacheUserId = userId;
      if (data.isNotEmpty) {
        prefs.setString('$_cachedDashboardKeyPrefix$userId', jsonEncode(data));
      }
      return data;
    });
    _dashboardFuture = future;
    future.then<void>(
      (_) {
        if (identical(_dashboardFuture, future)) _dashboardFuture = null;
      },
      onError: (_, __) {
        if (identical(_dashboardFuture, future)) _dashboardFuture = null;
      },
    );
    return future;
  }

  /// Fetch a new dashboard response after a successful activity write. This
  /// deliberately bypasses the in-memory value so the dashboard never shows a
  /// stale count after creating, editing, or updating a referral.
  static Future<Map<String, dynamic>> refreshDashboardData() {
    _weeklyCache = null;
    _monthlyCache = null;
    return getDashboardData(refresh: true);
  }

  static Future<Map<String, dynamic>> _fetchDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    final response = await ApiClient.postFormData(
      'dashboard.php',
      {'user_id': userId},
      baseOverride: ApiClient.flutterBaseUrl,
    );
    if (response is Map && response['data'] is Map) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }
    if (response is Map) return Map<String, dynamic>.from(response);
    return {};
  }

  /// GET reports.php?user_id=X
  static Future<Map<String, dynamic>> getReports() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    try {
      final response =
          await ApiClient.get(
        'reports.php',
        queryParams: {'user_id': userId},
        baseOverride: ApiClient.flutterBaseUrl,
      );
      if (response is Map<String, dynamic>) return response;
      if (response is Map) return Map<String, dynamic>.from(response);
      return {};
    } catch (e) {
      return {};
    }
  }

  static Map<String, dynamic>? _weeklyCache;
  static Map<String, dynamic>? _monthlyCache;

  /// Builds the dashboard's weekly activity figures from the same records the
  /// tracking pages display.  `dashboard.php` may return an all-time or
  /// month-to-date performance block, whereas the member web dashboard is
  /// explicitly week-based.
  static Future<Map<String, dynamic>> getWeeklyPerformance(
      {bool monthly = false, bool refresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    if (userId.isEmpty) return {};

    if (!refresh) {
      final cached = monthly ? _monthlyCache : _weeklyCache;
      if (cached != null) return cached;
    }

    final periodKey = monthly ? 'monthly' : 'weekly';
    try {
      final reports = await ReportService.getReports(period: periodKey);
      final perf = reports['performance'];
      if (perf is Map && perf.isNotEmpty) {
        final result = Map<String, dynamic>.from(perf);
        result['business_given_amount'] ??= result['business_given'] ?? 0;
        result['business_received_amount'] ??= result['business_received'] ?? 0;
        result['business_given_count'] ??= result['cnotes_given'] ?? 0;
        result['business_received_count'] ??= result['cnotes_received'] ?? 0;
        result['testimonials_given'] ??= result['testimony_count'] ?? 0;
        if (monthly) {
          _monthlyCache = result;
        } else {
          _weeklyCache = result;
        }
        return result;
      }
    } catch (e) {
      debugPrint('Error getting reports in getWeeklyPerformance: $e');
    }

    Future<List<ActivityModel>> load(String endpoint, String type,
        {Map<String, String>? params}) async {
      try {
        final result = await ActivityService.getActivities(
          endpoint,
          type,
          extraParams: params,
        );
        return List<ActivityModel>.from(result['activities'] ?? []);
      } catch (_) {
        return [];
      }
    }

    final results = await Future.wait([
      load('referrals.php', 'referral', params: const {'action': 'list_given'}),
      load('referrals.php', 'referral',
          params: const {'action': 'list_received'}),
      load('cnotes.php', 'cnote'),
      load('cnotes.php', 'cnote', params: const {'type': 'received'}),
      load('cnotes.php', 'cnote',
          params: const {'action': 'list_received'}),
      load('testimonials.php', 'testimonial'),
      load('r2r.php', 'r2r'),
      load('visitors.php', 'visitor'),
    ]);

    // The default referrals response is the member's given list. Some older
    // deployments ignore type=received and return that same list again, so do
    // not count it as received unless its rows are actually addressed to the
    // signed-in user.
    final period = monthly ? _thisMonth : _thisWeek;
    bool sameUser(dynamic value) {
      final left = value?.toString().trim() ?? '';
      if (left.isEmpty || left == 'null') return false;
      return left == userId ||
          (int.tryParse(left) != null &&
              int.tryParse(userId) != null &&
              int.parse(left) == int.parse(userId));
    }

    dynamic referralSender(ActivityModel item) => item.rawJson['given_by'] ??
        item.rawJson['sender_id'] ??
        item.rawJson['from_user_id'] ??
        item.rawJson['created_by'];

    final givenResponse = period(results[0]);
    // `action=list_given` is the primary scope, but older servers can ignore
    // it and return chapter-wide rows. If sender data is present, use it as
    // the source of truth so the card counts only referrals given by this user.
    // Very old responses omit sender data entirely; keep their API-scoped list
    // instead of incorrectly turning a valid count into zero.
    final hasSenderData =
        givenResponse.any((item) => referralSender(item) != null);
    final referralsGiven = hasSenderData
        ? givenResponse
            .where((item) => sameUser(referralSender(item)))
            .toList()
        : givenResponse;
    final receivedResponse = results[1];
    final sameAsGiven = receivedResponse.isNotEmpty &&
        receivedResponse.map((item) => item.id).toSet().length ==
            results[0].map((item) => item.id).toSet().length &&
        receivedResponse.map((item) => item.id).toSet().containsAll(
            results[0].map((item) => item.id).toSet());
    final receivedSource = sameAsGiven ? results[0] : receivedResponse;
    final referralsReceived = period(receivedSource).where((item) {
      final recipient =
          (item.rawJson['received_by'] ?? item.rawJson['member_id'])
              ?.toString();
      return recipient == userId;
    }).toList();
    final cnotesGivenResponse = results[2];
    final cnotesReceivedResponses = [...results[3], ...results[4]];
    final cnotes = period(<int, ActivityModel>{
      for (final item in [...cnotesGivenResponse, ...cnotesReceivedResponses])
        item.id: item,
    }.values.toList());
    final testimonials = period(results[5]);
    final r2r = period(results[6]);
    final visitors = period(results[7]);

    final cnotesGiven = period(cnotesGivenResponse)
        .where((item) => item.rawJson['given_by']?.toString() == userId)
        .toList();
    final cnotesReceived = cnotes
        .where((item) => item.rawJson['received_by']?.toString() == userId)
        .toList();
    final testimonialsGiven = testimonials
        .where((item) => item.rawJson['given_by']?.toString() == userId)
        .toList();
    final testimonialsReceived = testimonials
        .where((item) => item.rawJson['received_by']?.toString() == userId)
        .toList();

    double totalAmount(Iterable<ActivityModel> records) =>
        records.fold(0, (sum, item) => sum + item.amount);

    return {
      'referrals_given': referralsGiven.length,
      'referrals_received': referralsReceived.length,
      'business_given_amount': totalAmount(cnotesGiven),
      'business_given_count': cnotesGiven.length,
      'business_received_amount': totalAmount(cnotesReceived),
      'business_received_count': cnotesReceived.length,
      'testimonials_given': testimonialsGiven.length,
      'testimonials_received': testimonialsReceived.length,
      'r2r_count': r2r.length,
      'visitor_count': visitors.length,
    };
  }

  static List<ActivityModel> _thisWeek(List<ActivityModel> records) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - DateTime.monday));
    final end = start.add(const Duration(days: 7));
    return records.where((record) {
      final date = _periodDate(record);
      return date != null && !date.isBefore(start) && date.isBefore(end);
    }).toList();
  }

  static List<ActivityModel> _thisMonth(List<ActivityModel> records) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    return records.where((record) {
      final date = _periodDate(record);
      return date != null && !date.isBefore(start) && date.isBefore(end);
    }).toList();
  }

  /// Dashboard periods describe when an activity was recorded. Referrals can
  /// carry a separate future/past referral_date, so prefer the server's
  /// created timestamp and only fall back to the activity date when older API
  /// responses do not include it.
  static DateTime? _periodDate(ActivityModel record) {
    final created = record.rawJson['created_at'] ??
        record.rawJson['createdAt'] ??
        record.rawJson['entry_date'];
    return _parseActivityDate(created?.toString() ?? record.date);
  }

  static DateTime? _parseActivityDate(String raw) {
    final value = raw.trim().split(RegExp(r'[ T]')).first;
    final iso = DateTime.tryParse(value);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final dmy = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$')
        .firstMatch(value);
    if (dmy == null) return null;
    final day = int.tryParse(dmy.group(1)!);
    final month = int.tryParse(dmy.group(2)!);
    final year = int.tryParse(dmy.group(3)!);
    if (day == null || month == null || year == null) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

}
