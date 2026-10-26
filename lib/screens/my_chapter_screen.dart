import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';

class MyChapterScreen extends StatefulWidget {
  const MyChapterScreen({super.key});

  @override
  State<MyChapterScreen> createState() => _MyChapterScreenState();
}

class _MyChapterScreenState extends State<MyChapterScreen> {
  // null means show directory, otherwise show chapter details
  String? _selectedChapter;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _allChapters = [
    {"name": "RMB\nBRIGHT\nBRI-01", "location": "Salem", "team": "C: A\nVC: B\nS: C"},
    {"name": "RMB\nChampions\nRMB-001", "location": "Salem", "team": "-"},
    {"name": "RMB\nDIAMOND\nDIA-01", "location": "Salem", "team": "-"},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = AppColors.secondary;
    final cardBgColor = AppColors.card;
    
    return Scaffold(
      backgroundColor: AppUI.pageBg,
      body: _selectedChapter == null 
        ? _buildDirectoryView(goldColor, cardBgColor)
        : _buildDetailsView(goldColor, cardBgColor),
    );
  }

  Widget _buildDirectoryView(Color goldColor, Color cardBgColor) {
    final darkCardColor = AppColors.card;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, color: goldColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Chapter-Wise Performance\nDirectory",
                  style: TextStyle(color: goldColor, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppUI.cardDecoration,
            child: Column(
              children: [
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
                            border: Border.all(color: AppColors.border)
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
                        border: Border.all(color: AppColors.border)
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
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
                
                // Header
                // List of Chapters as Cards
                ..._allChapters
                    .where((c) => 
                        c['name']!.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                        c['location']!.toLowerCase().contains(_searchQuery.toLowerCase()))
                    .map((c) => _buildDirectoryRow(c['name']!, c['location']!, c['team']!)),
                const SizedBox(height: 16),
                
                // Pagination
                Text("Showing 1-${_allChapters.where((c) => c['name']!.toLowerCase().contains(_searchQuery.toLowerCase()) || c['location']!.toLowerCase().contains(_searchQuery.toLowerCase())).length} of ${_allChapters.where((c) => c['name']!.toLowerCase().contains(_searchQuery.toLowerCase()) || c['location']!.toLowerCase().contains(_searchQuery.toLowerCase())).length}", style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
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
          )
        ],
      ),
    );
  }

  Widget _buildDirectoryRow(String chapter, String location, String team) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedChapter = chapter.replaceAll("\n", " ");
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: AppUI.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: AppColors.secondary, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(chapter.replaceAll("\n", " "), style: AppUI.headingText(size: 13))),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: AppUI.divider, height: 1),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, color: AppColors.textMuted, size: 14),
                const SizedBox(width: 8),
                SizedBox(width: 60, child: Text('Location', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                Text(":", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(child: Text(location, style: TextStyle(color: AppUI.muted, fontSize: 12))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.group, color: AppColors.textMuted, size: 14),
                const SizedBox(width: 8),
                SizedBox(width: 60, child: Text('Team', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                Text(":", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(child: Text(team.replaceAll("\n", ", "), style: TextStyle(color: AppUI.muted, fontSize: 12))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsView(Color goldColor, Color cardBgColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.primary),
                onPressed: () => setState(() => _selectedChapter = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedChapter ?? "RMB BRIGHT (BRI-01)",
                  style: AppUI.headingText(size: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: AppUI.cardDecoration,
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.groups, color: goldColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Chapter Leadership Team",
                      style: TextStyle(color: goldColor, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                _buildLeadershipCard("A", "Chapter Chairman"),
                const SizedBox(height: 16),
                _buildLeadershipCard("B", "Vice Chairman"),
                const SizedBox(height: 16),
                _buildLeadershipCard("C", "Secretary"),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Stats Row 1
          Row(
            children: [
              Expanded(child: _buildStatCard("Business Closed", "₹2,000.00", Colors.teal)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard("Referrals Given", "1", goldColor)),
            ],
          ),
          const SizedBox(height: 12),
          // Stats Row 2
          Row(
            children: [
              Expanded(child: _buildStatCard("R2R Meetings", "2", Colors.blueAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard("Active Members", "2", Colors.lightBlue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeadershipCard(String name, String role) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: AppUI.cardDecoration,
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary,
            child: const Text("RMB", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const SizedBox(height: 12),
          Text(name, style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(role, style: TextStyle(color: AppUI.muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: AppUI.cardDecoration,
      child: Column(
        children: [
          Text(title, style: TextStyle(color: AppUI.muted, fontSize: 11), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
