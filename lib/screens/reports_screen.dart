import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_error_view.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<Map<String, dynamic>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = ReportService.getReports();
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = AppColors.secondary;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: goldColor));
          }

          if (snapshot.hasError) {
            return AppErrorView(
              message: 'Unable to load reports.',
              onRetry: () => setState(() {
                _reportsFuture = ReportService.getReports();
              }),
            );
          }

          final reports = snapshot.data ?? {};
          final performance = reports['performance'] ?? {};
          final leaderboard = reports['leaderboard'] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reports & Performance', style: TextStyle(color: goldColor, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // Performance Summary
                Text('Monthly Performance', style: TextStyle(color: goldColor, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildPerformanceSummary(performance, goldColor),
                const SizedBox(height: 24),

                // Leaderboard
                Text('Chapter Leaderboard', style: TextStyle(color: goldColor, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildLeaderboard(leaderboard, goldColor),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPerformanceSummary(Map<String, dynamic> performance, Color goldColor) {
    if (performance.isEmpty) {
      return Center(child: Text('No performance data available', style: TextStyle(color: Colors.grey.shade600)));
    }

    final referralsGiven = performance['referrals_given'] ?? 0;
    final referralsReceived = performance['referrals_received'] ?? 0;
    final businessGiven = performance['business_given_amount'] ?? 0;
    final businessReceived = performance['business_received_amount'] ?? 0;
    final testimonialsGiven = performance['testimonials_given'] ?? 0;
    final r2rCount = performance['r2r_count'] ?? 0;
    final presentCount = performance['present_count'] ?? 0;
    final visitorCount = performance['visitor_count'] ?? 0;

    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildStatCard('Referrals Given', referralsGiven.toString(), Icons.share, goldColor),
            _buildStatCard('Referrals Received', referralsReceived.toString(), Icons.call_received, goldColor),
            _buildStatCard(
              'Business Given',
              '₹$businessGiven',
              Icons.arrow_upward,
              const Color(0xFF20C997),
              subtitle: '${performance['business_given_count'] ?? 0} C-Notes',
            ),
            _buildStatCard('Business Received', '₹$businessReceived', Icons.arrow_downward, const Color(0xFF388DEC)),
            _buildStatCard('Testimonials', testimonialsGiven.toString(), Icons.rate_review, goldColor),
            _buildStatCard('R2R Meetings', r2rCount.toString(), Icons.handshake, goldColor),
            _buildStatCard('Attendance', presentCount.toString(), Icons.event_available, const Color(0xFF20C997)),
            _buildStatCard('Visitors', visitorCount.toString(), Icons.person_add, const Color(0xFF388DEC)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.primaryLight.withAlpha(89), blurRadius: 8)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Text(
            value,
            style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(List leaderboard, Color goldColor) {
    if (leaderboard.isEmpty) {
      return Center(child: Text('No leaderboard data available', style: TextStyle(color: Colors.grey.shade600)));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: leaderboard.length,
      itemBuilder: (context, index) => _buildLeaderboardRow(leaderboard[index], index + 1, goldColor),
    );
  }

  Widget _buildLeaderboardRow(Map<String, dynamic> member, int rank, Color goldColor) {
    final name = member['display_name'] ?? 'Unknown';
    final company = member['company_name'] ?? '';
    final score = member['score'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: AppColors.primaryLight.withAlpha(89), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: goldColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                rank.toString(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  company,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: goldColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              score.toString(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
