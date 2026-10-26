import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/user_avatar.dart';
import '../models/member.dart';
import '../models/activity.dart';
import '../models/activity_model.dart';
import '../services/member_service.dart';
import '../services/activity_service.dart';
import '../services/api_client.dart';
import '../services/push_notification_service.dart';
import '../theme/app_ui.dart';
import 'performance_screen.dart';
import 'members_screen.dart';
import 'my_profile_screen.dart';
import 'chapter_meetings_screen.dart';
import 'attendance_screen.dart';
import 'scan_qr_screen.dart';
import 'member_dashboard_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/submit_activity_modal.dart';
import '../widgets/change_password_modal.dart';
import 'tracking_screens.dart';
import 'my_chapter_screen.dart';
import 'my_reports_screen.dart';
import 'notifications_screen.dart';
import '../theme/app_colors.dart';

class MemberShellScreen extends StatefulWidget {
  final Map<String, String> user;
  final Future<void> Function() onLogout;

  const MemberShellScreen({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<MemberShellScreen> createState() => _MemberShellScreenState();
}

class _MemberShellScreenState extends State<MemberShellScreen> {
  int _currentIndex = 0;
  final Set<int> _visitedIndices = {0};
  int _dashboardRefreshToken = 0;
  // Bumped per category on a successful submit. The six list screens below
  // sit in an IndexedStack and stay mounted, so switching _currentIndex
  // alone would land on the tab without refetching - it would still show
  // whatever it last loaded, missing the record that was just added. Keying
  // the screen off this counter forces Flutter to remount it, which reruns
  // its initState fetch.
  final Map<String, int> _refreshTicks = {
    'referral': 0,
    'cnote': 0,
    'r2r': 0,
    'testimonial': 0,
    'visitor': 0,
    'giveask': 0,
  };
  final Map<String, bool> _activityListGivenByMe = {
    'referral': true,
    'cnote': true,
    'r2r': true,
    'testimonial': true,
  };
  final Map<String, int> _activityListNavigationTicks = {
    'referral': 0,
    'cnote': 0,
    'r2r': 0,
    'testimonial': 0,
  };

  static const Map<String, int> _tabIndexForCategory = {
    'referral': 9,
    'cnote': 10,
    'r2r': 11,
    'testimonial': 12,
    'visitor': 13,
    'giveask': 14,
  };

  void _switchTab(int targetIndex) {
    if (!mounted) return;
    setState(() {
      _currentIndex = targetIndex;
      _visitedIndices.add(targetIndex);
    });
    if (targetIndex == 4 && _activities.isEmpty) {
      _fetchActivities();
    }
  }

  Widget _buildTab(int index, Widget child) {
    if (!_visitedIndices.contains(index)) {
      return const SizedBox.shrink();
    }
    return child;
  }

  void _openActivityList(String activity, bool givenByMe) {
    final targetIndex = switch (activity) {
      'referral' => 18,
      'cnote' => 20,
      _ => _tabIndexForCategory[activity],
    };
    if (targetIndex == null) return;
    setState(() {
      _activityListGivenByMe[activity] = givenByMe;
      _activityListNavigationTicks[activity] =
          (_activityListNavigationTicks[activity] ?? 0) + 1;
      _currentIndex = targetIndex;
      _visitedIndices.add(targetIndex);
    });
  }
  // Indices:
  // 0: Dashboard
  // 1: Stats / Performance
  // 2: Directory / MembersScreen
  // 3: My Profile
  // 4: My Updates
  // 5: Meetings
  // 6: Events
  // 7: Attendance
  // 8: Scan QR

  List<Member> _members = [];

  /// Set when the directory could not be loaded. Every member dropdown in the
  /// app is fed from `_members`, so this has to stay visible rather than being
  /// papered over with placeholder data.
  String? _membersError;
  List<ActivityItem> _activities = [];
  bool _activitiesLoading = false;

  @override
  void initState() {
    super.initState();
    _visitedIndices.add(_currentIndex);
    AppColors.isDarkMode.addListener(_onThemeChanged);
    PushNotificationService.notificationTap.addListener(_openPushDestination);
    // Covers an app launched from a terminated state by a notification: the
    // FCM listener can publish the tap before this shell has been built.
    _openPushDestination();
    _fetchMembers();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppColors.isDarkMode.removeListener(_onThemeChanged);
    PushNotificationService.notificationTap.removeListener(_openPushDestination);
    super.dispose();
  }

  void _openPushDestination() {
    final payload = PushNotificationService.notificationTap.value;
    if (payload == null) return;
    final type = (payload['type'] ?? '').trim().toLowerCase();

    if (type == 'referral' || payload.containsKey('referral_id')) {
      PushNotificationService.notificationTap.value = null;
      if (!mounted) return;
      _openActivityList('referral', false);
    } else if (type == 'r2r' || payload.containsKey('r2r_id')) {
      PushNotificationService.notificationTap.value = null;
      if (!mounted) return;
      _openActivityList('r2r', false);
    } else if (type == 'cnote' || type == 'cnotes' || payload.containsKey('cnote_id')) {
      PushNotificationService.notificationTap.value = null;
      if (!mounted) return;
      _openActivityList('cnote', false);
    } else if (type == 'testimonial' || payload.containsKey('testimonial_id')) {
      PushNotificationService.notificationTap.value = null;
      if (!mounted) return;
      _openActivityList('testimonial', false);
    }
  }

  /// Builds the "My Updates" feed from every activity endpoint. One endpoint
  /// failing shouldn't blank the whole feed, so each is caught separately.
  Future<void> _fetchActivities() async {
    const sources = <String, String>{
      'referrals.php': 'referrals',
      'cnotes.php': 'cnotes',
      'r2r.php': 'r2r',
      'testimonials.php': 'testimonials',
      'visitors.php': 'visitors',
    };

    final collected = <ActivityItem>[];
    final results = await Future.wait(sources.entries.map((entry) async {
      try {
        final res = await ActivityService.getActivities(entry.key, entry.value);
        return List<ActivityItem>.from(
          List<ActivityModel>.from(res['activities'] ?? [])
              .map((m) => ActivityItem.fromJson(m.rawJson, entry.value)),
        );
      } catch (e) {
        debugPrint('[Shell] ${entry.key} failed: $e');
        return <ActivityItem>[];
      }
    }));
    for (final result in results) {
      collected.addAll(result);
    }

    collected.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) {
      setState(() {
        _activities = collected;
        _activitiesLoading = false;
      });
    }
  }

  Future<void> _fetchMembers() async {
    // If memory is empty, immediately populate from disk cache so forms are usable instantly
    if (_members.isEmpty) {
      final cached = await MemberService.getCachedMembers();
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _members = cached.map((m) => m.toMember()).toList();
          _membersError = null;
        });
      }
    }

    try {
      final res = await MemberService.getAllMembers(refresh: true);
      if (mounted) {
        setState(() {
          _members = res.map((m) => m.toMember()).toList();
          _membersError = null;
        });
      }
      await _backfillChapterName();
    } catch (e) {
      debugPrint('Error fetching members: $e');
      if (mounted) {
        setState(() {
          // If we already have members loaded from disk or previous fetch, preserve them!
          if (_members.isEmpty) {
            final raw = e is ApiException
                ? e.message
                : 'Could not load the member list.';
            _membersError = (raw.contains('<') || raw.contains('<!DOCTYPE'))
                ? 'Could not load the member list. Please tap Retry.'
                : raw;
          } else {
            _membersError = null;
          }
        });
      }
    }
  }

  /// Login and auth.php?action=me have both been seen returning chapter_id
  /// without a matching chapter_name - every screen that reads chapter_name
  /// from prefs would then show a blank/dash where the chapter should be.
  /// Filtering already switched to chapter_id (reliable), but the display
  /// value still needs a real name; resolve it once here, from whichever
  /// fetched member shares the same chapter_id, and persist it so every
  /// other screen's prefs.getString('chapter_name') picks it up too.
  Future<void> _backfillChapterName() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString('chapter_name') ?? '').isNotEmpty) return;
    final chapterId = int.tryParse(prefs.getString('chapter_id') ?? '');
    if (chapterId == null || chapterId == 0) return;
    for (final m in _members) {
      if (m.chapterId == chapterId &&
          m.chapter.isNotEmpty &&
          m.chapter != 'Unknown') {
        await prefs.setString('chapter_name', m.chapter);
        break;
      }
    }
  }

  Future<void> _openSubmitModal(
      {String? initialCategory,
      Map<String, dynamic>? initialGiveAsk,
      ActivityModel? initialActivity}) async {
    String? mappedCategory = initialCategory;
    if (initialCategory == 'referrals') mappedCategory = 'referral';
    if (initialCategory == 'cnotes') mappedCategory = 'cnote';
    if (initialCategory == 'testimonials') mappedCategory = 'testimonial';
    if (initialCategory == 'visitors') mappedCategory = 'visitor';

    await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SubmitActivityModal(
          members: _members,
          membersError: _membersError,
          onRetryMembers: _membersError == null ? null : _fetchMembers,
          initialCategory: mappedCategory,
          initialGiveAsk: initialGiveAsk,
          initialActivity: initialActivity,
          onSubmit: (newItem) {
            // Keep the callback if any legacy code needs it, though we rely on API refetches now.
          },
          onSubmitted: (category) {
            final targetIndex = _tabIndexForCategory[category];
            if (targetIndex == null) return;
            setState(() {
              _refreshTicks[category] = (_refreshTicks[category] ?? 0) + 1;
              _dashboardRefreshToken++;
              _currentIndex = targetIndex;
              _visitedIndices.add(targetIndex);
            });
            // The modal already shows the success snackbar with a full summary.
            // No duplicate needed here.
          },
        );
      },
    );
  }

  void _openChangePasswordModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ChangePasswordModal(),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.border),
        ),
        title: Text('Confirm Logout', style: AppUI.titleText(size: 16)),
        content: Text('Are you sure you want to sign out of your account?',
            style: AppUI.bodyText(size: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppUI.mutedText(size: 14)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await widget.onLogout();
            },
            child: const Text('Logout',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _getScreenTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'My Performance';
      case 2:
        return 'Members Directory';
      case 3:
        return 'My Profile';
      case 4:
        return 'My Updates';
      case 5:
        return 'Chapter Meetings';
      case 6:
        return 'Chapter Events';
      case 7:
        return 'Attendance Tracker';
      case 8:
        return 'Scan QR Code';
      case 9:
        return 'Referrals';
      case 10:
        return 'C-Notes';
      case 11:
        return 'R2R Meetings';
      case 12:
        return 'Testimonials';
      case 13:
        return 'Invite Visitor';
      case 14:
        return 'Weekly Give & Ask';
      case 15:
        return 'My Chapter';
      case 16:
        return 'My Performance Report';
      case 17:
        return 'Notifications';
      case 18:
        return 'Given Referrals';
      case 19:
        return 'Received Referrals';
      case 20:
        return _activityListGivenByMe['cnote'] == false
            ? 'Received C-Notes'
            : 'Given C-Notes';
      default:
        return 'Member Portal';
    }
  }

  Widget _buildDrawerItem({
    required String title,
    required IconData icon,
    required int targetIndex,
    required bool isSelected,
  }) {
    final goldColor = AppColors.secondary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: isSelected ? AppColors.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: ListTile(
          dense: true,
          minVerticalPadding: 0,
          visualDensity: const VisualDensity(vertical: 0),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Icon(icon, color: goldColor, size: 18),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            _switchTab(targetIndex);
          },
        ),
      ),
    );
  }

  Widget _buildDrawerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 14, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
            color: AppColors.secondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = AppColors.secondary;

    return PopScope(
        canPop: _currentIndex == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _currentIndex != 0) {
            _switchTab(0);
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.appBar,
            elevation: 0,
            leading: Builder(
              builder: (context) {
                if (_currentIndex >= 18) {
                  return IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => _switchTab(0),
                  );
                }
                return IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                );
              },
            ),
          title: Text(
            _getScreenTitle(),
            style: TextStyle(
                color: goldColor, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.notifications, color: goldColor, size: 22),
              onPressed: () => _switchTab(17),
            ),
            IconButton(
              icon: Icon(Icons.qr_code_scanner, color: goldColor, size: 22),
              onPressed: () => _switchTab(8),
            ),
            PopupMenuButton<String>(
              offset: const Offset(0, 48),
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppColors.border),
              ),
              onSelected: (value) {
                if (value == 'profile') {
                  _switchTab(3);
                } else if (value == 'password') {
                  _openChangePasswordModal();
                } else if (value == 'logout') {
                  _showLogoutConfirmation();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person,
                          color: AppColors.menuPrimary, size: 20),
                      const SizedBox(width: 12),
                      Text('My Profile',
                          style: TextStyle(
                              color: AppColors.menuPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'password',
                  child: Row(
                    children: [
                      Icon(Icons.vpn_key_outlined,
                          color: AppColors.menuSecondary, size: 20),
                      const SizedBox(width: 12),
                      Text('Change Password',
                          style: TextStyle(
                              color: AppColors.menuSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent, size: 20),
                      SizedBox(width: 12),
                      Text('Logout',
                          style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                // Was a fixed person glyph, so a member who had uploaded a
                // photo never saw it here. Loads the same `avatar` the profile
                // screen shows, with the glyph kept as the fall back.
                child: UserAvatar(
                  size: 20,
                  iconColor: AppColors.primaryLight,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: Divider(color: goldColor, height: 2, thickness: 2),
          ),
        ),
        drawer: Drawer(
          width: 245,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(14)),
            side: BorderSide(color: Color(0xFFFFC107), width: 1.5),
          ),
          backgroundColor: AppColors.appBar,
          child: Column(
            children: [
              // Drawer Header — tapping the logo closes the drawer and returns
              // to the Dashboard.
              Material(
                color: AppColors.sidebar,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _switchTab(0);
                  },
                  splashColor: goldColor.withValues(alpha: 0.25),
                  highlightColor: goldColor.withValues(alpha: 0.12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(
                        top: 32, bottom: 14, left: 20, right: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: goldColor, width: 2),
                          ),
                          child: ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Image.asset(
                                'assets/images/horizontal_logo.jpeg',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                    Icons.campaign,
                                    color: goldColor,
                                    size: 20),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RMB Connect',
                                style: TextStyle(
                                    color: goldColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ),
                              const Text(
                                'Member Portal',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // MAIN
                    _buildDrawerSectionHeader('MAIN'),
                    _buildDrawerItem(
                        title: 'Dashboard',
                        icon: Icons.dashboard,
                        targetIndex: 0,
                        isSelected: _currentIndex == 0),
                    _buildDrawerItem(
                        title: 'Performance',
                        icon: Icons.emoji_events,
                        targetIndex: 1,
                        isSelected: _currentIndex == 1),
                    _buildDrawerItem(
                        title: 'Directory',
                        icon: Icons.people,
                        targetIndex: 2,
                        isSelected: _currentIndex == 2),
                    _buildDrawerItem(
                        title: 'My Profile',
                        icon: Icons.person,
                        targetIndex: 3,
                        isSelected: _currentIndex == 3),
                    _buildDrawerItem(
                        title: 'My Updates',
                        icon: Icons.history,
                        targetIndex: 4,
                        isSelected: _currentIndex == 4),

                    // SUBMIT ACTIVITY
                    _buildDrawerSectionHeader('SUBMIT ACTIVITY'),
                    _buildDrawerItem(
                        title: 'Referrals',
                        icon: Icons.share,
                        targetIndex: 9,
                        isSelected: _currentIndex == 9),
                    _buildDrawerItem(
                        title: 'C-Notes',
                        icon: Icons.business,
                        targetIndex: 10,
                        isSelected: _currentIndex == 10),
                    _buildDrawerItem(
                        title: 'R2R',
                        icon: Icons.handshake,
                        targetIndex: 11,
                        isSelected: _currentIndex == 11),
                    _buildDrawerItem(
                        title: 'Testimonials',
                        icon: Icons.format_quote,
                        targetIndex: 12,
                        isSelected: _currentIndex == 12),
                    _buildDrawerItem(
                        title: 'Invite Visitor',
                        icon: Icons.person_add_alt,
                        targetIndex: 13,
                        isSelected: _currentIndex == 13),
                    _buildDrawerItem(
                        title: 'Give & Ask',
                        icon: Icons.volunteer_activism,
                        targetIndex: 14,
                        isSelected: _currentIndex == 14),

                    // CHAPTER
                    _buildDrawerSectionHeader('CHAPTER'),
                    _buildDrawerItem(
                        title: 'Meetings',
                        icon: Icons.calendar_month,
                        targetIndex: 5,
                        isSelected: _currentIndex == 5),
                    _buildDrawerItem(
                        title: 'Events',
                        icon: Icons.calendar_month,
                        targetIndex: 6,
                        isSelected: _currentIndex == 6),
                    _buildDrawerItem(
                        title: 'Attendance',
                        icon: Icons.check_circle_outline,
                        targetIndex: 7,
                        isSelected: _currentIndex == 7),
                    _buildDrawerItem(
                        title: 'Scan QR',
                        icon: Icons.qr_code_scanner,
                        targetIndex: 8,
                        isSelected: _currentIndex == 8),
                    _buildDrawerItem(
                        title: 'My Reports',
                        icon: Icons.pie_chart,
                        targetIndex: 16,
                        isSelected: _currentIndex == 16),
                    _buildDrawerItem(
                        title: 'Notifications',
                        icon: Icons.notifications,
                        targetIndex: 17,
                        isSelected: _currentIndex == 17),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Container(
          color: AppColors.bg,
          child: IndexedStack(
          index: _currentIndex >= 21 ? 0 : _currentIndex,
          children: [
            MemberDashboardScreen(
              userName: widget.user['name'] ?? 'Chapter Member',
              role: widget.user['role'] ?? 'Member',
              onScanPressed: () {
                _switchTab(8);
              },
              onViewMeetingsPressed: () {
                // This is a generic dashboard shortcut with no specific
                // meeting attached, so it belongs on the Meetings list, not
                // pushed into a meeting's own detail screen (which now
                // requires a real MeetingModel - it used to accept none
                // because it only ever showed hardcoded placeholder data).
                _switchTab(5);
              },
              onViewEventsPressed: () {
                _switchTab(6);
              },
              onAttendancePressed: () {
                _switchTab(7);
              },
              onActivityListRequested: _openActivityList,
              refreshToken: _dashboardRefreshToken,
              isActive: _currentIndex == 0,
              onShortcutPressed: (shortcut) {
                String cat = 'referrals';
                if (shortcut == 'Record C-Note' || shortcut == 'C-Notes') {
                  cat = 'cnotes';
                }
                if (shortcut == 'Log R2R' || shortcut == 'R2R Meeting') {
                  cat = 'r2r';
                }
                if (shortcut == 'Testimonial') cat = 'testimonials';
                _openSubmitModal(initialCategory: cat);
              },
            ),
            _buildTab(
              1,
              const PerformanceScreen(
                businessGiven: 0,
                businessReceived: 0,
                referralsGiven: 0,
                referralsReceived: 0,
                r2rCount: 0,
                attendanceRate: 0,
              ),
            ),
            _buildTab(
              2,
              MembersScreen(members: _members, isAdmin: false),
            ),
            _buildTab(
              3,
              MyProfileScreen(user: widget.user),
            ),
            _buildTab(
              4,
              _MyUpdatesScreen(
                  activities: _activities, isLoading: _activitiesLoading),
            ),
            _buildTab(
              5,
              const ChapterMeetingsScreen(isEventView: false),
            ),
            _buildTab(
              6,
              const ChapterMeetingsScreen(isEventView: true),
            ),
            _buildTab(
              7,
              const AttendanceScreen(),
            ),
            _buildTab(
              8,
              ScanQrScreen(
                isActive: _currentIndex == 8,
                onBackPressed: () => _switchTab(0),
              ),
            ),
            _buildTab(
              9,
              ReferralsScreen(
                  key: ValueKey(
                      'referral-${_refreshTicks['referral']}-${_activityListNavigationTicks['referral']}'),
                  initialGivenByMe: _activityListGivenByMe['referral'] ?? true,
                  onOpenSubmit: () =>
                      _openSubmitModal(initialCategory: 'referrals'),
                  onEditItem: (act) => _openSubmitModal(
                      initialCategory: 'referrals', initialActivity: act)),
            ),
            _buildTab(
              10,
              CNotesScreen(
                  key: ValueKey(
                      'cnote-${_refreshTicks['cnote']}-${_activityListNavigationTicks['cnote']}'),
                  initialGivenByMe: _activityListGivenByMe['cnote'] ?? true,
                  onOpenSubmit: () => _openSubmitModal(initialCategory: 'cnotes'),
                  onEditItem: (act) => _openSubmitModal(
                      initialCategory: 'cnotes', initialActivity: act)),
            ),
            _buildTab(
              11,
              R2RScreen(
                  key: ValueKey(
                      'r2r-${_refreshTicks['r2r']}-${_activityListNavigationTicks['r2r']}'),
                  initialGivenByMe: _activityListGivenByMe['r2r'] ?? true,
                  onOpenSubmit: () => _openSubmitModal(initialCategory: 'r2r'),
                  onEditItem: (act) => _openSubmitModal(
                      initialCategory: 'r2r', initialActivity: act)),
            ),
            _buildTab(
              12,
              TestimonialsScreen(
                  key: ValueKey(
                      'testimonial-${_refreshTicks['testimonial']}-${_activityListNavigationTicks['testimonial']}'),
                  initialGivenByMe: _activityListGivenByMe['testimonial'] ?? true,
                  onOpenSubmit: () =>
                      _openSubmitModal(initialCategory: 'testimonials'),
                  onEditItem: (act) => _openSubmitModal(
                      initialCategory: 'testimonials', initialActivity: act)),
            ),
            _buildTab(
              13,
              InviteVisitorScreen(
                  key: ValueKey('visitor-${_refreshTicks['visitor']}'),
                  onOpenSubmit: () =>
                      _openSubmitModal(initialCategory: 'visitors'),
                  onEditItem: (act) => _openSubmitModal(
                      initialCategory: 'visitors', initialActivity: act)),
            ),
            _buildTab(
              14,
              GiveAskScreen(
                key: ValueKey('giveask-${_refreshTicks['giveask']}'),
                onOpenSubmit: () => _openSubmitModal(initialCategory: 'giveask'),
                onEditItem: (item) => _openSubmitModal(
                    initialCategory: 'giveask', initialActivity: item),
              ),
            ),
            _buildTab(15, const MyChapterScreen()),
            _buildTab(16, const MyReportsScreen()),
            _buildTab(17, NotificationsScreen(isActive: _currentIndex == 17)),
            _buildTab(
              18,
              ReferralsScreen(
                  key: ValueKey(
                      'given-referrals-${_refreshTicks['referral']}-${_activityListNavigationTicks['referral']}'),
                  listOnly: true,
                  initialGivenByMe:
                      _activityListGivenByMe['referral'] ?? true,
                  onOpenSubmit: () =>
                      _openSubmitModal(initialCategory: 'referrals'),
                  onEditItem: (act) => _openSubmitModal(
                      initialCategory: 'referrals', initialActivity: act)),
            ),
            _buildTab(
              19,
              ReferralsScreen(
                  key: ValueKey(
                      'received-referrals-${_refreshTicks['referral']}-${_activityListNavigationTicks['referral']}'),
                  receivedOnly: true,
                  initialGivenByMe: false,
                  onOpenSubmit: () =>
                      _openSubmitModal(initialCategory: 'referrals'),
                  onEditItem: (act) => _openSubmitModal(
                      initialCategory: 'referrals', initialActivity: act)),
            ),
            _buildTab(
              20,
              CNotesScreen(
                  key: ValueKey(
                      'business-cnotes-${_refreshTicks['cnote']}-${_activityListNavigationTicks['cnote']}'),
                  listOnly: true,
                  initialGivenByMe: _activityListGivenByMe['cnote'] ?? true,
                  onOpenSubmit: () =>
                      _openSubmitModal(initialCategory: 'cnotes'),
                  onEditItem: (act) => _openSubmitModal(
                      initialCategory: 'cnotes', initialActivity: act)),
            ),
          ],
        ),
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _currentIndex == 0
              ? 0
              : (_currentIndex == 1
                  ? 1
                  : (_currentIndex == 2 ? 3 : (_currentIndex == 3 ? 4 : 0))),
          onTapTab: (index) {
            if (index == 2) {
              _openSubmitModal();
            } else {
              if (index == 0) _switchTab(0);
              if (index == 1) _switchTab(1);
              if (index == 3) _switchTab(2); // Directory
              if (index == 4) _switchTab(3); // Profile
            }
          },
          onOpenSubmitModal: _openSubmitModal,
        ),
      ),
  );
}
}

class _MyUpdatesScreen extends StatefulWidget {
  final List<ActivityItem> activities;
  final bool isLoading;

  const _MyUpdatesScreen({required this.activities, this.isLoading = false});

  @override
  State<_MyUpdatesScreen> createState() => _MyUpdatesScreenState();
}

class _MyUpdatesScreenState extends State<_MyUpdatesScreen> {
  String _activityType = 'All Types';
  String _approvalStatus = 'All Statuses';

  /// Applies the Activity Type and Approval Status dropdowns, which
  /// previously had no effect on the rendered list.
  List<ActivityItem> get _visibleActivities {
    const typeToCategory = <String, String>{
      'Referrals': 'referrals',
      'C-Notes': 'cnotes',
      'R2R': 'r2r',
      'Testimonials': 'testimonials',
    };

    return widget.activities.where((a) {
      if (_activityType != 'All Types' &&
          a.category != typeToCategory[_activityType]) {
        return false;
      }
      if (_approvalStatus != 'All Statuses' && a.status != _approvalStatus) {
        return false;
      }
      return true;
    }).toList();
  }

  String _formatCategory(String cat) {
    if (cat == 'cnotes') return 'C-Note';
    if (cat == 'r2r') return 'R2R';
    if (cat == 'referrals') return 'Referral';
    if (cat == 'testimonials') return 'Testimonial';
    return cat;
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = AppColors.secondary;
    final cardBgColor = AppColors.card;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "A unified history of everything you've submitted",
            style: AppUI.mutedText(size: 11),
          ),
          const SizedBox(height: 16),

          // Dropdowns
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Activity Type',
                    style: TextStyle(
                        color: goldColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: AppColors.cardGradient,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _activityType,
                      isExpanded: true,
                      dropdownColor: AppColors.card,
                      icon: Icon(Icons.arrow_drop_down,
                          color: AppColors.textMuted),
                      style: AppUI.bodyText(size: 13),
                      items: [
                        'All Types',
                        'Referrals',
                        'C-Notes',
                        'R2R',
                        'Testimonials'
                      ]
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _activityType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Approval Status',
                    style: TextStyle(
                        color: goldColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: AppColors.cardGradient,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _approvalStatus,
                      isExpanded: true,
                      dropdownColor: AppColors.card,
                      icon: Icon(Icons.arrow_drop_down,
                          color: AppColors.textMuted),
                      style: AppUI.bodyText(size: 13),
                      items: ['All Statuses', 'Approved', 'Pending', 'Rejected']
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _approvalStatus = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Timeline List
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: widget.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _visibleActivities.isEmpty
                    ? const AppEmptyState('No updates yet.',
                        icon: Icons.history)
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _visibleActivities.length,
                        itemBuilder: (context, index) {
                          final items = _visibleActivities;
                          final a = items[index];
                          final isLast = index == items.length - 1;

                          Color iconColor;
                          IconData iconData;
                          if (a.category == 'referrals') {
                            iconColor = Colors.orange;
                            iconData = Icons.share;
                          } else if (a.category == 'cnotes') {
                            iconColor = Colors.greenAccent;
                            iconData = Icons.description;
                          } else if (a.category == 'r2r') {
                            iconColor = Colors.lightBlueAccent;
                            iconData = Icons.handshake;
                          } else {
                            iconColor = goldColor;
                            iconData = Icons.format_quote;
                          }

                          bool isApproved = a.status == 'Approved';

                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Timeline Graphics
                                SizedBox(
                                  width: 40,
                                  child: Stack(
                                    alignment: Alignment.topCenter,
                                    children: [
                                      if (!isLast)
                                        Container(
                                          margin:
                                              const EdgeInsets.only(top: 24),
                                          width: 2,
                                          color: AppColors.border,
                                        ),
                                      Container(
                                        margin: const EdgeInsets.only(top: 12),
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          gradient: AppColors.cardGradient,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: iconColor, width: 2),
                                        ),
                                        child: Icon(iconData,
                                            color: iconColor, size: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                // Content
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        top: 12, bottom: 20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                            text: TextSpan(children: [
                                          TextSpan(
                                              text:
                                                  '${_formatCategory(a.category)}  ',
                                              style: TextStyle(
                                                  color: iconColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11)),
                                          TextSpan(
                                              text: a.details,
                                              style: AppUI.bodyText(size: 11)),
                                        ])),
                                        const SizedBox(height: 6),
                                        Text(
                                          a.status,
                                          style: TextStyle(
                                            color: isApproved
                                                ? const Color(0xFF22C55E)
                                                : AppColors.secondary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${a.date} - Submitted ${a.date}, 05:21 PM',
                                          style: AppUI.mutedText(size: 9),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
