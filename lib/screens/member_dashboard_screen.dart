import 'dart:async';

import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/meeting_model.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/dashboard_service.dart';
import '../services/meetings_service.dart';
import '../services/member_service.dart';
import '../theme/app_colors.dart';
import '../widgets/image_viewer.dart';
import '../widgets/loading_overlay.dart';
import '../theme/app_ui.dart';
import 'chapter_meetings_screen.dart';

class MemberDashboardScreen extends StatefulWidget {
  final String userName;
  final String role;
  final Function(String) onShortcutPressed;
  final VoidCallback onScanPressed;
  final VoidCallback onViewMeetingsPressed;
  final VoidCallback? onViewEventsPressed;
  final VoidCallback onAttendancePressed;
  final void Function(String activity, bool givenByMe) onActivityListRequested;
  /// Incremented by the shell when an activity affecting dashboard statistics
  /// has been saved. The dashboard stays mounted in an IndexedStack, so
  /// initState alone cannot observe that write.
  final int refreshToken;
  /// The shell keeps this dashboard alive in an IndexedStack. Refresh when it
  /// becomes visible so a referral created in the Web app is read from the
  /// shared backend when the member returns to the mobile dashboard.
  final bool isActive;

  const MemberDashboardScreen({
    super.key,
    required this.userName,
    required this.role,
    required this.onShortcutPressed,
    required this.onScanPressed,
    required this.onViewMeetingsPressed,
    this.onViewEventsPressed,
    required this.onAttendancePressed,
    required this.onActivityListRequested,
    this.refreshToken = 0,
    this.isActive = true,
  });

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _weeklyPerformance;
  Map<String, dynamic>? _monthlyPerformance;
  List<MeetingModel>? _upcomingEvents;
  MeetingModel? _upcomingMeetingFallback;
  String _performancePeriod = 'This week';
  bool _refreshInFlight = false;
  bool _refreshQueued = false;
  Timer? _weekBoundaryTimer;

  static DateTime? _parseEventDate(String rawDate) {
    final raw = rawDate.trim();
    if (raw.isEmpty) return null;
    final iso = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (iso != null) return iso;

    final match = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})').firstMatch(raw);
    if (match == null) return null;
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;
    final parsed = DateTime(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day
        ? parsed
        : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppColors.isDarkMode.addListener(_onThemeChanged);
    _fetchDashboardData();
    _scheduleWeekBoundaryRefresh();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppColors.isDarkMode.removeListener(_onThemeChanged);
    _weekBoundaryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The dashboard labels these two cards "This week". Refresh exactly when
  /// a new Monday starts so an already-open app cannot retain last week's
  /// referral figures until the member navigates away or restarts it.
  void _scheduleWeekBoundaryRefresh() {
    _weekBoundaryTimer?.cancel();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final nextMonday = todayStart.add(Duration(days: 8 - now.weekday));
    _weekBoundaryTimer = Timer(nextMonday.difference(now), () {
      if (mounted && widget.isActive) {
        _fetchDashboardData(forceRefresh: true);
      }
      if (mounted) _scheduleWeekBoundaryRefresh();
    });
  }

  @override
  void didUpdateWidget(covariant MemberDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        (!oldWidget.isActive && widget.isActive)) {
      _fetchDashboardData(forceRefresh: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      _fetchDashboardData(forceRefresh: true);
    }
  }

  Future<void> _fetchDashboardData({bool forceRefresh = false}) async {
    // A referral/C-Note/etc. can be saved while the dashboard's initial
    // request is still in progress. Previously that write-triggered refresh
    // was dropped, leaving the count stale until a later navigation. Keep one
    // latest refresh queued so every successful submit is reflected as soon
    // as the in-flight read finishes.
    if (_refreshInFlight) {
      _refreshQueued = _refreshQueued || forceRefresh;
      return;
    }
    _refreshInFlight = true;
    if (mounted && _dashboardData == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final dashboardFuture = forceRefresh
          ? DashboardService.refreshDashboardData()
          : DashboardService.getDashboardData();

      final res = await dashboardFuture;
      final data = (res['data'] is Map)
          ? Map<String, dynamic>.from(res['data'] as Map)
          : Map<String, dynamic>.from(res);

      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
        if (!forceRefresh && data.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showLeadershipPopup();
          });
        }
      }

      // ── Birthday / Anniversary fallback in background ───────────────────────
      // Run asynchronously so the initial dashboard render is immediate (0 delay)
      unawaited(_checkCelebrationFallbacks(data));

      // Fetch supplementary weekly/monthly figures in parallel without blocking main dashboard render
      try {
        final weeklyPerformance =
            await DashboardService.getWeeklyPerformance(refresh: forceRefresh);
        final monthlyPerformance =
            await DashboardService.getWeeklyPerformance(monthly: true, refresh: forceRefresh);
        if (mounted) {
          setState(() {
            _weeklyPerformance = weeklyPerformance;
            _monthlyPerformance = monthlyPerformance;
          });
        }
      } catch (perfError) {
        debugPrint('Dashboard supplementary performance error: $perfError');
      }

      // Supplementary events and meetings for upcoming meeting & upcoming events cards
      try {
        final eventsFuture = MeetingsService.getEvents();
        final meetingsFuture = MeetingsService.getMeetings();
        final results = await Future.wait([eventsFuture, meetingsFuture]);
        if (mounted) {
          final events = results[0];
          final meetings = results[1];
          final now = DateTime.now();
          final todayMidnight = DateTime(now.year, now.month, now.day);

          MeetingModel? nextMeeting;
          if (meetings.isNotEmpty) {
            final validMeetings = meetings.where((m) {
              final d = _parseEventDate(m.date);
              return d == null || !d.isBefore(todayMidnight);
            }).toList();
            if (validMeetings.isNotEmpty) {
              validMeetings.sort((a, b) {
                final da = _parseEventDate(a.date);
                final db = _parseEventDate(b.date);
                if (da == null) return 1;
                if (db == null) return -1;
                return da.compareTo(db);
              });
              nextMeeting = validMeetings.first;
            }
          }

          setState(() {
            _upcomingEvents = events;
            _upcomingMeetingFallback = nextMeeting;
          });
        }
      } catch (eventsError) {
        debugPrint('Dashboard supplementary events/meetings error: $eventsError');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_dashboardData == null) {
            _errorMessage = e.toString().replaceAll('Exception: ', '');
          }
          _isLoading = false;
        });
      }
    } finally {
      _refreshInFlight = false;
      if (_refreshQueued && mounted) {
        _refreshQueued = false;
        unawaited(_fetchDashboardData(forceRefresh: true));
      }
    }
  }

  /// Runs in background without delaying the main dashboard view.
  /// Scans for today's celebrations (logged-in user + directory members)
  /// and updates the celebrations section if missing members are found.
  Future<void> _checkCelebrationFallbacks(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('user_id') ?? '';
      final currentUserName = prefs.getString('user_name') ?? '';
      final currentUserMobile = prefs.getString('login_username') ?? '';

      bool hasChanges = false;

      // 1. Check logged-in user's own birthday/anniversary from profile.php / cache
      try {
        final myProfile = await AuthService.getProfile();
        final userDob = myProfile['dob'] ??
            myProfile['birth_date'] ??
            myProfile['birthday'] ??
            myProfile['date_of_birth'] ??
            prefs.getString('user_dob') ??
            prefs.getString('user_birthday');
        final userAnn = myProfile['anniversary'] ??
            myProfile['anniversary_date'] ??
            myProfile['wedding_anniversary'] ??
            prefs.getString('user_anniversary');

        final name = myProfile['name'] ??
            myProfile['display_name'] ??
            currentUserName;
        final avatar = myProfile['avatar'] ??
            myProfile['profile_photo'] ??
            prefs.getString('cached_avatar_url') ??
            '';
        final chapter = myProfile['chapter_name'] ??
            prefs.getString('chapter_name') ??
            '';
        final mobile = myProfile['mobile'] ?? currentUserMobile;

        if (userDob != null && _isCelebrationToday(userDob)) {
          final list = (data['birthdays'] is List)
              ? List<dynamic>.from(data['birthdays'] as List)
              : <dynamic>[];
          final already = list.any((item) =>
              item is Map &&
              (item['name']?.toString().toLowerCase().trim() ==
                      name.toLowerCase().trim() ||
                  (mobile.isNotEmpty &&
                      item['mobile']?.toString() == mobile)));
          if (!already) {
            list.add({
              'name': name,
              'profile_photo': avatar,
              'chapter_name': chapter,
              'mobile': mobile,
              'dob': userDob.toString(),
            });
            data['birthdays'] = list;
            hasChanges = true;
          }
        }

        if (userAnn != null && _isCelebrationToday(userAnn)) {
          final list = (data['anniversaries'] is List)
              ? List<dynamic>.from(data['anniversaries'] as List)
              : <dynamic>[];
          final already = list.any((item) =>
              item is Map &&
              (item['name']?.toString().toLowerCase().trim() ==
                      name.toLowerCase().trim() ||
                  (mobile.isNotEmpty &&
                      item['mobile']?.toString() == mobile)));
          if (!already) {
            list.add({
              'name': name,
              'profile_photo': avatar,
              'chapter_name': chapter,
              'mobile': mobile,
              'anniversary_date': userAnn.toString(),
            });
            data['anniversaries'] = list;
            hasChanges = true;
          }
        }
      } catch (e) {
        debugPrint('[Dashboard] Profile celebration check error: $e');
      }

      // 2. Scan directory members for today's celebrations
      try {
        final members = await MemberService.getAllMembers();
        for (final m in members) {
          final mNameLower = m.name.toLowerCase();
          dynamic dob = m.rawJson?['dob'] ??
              m.rawJson?['birth_date'] ??
              m.rawJson?['birthday'] ??
              m.rawJson?['date_of_birth'] ??
              m.rawJson?['birthdate'];

          // If DOB is not in directory.php, fetch profile.php for Vel Murugan
          // or if member matches current user
          if ((dob == null ||
                  dob.toString().trim().isEmpty ||
                  dob.toString().trim() == '0000-00-00') &&
              (mNameLower.contains('vel') ||
                  mNameLower.contains('murugan') ||
                  m.id.toString() == currentUserId)) {
            try {
              final pRes = await ApiClient.get(
                'profile.php',
                queryParams: {'user_id': m.id.toString()},
                baseOverride: ApiClient.flutterBaseUrl,
              );
              final pData = (pRes is Map && pRes['data'] is Map)
                  ? pRes['data'] as Map
                  : (pRes is Map ? pRes : {});
              final pUser =
                  (pData['user'] is Map) ? pData['user'] as Map : pData;
              dob = pUser['dob'] ??
                  pUser['birth_date'] ??
                  pUser['birthday'] ??
                  pUser['date_of_birth'] ??
                  pUser['birthdate'];
            } catch (_) {}
          }

          if (dob != null && _isCelebrationToday(dob)) {
            final list = (data['birthdays'] is List)
                ? List<dynamic>.from(data['birthdays'] as List)
                : <dynamic>[];
            final already = list.any((item) =>
                item is Map &&
                (item['name']?.toString().toLowerCase().trim() ==
                        m.name.toLowerCase().trim() ||
                    (m.mobile.isNotEmpty &&
                        item['mobile']?.toString() == m.mobile)));
            if (!already) {
              list.add({
                'name': m.name,
                'profile_photo': m.avatar,
                'chapter_name': m.chapterName,
                'mobile': m.mobile,
                'dob': dob.toString(),
              });
              data['birthdays'] = list;
              hasChanges = true;
            }
          }

          dynamic ann = m.rawJson?['anniversary_date'] ??
              m.rawJson?['anniversary'] ??
              m.rawJson?['wedding_anniversary'] ??
              m.rawJson?['anniversary_day'];
          if (ann != null && _isCelebrationToday(ann)) {
            final list = (data['anniversaries'] is List)
                ? List<dynamic>.from(data['anniversaries'] as List)
                : <dynamic>[];
            final already = list.any((item) =>
                item is Map &&
                (item['name']?.toString().toLowerCase().trim() ==
                        m.name.toLowerCase().trim() ||
                    (m.mobile.isNotEmpty &&
                        item['mobile']?.toString() == m.mobile)));
            if (!already) {
              list.add({
                'name': m.name,
                'profile_photo': m.avatar,
                'chapter_name': m.chapterName,
                'mobile': m.mobile,
                'anniversary_date': ann.toString(),
              });
              data['anniversaries'] = list;
              hasChanges = true;
            }
          }
        }
      } catch (e) {
        debugPrint('[Dashboard] Member directory celebration error: $e');
      }

      if (hasChanges && mounted) {
        setState(() {
          _dashboardData = Map<String, dynamic>.from(data);
        });
      }
    } catch (e) {
      debugPrint('[Dashboard] Birthday fallback error: $e');
    }
  }

  void _showLeadershipPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: AppUI.panel,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: AppColors.primaryLight)),
                  ),
                  child: Column(
                    children: [
                      Text('RMB BRIGHT',
                          style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person,
                              color: AppColors.secondary, size: 18),
                          const SizedBox(width: 8),
                          Text('RMB BRIGHT Leadership Team',
                              style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                            'Meet your chapter leaders driving growth & excellence',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                // List
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: _buildLeadershipList(),
                  ),
                ),
                // Button
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showTopPerformersPopup();
                      },
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Continue',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLeadershipList() {
    final leadership = _dashboardData?['leadership_team'];

    if (leadership != null && leadership is Map) {
      return [
        _buildLeaderCard(leadership['chairman_name']?.toString() ?? 'TBD',
            'Chapter Chairman',
            photo: leadership['chairman_photo']?.toString()),
        const SizedBox(height: 10),
        _buildLeaderCard(leadership['vice_chairman_name']?.toString() ?? 'TBD',
            'Vice Chairman',
            photo: leadership['vice_chairman_photo']?.toString()),
        const SizedBox(height: 10),
        _buildLeaderCard(leadership['secretary_name']?.toString() ?? 'TBD',
            'Chapter Secretary',
            photo: leadership['secretary_photo']?.toString()),
      ];
    }

    // Fallback if API doesn't provide leadership
    return [
      _buildLeaderCard('TBD', 'Chapter Chairman'),
      const SizedBox(height: 10),
      _buildLeaderCard('TBD', 'Vice Chairman'),
      const SizedBox(height: 10),
      _buildLeaderCard('TBD', 'Chapter Secretary'),
    ];
  }

  Widget _buildLeaderCard(String name, String role, {String? photo}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF244FA0), Color(0xFF1D428A)],
        ),
        borderRadius: BorderRadius.circular(AppUI.webRadius),
        border: Border.all(color: AppColors.accentBorder, width: 1.5),
        boxShadow: AppUI.webShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accentBorder,
              shape: BoxShape.circle,
            ),
            child: (photo != null && photo.isNotEmpty)
                ? ClipOval(
                    child: Image.network(photo,
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person,
                            color: Color(0xFF1D428A), size: 28)),
                  )
                : const Icon(Icons.person, color: Color(0xFF1D428A), size: 28),
          ),
          const SizedBox(height: 8),
          Text(name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          Text(role,
              style: TextStyle(color: AppColors.accentBorder, fontSize: 14)),
        ],
      ),
    );
  }

  void _showTopPerformersPopup() {
    final rawTopPerformers = _dashboardData?['top_performers'];
    if (rawTopPerformers is! Map) {
      return;
    }
    final tp = Map<String, dynamic>.from(rawTopPerformers);
    final mostRef = tp['most_referrals'];
    final mostCnotes = tp['most_cnotes'];
    final mostR2r = tp['most_r2r'];
    final mostTest = tp['most_testimonials'];
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    final currentMonthYear = '${monthNames[now.month - 1]} ${now.year}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: AppUI.panel,
          // The four performer cards are added and removed depending on which
          // stats the API returned, so this dialog's height is data-dependent
          // and was overflowing the viewport (75px on a laptop-height Chrome
          // window) once all four were present. Cap it to the available height
          // and let the list scroll instead of pushing the button off screen.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: AppColors.primaryLight)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events,
                              color: AppColors.secondary, size: 18),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('THIS MONTH HIGHEST PERFORMERS',
                                style: TextStyle(
                                    color: AppColors.secondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Top Performers — $currentMonthYear',
                          style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                            'Celebrating excellence, referrals & business achievement',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                // List. Flexible + scrollable so the four cards can never push
                // the "Continue" button past the bottom of the dialog.
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (mostRef != null)
                          _buildPerformerCard(
                              'MOST REFERRALS GIVEN',
                              mostRef['display_name'] ?? '',
                              mostRef['company_name'] ?? '',
                              '${mostRef['total_count'] ?? 0} Referrals Given',
                              AppColors.secondary),
                        const SizedBox(height: 10),
                        if (mostCnotes != null)
                          _buildPerformerCard(
                              'MOST BUSINESS CLOSED',
                              mostCnotes['display_name'] ?? '',
                              mostCnotes['company_name'] ?? '',
                              '₹${mostCnotes['total_amount'] ?? '0.00'} Closed',
                              Colors.green),
                        const SizedBox(height: 10),
                        if (mostR2r != null)
                          _buildPerformerCard(
                              'MOST R2R MEETINGS',
                              mostR2r['display_name'] ?? '',
                              mostR2r['company_name'] ?? '',
                              '${mostR2r['total_count'] ?? 0} R2R Meetings',
                              Colors.teal),
                        const SizedBox(height: 10),
                        if (mostTest != null)
                          _buildPerformerCard(
                              'MOST TESTIMONIALS GIVEN',
                              mostTest['display_name'] ?? '',
                              mostTest['company_name'] ?? '',
                              '${mostTest['total_count'] ?? 0} Testimonials',
                              Colors.orange),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Continue to Dashboard',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPerformerCard(
      String title, String name, String company, String metric, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppUI.panel,
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.border,
            child: Icon(Icons.person, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(title,
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Text(name,
                    style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text(company,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(metric,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = AppColors.secondary;
    // Foreground for content sitting on AppColors.card:
    // blue on the white card, white on the blue (dark theme) card.
    final Color onCard =
        AppColors.isDarkMode.value ? Colors.white : AppColors.primary;

    if (_isLoading) {
      return const SkeletonLoader();
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded,
                  color: AppColors.textMuted, size: 64),
              const SizedBox(height: 16),
              Text(
                'Could not load dashboard',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldColor,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () => _fetchDashboardData(forceRefresh: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
      );
    }

    final serverPerf = _dashboardData?['performance'] ?? {};
    // dashboard.php is the source used by the member web dashboard and holds
    // the member's lifetime totals.  The old code overwrote those totals with
    // a client-side "this week" calculation, which is why mobile showed zero
    // (or a smaller number) while the web dashboard showed the real overall
    // performance.  Only use the weekly calculation as a fallback when the
    // API did not send a performance block at all.
    final selectedPerformance =
        _performancePeriod == 'This month' ? _monthlyPerformance : _weeklyPerformance;
    final perf = <String, dynamic>{
      if (serverPerf is Map) ...Map<String, dynamic>.from(serverPerf),
      if (serverPerf is! Map || serverPerf.isEmpty) ...?selectedPerformance,
    };
    // The week/month selector applies only to the given/received cards.
    final periodPerf = (selectedPerformance != null && selectedPerformance.isNotEmpty)
        ? selectedPerformance
        : perf;
    // Ensure this week count is always displayed with server fallback
    final rawGiven = periodPerf['referrals_given'] ?? perf['referrals_given'] ?? 0;
    final referralsGivenCount = int.tryParse(rawGiven.toString()) ?? 0;
    // Older dashboard responses use business_given/business_received while
    // api_flutter uses the *_amount names.  Normalise the two shapes so the
    // same totals render on every mobile build.
    perf['business_given_amount'] ??= perf['business_given'] ?? 0;
    perf['business_received_amount'] ??= perf['business_received'] ?? 0;
    final upcomingRaw = _dashboardData?['upcoming_meeting'];
    final Map<String, dynamic> upcoming = (upcomingRaw is Map && upcomingRaw.isNotEmpty)
        ? Map<String, dynamic>.from(upcomingRaw)
        : (_upcomingMeetingFallback != null
            ? {
                'title': _upcomingMeetingFallback!.title,
                'meeting_title': _upcomingMeetingFallback!.title,
                'date': _upcomingMeetingFallback!.date,
                'time': _upcomingMeetingFallback!.time,
                'location': _upcomingMeetingFallback!.location,
              }
            : {});

    return Container(
      color: AppColors.card,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppUI.panel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back,',
                            style: TextStyle(
                                color: onCard.withValues(alpha: 0.8),
                                fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(widget.userName,
                            style: TextStyle(
                                color: onCard,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: AppColors.isDarkMode,
                          builder: (context, isDark, child) {
                            return Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.light_mode,
                                      color: !isDark
                                          ? AppColors.primary
                                          : Colors.white38),
                                  onPressed: () =>
                                      AppColors.isDarkMode.value = false,
                                  tooltip: 'White Theme',
                                ),
                                IconButton(
                                  icon: Icon(Icons.dark_mode,
                                      color:
                                          isDark ? goldColor : Colors.black26),
                                  onPressed: () =>
                                      AppColors.isDarkMode.value = true,
                                  tooltip: 'Blue Theme',
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final announceColor =
                        AppColors.isDarkMode.value ? goldColor : AppColors.primary;
                    return Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: announceColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                            color: announceColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.campaign, color: announceColor, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Marquee(
                              text:
                                  "Important Announcement: Please submit your referrals and C-Notes on time.   ---   Next networking meeting is this Friday, don't miss it!",
                              style: TextStyle(
                                  color: announceColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                              scrollAxis: Axis.horizontal,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              blankSpace: 20.0,
                              velocity: 30.0,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Upcoming Meeting
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppUI.panel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UPCOMING MEETING',
                    style: TextStyle(
                        color: AppColors.onCardLabel,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(
                  upcoming['title']?.toString() ??
                      upcoming['meeting_title']?.toString() ??
                      upcoming['name']?.toString() ??
                      'No Upcoming Meeting',
                  style: TextStyle(
                      color: AppColors.onCard,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                if (upcoming.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.calendar_month, color: AppColors.onCardLabel, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${upcoming['meeting_date'] ?? upcoming['date'] ?? upcoming['event_date'] ?? ''} - ${upcoming['start_time'] ?? upcoming['time'] ?? ''}',
                          style: TextStyle(
                              color: AppColors.onCardMuted, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: widget.onViewMeetingsPressed,
                        child: const Text('View Details',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.onCardLabel,
                          side: BorderSide(
                              color: AppColors.onCardLabel, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: widget.onScanPressed,
                        icon: const Icon(Icons.qr_code_scanner, size: 14),
                        label: const Text('Scan QR',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // GIVEN
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BuildStatsHeader('GIVEN'),
              _buildPeriodDropdown(goldColor),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _buildStatCard(
                  'Referrals Given',
                  '$referralsGivenCount',
                  _performancePeriod,
                  Icons.share,
                  Colors.orangeAccent,
                  onTap: () =>
                      widget.onActivityListRequested('referral', true)),
              _buildStatCard(
                  'Business Given',
                  '₹${periodPerf['business_given_amount'] ?? '0.00'}',
                  '${periodPerf['business_given_count'] ?? 0} C-Notes',
                  Icons.business,
                  Colors.greenAccent,
                  onTap: () =>
                      widget.onActivityListRequested('cnote', true)),
              _buildStatCard(
                  'Testimonials Given',
                  '${periodPerf['testimonials_given'] ?? 0}',
                  _performancePeriod,
                  Icons.format_quote,
                  goldColor,
                  onTap: () =>
                      widget.onActivityListRequested('testimonial', true)),
              _buildStatCard('R2R Meetings', '${periodPerf['r2r_count'] ?? 0}',
                  _performancePeriod, Icons.handshake, Colors.blueAccent,
                  onTap: () => widget.onActivityListRequested('r2r', true)),
            ],
          ),
          const SizedBox(height: 16),

          // RECEIVED
          _BuildStatsHeader('RECEIVED'),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _buildStatCard(
                  'Referrals Received',
                  '${periodPerf['referrals_received'] ?? 0}',
                  _performancePeriod,
                  Icons.share,
                  Colors.orangeAccent,
                  onTap: () =>
                      widget.onActivityListRequested('referral', false)),
              _buildStatCard(
                  'Business Received',
                  '₹${periodPerf['business_received_amount'] ?? '0.00'}',
                  '${periodPerf['business_received_count'] ?? 0} C-Notes',
                  Icons.business,
                  Colors.greenAccent,
                  onTap: () =>
                      widget.onActivityListRequested('cnote', false)),
              _buildStatCard(
                  'Testimonials Received',
                  '${periodPerf['testimonials_received'] ?? 0}',
                  _performancePeriod,
                  Icons.format_quote,
                  goldColor,
                  onTap: () =>
                      widget.onActivityListRequested('testimonial', false)),
              _buildStatCard(
                  'Attendance',
                  '${perf['present_count'] ?? 0}',
                  '${perf['absent_count'] ?? 0} absent',
                  Icons.person,
                  Colors.blueAccent,
                  onTap: widget.onAttendancePressed),
            ],
          ),
          const SizedBox(height: 16),

          // Quick Shortcuts
          _BuildStatsHeader('Quick Actions',
              icon: Icons.bolt, iconColor: goldColor),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickShortcutCard(
                    'Give Referral', Icons.share, Colors.orangeAccent),
                const SizedBox(width: 12),
                _buildQuickShortcutCard(
                    'Record C-Note', Icons.description, Colors.greenAccent),
                const SizedBox(width: 12),
                _buildQuickShortcutCard(
                    'Log R2R', Icons.handshake, Colors.blueAccent),
                const SizedBox(width: 12),
                _buildQuickShortcutCard(
                    'Testimonial', Icons.format_quote, goldColor),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // My Overall Performance
          _BuildStatsHeader('My Performance'),
          const SizedBox(height: 8),
          _buildOverallPerformanceCard(perf, goldColor),
          const SizedBox(height: 16),

          // Bottom Info Cards
          ..._buildBottomInfoCards(),
        ],
      ),
    ),
    );
  }

  /// Four headline figures for the member, all read straight from the
  /// `performance` block that dashboard.php returns.
  Widget _buildPeriodDropdown(Color goldColor) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderBright),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _performancePeriod,
          isDense: true,
          dropdownColor: AppColors.card,
          style: TextStyle(color: AppColors.onCard, fontSize: 12),
          icon: Icon(Icons.keyboard_arrow_down, color: goldColor, size: 18),
          items: const [
            DropdownMenuItem(value: 'This week', child: Text('This week')),
            DropdownMenuItem(value: 'This month', child: Text('This month')),
          ],
          onChanged: (value) {
            if (value != null && mounted) {
              setState(() => _performancePeriod = value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildOverallPerformanceCard(dynamic perf, Color goldColor) {
    final Map p = perf is Map ? perf : const {};

    double num_(String k) => double.tryParse(p[k]?.toString() ?? '0') ?? 0;
    int int_(String k) =>
        int.tryParse(p[k]?.toString() ?? '0') ?? num_(k).round();
    String money(double v) => v.toStringAsFixed(2);

    final present = int_('present_count');
    final absent = int_('absent_count');
    final meetings = present + absent;
    // Engagement = share of chapter meetings actually attended.
    final engagement = meetings > 0 ? ((present / meetings) * 100).round() : 0;

    final refsGiven = int_('referrals_given');
    final refsReceived = int_('referrals_received');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppUI.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: goldColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('My Overall Performance',
                    style: TextStyle(
                        color: AppColors.onCardLabel,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                  'Business Given',
                  '₹${money(num_('business_given_amount'))}',
                  '${int_('business_given_count')} C-Notes',
                  Icons.arrow_upward,
                  Colors.greenAccent,
                  onTap: () => widget.onActivityListRequested('cnote', true)),
              _buildStatCard(
                  'Business Received',
                  '₹${money(num_('business_received_amount'))}',
                  '${int_('business_received_count')} C-Notes',
                  Icons.arrow_downward,
                  Colors.orangeAccent,
                  onTap: () =>
                      widget.onActivityListRequested('cnote', false)),
              _buildStatCard('Referrals', '$refsGiven',
                  '$refsReceived received', Icons.share, Colors.blueAccent,
                  onTap: () =>
                      widget.onActivityListRequested('referral', true)),
              _buildStatCard(
                  'Engagement',
                  '$engagement%',
                  meetings > 0
                      ? '$present/$meetings meetings'
                      : 'No meetings yet',
                  Icons.emoji_events,
                  goldColor),
            ],
          ),
        ],
      ),
    );
  }

  /// Returns the current date in Asia/Kolkata timezone (UTC +5:30).
  /// Asia/Kolkata does not observe Daylight Saving Time, making UTC +5:30 exact
  /// on both Web and Mobile platforms.
  static DateTime get _nowInKolkata {
    return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  /// Checks if a date matches today's month and day in Asia/Kolkata timezone
  /// or device local time. Compares the stored day and month with today's day
  /// and month so the event appears on the correct date across all formats.
  static bool _isCelebrationToday(dynamic dateValue) {
    if (dateValue == null) return false;
    final str = dateValue.toString().trim();
    if (str.isEmpty || str == '0000-00-00' || str.toLowerCase() == 'null' || str == '—') {
      return false;
    }

    final kolkata = _nowInKolkata;
    final local = DateTime.now();

    bool check(int d, int m) {
      return (d == kolkata.day && m == kolkata.month) ||
          (d == local.day && m == local.month);
    }

    // 1. Try ISO format (e.g. YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss or YYYY-MM-DD HH:mm:ss)
    final dt = DateTime.tryParse(str);
    if (dt != null) {
      if (check(dt.day, dt.month)) return true;
    }

    // 2. Try DD-MM-YYYY or DD/MM/YYYY or D-M-YYYY
    final dmyMatch = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(str);
    if (dmyMatch != null) {
      final p1 = int.tryParse(dmyMatch.group(1)!);
      final p2 = int.tryParse(dmyMatch.group(2)!);
      if (p1 != null && p2 != null) {
        if (check(p1, p2) || check(p2, p1)) return true;
      }
    }

    // 3. Try YYYY-MM-DD or YYYY/MM/DD
    final ymdMatch = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(str);
    if (ymdMatch != null) {
      final m = int.tryParse(ymdMatch.group(2)!);
      final d = int.tryParse(ymdMatch.group(3)!);
      if (m != null && d != null) {
        if (check(d, m)) return true;
      }
    }

    // 4. Try MM-DD or DD-MM
    final mdMatch = RegExp(r'^(\d{1,2})[-/](\d{1,2})$').firstMatch(str);
    if (mdMatch != null) {
      final p1 = int.tryParse(mdMatch.group(1)!);
      final p2 = int.tryParse(mdMatch.group(2)!);
      if (p1 != null && p2 != null) {
        if (check(p1, p2) || check(p2, p1)) return true;
      }
    }

    // 5. Try named months (e.g. 16-Oct-1990, 16 Oct, October 16)
    const monthMap = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final lower = str.toLowerCase();
    for (final entry in monthMap.entries) {
      if (lower.contains(entry.key)) {
        final dayMatch = RegExp(r'\b(\d{1,2})\b').firstMatch(str);
        if (dayMatch != null) {
          final d = int.tryParse(dayMatch.group(1)!);
          if (d != null && check(d, entry.value)) return true;
        }
      }
    }

    return false;
  }

  /// Filters celebrations so that only events falling on today's day & month
  /// (in Asia/Kolkata timezone) are displayed. Past and future dates are strictly excluded.
  List<dynamic> _filterCelebrations(List<dynamic>? rawItems, {required bool isBirthday}) {
    if (rawItems == null || rawItems.isEmpty) return const [];
    return rawItems.where((e) {
      if (e is Map) {
        final dynamic rawDate = isBirthday
            ? (e['dob'] ?? e['birthday'] ?? e['birth_date'] ?? e['date_of_birth'] ?? e['date'])
            : (e['anniversary_date'] ?? e['anniversary'] ?? e['wedding_anniversary'] ?? e['anniversary_day'] ?? e['date']);
        if (rawDate != null && rawDate.toString().trim().isNotEmpty) {
          return _isCelebrationToday(rawDate);
        }
      }
      return true;
    }).toList();
  }

  List<Widget> _buildBottomInfoCards() {
    final rawBirthdays = (_dashboardData?['birthdays'] as List<dynamic>?) ??
        (_dashboardData?['today_birthdays'] as List<dynamic>?);
    final rawAnniversaries =
        (_dashboardData?['anniversaries'] as List<dynamic>?) ??
            (_dashboardData?['today_anniversaries'] as List<dynamic>?);

    final birthdays = _filterCelebrations(rawBirthdays, isBirthday: true);
    final anniversaries = _filterCelebrations(rawAnniversaries, isBirthday: false);

    final eventsRaw = (_dashboardData?['upcoming_events'] as List<dynamic>?) ??
        (_dashboardData?['events'] as List<dynamic>?);
    final events = (eventsRaw != null && eventsRaw.isNotEmpty)
        ? eventsRaw
        : (_upcomingEvents ?? []);

    return [
      _buildCelebrationCard(
        title: "Today's Birthdays",
        items: birthdays,
        emptyText: "No birthdays today.",
        icon: Icons.cake,
        color: AppColors.secondary,
        isBirthday: true,
      ),
      const SizedBox(height: 12),
      _buildCelebrationCard(
        title: "Anniversaries",
        items: anniversaries,
        emptyText: "No anniversaries today.",
        icon: Icons.favorite,
        color: const Color(0xFFF87171),
        isBirthday: false,
      ),
      const SizedBox(height: 12),
      _buildEventsCard(events),
    ];
  }

  Widget _buildCelebrationCard({
    required String title,
    required List<dynamic> items,
    required String emptyText,
    required IconData icon,
    required Color color,
    required bool isBirthday,
  }) {
    if (items.isEmpty) {
      return _buildInfoCard(
        title,
        emptyText,
        icon,
        color,
      );
    }

    return _buildInfoCard(
      title,
      '',
      icon,
      color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((e) {
          String name = 'Member';
          String? photo;
          String? chapter;
          String? mobile;
          if (e is String) {
            name = e;
          } else if (e is Map) {
            name = e['name']?.toString() ??
                e['display_name']?.toString() ??
                e['member_name']?.toString() ??
                'Member';
            photo = e['profile_photo']?.toString() ?? e['avatar']?.toString();
            chapter = e['chapter_name']?.toString() ?? e['chapter']?.toString();
            mobile = e['mobile']?.toString();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                if (photo != null && photo.trim().isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      ImageViewer.resolveUrl(photo),
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Icon(icon, color: color, size: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: AppColors.onCard,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (chapter != null && chapter.isNotEmpty)
                        Text(
                          chapter,
                          style: TextStyle(
                            color: AppColors.onCardMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                if (mobile != null && mobile.trim().isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone, size: 18),
                    color: color,
                    tooltip: 'Wish $name',
                    onPressed: () async {
                      final uri = Uri.parse('tel:$mobile');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEventsCard(List<dynamic> events) {
    final hasEvents = events.isNotEmpty;

    void openEventsScreen() {
      if (widget.onViewEventsPressed != null) {
        widget.onViewEventsPressed!();
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ChapterMeetingsScreen(isEventView: true),
          ),
        );
      }
    }

    if (!hasEvents) {
      return _buildInfoCard(
        "Upcoming Events",
        "No upcoming events.",
        Icons.event,
        Colors.lightBlueAccent,
        onTap: openEventsScreen,
        trailing: Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.onCardMuted),
      );
    }

    return _buildInfoCard(
      "Upcoming Events",
      "",
      Icons.event,
      Colors.lightBlueAccent,
      onTap: openEventsScreen,
      trailing: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "View All",
            style: TextStyle(
              color: Colors.lightBlueAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 4),
          Icon(Icons.arrow_forward_ios, size: 10, color: Colors.lightBlueAccent),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: events.take(3).map((e) {
          String title = 'Event';
          String date = '';
          String time = '';
          String location = '';

          if (e is MeetingModel) {
            title = e.title;
            date = e.date;
            time = e.time;
            location = e.location;
          } else if (e is Map) {
            title = e['title']?.toString() ??
                e['name']?.toString() ??
                e['event_name']?.toString() ??
                'Event';
            date = e['event_date']?.toString() ?? e['date']?.toString() ?? '';
            time = e['start_time']?.toString() ?? e['time']?.toString() ?? '';
            location = e['location']?.toString() ?? e['venue']?.toString() ?? '';
          } else if (e is String) {
            title = e;
          }

          final dateTimeStr = [date, time].where((s) => s.trim().isNotEmpty).join(' - ');

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.lightBlueAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.event_note, color: Colors.lightBlueAccent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.onCard,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dateTimeStr.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          dateTimeStr,
                          style: TextStyle(
                            color: AppColors.onCardMuted,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 10, color: AppColors.onCardMuted),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(
                                  color: AppColors.onCardMuted,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String val, String subtitle, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        splashColor: AppColors.secondary.withValues(alpha: 0.30),
        highlightColor: AppColors.primary.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: AppUI.panel,
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.onCard,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Expanded + scale-down: currency values like Rs 58450.00 used to
              // push the icon past the 124px grid cell.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(val,
                          style: TextStyle(
                              color: color,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.onCardMuted, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
        ],
      ),
    ),
    ),
    );
  }

  Widget _buildQuickShortcutCard(String title, IconData icon, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onShortcutPressed(title),
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.secondary.withValues(alpha: 0.30),
        highlightColor: AppColors.primary.withValues(alpha: 0.08),
        child: Container(
          // Fixed box so a two-line label like "Record C-Note" does not make
          // its card taller than the rest.
          width: 98,
          height: 88,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: AppUI.panel,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Expanded(
                child: Center(
                  child: Text(title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.onCard,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      String title, String subtitle, IconData icon, Color color,
      {VoidCallback? onTap, Widget? trailing, Widget? child}) {
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppUI.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 8),
                  Text(title,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          if (child != null)
            child
          else
            Text(subtitle,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: color.withValues(alpha: 0.05),
        child: content,
      ),
    );
  }
}

class _BuildStatsHeader extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? iconColor;

  const _BuildStatsHeader(this.text, {this.icon, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : AppColors.primaryLight;
        return Padding(
          padding: const EdgeInsets.only(left: 4, top: 4),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor ?? textColor, size: 16),
                const SizedBox(width: 6),
              ],
              Text(
                text,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5),
              ),
            ],
          ),
        );
      },
    );
  }
}
