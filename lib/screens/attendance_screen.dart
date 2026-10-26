import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  Widget build(BuildContext context) {
    final goldColor = AppColors.secondary;
    final darkCardColor = AppColors.card;

    return Scaffold(
      backgroundColor: AppUI.pageBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row - the year dropdown here only ever offered
            // 2026/2025 with nothing behind it filtering by year, so it was
            // removed rather than kept as a decorative control.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Your meeting attendance record',
                    style: AppUI.mutedText(size: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stat Cards Grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              childAspectRatio: 1.6,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard(
                  title: "This Month\nPresent",
                  value: "1",
                  subtitle: "of 1 meetings",
                  valueColor: AppColors.secondary,
                  icon: Icons.how_to_reg,
                  iconColor: Colors.greenAccent,
                  iconBgColor: const Color(0xFF1A4A45),
                ),
                _buildStatCard(
                  title: "This Month\nAbsent",
                  value: "0",
                  subtitle: "",
                  valueColor: AppColors.secondary,
                  icon: Icons.person_off,
                  iconColor: Colors.redAccent,
                  iconBgColor: const Color(0xFF4A1A25),
                ),
                _buildStatCard(
                  title: "This Month Late",
                  value: "0",
                  subtitle: "",
                  valueColor: AppColors.secondary,
                  icon: Icons.access_time_filled,
                  iconColor: AppColors.secondary,
                  iconBgColor: const Color(0xFF4A3E1A),
                ),
                _buildStatCard(
                  title: "Lifetime\nAttendance",
                  value: "100%",
                  subtitle: "1/1 meetings",
                  valueColor: AppUI.body,
                  icon: Icons.pie_chart,
                  iconColor: AppColors.secondary,
                  iconBgColor: const Color(0xFF4A3E1A),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress Bar Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: AppUI.cardDecoration,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Lifetime Attendance Rate", style: AppUI.bodyText(size: 13)),
                      Text("100%", style: AppUI.bodyText(size: 13, weight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: 1.0,
                    backgroundColor: darkCardColor,
                    color: goldColor,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // History Table Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppUI.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Attendance History",
                    style: TextStyle(color: goldColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Show & Search
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text("Show ", style: TextStyle(color: AppUI.muted, fontSize: 11)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: darkCardColor,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text("25", style: AppUI.bodyText(size: 11)),
                          ),
                        ],
                      ),
                      Container(
                        width: 120,
                        height: 28,
                        decoration: BoxDecoration(
                          color: darkCardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          style: AppUI.bodyText(size: 11),
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

                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: AppUI.cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_today, color: goldColor, size: 14),
                                const SizedBox(width: 8),
                                Text("21 Aug 2026", style: AppUI.titleText(size: 13)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A8038),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text("Present", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: AppUI.divider, height: 1),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.groups, color: AppColors.textMuted, size: 14),
                            const SizedBox(width: 8),
                            SizedBox(width: 80, child: Text('Meeting', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                            Text(":", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            const SizedBox(width: 8),
                            Expanded(child: Text("Weekly Networking Meeting", style: AppUI.bodyText(size: 13))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on, color: AppColors.textMuted, size: 14),
                            const SizedBox(width: 8),
                            SizedBox(width: 80, child: Text('Venue', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                            Text(":", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            const SizedBox(width: 8),
                            Expanded(child: Text("—", style: AppUI.bodyText(size: 13))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.access_time, color: AppColors.textMuted, size: 14),
                            const SizedBox(width: 8),
                            SizedBox(width: 80, child: Text('Check-in', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                            Text(":", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            const SizedBox(width: 8),
                            Expanded(child: Text("04:03 PM", style: AppUI.bodyText(size: 13))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Center(child: Text("Showing 1-1 of 1", style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.border, borderRadius: const BorderRadius.horizontal(left: Radius.circular(4))),
                        child: Icon(Icons.chevron_left, color: AppUI.body, size: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        color: const Color(0xFF0D6EFD),
                        child: const Text("1", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.border, borderRadius: const BorderRadius.horizontal(right: Radius.circular(4))),
                        child: Icon(Icons.chevron_right, color: AppUI.body, size: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color valueColor,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppUI.cardDecoration,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: AppUI.mutedText(size: 10)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 18)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: AppUI.muted, fontSize: 10)),
              ],
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
