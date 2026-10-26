import 'package:flutter/material.dart';
import '../services/meetings_service.dart';
import '../models/meeting_model.dart';
import 'meeting_details_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';

class ChapterMeetingsScreen extends StatefulWidget {
  final bool isEventView;
  const ChapterMeetingsScreen({super.key, this.isEventView = false});

  @override
  State<ChapterMeetingsScreen> createState() => _ChapterMeetingsScreenState();
}

class _ChapterMeetingsScreenState extends State<ChapterMeetingsScreen> {
  bool _isUpcoming = true;
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;
  List<MeetingModel> _apiList = [];

  DateTime? _eventDate(String rawDate) {
    final raw = rawDate.trim();
    if (raw.isEmpty) return null;
    final iso = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (iso != null) return iso;

    // events.php commonly returns display dates such as 02-10-2026, which
    // DateTime.tryParse does not accept. Parse those before filtering tabs.
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

  void _selectPeriod(bool upcoming) {
    if (_isUpcoming == upcoming) return;
    setState(() => _isUpcoming = upcoming);
  }

  /// Split by date so Upcoming and Past actually differ.
  List<MeetingModel> get _visibleList {
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    bool isPast(MeetingModel m) {
      final d = _eventDate(m.date);
      if (d == null) return false; // undated entries stay under Upcoming
      return d.isBefore(midnight);
    }

    final byDate = _apiList.where((m) => _isUpcoming ? !isPast(m) : isPast(m));
    if (_searchQuery.trim().isEmpty) return byDate.toList();
    final q = _searchQuery.trim().toLowerCase();
    return byDate
        .where((m) => m.title.toLowerCase().contains(q) || m.location.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    AppColors.isDarkMode.addListener(_onThemeChanged);
    _fetchData();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppColors.isDarkMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (_apiList.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final data = widget.isEventView ? await MeetingsService.getEvents() : await MeetingsService.getMeetings();
      if (mounted) {
        setState(() {
          _apiList = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_apiList.isEmpty) {
            _errorMessage = e.toString().replaceAll('Exception: ', '');
          }
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode.value;
    final goldColor = AppColors.secondary;
    final sectionBgColor = isDark ? const Color(0xFF143066) : AppColors.card;
    final inputBgColor = isDark ? const Color(0xFF102A5C) : AppColors.card;
    final sectionBorderColor = isDark ? AppColors.accentBorder.withValues(alpha: 0.3) : AppColors.border;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isEventView 
                ? 'Discover and register for upcoming events.'
                : 'RMB BRIGHT meeting schedule',
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            
            // Toggles
            Row(
              children: [
                GestureDetector(
                  onTap: () => _selectPeriod(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isUpcoming
                          ? goldColor
                          : (isDark ? const Color(0xFF1F3870) : Colors.transparent),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _isUpcoming
                            ? goldColor
                            : (isDark ? AppColors.accentBorder.withValues(alpha: 0.5) : AppColors.border),
                      ),
                    ),
                    child: Text(
                      "Upcoming", 
                      style: TextStyle(
                        color: _isUpcoming
                            ? Colors.white
                            : (isDark ? Colors.white70 : AppUI.body), 
                        fontSize: 12, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _selectPeriod(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: !_isUpcoming
                          ? goldColor
                          : (isDark ? const Color(0xFF1F3870) : Colors.transparent),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: !_isUpcoming
                            ? goldColor
                            : (isDark ? AppColors.accentBorder.withValues(alpha: 0.5) : AppColors.border),
                      ),
                    ),
                    child: Text(
                      "Past", 
                      style: TextStyle(
                        color: !_isUpcoming
                            ? Colors.white
                            : (isDark ? Colors.white70 : AppUI.body), 
                        fontSize: 12, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (widget.isEventView) ...[
              // Events Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: sectionBgColor, 
                  borderRadius: BorderRadius.circular(12), 
                  border: Border.all(color: sectionBorderColor),
                ),
                child: _isLoading 
                    ? Center(child: Padding(padding: const EdgeInsets.all(40), child: CircularProgressIndicator(color: goldColor)))
                    : _errorMessage != null
                        ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent))))
                        : _visibleList.isEmpty
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.calendar_month, color: goldColor, size: 48),
                                  const SizedBox(height: 16),
                                  Text(
                                    "No events found.", 
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : AppUI.heading,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  ..._visibleList.map((item) {
                                    final date = item.date;
                                    final title = item.title;
                                    final time = item.time;
                                    final venue = item.location;
                                    
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: AppUI.panel,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.event, color: isDark ? goldColor : AppColors.primary, size: 16),
                                                  const SizedBox(width: 8),
                                                  Text(date, style: TextStyle(color: AppColors.onCard, fontSize: 13, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                              GestureDetector(
                                                onTap: () {
                                                  Navigator.push(context, MaterialPageRoute(builder: (_) => MeetingDetailsScreen(meeting: item, onBackToList: () { Navigator.pop(context); })));
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? AppColors.accentBorder.withValues(alpha: 0.15) : Colors.transparent,
                                                    border: Border.all(color: isDark ? AppColors.accentBorder : AppColors.secondary),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text('View', style: TextStyle(color: isDark ? AppColors.accentBorder : AppColors.secondary, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            child: Divider(color: AppUI.divider, height: 1),
                                          ),
                                          Text(title, style: TextStyle(color: isDark ? Colors.white : AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.access_time, color: AppColors.onCardMuted, size: 14),
                                              const SizedBox(width: 6),
                                              Text(time, style: TextStyle(color: AppColors.onCardMuted, fontSize: 12)),
                                              const SizedBox(width: 16),
                                              Icon(Icons.location_on, color: AppColors.onCardMuted, size: 14),
                                              const SizedBox(width: 6),
                                              Expanded(child: Text(venue, style: TextStyle(color: AppColors.onCardMuted, fontSize: 12))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
              ),
            ] else ...[
              // Meetings Data Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sectionBgColor, 
                  borderRadius: BorderRadius.circular(12), 
                  border: Border.all(color: sectionBorderColor),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text("Show ", style: TextStyle(color: isDark ? Colors.white70 : AppUI.muted, fontSize: 11)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: inputBgColor, 
                                borderRadius: BorderRadius.circular(4), 
                                border: Border.all(color: sectionBorderColor),
                              ),
                              child: Text("${_visibleList.length}", style: TextStyle(color: isDark ? Colors.white : AppUI.body, fontSize: 11)),
                            ),
                          ],
                        ),
                        Container(
                          width: 120,
                          height: 28,
                          decoration: BoxDecoration(
                            color: inputBgColor, 
                            borderRadius: BorderRadius.circular(14), 
                            border: Border.all(color: sectionBorderColor),
                          ),
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            style: TextStyle(color: isDark ? Colors.white : AppUI.body, fontSize: 11),
                            decoration: InputDecoration(
                              hintText: 'Search records...',
                              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 10),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (_isLoading)
                      Padding(padding: const EdgeInsets.all(40), child: CircularProgressIndicator(color: goldColor))
                    else if (_errorMessage != null)
                      Padding(padding: const EdgeInsets.all(20), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)))
                    else if (_visibleList.isEmpty)
                      Padding(padding: const EdgeInsets.all(40), child: Text(_isUpcoming ? 'No upcoming meetings found.' : 'No past meetings found.', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textMuted)))
                    else
                      ..._visibleList.map((item) {
                        final date = item.date;
                        final title = item.title;
                        final time = item.time;
                        final venue = item.location;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: AppUI.panel,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.event, color: isDark ? goldColor : AppColors.primary, size: 16),
                                      const SizedBox(width: 8),
                                      Text(date, style: TextStyle(color: AppColors.onCard, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => MeetingDetailsScreen(meeting: item, onBackToList: () { Navigator.pop(context); })));
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppColors.accentBorder.withValues(alpha: 0.15) : Colors.transparent,
                                        border: Border.all(color: isDark ? AppColors.accentBorder : AppColors.secondary),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text('View', style: TextStyle(color: isDark ? AppColors.accentBorder : AppColors.secondary, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Divider(color: AppUI.divider, height: 1),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(title, style: TextStyle(color: isDark ? Colors.white : AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold))),
                                  _buildBadge(
                                    item.status.isEmpty
                                        ? 'Scheduled'
                                        : item.status[0].toUpperCase() + item.status.substring(1).toLowerCase(),
                                    item.status.toLowerCase() == 'completed' || item.status.toLowerCase() == 'published'
                                        ? const Color(0xFF28A745)
                                        : item.status.toLowerCase() == 'cancelled'
                                            ? const Color(0xFFDC3545)
                                            : const Color(0xFF17A2B8),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.access_time, color: AppColors.onCardMuted, size: 14),
                                  const SizedBox(width: 6),
                                  Text(time, style: TextStyle(color: AppColors.onCardMuted, fontSize: 12)),
                                  const SizedBox(width: 16),
                                  Icon(Icons.location_on, color: AppColors.onCardMuted, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(venue, style: TextStyle(color: AppColors.onCardMuted, fontSize: 12))),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 16),
                    Text("Showing ${_visibleList.length} records", style: TextStyle(color: isDark ? Colors.white70 : AppColors.textMuted, fontSize: 11)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF102A5C) : AppColors.border,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
                            border: Border.all(color: isDark ? AppColors.accentBorder.withValues(alpha: 0.3) : AppColors.border),
                          ),
                          child: Icon(Icons.chevron_left, color: isDark ? Colors.white70 : AppUI.body, size: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          color: const Color(0xFF0D6EFD),
                          child: const Text("1", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF102A5C) : AppColors.border,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                            border: Border.all(color: isDark ? AppColors.accentBorder.withValues(alpha: 0.3) : AppColors.border),
                          ),
                          child: Icon(Icons.chevron_right, color: isDark ? Colors.white70 : AppUI.body, size: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      ),
    );
  }
}
