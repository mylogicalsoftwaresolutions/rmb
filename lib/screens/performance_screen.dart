import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';
import '../services/report_service.dart';
import '../services/dashboard_service.dart';
import '../widgets/loading_overlay.dart';
import '../services/api_client.dart';

class PerformanceScreen extends StatefulWidget {
  final double businessGiven;
  final double businessReceived;
  final int referralsGiven;
  final int referralsReceived;
  final int r2rCount;
  final double attendanceRate;

  const PerformanceScreen({
    super.key,
    this.businessGiven = 12000.0,
    this.businessReceived = 4500.0,
    this.referralsGiven = 3,
    this.referralsReceived = 2,
    this.r2rCount = 4,
    this.attendanceRate = 98.0,
  });

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  // The web member dashboard presents lifetime contribution totals, so make
  // that the first mobile view too. Members can still select a smaller period.
  String _selectedMonthRange = "Lifetime";

  double _currentBusinessGiven = 0;
  double _currentBusinessReceived = 0;
  int _currentReferralsGiven = 0;
  int _currentReferralsReceived = 0;
  int _currentR2RCount = 0;
  double _currentAttendanceRate = 0;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _perf = {};
  List<Map<String, dynamic>> _leaderboard = [];
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _updateDataForRange(_selectedMonthRange);
  }

  /// Pulls the figures for [range] from reports.php. The API supports every
  /// period the selector offers, so nothing here is derived or estimated.
  Future<void> _updateDataForRange(String range) async {
    setState(() {
      _selectedMonthRange = range;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reports = await ReportService.getReports(
        period: ReportService.periodParams[range] ?? 'monthly',
      );
      final perf = Map<String, dynamic>.from(reports['performance'] ?? {});
      // dashboard.php powers the web member dashboard.  Use it as a fallback
      // when reports.php returns an empty performance object on mobile.
      if (perf.isEmpty) {
        final dashboard = await DashboardService.getDashboardData();
        final dashboardPerf = dashboard['performance'];
        if (dashboardPerf is Map) {
          perf.addAll(Map<String, dynamic>.from(dashboardPerf));
        }
      }
      perf['business_given_amount'] ??= perf['business_given'] ?? 0;
      perf['business_received_amount'] ??= perf['business_received'] ?? 0;
      final board = reports['leaderboard'];
      final userId = await ApiClient.getUserId();
      final prefs = await SharedPreferences.getInstance();
      final myChapter = prefs.getString('chapter_name') ?? '';
      if (!mounted) return;

      final present = _toInt(perf['present_count']);
      final absent = _toInt(perf['absent_count']);
      final total = present + absent;

      setState(() {
        _perf = perf;
        _userId = userId;
        final all = board is List
            ? List<Map<String, dynamic>>.from(
                board.map((e) => Map<String, dynamic>.from(e as Map)))
            : <Map<String, dynamic>>[];
        // Show only members of the signed-in member's own chapter.
        _leaderboard = myChapter.isEmpty
            ? all
            : all
                .where((m) =>
                    (m['chapter_name'] ?? '').toString().trim().toLowerCase() ==
                    myChapter.trim().toLowerCase())
                .toList();
        // The API sends these in no particular order (nothing to sort by
        // while every score ties at 0, so it comes back differently on
        // every call) - a leaderboard has to rank highest-first regardless,
        // so this is the one place responsible for that ordering.
        _leaderboard.sort((a, b) => _toInt(b['score']).compareTo(_toInt(a['score'])));
        _currentBusinessGiven = _toDouble(perf['business_given_amount']);
        _currentBusinessReceived = _toDouble(perf['business_received_amount']);
        _currentReferralsGiven = _toInt(perf['referrals_given']);
        _currentReferralsReceived = _toInt(perf['referrals_received']);
        _currentR2RCount = _toInt(perf['r2r_count']);
        _currentAttendanceRate = total > 0 ? (present / total) * 100 : 0;
        _isLoading = false;
      });
      // Re-rank from the dedicated endpoint so the board matches the
      // selected metric and period rather than reports.php's fixed
      // referrals-given ordering.
      await _fetchLeaderboard();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// e.g. "This Quarter - 01 Jul 2026 - 30 Sep 2026", using the start/end
  /// the API returns for the selected period.
  String get _periodLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    String fmt(dynamic raw) {
      final d = DateTime.tryParse(raw?.toString() ?? '');
      if (d == null) return '';
      return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
    }

    final start = fmt(_perf['start']);
    final end = fmt(_perf['end']);
    if (start.isEmpty || end.isEmpty) return _selectedMonthRange;
    return '$_selectedMonthRange - $start - $end';
  }

  static double _toDouble(dynamic v) =>
      double.tryParse(v?.toString() ?? '0') ?? 0.0;

  static int _toInt(dynamic v) =>
      int.tryParse(v?.toString() ?? '0') ?? _toDouble(v).round();

  String _selectedLeaderboardCategory = "Referrals Given";
  bool _leaderboardLoading = false;

  /// Re-ranks the chapter leaderboard from the API whenever the metric or
  /// period changes.
  ///
  /// leaderboard.php ranks server-side by the metric and chapter selected for
  /// the signed-in member.
  Future<void> _fetchLeaderboard() async {
    final metric = ReportService.leaderboardMetrics[_selectedLeaderboardCategory] ??
        'referrals_given';
    final period =
        ReportService.leaderboardPeriods[_selectedMonthRange] ?? 'monthly';
    setState(() => _leaderboardLoading = true);
    try {
      List<Map<String, dynamic>> rows;
      try {
        rows = await ReportService.getChapterLeaderboard(
          period: period,
          metric: metric,
        );
      } catch (_) {
        // Keep a chapter member list visible if the ranking service is down.
        rows = const [];
      }
      // Keep the chapter table populated from directory.php if ranking data
      // is temporarily unavailable.
      final fallbackRows = rows.isEmpty
          ? await ReportService.getChapterMembers(
              chapterName:
                  (await SharedPreferences.getInstance()).getString('chapter_name'),
            )
          : rows;
      if (!mounted) return;
      setState(() {
        if (fallbackRows.isNotEmpty) {
          _leaderboard = fallbackRows
            ..sort((a, b) => _toDouble(b['score']).compareTo(_toDouble(a['score'])));
        }
        _leaderboardLoading = false;
      });
    } catch (_) {
      // Keep whatever is already ranked rather than blanking the table.
      if (mounted) setState(() => _leaderboardLoading = false);
    }
  }

  String _leaderboardQuery = '';

  /// The rows actually rendered: filtered by the search box, then capped by
  /// the "Show N entries" dropdown. Both controls used to be decorative -
  /// the search field had no onChanged and the entry count was never applied,
  /// so the table always showed every row regardless of either.
  List<Map<String, dynamic>> get _visibleLeaderboard {
    final q = _leaderboardQuery.trim().toLowerCase();
    var rows = _leaderboard;
    if (q.isNotEmpty) {
      rows = rows.where((m) {
        final name = (m['display_name'] ??
                '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}')
            .toString()
            .toLowerCase();
        final company = (m['company_name'] ?? '').toString().toLowerCase();
        return name.contains(q) || company.contains(q);
      }).toList();
    }
    if (rows.length > _showEntriesCount) {
      rows = rows.sublist(0, _showEntriesCount);
    }
    return rows;
  }

  /// Icon for the metric picked in the category dropdown - shown instead of
  /// a text abbreviation ("BIZ"/"R2R"/"ATT"), which read as unexplained
  /// jargon in the column header.
  IconData get _metricIcon {
    switch (_selectedLeaderboardCategory) {
      case 'Business Given':
      case 'Business Received':
        return Icons.currency_rupee;
      case 'R2R Meetings':
        return Icons.handshake_outlined;
      default:
        return Icons.share_outlined;
    }
  }

  /// The detail dialog used to always say "referrals given" no matter which
  /// category was selected, so picking Business Given/R2R/Attendance still
  /// showed the wrong label. This gives each category its own wording.
  String _metricPhrase(int score) {
    switch (_selectedLeaderboardCategory) {
      case 'Business Given':
        return '$score business given';
      case 'Business Received':
        return '$score business received';
      case 'R2R Meetings':
        return '$score R2R meetings';
      case 'Referrals Received':
        return '$score referrals received';
      default:
        return '$score referrals given';
    }
  }
  int _showEntriesCount = 25;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Custom formatted values
  String _formatCurrency(double amount) {
    if (amount == 0) return "₹0.00";
    return "₹${amount.toStringAsFixed(2)}";
  }

  @override
  Widget build(BuildContext context) {
    // This page reads AppColors directly rather than Theme.of(context).  It
    // therefore must listen to the app's theme notifier itself; otherwise an
    // IndexedStack keeps the old blue cards painted after White Theme is
    // selected from the dashboard.
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, _, __) {
        if (_isLoading) return const SkeletonLoader();
        return _buildPerformancePage(context);
      },
    );
  }

  Widget _buildPerformancePage(BuildContext context) {

    final goldColor = AppColors.secondary;

    return Scaffold(
      backgroundColor: AppColors.card,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month selector header matching Image 1
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: AppColors.card,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _periodLabel,
                        style: TextStyle(
                          color: AppColors.onCardMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.isDarkMode.value ? AppColors.modalInput : AppColors.card,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borderBright),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedMonthRange,
                        dropdownColor: AppColors.isDarkMode.value ? AppColors.modalInput : AppColors.card,
                        icon: Icon(Icons.keyboard_arrow_down, color: AppColors.onCardMuted, size: 18),
                        style: TextStyle(color: AppColors.onCard, fontSize: 12, fontWeight: FontWeight.bold),
                        items: ["This Week", "This Month", "This Quarter", "This Year", "This Term", "Lifetime"].map((String val) {
                          return DropdownMenuItem<String>(
                            value: val,
                            child: Text(val),
                          );
                        }).toList(),
                        onChanged: (String? newVal) {
                          if (newVal != null) {
                            _updateDataForRange(newVal);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.onCardDivider, height: 1, thickness: 1),

            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppColors.danger.withValues(alpha: 0.12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMessage!,
                          style: TextStyle(color: AppColors.danger, fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: () => _updateDataForRange(_selectedMonthRange),
                      child: const Text('Retry', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 8-Card Stat Grid matching Image 1
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.35,
                    children: [
                      _buildGridCard(
                        title: "Referrals Given",
                        value: _currentReferralsGiven.toString(),
                        subtitle: "$_currentReferralsReceived received",
                        icon: Icons.share,
                        badgeColor: AppColors.secondary.withAlpha(38),
                        badgeIconColor: goldColor,
                      ),
                      _buildGridCard(
                        title: "Business Given",
                        value: _formatCurrency(_currentBusinessGiven),
                        subtitle: "${_toInt(_perf['business_given_count'])} C-Notes",
                        icon: Icons.arrow_upward,
                        badgeColor: const Color(0xFF20C997).withAlpha(38),
                        badgeIconColor: const Color(0xFF20C997),
                      ),
                      _buildGridCard(
                        title: "Business Received",
                        value: _formatCurrency(_currentBusinessReceived),
                        subtitle: "${_toInt(_perf['business_received_count'])} C-Notes",
                        icon: Icons.arrow_downward,
                        badgeColor: const Color(0xFF388DEC).withAlpha(38),
                        badgeIconColor: const Color(0xFF388DEC),
                      ),
                      _buildGridCard(
                        title: "R2R Meetings",
                        value: _currentR2RCount.toString(),
                        subtitle: "Completed",
                        icon: Icons.handshake_outlined,
                        badgeColor: AppColors.secondary.withAlpha(38),
                        badgeIconColor: goldColor,
                      ),
                      _buildGridCard(
                        title: "Testimonials",
                        value: "${_toInt(_perf['testimonials_given'])}",
                        subtitle: "${_toInt(_perf['testimonials_received'])} received",
                        icon: Icons.format_quote_outlined,
                        badgeColor: const Color(0xFF20C997).withAlpha(38),
                        badgeIconColor: const Color(0xFF20C997),
                      ),
                      _buildGridCard(
                        title: "Attendance",
                        value: "${_toInt(_perf['present_count'])}",
                        subtitle: "${_toInt(_perf['absent_count'])} absent",
                        icon: Icons.person_outline,
                        badgeColor: AppColors.secondary.withAlpha(38),
                        badgeIconColor: goldColor,
                      ),
                      _buildGridCard(
                        title: "Visitors Invited",
                        value: "${_toInt(_perf['visitor_count'])}",
                        subtitle: _toInt(_perf['visitor_count']) == 0 ? "No guests" : "Invited",
                        icon: Icons.person_add_outlined,
                        badgeColor: const Color(0xFF388DEC).withAlpha(38),
                        badgeIconColor: const Color(0xFF388DEC),
                      ),
                      _buildGridCard(
                        title: "Total Business",
                        value: _formatCurrency(_currentBusinessGiven + _currentBusinessReceived),
                        subtitle: "Combined Value",
                        icon: Icons.currency_rupee,
                        badgeColor: const Color(0xFF388DEC).withAlpha(38),
                        badgeIconColor: const Color(0xFF388DEC),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Trend Section matching Image 2
                  Text(
                    "Trend — Referrals & Business",
                    style: TextStyle(
                      color: goldColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 160,
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: goldColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 20, offset: const Offset(0, 8)),
                        BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1)),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _TrendChartPainter(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("High: 5", style: TextStyle(color: AppColors.onCardMuted, fontSize: 10)),
                              Text("Stats Flow", style: TextStyle(color: goldColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Week 1", style: TextStyle(color: AppColors.onCardMuted, fontSize: 9)),
                              Text("Week 2", style: TextStyle(color: AppColors.onCardMuted, fontSize: 9)),
                              Text("Week 3", style: TextStyle(color: AppColors.onCardMuted, fontSize: 9)),
                              Text("Week 4", style: TextStyle(color: AppColors.onCardMuted, fontSize: 9)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // vs Chapter Average Section matching Image 2
                  Text(
                    "vs Chapter Average",
                    style: TextStyle(
                      color: goldColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppColors.cardGradient,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: goldColor,
                        width: 1.5,
                      ),
                      boxShadow: AppUI.webShadow,
                    ),
                    child: Column(
                      children: [
                        _buildComparisonRow(
                          label: "Referrals Given",
                          userVal: _currentReferralsGiven.toDouble(),
                          avgVal: 2.0,
                          valString: "$_currentReferralsGiven vs avg 2",
                          progressColor: goldColor,
                        ),
                        const SizedBox(height: 16),
                        _buildComparisonRow(
                          label: "Business Given",
                          userVal: _currentBusinessGiven,
                          avgVal: 8000.0,
                          valString: "₹${_currentBusinessGiven.toInt()} vs avg ₹8000",
                          progressColor: const Color(0xFF20C997),
                        ),
                        const SizedBox(height: 16),
                        _buildComparisonRow(
                          label: "R2R Meetings",
                          userVal: _currentR2RCount.toDouble(),
                          avgVal: 2.5,
                          valString: "$_currentR2RCount vs avg 2.5",
                          progressColor: const Color(0xFF388DEC),
                        ),
                        const SizedBox(height: 16),
                        _buildComparisonRow(
                          label: "Attendance",
                          userVal: _currentAttendanceRate,
                          avgVal: 80.0,
                          valString:
                              "${_currentAttendanceRate.toStringAsFixed(0)}% vs avg 80%",
                          progressColor: goldColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Chapter Leaderboard Section matching Image 3
                  Text(
                    "Chapter Leaderboard",
                    style: TextStyle(
                      color: goldColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.cardGradient,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: goldColor,
                        width: 1.5,
                      ),
                      boxShadow: AppUI.webShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Leaderboard Filters Header
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Dropdown Category Selector
                              Container(
                                width: double.infinity,
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.isDarkMode.value ? AppColors.modalInput : AppColors.card,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.borderBright),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedLeaderboardCategory,
                                    dropdownColor: AppColors.isDarkMode.value ? AppColors.modalInput : AppColors.card,
                                    icon: Icon(Icons.keyboard_arrow_down, color: goldColor),
                                    isExpanded: true,
                                    style: TextStyle(color: AppColors.onCard, fontSize: 13, fontWeight: FontWeight.bold),
                                    // Only metrics chapter_leaderboard.php
                                    // actually ranks by - it ignores
                                    // anything else and silently returns
                                    // referrals_given, which made the old
                                    // "Attendance" option show referral
                                    // numbers under an attendance label.
                                    items: ReportService.leaderboardMetrics.keys
                                        .map((String val) {
                                      return DropdownMenuItem<String>(
                                        value: val,
                                        child: Text(val),
                                      );
                                    }).toList(),
                                    onChanged: (String? val) {
                                      if (val != null && val != _selectedLeaderboardCategory) {
                                        setState(() {
                                          _selectedLeaderboardCategory = val;
                                        });
                                        _fetchLeaderboard();
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  // Show entries dropdown
                                  Text("Show ", style: TextStyle(color: AppColors.onCardMuted, fontSize: 12)),
                                  Container(
                                    height: 32,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.isDarkMode.value ? AppColors.modalInput : AppColors.card,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.borderBright),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: _showEntriesCount,
                                        dropdownColor: AppColors.isDarkMode.value ? AppColors.modalInput : AppColors.card,
                                        icon: Icon(Icons.keyboard_arrow_down, color: AppColors.onCardMuted, size: 14),
                                        style: TextStyle(color: AppColors.onCard, fontSize: 11, fontWeight: FontWeight.bold),
                                        items: [10, 25, 50].map((int val) {
                                          return DropdownMenuItem<int>(
                                            value: val,
                                            child: Text(val.toString()),
                                          );
                                        }).toList(),
                                        onChanged: (int? val) {
                                          if (val != null) {
                                            setState(() {
                                              _showEntriesCount = val;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  Text(" entries", style: TextStyle(color: AppColors.onCardMuted, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Search input
                              Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.isDarkMode.value ? AppColors.modalInput : AppColors.card,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.searchBorder),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (v) =>
                                      setState(() => _leaderboardQuery = v),
                                  style: TextStyle(color: AppColors.onCard, fontSize: 13),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: "Search records...",
                                    hintStyle: TextStyle(color: AppColors.onCardMuted, fontSize: 12),
                                    border: InputBorder.none,
                                    prefixIcon: Icon(Icons.search, color: AppColors.onCardMuted, size: 18),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Leaderboard Table
                        Divider(color: AppColors.onCardDivider, height: 1),
                        Container(
                          color: AppColors.isDarkMode.value
                              ? const Color(0xFF19406D).withAlpha(120)
                              : AppColors.card,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          child: Row(
                            children: [
                              SizedBox(width: 32, child: Text("#", style: TextStyle(color: goldColor, fontSize: 11, fontWeight: FontWeight.bold))),
                              Expanded(flex: 3, child: _leaderHeader(Icons.person_outline, "MEMBER")),
                              Expanded(flex: 3, child: _leaderHeader(Icons.business_outlined, "COMPANY")),
                              SizedBox(width: 32, child: Icon(_metricIcon, color: AppColors.secondary, size: 16)),
                            ],
                          ),
                        ),
                        Divider(color: AppColors.onCardDivider, height: 1),

                        if (_leaderboardLoading)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: goldColor),
                              ),
                            ),
                          )
                        else if (_visibleLeaderboard.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(_leaderboardQuery.trim().isEmpty
                                      ? 'No leaderboard data yet.'
                                      : 'No members match "$_leaderboardQuery".',
                                  style: TextStyle(
                                      color: AppColors.onCardMuted,
                                      fontSize: 12)),
                            ),
                          )
                        else
                          ...List.generate(_visibleLeaderboard.length, (i) {
                            final m = _visibleLeaderboard[i];
                            final name = (m['display_name'] ??
                                    '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}')
                                .toString()
                                .trim();
                            return _buildLeaderboardRow(
                              rank: i + 1,
                              name: name.isEmpty ? 'Unknown' : name,
                              company: (m['company_name'] ?? '').toString(),
                              score: _toInt(m['score']),
                              avatarInitials: _initials(name),
                              isCurrentUser: m['id']?.toString() == _userId,
                              trophyColor: _rankColor(i + 1, goldColor),
                            );
                          }),
                        const SizedBox(height: 8),

                        // Pagination Footer matching Image 3
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Showing ${_visibleLeaderboard.isEmpty ? 0 : 1}-${_visibleLeaderboard.length} of ${_leaderboard.length}",
                                style: TextStyle(color: AppColors.onCardMuted, fontSize: 11),
                              ),
                              Row(
                                children: [
                                  _buildPaginationButton("Prev", isEnabled: false),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: goldColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "1",
                                      style: TextStyle(
                                        color: const Color(0xFF102A5C),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  _buildPaginationButton("Next", isEnabled: false),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard({
    required String title,
    required String value,
    required String? subtitle,
    required IconData icon,
    required Color badgeColor,
    required Color badgeIconColor,
  }) {
    final goldColor = AppColors.secondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: goldColor,
          width: 1.5,
        ),
        boxShadow: AppUI.webShadow,
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.onCardMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: goldColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.onCardMuted,
                    fontSize: 10,
                  ),
                )
              else
                const SizedBox(height: 10),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 4,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: badgeIconColor,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow({
    required String label,
    required double userVal,
    required double avgVal,
    required String valString,
    required Color progressColor,
  }) {
    double ratio = 0.5;
    if (userVal + avgVal > 0) {
      ratio = userVal / (userVal + avgVal);
      ratio = ratio.clamp(0.1, 0.9); // keep visible
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(color: AppColors.onCard, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Text(
              valString,
              style: TextStyle(color: progressColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 10,
            width: double.infinity,
            color: AppColors.isDarkMode.value
                ? const Color(0xFF102A54)
                : const Color(0xFFE5E7EB),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: progressColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final parts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  static Color _rankColor(int rank, Color goldColor) {
    if (rank == 1) return goldColor;
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return const Color(0xFF9CA3AF);
  }

  Widget _leaderHeader(IconData icon, String label, {bool alignEnd = false}) {
    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.secondary, size: 13),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.onCardMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  /// Tapping a leaderboard row surfaces the company and the given count,
  /// which are truncated in the table itself.
  void _showLeaderDetail(String name, String company, int score) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        title: Text(name, style: TextStyle(color: AppColors.onCardLabel, fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.business_outlined, color: AppColors.secondary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(company.isEmpty ? '-' : company,
                    style: TextStyle(color: AppColors.onCard, fontSize: 15)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Icon(_metricIcon, color: AppColors.secondary, size: 18),
              const SizedBox(width: 8),
              Text(_metricPhrase(score),
                  style: TextStyle(color: AppColors.onCard, fontSize: 15)),
            ]),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardRow({
    required int rank,
    required String name,
    required String company,
    required int score,
    required String avatarInitials,
    required bool isCurrentUser,
    required Color trophyColor,
  }) {
    final goldColor = AppColors.secondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? (AppColors.isDarkMode.value
                ? AppColors.secondary.withValues(alpha: 0.15)
                : const Color(0xFF19406D).withAlpha(30))
            : (AppColors.isDarkMode.value
                ? const Color(0xFF102A54).withValues(alpha: 0.5)
                : AppColors.card),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrentUser ? AppColors.secondary : AppColors.onCardDivider,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showLeaderDetail(name, company, score),
        child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          // Rank Badge / Icon
          SizedBox(
            width: 32,
            child: Row(
              children: [
                Icon(Icons.emoji_events, color: trophyColor, size: 16),
                const SizedBox(width: 2),
                Text(
                  rank.toString(),
                  style: TextStyle(color: AppColors.onCardMuted, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Member Name with initials avatar
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: isCurrentUser ? goldColor : const Color(0xFF225591),
                  child: Text(
                    avatarInitials,
                    style: TextStyle(
                      color: isCurrentUser ? const Color(0xFF102A5C) : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.onCard,
                            fontSize: 12,
                            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: goldColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "You",
                            style: TextStyle(color: const Color(0xFF102A5C), fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Company Name
          Expanded(
            flex: 3,
            child: Text(
              company.isEmpty ? '-' : company,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.onCardMuted, fontSize: 12),
            ),
          ),
          // Referrals given
          SizedBox(
            width: 46,
            child: Text(
              '$score',
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: AppColors.onCardLabel,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildPaginationButton(String label, {required bool isEnabled}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isEnabled
            ? (AppColors.isDarkMode.value ? AppColors.modalInput : AppColors.card)
            : (AppColors.isDarkMode.value ? AppColors.modalInput.withAlpha(128) : AppColors.card.withAlpha(128)),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.primary.withAlpha(isEnabled ? 120 : 60)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isEnabled ? AppColors.onCard : AppColors.onCardMuted,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Custom Painter for a nice modern line chart
class _TrendChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintArea = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.secondary.withAlpha(76),
          AppColors.secondary.withAlpha(0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.cubicTo(
      size.width * 0.25, size.height * 0.8,
      size.width * 0.45, size.height * 0.2,
      size.width * 0.7, size.height * 0.3,
    );
    path.quadraticBezierTo(
      size.width * 0.85, size.height * 0.35,
      size.width, size.height * 0.15,
    );

    // Draw area under path
    final areaPath = Path.from(path);
    areaPath.lineTo(size.width, size.height * 0.85);
    areaPath.lineTo(0, size.height * 0.85);
    areaPath.close();

    // Draw horizontal grid lines
    final paintGrid = Paint()
      ..color = AppColors.onCardDivider
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (double i = 0.2; i < 0.9; i += 0.25) {
      canvas.drawLine(Offset(0, size.height * i), Offset(size.width, size.height * i), paintGrid);
    }

    canvas.drawPath(areaPath, paintArea);
    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
