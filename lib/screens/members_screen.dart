import 'package:flutter/material.dart';
import '../services/member_service.dart';
import '../models/user_model.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/member.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';

class MembersScreen extends StatefulWidget {
  final List<Member> members;
  final bool isAdmin;

  const MembersScreen({super.key, required this.members, this.isAdmin = true});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  String _selectedMember = 'All Members';
  String _selectedCompany = 'All Companies';
  String _selectedCategory = 'All Categories';
  String _selectedChapter = 'All Chapters';

  bool _isLoading = true;
  String? _errorMessage;
  List<UserModel> _allMembers = [];
  List<UserModel> _apiMembers = [];
  List<String> _memberOptions = ['All Members'];
  List<String> _companyOptions = ['All Companies'];
  List<String> _categoryOptions = ['All Categories'];
  List<String> _chapterOptions = ['All Chapters'];
  bool _loadingRest = false;
  bool _isLoadingRest = false;

  /// The dropdowns used to hold hardcoded sample values that never matched
  /// real data, so any selection filtered everything out.
  void _rebuildFilterOptions() {
    String cap(String v) => v.trim();
    final cats = _allMembers
        .map((m) => cap(m.businessCategory))
        .where((v) => v.isNotEmpty && v.toLowerCase() != 'unknown')
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _categoryOptions = ['All Categories', ...cats];
    if (!_categoryOptions.contains(_selectedCategory)) {
      _selectedCategory = 'All Categories';
    }

    final chapters = _allMembers
        .map((m) => cap(m.chapterName))
        .where((v) => v.isNotEmpty && v.toLowerCase() != 'unknown')
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _chapterOptions = ['All Chapters', ...chapters];
    if (!_chapterOptions.contains(_selectedChapter)) {
      _selectedChapter = 'All Chapters';
    }

    _updateMemberAndCompanyOptions();
  }

  void _updateMemberAndCompanyOptions({bool fromMemberChange = false, bool fromCompanyChange = false}) {
    String cap(String v) => v.trim();

    final scopedMembers = _allMembers.where((m) {
      final matchesCategory = _selectedCategory == 'All Categories' ||
          cap(m.businessCategory).toLowerCase() == _selectedCategory.toLowerCase();
      final matchesChapter = _selectedChapter == 'All Chapters' ||
          cap(m.chapterName).toLowerCase() == _selectedChapter.toLowerCase();
      return matchesCategory && matchesChapter;
    }).toList();

    if (fromMemberChange) {
      if (_selectedMember != 'All Members') {
        UserModel? found;
        try {
          found = _allMembers.firstWhere(
            (m) => cap(m.name).toLowerCase() == _selectedMember.toLowerCase(),
          );
        } catch (_) {
          found = null;
        }
        final comp = found != null ? cap(found.companyName) : '';
        if (comp.isNotEmpty && comp.toLowerCase() != 'unknown') {
          _selectedCompany = comp;
          _companyOptions = ['All Companies', comp];
        } else {
          _selectedCompany = 'All Companies';
          final comps = scopedMembers
              .map((m) => cap(m.companyName))
              .where((c) => c.isNotEmpty && c.toLowerCase() != 'unknown')
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          _companyOptions = ['All Companies', ...comps];
        }
      } else {
        _selectedCompany = 'All Companies';
        final comps = scopedMembers
            .map((m) => cap(m.companyName))
            .where((c) => c.isNotEmpty && c.toLowerCase() != 'unknown')
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _companyOptions = ['All Companies', ...comps];
      }
    } else if (fromCompanyChange) {
      if (_selectedCompany != 'All Companies') {
        final membersInComp = scopedMembers
            .where((m) => cap(m.companyName).toLowerCase() == _selectedCompany.toLowerCase())
            .map((m) => cap(m.name))
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _memberOptions = ['All Members', ...membersInComp];
        if (!_memberOptions.contains(_selectedMember)) {
          _selectedMember = 'All Members';
        }
      } else {
        _selectedMember = 'All Members';
        final names = scopedMembers
            .map((m) => cap(m.name))
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _memberOptions = ['All Members', ...names];
      }
    } else {
      if (_selectedMember != 'All Members') {
        UserModel? found;
        try {
          found = _allMembers.firstWhere(
            (m) => cap(m.name).toLowerCase() == _selectedMember.toLowerCase(),
          );
        } catch (_) {
          found = null;
        }
        final comp = found != null ? cap(found.companyName) : '';
        _companyOptions = ['All Companies', if (comp.isNotEmpty && comp.toLowerCase() != 'unknown') comp];
      } else if (_selectedCompany != 'All Companies') {
        final membersInComp = scopedMembers
            .where((m) => cap(m.companyName).toLowerCase() == _selectedCompany.toLowerCase())
            .map((m) => cap(m.name))
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _memberOptions = ['All Members', ...membersInComp];
      } else {
        final names = scopedMembers
            .map((m) => cap(m.name))
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _memberOptions = ['All Members', ...names];

        final comps = scopedMembers
            .map((m) => cap(m.companyName))
            .where((c) => c.isNotEmpty && c.toLowerCase() != 'unknown')
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _companyOptions = ['All Companies', ...comps];
      }

      if (!_memberOptions.contains(_selectedMember)) {
        _selectedMember = 'All Members';
      }
      if (!_companyOptions.contains(_selectedCompany)) {
        _selectedCompany = 'All Companies';
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _nameController.clear();
      _companyController.clear();
      _mobileController.clear();
      _selectedMember = 'All Members';
      _selectedCompany = 'All Companies';
      _selectedCategory = 'All Categories';
      _selectedChapter = 'All Chapters';
      _rebuildFilterOptions();
      _applySearchInternal();
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await MemberService.getMembers();
      if (mounted) {
        setState(() {
          _allMembers = data['members'];
          _rebuildFilterOptions();
          // Directory shows every member the API returns, not just the
          // signed-in member's own chapter - each card displays its own
          // chapter name so the source is still clear.
          _apiMembers = List.from(_allMembers);
          _isLoading = false;
        });
      }
      // members.php caps its list at 50 rows, so the first page stops
      // mid-alphabet. Show those straight away, then pull the rest in the
      // background (one request per id - the only route past the cap) and
      // fold them in when they arrive.
      _loadRemainingMembers();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  /// Fills in the members the 50-row cap leaves out, without holding up
  /// the first paint.
  Future<void> _loadRemainingMembers() async {
    if (_loadingRest) return;
    _loadingRest = true;
    if (mounted) setState(() => _isLoadingRest = true);
    try {
      final all = await MemberService.getAllMembers();
      if (!mounted) return;
      setState(() {
        _allMembers = all;
        _rebuildFilterOptions();
        _applySearchInternal();
        _isLoadingRest = false;
      });
    } catch (_) {
      // The capped first page is already on screen; leave it rather than
      // replacing a partial directory with an error.
      if (mounted) setState(() => _isLoadingRest = false);
    } finally {
      _loadingRest = false;
    }
  }

  void _applySearch() {
    setState(_applySearchInternal);
  }

  void _applySearchInternal() {
    final mobileQuery = _mobileController.text.trim().toLowerCase();

    _apiMembers = _allMembers.where((member) {
      final nameTrim = member.name.trim();
      final companyTrim = member.companyName.trim();

      final matchesMember = _selectedMember == 'All Members' ||
          nameTrim.toLowerCase() == _selectedMember.toLowerCase();
      final matchesCompany = _selectedCompany == 'All Companies' ||
          companyTrim.toLowerCase() == _selectedCompany.toLowerCase();
      final matchesMobile = mobileQuery.isEmpty || member.mobile.contains(mobileQuery);

      final matchesCategory = _selectedCategory == 'All Categories' ||
          member.businessCategory.toLowerCase().trim() ==
              _selectedCategory.toLowerCase().trim();
      final matchesChapter = _selectedChapter == 'All Chapters' ||
          member.chapterName.toLowerCase().trim() ==
              _selectedChapter.toLowerCase().trim();

      return matchesMember && matchesCompany && matchesMobile && matchesCategory && matchesChapter;
    }).toList();
  }

  Future<void> _showMemberDetail(UserModel memberSummary) async {
    final goldColor = AppColors.secondary;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: goldColor)),
    );

    final detailFuture =
        MemberService.getMemberDetail(memberSummary.id).catchError((e) {
      debugPrint('Error fetching details: $e');
      return <String, dynamic>{};
    });
    final giveAskFuture =
        MemberService.getMemberGiveAsk(memberSummary.id).catchError((e) {
      debugPrint('Error fetching give & ask: $e');
      return null;
    });

    Map<String, dynamic>? detailData;
    Map<String, String>? giveAskData;
    try {
      detailData = await detailFuture;
      giveAskData = await giveAskFuture;
    } catch (e) {
      debugPrint('Error fetching details: $e');
    }

    if (mounted) Navigator.pop(context); // Close loading spinner

    // The list request already carried most of these fields, so fall back to
    // the summary instead of dead-ending when the detail call fails.
    if (detailData == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not reach the server — showing the details we already have.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    final Map<String, dynamic> d = detailData ?? <String, dynamic>{};

    String pick(String key, String fallback) {
      final v = d[key];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      return fallback.trim().isEmpty ? '-' : fallback;
    }

    final String name = pick('name', memberSummary.name);
    final String code = pick('member_code', memberSummary.memberCode);
    final String role = pick('role', memberSummary.role);
    final String company = pick('company_name', memberSummary.companyName);
    final String chapter = pick('chapter_name', memberSummary.chapterName);
    final String category = pick('business_category', memberSummary.businessCategory);
    final String mobile = pick('mobile', memberSummary.mobile);
    final String city = pick('city', memberSummary.city);
    final String email = pick('email', memberSummary.email);

    final String rawDob = pick('dob', '');
    final String dob = (rawDob != '-' && rawDob.isNotEmpty && rawDob != '0000-00-00')
        ? rawDob
        : (pick('birth_date', '').isNotEmpty && pick('birth_date', '') != '-' && pick('birth_date', '') != '0000-00-00'
            ? pick('birth_date', '')
            : (pick('birthday', '').isNotEmpty && pick('birthday', '') != '-' && pick('birthday', '') != '0000-00-00'
                ? pick('birthday', '')
                : ''));

    final String rawAnn = pick('anniversary', '');
    final String anniversary = (rawAnn != '-' && rawAnn.isNotEmpty && rawAnn != '0000-00-00')
        ? rawAnn
        : (pick('anniversary_date', '').isNotEmpty && pick('anniversary_date', '') != '-' && pick('anniversary_date', '') != '0000-00-00'
            ? pick('anniversary_date', '')
            : (pick('wedding_anniversary', '').isNotEmpty && pick('wedding_anniversary', '') != '-' && pick('wedding_anniversary', '') != '0000-00-00'
                ? pick('wedding_anniversary', '')
                : ''));

    String give = pick('give', '');
    if (give == '-' || give.isEmpty) give = pick('gives', '');
    if (give == '-' || give.isEmpty) give = pick('what_i_give', '');
    if (give == '-' || give.isEmpty) give = memberSummary.give;
    if ((give == '-' || give.isEmpty) && giveAskData != null) {
      give = giveAskData['give'] ?? '';
    }

    String ask = pick('ask', '');
    if (ask == '-' || ask.isEmpty) ask = pick('asks', '');
    if (ask == '-' || ask.isEmpty) ask = pick('what_i_ask', '');
    if (ask == '-' || ask.isEmpty) ask = memberSummary.ask;
    if ((ask == '-' || ask.isEmpty) && giveAskData != null) {
      ask = giveAskData['ask'] ?? '';
    }
    
    // Strip spaces/dashes so tel: and wa.me get a clean number.
    final digits = mobile.replaceAll(RegExp(r'[^0-9]'), '');
    final hasMobile = digits.length >= 10;

    final lifetimeStats = d['lifetime_stats'] ?? {};
    final double given = (lifetimeStats['business_given'] ?? 0).toDouble();
    final double received = (lifetimeStats['business_received'] ?? 0).toDouble();
    final int refs = lifetimeStats['referrals_given'] ?? 0;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.primary, width: 1.5),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
              maxWidth: 450,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Member Details',
                        style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.onCard, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.cardGradient,
                            border: Border.all(color: goldColor, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: goldColor.withValues(alpha: 0.15),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(Icons.person, color: goldColor, size: 38),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onCardLabel,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: goldColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$code • $role',
                            style: TextStyle(color: goldColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Lifetime Stats Display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(gradient: AppColors.cardGradient, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text("Given", style: TextStyle(color: AppColors.onCardMuted, fontSize: 11)),
                            Text("₹${(given/1000).toStringAsFixed(1)}k", style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        Column(
                          children: [
                            Text("Received", style: TextStyle(color: AppColors.onCardMuted, fontSize: 11)),
                            Text("₹${(received/1000).toStringAsFixed(1)}k", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        Column(
                          children: [
                            Text("Referrals", style: TextStyle(color: AppColors.onCardMuted, fontSize: 11)),
                            Text("$refs", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 12),

                  _buildDetailTile(Icons.business, 'Company & Chapter', '$company ($chapter)'),
                  _buildDetailTile(Icons.label_outline, 'Business Category', category),
                  if (hasMobile)
                    _buildDetailTile(Icons.phone_outlined, 'Mobile', '+91 $digits'),
                  if (city.trim().isNotEmpty && city != '-')
                    _buildDetailTile(Icons.location_city_outlined, 'City', city),
                  if (email.trim().isNotEmpty && email != '-')
                    _buildDetailTile(Icons.email_outlined, 'Email', email),
                  if (dob.trim().isNotEmpty && dob != '-')
                    _buildDetailTile(Icons.cake_outlined, 'Birthday', dob),
                  if (anniversary.trim().isNotEmpty && anniversary != '-')
                    _buildDetailTile(Icons.favorite_outline, 'Anniversary', anniversary),

                  const SizedBox(height: 14),
                  Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 14),

                  // Give & Ask Section Header
                  Row(
                    children: [
                      Icon(Icons.handshake_outlined, color: AppColors.cardHeading, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Give & Ask',
                        style: TextStyle(
                          color: AppColors.cardHeading,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Gives Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.leaderboardBorder, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.volunteer_activism, color: Color(0xFF20C997), size: 15),
                            SizedBox(width: 6),
                            Text(
                              'Gives (What I Give)',
                              style: TextStyle(
                                color: Color(0xFF20C997),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          give.trim().isNotEmpty ? give.trim() : 'Not specified',
                          style: TextStyle(
                            color: give.trim().isNotEmpty ? AppColors.onCard : AppColors.onCardMuted,
                            fontSize: 13,
                            fontStyle: give.trim().isNotEmpty ? FontStyle.normal : FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Asks Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.leaderboardBorder, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.campaign, color: AppColors.secondary, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              'Asks (What I Ask)',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ask.trim().isNotEmpty ? ask.trim() : 'Not specified',
                          style: TextStyle(
                            color: ask.trim().isNotEmpty ? AppColors.onCard : AppColors.onCardMuted,
                            fontSize: 13,
                            fontStyle: ask.trim().isNotEmpty ? FontStyle.normal : FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: goldColor,
                            foregroundColor: AppColors.card,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: hasMobile
                              ? () => launchUrl(Uri.parse('tel:$digits'),
                                  mode: LaunchMode.externalApplication)
                              : null,
                          icon: const Icon(Icons.phone, size: 16),
                          label: const Text('Call', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: hasMobile
                              ? () => launchUrl(
                                  Uri.parse(
                                      'https://wa.me/${digits.length > 10 ? digits : '91$digits'}'),
                                  mode: LaunchMode.externalApplication)
                              : null,
                          icon: const Icon(Icons.message, size: 16),
                          label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.onCardLabel, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(value, style: TextStyle(color: AppColors.onCardLabel, fontSize: 15, fontWeight: FontWeight.w600)),
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
    final formBgColor = AppColors.card;
    final inputBgColor = AppColors.card;

    return Container(
      color: AppColors.card,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: formBgColor,
              borderRadius: BorderRadius.circular(AppUI.cardRadius),
              border: Border.all(color: AppColors.primary, width: 1.5),
              boxShadow: AppUI.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find and connect with members across all chapters',
                  style: AppUI.headingText(size: 15),
                ),
                const SizedBox(height: 16),
                
                // Member Name Dropdown
                _buildSearchLabel('Member Name'),
                _buildDropdown(
                  value: _selectedMember,
                  items: _memberOptions,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _selectedMember = v;
                      _updateMemberAndCompanyOptions(fromMemberChange: true);
                      _applySearchInternal();
                    });
                  },
                  bgColor: inputBgColor,
                ),

                // Company Name Dropdown
                _buildSearchLabel('Company Name'),
                _buildDropdown(
                  value: _selectedCompany,
                  items: _companyOptions,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _selectedCompany = v;
                      _updateMemberAndCompanyOptions(fromCompanyChange: true);
                      _applySearchInternal();
                    });
                  },
                  bgColor: inputBgColor,
                ),

                // Mobile Search Input
                _buildSearchInput('Mobile', 'Search by mobile number', _mobileController, inputBgColor, isPhone: true),
                
                // Category Dropdown
                _buildSearchLabel('Category'),
                _buildDropdown(
                  value: _selectedCategory,
                  items: _categoryOptions,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _selectedCategory = v;
                      _updateMemberAndCompanyOptions();
                      _applySearchInternal();
                    });
                  },
                  bgColor: inputBgColor,
                ),
                
                // Chapter Dropdown
                _buildSearchLabel('Chapter'),
                _buildDropdown(
                  value: _selectedChapter,
                  items: _chapterOptions,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _selectedChapter = v;
                      _updateMemberAndCompanyOptions();
                      _applySearchInternal();
                    });
                  },
                  bgColor: inputBgColor,
                ),
                
                const SizedBox(height: 16),
                
                // Action Buttons: Search & Reset
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.navAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _applySearch,
                          icon: const Icon(Icons.search, size: 20),
                          label: const Text('Search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: goldColor,
                            side: BorderSide(color: goldColor, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _resetFilters,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Reset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Found Results Text
          if (!_isLoading && _errorMessage == null)
            Text(
              _isLoadingRest
                  ? '${_apiMembers.length} members found — loading more…'
                  : '${_apiMembers.length} members found',
              style: AppUI.bodyText(size: 14, weight: FontWeight.w600),
            ),
          
          const SizedBox(height: 16),
          
          // Member Grid View
          if (_isLoading)
            Center(child: Padding(padding: const EdgeInsets.all(40), child: CircularProgressIndicator(color: goldColor)))
          else if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppUI.cardRadius),
                border: Border.all(color: AppColors.danger, width: 1.5),
                boxShadow: AppUI.cardShadow,
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_off, color: AppColors.danger, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: AppUI.bodyText(size: 14),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.navAccent,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    ),
                    onPressed: _fetchMembers,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            )
          else if (_apiMembers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text('No members match your search criteria.', style: AppUI.mutedText(size: 13)),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _apiMembers.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (context, index) {
                final m = _apiMembers[index];
                return _buildMemberCard(m, formBgColor, goldColor);
              },
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildSearchLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 12),
      child: Text(label, style: TextStyle(color: AppColors.onCardLabel, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildSearchInput(String label, String hint, TextEditingController controller, Color bgColor, {bool isPhone = false}) {
    final isDark = AppColors.isDarkMode.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchLabel(label),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF102A54) : bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.inputBorder : AppColors.primary, width: 1.5),
          ),
          child: TextField(
            controller: controller,
            keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
            style: TextStyle(color: isDark ? Colors.white : AppColors.onCard, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: isDark ? const Color(0xFF7A92B4) : AppColors.textMuted, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required Color bgColor,
  }) {
    final isDark = AppColors.isDarkMode.value;
    final uniqueItems = items.toSet().toList();
    final safeValue = uniqueItems.contains(value) ? value : (uniqueItems.isNotEmpty ? uniqueItems.first : null);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF102A54) : bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.inputBorder : AppColors.primary, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          dropdownColor: isDark ? const Color(0xFF102A54) : Colors.white,
          isExpanded: true,
          style: TextStyle(color: isDark ? Colors.white : AppColors.onCard, fontSize: 14),
          icon: Icon(Icons.arrow_drop_down, color: isDark ? AppColors.secondary : AppColors.primary),
          items: uniqueItems.map((i) => DropdownMenuItem(
            value: i, 
            child: Text(
              i, 
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildMemberCard(UserModel member, Color bgColor, Color goldColor) {
    final String name = member.name;
    final String category =
        member.businessCategory.isEmpty ? '-' : member.businessCategory;
    final String chapter = member.chapterName.isEmpty ? '-' : member.chapterName;

    return InkWell(
      onTap: () => _showMemberDetail(member),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryLight, AppColors.primaryMid],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: goldColor.withValues(alpha: 0.25)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [goldColor, const Color(0xFFE5A50A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              category,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFC0D3EB), fontSize: 11),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppColors.cardGradient,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: goldColor, width: 1),
              ),
              child: Text(
                chapter,
                style: TextStyle(
                  color: goldColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
