import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../services/auth_service.dart';
import '../models/member.dart';
import '../models/activity_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';

class NewReferralScreen extends StatefulWidget {
  final List<Member> members;
  final ActivityModel? existingActivity;
  const NewReferralScreen({super.key, required this.members, this.existingActivity});

  @override
  State<NewReferralScreen> createState() => _NewReferralScreenState();
}

class _NewReferralScreenState extends State<NewReferralScreen> {
  bool _isInternal = true;
  bool _isSubmitting = false;

  // Logged-in user's chapter (resolved at init)
  String _myChapter = '';

  final _dateController = TextEditingController();
  
  // Internal fields
  String? _selectedMember;
  final _categoryController = TextEditingController();
  final _descInternalController = TextEditingController();

  // External fields
  String? _selectedExternalChapter;  // chapter chosen for external referral
  String? _selectedMemberExternal;   // member chosen within that chapter
  final _contactNameController = TextEditingController();
  final _companyController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _descExternalController = TextEditingController();

  @override
  void dispose() {
    _dateController.dispose();
    _categoryController.dispose();
    _descInternalController.dispose();
    _contactNameController.dispose();
    _companyController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _descExternalController.dispose();
    super.dispose();
  }

  // ── Chapter helpers ──────────────────────────────────────────────────────

  /// Members in the logged-in user's own chapter (for Internal tab).
  List<Member> get _sameChapterMembers {
    if (_myChapter.isEmpty) return widget.members;
    return widget.members
        .where((m) => m.chapter == _myChapter)
        .toList();
  }

  /// Unique chapters excluding the logged-in user's chapter (for External tab).
  List<String> get _otherChapters {
    return widget.members
        .map((m) => m.chapter)
        .toSet()
        .where((c) => c != _myChapter && c.isNotEmpty && c != 'Unknown')
        .toList()
      ..sort();
  }

  /// Members in the selected external chapter.
  List<Member> get _externalChapterMembers {
    if (_selectedExternalChapter == null) return [];
    return widget.members
        .where((m) => m.chapter == _selectedExternalChapter)
        .toList();
  }

  Future<void> _loadMyChapter() async {
    final prefs = await SharedPreferences.getInstance();
    var chapter = prefs.getString('chapter_name') ?? '';

    // Try to derive from member list
    if (chapter.isEmpty) {
      final myId = prefs.getString('user_id') ?? '';
      if (myId.isNotEmpty) {
        for (final m in widget.members) {
          if (m.id.toString() == myId) {
            chapter = m.chapter;
            await prefs.setString('chapter_name', chapter);
            break;
          }
        }
      }
    }

    // Fall back to profile API
    if (chapter.isEmpty) {
      try {
        final profile = await AuthService.getProfile();
        final fromProfile =
            (profile['chapter_name'] ?? profile['chapter'] ?? '').toString();
        if (fromProfile.isNotEmpty) {
          chapter = fromProfile;
          await prefs.setString('chapter_name', chapter);
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _myChapter = chapter);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMyChapter();
    if (widget.existingActivity != null) {
      final act = widget.existingActivity!;
      _dateController.text = act.date;
      _categoryController.text = (act.rawJson['business_category'] ?? act.rawJson['category'] ?? '').toString();
    } else {
      final now = DateTime.now();
      _dateController.text = "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: AppUI.datePickerTheme,
    );
    if (picked != null && mounted) {
      setState(() {
        _dateController.text = "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
      });
    }
  }

  bool _showValidationErrors = false;

  Future<void> _submitReferral() async {
    if (_isSubmitting) return;
    final memberId = _isInternal
        ? (_selectedMember ?? '')
        : (_selectedMemberExternal ?? '');

    final missing = <String>[];
    if (!_isInternal && (_selectedExternalChapter == null || _selectedExternalChapter!.isEmpty)) {
      missing.add('Select Chapter');
    }
    if (memberId.isEmpty) {
      missing.add('Receiving Member');
    }
    if (!_isInternal && _contactNameController.text.trim().isEmpty) {
      missing.add('Contact Name');
    }
    if (_categoryController.text.trim().isEmpty) {
      missing.add('Business Category');
    }
    if (_dateController.text.trim().isEmpty) {
      missing.add('Referral Date');
    }

    if (missing.isNotEmpty) {
      setState(() => _showValidationErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill: ${missing.join(', ')}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() => _showValidationErrors = false);

    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      final detailsText = _isInternal
          ? _descInternalController.text
          : _descExternalController.text;
      final categoryText = _categoryController.text.trim();

      final body = {
        'user_id': userId ?? '',
        'action': widget.existingActivity != null ? 'update' : 'create',
        if (widget.existingActivity != null) 'id': widget.existingActivity!.id.toString(),
        'type': _isInternal ? 'Internal' : 'External',
        'referral_type': _isInternal ? 'internal' : 'external',
        'member_id': memberId,
        'received_by': memberId,
        'category': categoryText,
        'business_category': categoryText,
        'date': _dateController.text,
        'referral_date': _dateController.text,
        'details': detailsText,
        'description': detailsText,
        if (!_isInternal) 'chapter': _selectedExternalChapter ?? '',
        if (!_isInternal) 'visitor_name': _contactNameController.text,
        if (!_isInternal) 'external_name': _contactNameController.text,
        if (!_isInternal) 'company': _companyController.text,
        if (!_isInternal) 'external_company': _companyController.text,
        if (!_isInternal) 'company_name': _companyController.text,
        if (!_isInternal) 'phone': _mobileController.text,
        if (!_isInternal) 'external_mobile': _mobileController.text,
        if (!_isInternal) 'external_phone': _mobileController.text,
        if (!_isInternal) 'referral_phone': _mobileController.text,
        if (!_isInternal) 'email': _emailController.text,
      };

      await ActivityService.createReferral(body);
      
            if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF20C997)),
                SizedBox(width: 8),
                Text('Success', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text('Submitted successfully!', style: TextStyle(color: Color(0xFF374151))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK', style: TextStyle(color: AppColors.secondary)),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit referral. Please try again.'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 800,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10), spreadRadius: 5),
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: primaryColor, border: Border(bottom: BorderSide(color: primaryColor.withValues(alpha: 0.3)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Submit Referral', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
                        boxShadow: _panelShadow,
                      ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Referral', style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  Text('Referral Type', style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  
                  // Toggle
                  Row(
                    children: [
                      _buildTypeToggle(
                        title: 'Internal (RMB Member)', 
                        icon: Icons.people, 
                        isActive: _isInternal, 
                        onTap: () => setState(() => _isInternal = true)
                      ),
                      const SizedBox(width: 8),
                      _buildTypeToggle(
                        title: 'External Contact', 
                        icon: Icons.person_add, 
                        isActive: !_isInternal, 
                        onTap: () => setState(() => _isInternal = false)
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Form Fields
                  if (_isInternal) ...[
                    // Same-chapter members shown by default (like web)
                    if (_myChapter.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.group, size: 14, color: AppColors.primary.withValues(alpha: 0.6)),
                            const SizedBox(width: 6),
                            Text(
                              'Showing members from: $_myChapter',
                              style: TextStyle(color: AppColors.primary.withValues(alpha: 0.7), fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    _buildMemberDropdown(
                      'Receiving Member *',
                      _selectedMember,
                      _sameChapterMembers,
                      (val) => setState(() => _selectedMember = val),
                      errorText: (_showValidationErrors && (_selectedMember == null || _selectedMember!.isEmpty))
                          ? 'Please select member'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Business Category *',
                      _categoryController,
                      errorText: (_showValidationErrors && _categoryController.text.trim().isEmpty)
                          ? 'Please enter business category'
                          : null,
                    ),
                  ] else ...[
                    // External: pick chapter first, then member within that chapter
                    _buildChapterDropdown(
                      'Select Chapter *',
                      _selectedExternalChapter,
                      _otherChapters,
                      (val) => setState(() {
                        _selectedExternalChapter = val;
                        _selectedMemberExternal = null;
                      }),
                      errorText: (_showValidationErrors && (_selectedExternalChapter == null || _selectedExternalChapter!.isEmpty))
                          ? 'Please select a chapter'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    if (_selectedExternalChapter != null) ...[
                      _buildMemberDropdown(
                        'Receiving Member *',
                        _selectedMemberExternal,
                        _externalChapterMembers,
                        (val) => setState(() => _selectedMemberExternal = val),
                        errorText: (_showValidationErrors && (_selectedMemberExternal == null || _selectedMemberExternal!.isEmpty))
                            ? 'Please select member'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTextField(
                            'Contact Name *',
                            _contactNameController,
                            errorText: (_showValidationErrors && _contactNameController.text.trim().isEmpty)
                                ? 'Please enter contact name'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField('Company', _companyController)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Mobile', _mobileController)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField('Email', _emailController)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Business Category *',
                      _categoryController,
                      errorText: (_showValidationErrors && _categoryController.text.trim().isEmpty)
                          ? 'Please enter business category'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Referral Date *',
                    _dateController,
                    readOnly: true,
                    suffixIcon: Icons.calendar_today,
                    onTap: () => _selectDate(context),
                    errorText: (_showValidationErrors && _dateController.text.trim().isEmpty)
                        ? 'Please select referral date'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text('Description', style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        )
                      ],
                    ),
                    child: TextField(
                      controller: _isInternal ? _descInternalController : _descExternalController,
                      maxLines: 4,
                      style: TextStyle(color: primaryColor, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Details about this referral...',
                        hintStyle: TextStyle(color: primaryColor.withValues(alpha: 0.4), fontSize: 11),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _isSubmitting ? null : _submitReferral,
                        icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Icon(Icons.send, size: 16),
                        label: const Text('Submit Referral', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ],
),
      ),
    );
  }

  /// Elevation shared by the inputs and the Referral Type pills, so the blue
  /// bordered controls read as raised against the white sheet.
  static final List<BoxShadow> _fieldShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static final List<BoxShadow> _panelShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 16,
      offset: const Offset(0, 6),
      spreadRadius: 1,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  Widget _buildTypeToggle({required String title, required IconData icon, required bool isActive, required VoidCallback onTap}) {
    final primaryColor = AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive ? primaryColor : primaryColor.withValues(alpha: 0.3),
            width: isActive ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
          color: isActive ? primaryColor.withValues(alpha: 0.10) : Colors.white,
          boxShadow: _fieldShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? primaryColor : primaryColor.withValues(alpha: 0.6), size: 16),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(color: isActive ? primaryColor : primaryColor.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    final primaryColor = AppColors.primary;
    if (label.contains('*')) {
      final parts = label.split('*');
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: parts[0],
              style: TextStyle(
                color: primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const TextSpan(
              text: '*',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (parts.length > 1 && parts[1].isNotEmpty)
              TextSpan(
                text: parts[1],
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      );
    }
    return Text(label, style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w500));
  }

  Widget _buildErrorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 12, color: Colors.redAccent),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    IconData? suffixIcon,
    VoidCallback? onTap,
    String? errorText,
  }) {
    final primaryColor = AppColors.primary;
    final hasError = errorText != null && errorText.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        const SizedBox(height: 8),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasError ? Colors.redAccent : primaryColor,
              width: 1.5,
            ),
            boxShadow: _fieldShadow,
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            onChanged: (val) {
              if (_showValidationErrors) setState(() {});
            },
            style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: primaryColor.withValues(alpha: 0.5), size: 16) : null,
            ),
          ),
        ),
        if (hasError) _buildErrorText(errorText),
      ],
    );
  }

  Widget _buildMemberDropdown(
    String label,
    String? value,
    List<Member> items,
    Function(String?) onChanged, {
    String? errorText,
  }) {
    final primaryColor = AppColors.primary;
    final hasError = errorText != null && errorText.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        const SizedBox(height: 8),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasError ? Colors.redAccent : primaryColor,
              width: 1.5,
            ),
            boxShadow: _fieldShadow,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: const Text('-- Select member --', style: TextStyle(color: Colors.black38, fontSize: 11)),
              dropdownColor: Colors.white,
              icon: Icon(Icons.arrow_drop_down, color: primaryColor),
              items: items.map((e) => DropdownMenuItem(value: e.id.toString(), child: Text('${e.name.trim()} - ${e.company}', style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (val) {
                onChanged(val);
                if (_showValidationErrors) setState(() {});
              },
            ),
          ),
        ),
        if (hasError) _buildErrorText(errorText),
      ],
    );
  }

  Widget _buildChapterDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged, {
    String? errorText,
  }) {
    final primaryColor = AppColors.primary;
    final hasError = errorText != null && errorText.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        const SizedBox(height: 8),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasError ? Colors.redAccent : primaryColor,
              width: 1.5,
            ),
            boxShadow: _fieldShadow,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: const Text('-- Select Chapter --', style: TextStyle(color: Colors.black38, fontSize: 11)),
              dropdownColor: Colors.white,
              icon: Icon(Icons.arrow_drop_down, color: primaryColor),
              items: items
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (val) {
                onChanged(val);
                if (_showValidationErrors) setState(() {});
              },
            ),
          ),
        ),
        if (hasError) _buildErrorText(errorText),
      ],
    );
  }
}


