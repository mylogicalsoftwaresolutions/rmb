import 'package:flutter/material.dart';
import '../services/event_meeting_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';
import '../widgets/app_error_view.dart';

class EventsMeetingsScreen extends StatefulWidget {
  const EventsMeetingsScreen({super.key});

  @override
  State<EventsMeetingsScreen> createState() => _EventsMeetingsScreenState();
}

class _EventsMeetingsScreenState extends State<EventsMeetingsScreen> {
  late Future<List<Map<String, dynamic>>> _eventsMeetingsFuture;
  String _filterType = 'All'; // All, Events, Meetings

  @override
  void initState() {
    super.initState();
    AppColors.isDarkMode.addListener(_onThemeChanged);
    _loadData();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppColors.isDarkMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _eventsMeetingsFuture = EventMeetingService.getAllEventsAndMeetings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode.value;
    final goldColor = AppColors.secondary;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Events & Meetings',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Filter buttons
            Row(
              children: [
                _buildFilterButton('All', _filterType == 'All'),
                const SizedBox(width: 8),
                _buildFilterButton('Events', _filterType == 'Events'),
                const SizedBox(width: 8),
                _buildFilterButton('Meetings', _filterType == 'Meetings'),
              ],
            ),
            const SizedBox(height: 20),

            // List
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _eventsMeetingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: goldColor),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return AppErrorView(
                    message: 'Unable to load meetings and events.',
                    onRetry: _loadData,
                  );
                }

                final allData = snapshot.data ?? [];
                final filtered = _getFilteredList(allData);

                if (filtered.isEmpty) {
                  return AppEmptyState('No $_filterType found');
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _buildEventMeetingCard(filtered[index], goldColor),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, bool isSelected) {
    final isDark = AppColors.isDarkMode.value;
    final goldColor = AppColors.secondary;
    final unselectedBg = isDark ? const Color(0xFF1F3870) : Colors.grey.shade200;
    final unselectedText = isDark ? Colors.white70 : Colors.black87;

    return GestureDetector(
      onTap: () => setState(() => _filterType = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? goldColor : unselectedBg,
          borderRadius: BorderRadius.circular(6),
          border: isSelected ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : unselectedText,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEventMeetingCard(Map<String, dynamic> item, Color goldColor) {
    final isDark = AppColors.isDarkMode.value;
    final isEvent = item.containsKey('event_date');
    final title = item['title'] ?? item['name'] ?? 'Untitled';
    final date = item['date'] ?? item['event_date'] ?? item['meeting_date'] ?? 'N/A';
    final time = item['time'] ?? item['start_time'] ?? '';
    final description = item['description'] ?? item['details'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: AppUI.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isEvent ? Icons.event : Icons.meeting_room,
                color: isDark ? goldColor : AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.onCard,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF102A5C) : goldColor,
                  borderRadius: BorderRadius.circular(4),
                  border: isDark ? Border.all(color: goldColor, width: 1) : null,
                ),
                child: Text(
                  isEvent ? 'Event' : 'Meeting',
                  style: TextStyle(
                    color: isDark ? goldColor : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, color: AppColors.onCardMuted, size: 14),
              const SizedBox(width: 6),
              Text(
                date,
                style: TextStyle(color: AppColors.onCard, fontSize: 12),
              ),
              if (time.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(Icons.schedule, color: AppColors.onCardMuted, size: 14),
                const SizedBox(width: 6),
                Text(
                  time,
                  style: TextStyle(color: AppColors.onCard, fontSize: 12),
                ),
              ],
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: AppColors.onCardMuted, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredList(List<Map<String, dynamic>> data) {
    if (_filterType == 'Events') {
      return data.where((item) => item.containsKey('event_date')).toList();
    } else if (_filterType == 'Meetings') {
      return data.where((item) => !item.containsKey('event_date')).toList();
    }
    return data;
  }
}
