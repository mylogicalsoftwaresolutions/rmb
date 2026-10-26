import 'package:flutter/material.dart';
import '../models/meeting_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';

/// This used to show the same hardcoded meeting ("Weekly Networking
/// Meeting", "Friday, 21 Aug 2026 - 07:00") no matter which real meeting or
/// event was tapped in the list. It now takes the actual tapped record and
/// shows its real fields.
class MeetingDetailsScreen extends StatelessWidget {
  final MeetingModel meeting;
  final VoidCallback onBackToList;

  const MeetingDetailsScreen({
    super.key,
    required this.meeting,
    required this.onBackToList,
  });

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'completed':
      case 'published':
        return const Color(0xFF28A745);
      case 'cancelled':
        return const Color(0xFFDC3545);
      case 'scheduled':
      default:
        return const Color(0xFF17A2B8);
    }
  }

  String _titleCase(String s) =>
      s.isEmpty ? 'Scheduled' : s[0].toUpperCase() + s.substring(1).toLowerCase();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppColors.isDarkMode,
      builder: (context, isDark, _) {
        final statusLabel = _titleCase(meeting.status);
        final statusColor = _statusColor(meeting.status);
        final venue = meeting.location.trim().isEmpty ? '—' : meeting.location;
        final date = meeting.date.trim().isEmpty ? '—' : meeting.date;
        final time = meeting.time.trim().isEmpty ? '—' : meeting.time;
        final backColor = isDark ? AppColors.accentBorder : AppColors.primary;

        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppUI.appBar(
            meeting.title.isEmpty ? 'Meeting' : meeting.title,
            onBack: () => Navigator.pop(context),
          ),
          body: SingleChildScrollView(
            padding: AppUI.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$date${time == '—' ? '' : ' - $time'}',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onBackToList,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.accentBorder.withValues(alpha: 0.15) : Colors.transparent,
                          border: Border.all(color: backColor),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back,
                                color: backColor, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Back to List',
                              style: TextStyle(
                                color: backColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Status + venue
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBadge(statusLabel, statusColor),
                      const SizedBox(height: 24),
                      Text('VENUE', style: AppUI.sectionLabel(size: 10)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              color: AppColors.secondary, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(venue, style: AppUI.bodyText())),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Detail rows
                AppCard(
                  child: Column(
                    children: [
                      _buildDetailRow('Date', date),
                      Divider(color: AppUI.divider, height: 24),
                      _buildDetailRow('Time', time),
                      if (meeting.attendees > 0) ...[
                        Divider(color: AppUI.divider, height: 24),
                        _buildDetailRow('Attendees', '${meeting.attendees}'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppUI.mutedText(size: 12)),
        Text(value, style: AppUI.bodyText(size: 14, weight: FontWeight.bold)),
      ],
    );
  }
}
