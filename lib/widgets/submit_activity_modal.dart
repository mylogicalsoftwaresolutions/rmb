import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/member.dart';
import '../models/activity.dart';
import '../models/activity_model.dart';
import '../services/api_client.dart' show ApiClient, ApiException;
import '../services/activity_service.dart';
import '../services/auth_service.dart';
import '../services/member_service.dart';
import '../theme/app_colors.dart';

class SubmitActivityModal extends StatefulWidget {
  final List<Member> members;
  final String? initialCategory;
  final Map<String, dynamic>? initialGiveAsk;
  final Function(ActivityItem newItem) onSubmit;
  final ActivityModel? initialActivity;
  /// Fires once the record is actually saved, with the short category key
  /// ('referral', 'cnote', ...) so the caller can jump to that list screen
  /// instead of leaving the member back wherever the modal was opened from.
  final void Function(String category)? onSubmitted;

  /// Why the member list could not be loaded, if it could not. Every member
  /// dropdown on this form is fed from [members], so an empty list with no
  /// explanation looked like a broken form. When set, the dropdowns explain
  /// themselves and offer [onRetryMembers] instead of silently offering nothing.
  final String? membersError;
  final Future<void> Function()? onRetryMembers;

  const SubmitActivityModal({
    super.key,
    required this.members,
    this.initialCategory,
    this.initialGiveAsk,
    this.initialActivity,
    required this.onSubmit,
    this.onSubmitted,
    this.membersError,
    this.onRetryMembers,
  });

  @override
  State<SubmitActivityModal> createState() => _SubmitActivityModalState();
}

class _SubmitActivityModalState extends State<SubmitActivityModal> {
  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  /// The shared activity date is stored as DD-MM-YYYY.  New pop-up forms
  /// start at today, while edits open their existing date in the picker.
  DateTime _dateFromController() {
    final parts = _dateController.text.trim().split('-');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        final parsed = DateTime(year, month, day);
        if (parsed.year == year && parsed.month == month && parsed.day == day) {
          return parsed;
        }
      }
    }
    return DateTime.now();
  }

  Future<void> _selectActivityDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFromController(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && mounted) {
      setState(() => _dateController.text = _formatDate(picked));
    }
  }

  String? _selectedCategory;

  /// Members visible for a given form.
  ///
  /// Picking a specific chapter still narrows the list to that chapter. The
  /// same-chapter option no longer filters at all: members.php caps its
  /// response at 50 rows org-wide, so scoping to the signed-in member's own
  /// chapter left only a handful of people selectable and cut off members
  /// they legitimately needed to pick.
  String _myChapter = '';

  /// visitors.php has `chapter_id` as NOT NULL, so every visitor invite that
  /// omits it fails with a 1048 error the endpoint reports as HTTP 200. Kept
  /// alongside [_myChapter] so the visitor payload can send it.
  int? _myChapterId;

  List<Member> _localMembers = [];

  List<Member> get _activeMembers =>
      _localMembers.isNotEmpty ? _localMembers : widget.members;

  Future<void> _loadFallbackMembers() async {
    final cached = await MemberService.getCachedMembers();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _localMembers = cached.map((m) => m.toMember()).toList();
      });
      _loadMyChapter();
    }
  }

  List<String> _chapterOptions({bool excludeMyChapter = false}) {
    return _activeMembers
        .map((m) => m.chapter.trim())
        .where((c) =>
            c.isNotEmpty &&
            c.toLowerCase() != 'unknown' &&
            c.toLowerCase() != 'unknown chapter' &&
            c.toLowerCase() != 'null' &&
            (!excludeMyChapter || _myChapter.isEmpty || c.toLowerCase() != _myChapter.toLowerCase()))
        .toSet()
        .toList()
      ..sort();
  }

  List<Member> _visibleMembers(bool otherChapter, String? otherChapterName) {
    final valid = _activeMembers.where((m) {
      final ch = m.chapter.trim().toLowerCase();
      return ch.isNotEmpty && ch != 'unknown' && ch != 'unknown chapter' && ch != 'null';
    }).toList();

    if (otherChapter) {
      if (otherChapterName != null && otherChapterName.isNotEmpty) {
        return valid.where((m) => m.chapter.trim().toLowerCase() == otherChapterName.trim().toLowerCase()).toList();
      }
      return valid.where((m) => _myChapter.isEmpty || m.chapter.trim().toLowerCase() != _myChapter.trim().toLowerCase()).toList();
    }

    if (_myChapter.isNotEmpty) {
      final myChNorm = _myChapter.trim().toLowerCase().replaceAll('rmb', '').trim();
      final same = valid.where((m) {
        final chNorm = m.chapter.trim().toLowerCase().replaceAll('rmb', '').trim();
        return chNorm == myChNorm;
      }).toList();
      if (same.isNotEmpty) return same;
    }
    return valid;
  }

  /// True when [id] is a member that actually came back from the directory.
  ///
  /// referrals.php has a foreign key from `received_by` to `users.id` and
  /// answers a bad id with HTTP 200 plus a SQL error page, so the referral is
  /// written nowhere and nothing in the response says so. Validating here keeps
  /// that request off the wire entirely.
  bool _isRealMember(int? id) =>
      id != null && _activeMembers.any((m) => m.id == id);

  /// Shown in place of a member dropdown when the directory could not load.
  Widget _buildMembersUnavailable() {
    var message = widget.membersError ??
        'The member list is empty, so no one can be selected.';
    if (message.contains('<') ||
        message.contains('<!DOCTYPE') ||
        message.contains('html') ||
        message.contains('csrf-token')) {
      message = 'Could not load member list. Please tap Retry.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.modalInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 12),
                ),
              ),
            ],
          ),
          if (widget.onRetryMembers != null || _localMembers.isEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  if (widget.onRetryMembers != null) {
                    await widget.onRetryMembers!();
                  }
                  await _loadFallbackMembers();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// DropdownButton asserts unless its value matches exactly one item, so a
  /// selection that the filter has since removed must fall back to null.
  int? _safeMemberValue(List<Member> visible) {
    if (_selectedMemberId == null) return null;
    final hits = visible.where((m) => m.id == _selectedMemberId).length;
    return hits == 1 ? _selectedMemberId : null;
  }

  Future<void> _loadMyChapter() async {
    final prefs = await SharedPreferences.getInstance();
    var chapter = prefs.getString('chapter_name') ?? '';
    var chapterId = int.tryParse(prefs.getString('chapter_id') ?? '');

    // chapter_name/chapter_id are only written at login, so a session that
    // predates that would fall back to showing every member. Derive them
    // from the member list first by matching the signed-in user's own row.
    if (chapter.isEmpty || chapterId == null || chapterId == 0) {
      final myId = prefs.getString('user_id') ?? '';
      if (myId.isNotEmpty) {
        for (final m in _activeMembers) {
          if (m.id.toString() == myId) {
            chapter = m.chapter;
            chapterId = m.chapterId;
            await prefs.setString('chapter_name', chapter);
            await prefs.setString('chapter_id', chapterId.toString());
            break;
          }
        }
      }
    }

    // members.php's list is typically scoped to "other" members, not
    // including the caller - so the scan above finds nothing for plenty of
    // accounts. Once the member dropdowns were changed to fail closed
    // (never show cross-chapter members while the chapter is unresolved),
    // that turned into the dropdown staying permanently empty for anyone
    // this affects. Ask the server for the signed-in member's own profile
    // instead, which doesn't depend on being present in someone else's list.
    if (chapter.isEmpty || chapterId == null || chapterId == 0) {
      try {
        final profile = await AuthService.getProfile();
        final fromProfile =
            (profile['chapter_name'] ?? profile['chapter'] ?? '').toString();
        final idFromProfile = int.tryParse(profile['chapter_id']?.toString() ?? '');
        if (fromProfile.isNotEmpty) {
          chapter = fromProfile;
          await prefs.setString('chapter_name', chapter);
        }
        if (idFromProfile != null && idFromProfile != 0) {
          chapterId = idFromProfile;
          await prefs.setString('chapter_id', chapterId.toString());
        }
      } catch (_) {
        // Leave chapter empty; the dropdowns stay closed rather than
        // guessing at membership they can't confirm.
      }
    }

    // The resolved values are no longer used to filter the dropdowns, but
    // they are still written back to prefs above: other screens read
    // chapter_name/chapter_id from there and login does not always supply
    // both.
    if (mounted) {
      setState(() {
        _myChapter = chapter;
        _myChapterId = (chapterId == null || chapterId == 0) ? null : chapterId;
      });
    }
  }

  @override
  void initState() {
    _loadMyChapter();
    super.initState();
    _localMembers = List<Member>.from(widget.members);
    if (_localMembers.isEmpty) {
      _loadFallbackMembers();
    }
    _selectedCategory = widget.initialCategory;
    
    if (widget.initialActivity != null) {
      final act = widget.initialActivity!;
      _selectedCategory = act.type; // Should match one of the categories
      
      // Basic prefill
      _dateController.text = act.date;
      _notesController.text = act.description;
      _commentsController.text =
          act.rawJson['comments']?.toString() ?? '';
      _amountController.text = act.amount.toString();
      _companyController.text = act.rawJson['company']?.toString() ?? '';
      _locationController.text = (act.rawJson['location'] ??
              act.rawJson['meeting_location'] ??
              act.rawJson['venue'] ??
              act.rawJson['place'] ??
              act.rawJson['meeting_place'] ??
              act.rawJson['location_name'] ??
              '')
          .toString();
      _titleController.text = act.rawJson['title']?.toString() ?? '';
      
      // Specifically for GiveAsk
      if (act.type == 'giveask' || act.type == 'Give & Ask') {
         _selectedCategory = 'giveask';
         _givesController.text = act.rawJson['gives']?.toString() ?? '';
         _asksController.text = act.rawJson['asks']?.toString() ?? '';
      }

      // Referral-specific fields. The "Basic prefill" above only fills the
      // controllers every activity type shares (date/notes/comments); the
      // recipient dropdown, category and Internal/External type are unique
      // to referrals and were left at their defaults, so editing an existing
      // referral opened a form that looked blank even though the record had
      // all of this data.
      if (act.type == 'referral') {
        final recvRaw =
            act.rawJson['received_by'] ?? act.rawJson['member_id'];
        _selectedMemberId = int.tryParse(recvRaw?.toString() ?? '');

        _categoryController.text = (act.rawJson['business_category'] ??
                act.rawJson['category'] ??
                '')
            .toString();

        final rawType = (act.rawJson['referral_type'] ??
                act.rawJson['type'] ??
                'internal')
            .toString()
            .toLowerCase();
        _referralType = rawType == 'external' ? 'External' : 'Internal';

        _referralNameController.text =
            (act.rawJson['external_name'] ?? '').toString();
        _referralPhoneController.text = (act.rawJson['external_mobile'] ??
                act.rawJson['external_phone'] ??
                act.rawJson['referral_phone'] ??
                '')
            .toString();
        _referralCompanyController.text = (act.rawJson['external_company'] ??
                act.rawJson['company'] ??
                act.rawJson['company_name'] ??
                '')
            .toString();

        if (_referralType == 'External' && _selectedMemberId != null) {
          for (final m in widget.members) {
            if (m.id == _selectedMemberId) {
              _selectedChapterForReferral = m.chapter;
              break;
            }
          }
        }
      }
    } else {
      // A hard-coded date made every new referral appear as 20-08-2026 and
      // kept it out of the dashboard's current-week counts. Use the device's
      // current date whenever a fresh activity form is opened.
      _dateController.text = _formatDate(DateTime.now());
    }
        if (widget.initialGiveAsk != null) {
      _givesController.text = widget.initialGiveAsk!['gives'] ?? '';
      _asksController.text = widget.initialGiveAsk!['asks'] ?? '';
    }
  }

  int? _selectedMemberId;
  bool _showValidationErrors = false;
  String _referralType = 'Internal';
  String? _selectedChapterForReferral;
  String _cNoteType = 'Same Chapter';
  String? _selectedChapterForCNote;
  String _r2rType = 'Same Chapter';
  String? _selectedChapterForR2R;
  String _testimonialType = 'Same Chapter';
  String? _selectedChapterForTestimonial;
  String? _selectedProofFile;
  Uint8List? _proofBytes;

  Future<void> _pickFile() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Image Source',
                style: TextStyle(
                  color: AppColors.onModal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF2563EB)),
                title: Text('Take Photo with Camera',
                    style: TextStyle(color: AppColors.onModal)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF16A34A)),
                title: Text('Choose from Gallery',
                    style: TextStyle(color: AppColors.onModal)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null) {
      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 70,
        );
        if (picked != null && mounted) {
          final bytes = await picked.readAsBytes();
          setState(() {
            _selectedProofFile = picked.name;
            _proofBytes = bytes;
          });
          return;
        }
      } catch (e) {
        debugPrint('ImagePicker error: $e');
      }
    }

    if (source == null) {
      try {
        final result = await FilePicker.pickFiles(type: FileType.image);
        if (result.isNotEmpty && mounted) {
          final file = result.single;
          final bytes = await file.readAsBytes();
          setState(() {
            _selectedProofFile = file.name;
            _proofBytes = bytes;
          });
        }
      } catch (e) {
        debugPrint('FilePicker error: $e');
      }
    }
  }

  /// The picked proof image as a single multipart upload under [field].
  List<http.MultipartFile> _proofFiles(String field) {
    if (_proofBytes == null || _selectedProofFile == null) return const [];
    final name = _selectedProofFile!;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpeg';
    final mimeSubtype = (ext == 'png' || ext == 'webp' || ext == 'gif') ? ext : 'jpeg';
    final mediaType = MediaType('image', mimeSubtype);

    return [
      http.MultipartFile.fromBytes(
        field,
        _proofBytes!,
        filename: name,
        contentType: mediaType,
      ),
    ];
  }

  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _locationController = TextEditingController();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  // Description and Comments shared one controller, so typing in either
  // filled both.
  final _commentsController = TextEditingController();
  final _dateController = TextEditingController();

  final _visitorNameController = TextEditingController();
  final _categoryController = TextEditingController();
  // The person/prospect the referral is actually for - separate from
  // Receiving Member, which is the fellow chapter member it's being handed
  // to. The API already has a column for this (external_name comes back on
  // every referral row), it just had no input field to fill it from.
  final _referralNameController = TextEditingController();
  final _referralPhoneController = TextEditingController();
  final _referralCompanyController = TextEditingController();
  final _givesController = TextEditingController();
  final _asksController = TextEditingController();

  @override
  void dispose() {
    _companyController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _locationController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _commentsController.dispose();
    _dateController.dispose();
    _visitorNameController.dispose();
    _categoryController.dispose();
    _referralNameController.dispose();
    _referralPhoneController.dispose();
    _referralCompanyController.dispose();
    _givesController.dispose();
    _asksController.dispose();
    super.dispose();
  }

  bool _isSubmitting = false;

  /// Set when the record saved but the server silently dropped a field the
  /// member filled in. Shown under the success message instead of failing the
  /// whole submit, because the C-Note/R2R record itself really was created.
  String? _fieldWarning;

  /// One-line recap of the submitted record for the success message.
  String _submittedSummary(Map<String, String> body) {
    final bits = <String>[];

    final id = body['received_by'] ?? body['member_id'] ?? body['met_with'];
    if (id != null && id.isNotEmpty) {
      for (final m in _activeMembers) {
        if (m.id.toString() == id) {
          bits.add('To: ${m.name}');
          break;
        }
      }
    }
    final visitor = body['visitor_name'] ?? '';
    if (visitor.isNotEmpty) bits.add('Visitor: $visitor');

    final amount = body['amount'] ?? '';
    if (amount.isNotEmpty) bits.add('Amount: Rs $amount');

    final title = body['title'] ?? '';
    if (title.isNotEmpty) bits.add(title);

    final date = body['date'] ?? body['entry_date'] ?? '';
    if (date.isNotEmpty) bits.add(date);

    return bits.join('  -  ');
  }

  Future<void> _postToApi(String endpoint, Map<String, dynamic> body,
      {List<http.MultipartFile>? files}) async {
    final Map<String, String> stringBody = body.map((key, value) => MapEntry(key, value?.toString() ?? ''));
    setState(() {
      _isSubmitting = true;
      _fieldWarning = null;
    });
    try {
      if (endpoint == 'give_ask.php') {
        await ActivityService.createGiveAsk(stringBody);
      } else if (endpoint == 'referrals.php') {
        await ActivityService.createReferral(stringBody);
      } else if (endpoint == 'cnotes.php') {
        // Returns a warning when the record saved but a field was dropped
        // server-side, so the member is told instead of silently losing it.
        _fieldWarning = await ActivityService.createCNote(stringBody);
      } else if (endpoint == 'r2r.php') {
        _fieldWarning = await ActivityService.createR2R(stringBody, files: files);
      } else if (endpoint == 'testimonials.php') {
        await ActivityService.createTestimonial(stringBody, files: files);
      } else if (endpoint == 'visitors.php') {
        await ActivityService.createVisitor(stringBody);
      }
      
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);

        String activityName = 'Activity';
        String category = '';
        if (endpoint == 'give_ask.php') { activityName = 'Give & Ask'; category = 'giveask'; }
        if (endpoint == 'referrals.php') { activityName = 'Referral'; category = 'referral'; }
        if (endpoint == 'cnotes.php') { activityName = 'C-Note'; category = 'cnote'; }
        if (endpoint == 'r2r.php') { activityName = 'R2R Meeting'; category = 'r2r'; }
        if (endpoint == 'testimonials.php') { activityName = 'Testimonial'; category = 'testimonial'; }
        if (endpoint == 'visitors.php') { activityName = 'Visitor invite'; category = 'visitor'; }
        if (category.isNotEmpty) widget.onSubmitted?.call(category);

        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          widget.initialActivity != null
                              ? '$activityName updated successfully!'
                              : '$activityName submitted successfully!',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      if (_submittedSummary(stringBody).isNotEmpty)
                        Text(_submittedSummary(stringBody),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      // The record was created, but the server did not store
                      // one of the fields. Say so here rather than letting the
                      // member believe everything they typed was saved.
                      if (_fieldWarning != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _fieldWarning!,
                            style: const TextStyle(
                                color: Color(0xFFFFE082),
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => messenger.hideCurrentSnackBar(),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            // A dropped-field warning needs longer than the usual 4s to be read
            // and acted on.
            duration: Duration(seconds: _fieldWarning != null ? 8 : 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submitting $endpoint: $e');
      if (mounted) {
        // A real reason from the server (e.g. "Invalid action") used to be
        // replaced by a bare "Network error", which made a rejected save
        // look identical to no connection at all. Show what the server
        // actually said; keep the generic line only for genuine transport
        // failures.
        final reason = e is ApiException ? e.message.trim() : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reason.isNotEmpty
                ? reason
                : 'Network error. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    if (_selectedCategory == 'giveask') {
      final gives = _givesController.text.trim();
      final asks = _asksController.text.trim();
      if (gives.isEmpty && asks.isEmpty) {
        setState(() => _showValidationErrors = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter at least one Give or Ask.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (_dateController.text.trim().isEmpty) {
        setState(() => _showValidationErrors = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a date.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      setState(() => _showValidationErrors = false);
      await _postToApi('give_ask.php', {
        'action': (widget.initialGiveAsk != null || widget.initialActivity != null) ? 'update' : 'create',
        if (widget.initialGiveAsk != null) 'id': widget.initialGiveAsk!['id'],
        if (widget.initialActivity != null) 'id': widget.initialActivity!.id,
        'date': _dateController.text.trim(),
        'gives': gives,
        'asks': asks,
      });
      return;
    }

    if (_selectedCategory == 'referral') {
      final missing = <String>[];
      if (_referralType == 'External' && (_selectedChapterForReferral == null || _selectedChapterForReferral!.isEmpty)) {
        missing.add('Select Chapter');
      }
      if (_selectedMemberId == null) missing.add('Receiving Member');
      if (_categoryController.text.trim().isEmpty) missing.add('Business Category');
      if (_dateController.text.trim().isEmpty) missing.add('Referral Date');
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
      // referrals.php enforces `received_by` against users.id. An id that is
      // not in the real directory fails the insert with a 1452 integrity
      // violation that the endpoint reports as HTTP 200, so the referral is
      // never written. Refuse before the request instead of after.
      if (!_isRealMember(_selectedMemberId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'That member is not in the directory. Reload the member list and choose again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      setState(() => _showValidationErrors = false);

      await _postToApi('referrals.php', {
        'action': widget.initialActivity != null ? 'update' : 'create',
        if (widget.initialActivity != null) 'id': widget.initialActivity!.id,
        // referrals.php stores the recipient in `received_by` and enforces it
        // against users.id. Verified against the live endpoint: a valid id is
        // stored correctly, and an id that is not a real user fails the insert
        // with a 1452 integrity violation reported as HTTP 200. The earlier
        // note here blamed `member_id` for leaving received_by null - that was
        // wrong; the nulls came from demo ids, not from the column name.
        'received_by': _selectedMemberId,
        'member_id': _selectedMemberId,
        'category': _categoryController.text,
        'business_category': _categoryController.text,
        'date': _dateController.text,
        'referral_date': _dateController.text,
        'type': _referralType,
        'referral_type': _referralType.toLowerCase(),
        'details': _notesController.text,
        // Confirmed against a live referral row that this is the column
        // name. The phone/company equivalents aren't confirmed the same
        // way, so send every plausible column name - unrecognised keys are
        // harmless, silently dropping the value from one wrong guess isn't.
        'external_name': _referralNameController.text,
        'external_mobile': _referralPhoneController.text,
        'external_phone': _referralPhoneController.text,
        'referral_phone': _referralPhoneController.text,
        'external_company': _referralCompanyController.text,
        'company': _referralCompanyController.text,
        'company_name': _referralCompanyController.text,
      });
      return;
    }

    if (_selectedCategory == 'cnote') {
      final missing = <String>[];
      if (_cNoteType == 'Other Chapter' && (_selectedChapterForCNote == null || _selectedChapterForCNote!.isEmpty)) {
        missing.add('Select Chapter');
      }
      if (_selectedMemberId == null) missing.add('Receiving Member');
      if (_amountController.text.trim().isEmpty) missing.add('Amount');
      if (_dateController.text.trim().isEmpty) missing.add('Date');
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
      if (!_isRealMember(_selectedMemberId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'That member is not in the directory. Reload the member list and choose again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      setState(() => _showValidationErrors = false);

      String? memberCompany;
      String? receiverName;
      if (_selectedMemberId != null) {
        try {
          final m = widget.members.firstWhere((m) => m.id == _selectedMemberId);
          memberCompany = m.company;
          receiverName = m.name;
        } catch (_) {}
      }
      final effectiveCompany = _companyController.text.trim().isNotEmpty
          ? _companyController.text.trim()
          : (memberCompany ?? '');

      await _postToApi('cnotes.php', {
        'action': widget.initialActivity != null ? 'update' : 'create',
        if (widget.initialActivity != null) 'id': widget.initialActivity!.id,
        'received_by': _selectedMemberId,
        'to_member_id': _selectedMemberId,
        'receiver_id': _selectedMemberId,
        if (receiverName != null) 'received_by_name': receiverName,
        if (receiverName != null) 'to_member_name': receiverName,
        'amount': _amountController.text,
        'company': effectiveCompany,
        'company_name': effectiveCompany,
        'business_name': effectiveCompany,
        'companyName': effectiveCompany,
        'client_company': effectiveCompany,
        'business_category': _categoryController.text,
        'category': _categoryController.text,
        'date': _dateController.text,
        'type': _cNoteType,
        'description': _notesController.text,
        'comments': _commentsController.text,
      });
      return;
    }

    if (_selectedCategory == 'r2r') {
      final missing = <String>[];
      if (_r2rType == 'Other Chapter' && (_selectedChapterForR2R == null || _selectedChapterForR2R!.isEmpty)) {
        missing.add('Select Chapter');
      }
      if (_selectedMemberId == null) missing.add('Partner Member');
      if (_dateController.text.trim().isEmpty) missing.add('Meeting Date');
      if (_proofBytes == null && widget.initialActivity == null) {
        missing.add('Attach Proof');
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
      if (!_isRealMember(_selectedMemberId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'That member is not in the directory. Reload the member list and choose again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      setState(() => _showValidationErrors = false);
      String? partnerName;
      if (_selectedMemberId != null) {
        try {
          partnerName = widget.members.firstWhere((m) => m.id == _selectedMemberId).name;
        } catch (_) {}
      }

      final loc = _locationController.text.trim();
      final notes = _notesController.text.trim();
      final comments = _commentsController.text.trim();
      final desc = notes.isNotEmpty ? notes : comments;
      final userId = await ApiClient.getUserId();
      await _postToApi(
        'r2r.php',
        {
          'user_id': userId,
          'action': widget.initialActivity != null ? 'update' : 'add',
          if (widget.initialActivity != null) 'id': widget.initialActivity!.id,
          'member_id': _selectedMemberId,
          'partner_id': _selectedMemberId,
          'met_with': _selectedMemberId,
          'to_user_id': _selectedMemberId,
          'to_member_id': _selectedMemberId,
          if (partnerName != null) 'partner_name': partnerName,
          if (partnerName != null) 'met_with_name': partnerName,
          if (partnerName != null) 'member_name': partnerName,
          'date': _dateController.text,
          'meeting_date': _dateController.text,
          'location': loc,
          'meeting_location': loc,
          'venue': loc,
          'place': loc,
          'meeting_place': loc,
          'location_name': loc,
          'meeting_address': loc,
          'address': loc,
          'topics_discussed': desc,
          'topic': desc,
          'description': desc,
          'notes': notes,
          'comments': comments,
          'type': _r2rType,
          if (_selectedProofFile != null) ...{
            'image': _selectedProofFile!,
            'proof_image': _selectedProofFile!,
            'proof': _selectedProofFile!,
          } else if (widget.initialActivity != null) ...{
            if ((widget.initialActivity!.rawJson['image'] ?? '').toString().trim().isNotEmpty &&
                widget.initialActivity!.rawJson['image'].toString() != 'null')
              'image': widget.initialActivity!.rawJson['image'].toString().trim(),
            if ((widget.initialActivity!.rawJson['proof_image'] ?? '').toString().trim().isNotEmpty &&
                widget.initialActivity!.rawJson['proof_image'].toString() != 'null')
              'proof_image': widget.initialActivity!.rawJson['proof_image'].toString().trim(),
            if ((widget.initialActivity!.rawJson['image_url'] ?? '').toString().trim().isNotEmpty &&
                widget.initialActivity!.rawJson['image_url'].toString() != 'null')
              'image_url': widget.initialActivity!.rawJson['image_url'].toString().trim(),
            if ((widget.initialActivity!.rawJson['proof'] ?? '').toString().trim().isNotEmpty &&
                widget.initialActivity!.rawJson['proof'].toString() != 'null')
              'proof': widget.initialActivity!.rawJson['proof'].toString().trim(),
          },
        },
        files: _proofFiles('image'),
      );
      return;
    }

    if (_selectedCategory == 'testimonial') {
      final missing = <String>[];
      if (_testimonialType == 'Other Chapter' && (_selectedChapterForTestimonial == null || _selectedChapterForTestimonial!.isEmpty)) {
        missing.add('Select Chapter');
      }
      if (_selectedMemberId == null) missing.add('Receiving Member');
      final content = _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : _commentsController.text.trim();
      if (content.isEmpty) missing.add('Testimonial Content');
      if (_dateController.text.trim().isEmpty) missing.add('Date');
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
      if (!_isRealMember(_selectedMemberId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'That member is not in the directory. Reload the member list and choose again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      setState(() => _showValidationErrors = false);

      await _postToApi(
        'testimonials.php',
        {
          'action': widget.initialActivity != null ? 'update' : 'create',
          if (widget.initialActivity != null) 'id': widget.initialActivity!.id,
          'received_by': _selectedMemberId,
          'date': _dateController.text,
          'title': _titleController.text,
          // The testimonial form has no Description field — the member types
          // into Comments, so that is the testimonial text.
          'content': content,
          'comments': _commentsController.text,
          'type': _testimonialType,
          if (_selectedProofFile != null) 'media': _selectedProofFile,
        },
        files: _proofFiles('media'),
      );
      return;
    }

    if (_selectedCategory == 'visitor') {
      // The labels have always shown these as required (Visitor Name *,
      // Mobile *, Visit Date *), but nothing ever enforced it - the app
      // would submit an incomplete request and the server's rejection
      // arrived as a bare "network error", not a reason. Same class of gap
      // already closed on the referral form.
      final missing = <String>[];
      if (_visitorNameController.text.trim().isEmpty) missing.add('Visitor Name');
      if (_phoneController.text.trim().isEmpty) missing.add('Mobile');
      if (_dateController.text.trim().isEmpty) missing.add('Visit Date');
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

      await _postToApi('visitors.php', {
        'action': widget.initialActivity != null ? 'update' : 'create',
        if (widget.initialActivity != null) 'id': widget.initialActivity!.id,
        // Confirmed against a real visitors.php row: the column is `name`,
        // not `visitor_name` - kept as a harmless extra alias in case some
        // deployments still read it.
        'name': _visitorNameController.text,
        'visitor_name': _visitorNameController.text,
        'mobile': _phoneController.text,
        'visitor_mobile': _phoneController.text,
        'phone': _phoneController.text,
        'visit_date': _dateController.text,
        'date': _dateController.text,
        // Required NOT NULL column. Without it the insert fails with
        // "Column 'chapter_id' cannot be null", returned as HTTP 200 - so the
        // invite was never recorded and nothing said so.
        if (_myChapterId != null) 'chapter_id': _myChapterId.toString(),
        if (_myChapter.isNotEmpty) 'chapter_name': _myChapter,
        if (_myChapter.isNotEmpty) 'chapter': _myChapter,
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = AppColors.secondary;
    final isDark = AppColors.isDarkMode.value;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.paddingOf(context).bottom +
            20,
      ),
      decoration: BoxDecoration(
        color: AppColors.modalSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (_selectedCategory != null)
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: AppColors.onModal),
                        onPressed: () => setState(() => _selectedCategory = null),
                      ),
                    Text(
                      _selectedCategory == null ? 'Submit Activity' : 'Log ${_getCategoryLabel(_selectedCategory!)}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.onModal),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.onModal),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // If no category selected, show Grid View of available activities
            if (_selectedCategory == null) ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.25,
                children: [
                  _buildGridOptionCard('referral', 'Referral', Icons.share),
                  _buildGridOptionCard('cnote', 'C-Notes', Icons.business),
                  _buildGridOptionCard('r2r', 'R2R Meeting', Icons.handshake),
                  _buildGridOptionCard('testimonial', 'Testimonial', Icons.format_quote),
                  _buildGridOptionCard('visitor', 'Visitor Invite', Icons.person_add_alt),
                  _buildGridOptionCard('giveask', 'Give & Ask', Icons.volunteer_activism),
                ],
              ),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF19406E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ),
              ),
            ] else ...[
              // Input Form View for the selected activity
              if (_selectedCategory != 'visitor' && _selectedCategory != 'giveask' && _selectedCategory != 'referral' && _selectedCategory != 'cnote' && _selectedCategory != 'r2r' && _selectedCategory != 'testimonial') ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Select Member', style: TextStyle(color: AppColors.modalLabel, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF102A54) : AppColors.modalInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.inputBorder, width: 1.5),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _safeMemberValue(_visibleMembers(false, null)),
                      hint: Text('-- Choose Member --', style: TextStyle(color: isDark ? const Color(0xFF7A92B4) : const Color(0xFF6B7280))),
                      dropdownColor: isDark ? const Color(0xFF102A54) : Colors.white,
                      isExpanded: true,
                      iconEnabledColor: isDark ? AppColors.inputBorder : AppColors.primary,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                      items: _visibleMembers(false, null).map((m) {
                        return DropdownMenuItem<int>(
                          value: m.id,
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                text: m.name, 
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.primary, 
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: ' (${m.company})', 
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF7A92B4) : Colors.black87,
                                ),
                              ),
                            ]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedMemberId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (_selectedCategory == 'referral') ...[
                // Referral Type Toggle
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Referral Type', style: TextStyle(color: AppColors.modalLabel, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(height: 6),
                _ReferralTypeToggle(
                  referralType: _referralType,
                  onChanged: (type) {
                    setState(() {
                      _referralType = type;
                      if (type == 'Internal') {
                        _selectedMemberId = null;
                      } else {
                        _selectedChapterForReferral = null;
                        _selectedMemberId = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Select Chapter (Only if External)
                if (_referralType == 'External') ...[
                  _buildFieldLabel('Select Chapter *'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF102A54) : AppColors.modalInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_showValidationErrors && (_selectedChapterForReferral == null || _selectedChapterForReferral!.isEmpty))
                            ? Colors.redAccent
                            : AppColors.inputBorder,
                        width: 1.5,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (_selectedChapterForReferral != null &&
                                _chapterOptions(excludeMyChapter: true).contains(_selectedChapterForReferral))
                            ? _selectedChapterForReferral
                            : null,
                        hint: Text('-- Select Chapter --', style: TextStyle(color: isDark ? const Color(0xFF7A92B4) : const Color(0xFF6B7280))),
                        dropdownColor: isDark ? const Color(0xFF102A54) : Colors.white,
                        isExpanded: true,
                        iconEnabledColor: isDark ? AppColors.inputBorder : AppColors.primary,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                        items: _chapterOptions(excludeMyChapter: true).map((c) {
                          return DropdownMenuItem<String>(
                            value: c,
                            child: Text(c, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedChapterForReferral = val;
                            _selectedMemberId = null; // Reset member when chapter changes
                          });
                        },
                      ),
                    ),
                  ),
                  if (_showValidationErrors && (_selectedChapterForReferral == null || _selectedChapterForReferral!.isEmpty))
                    _buildErrorText('Please select a chapter'),
                  const SizedBox(height: 12),
                ],

                // Receiving Member
                _buildFieldLabel('Receiving Member *'),
                const SizedBox(height: 6),
                // No directory means no selectable recipient. Say so, instead of
                // rendering an empty dropdown that looks like a broken form.
                if (_activeMembers.isEmpty)
                  _buildMembersUnavailable()
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF102A54) : AppColors.modalInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_showValidationErrors && _selectedMemberId == null)
                            ? Colors.redAccent
                            : AppColors.inputBorder,
                        width: 1.5,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _safeMemberValue(_visibleMembers(_referralType == 'External', _selectedChapterForReferral)),
                        hint: Text('-- Select member --', style: TextStyle(color: isDark ? const Color(0xFF7A92B4) : const Color(0xFF6B7280))),
                        dropdownColor: isDark ? const Color(0xFF102A54) : Colors.white,
                        isExpanded: true,
                        iconEnabledColor: isDark ? AppColors.inputBorder : AppColors.primary,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                        items: _visibleMembers(_referralType == 'External', _selectedChapterForReferral).map((m) {
                          return DropdownMenuItem<int>(
                            value: m.id,
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                  text: m.name, 
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.primary, 
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text: ' (${m.company})', 
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF7A92B4) : Colors.black87,
                                  ),
                                ),
                              ]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedMemberId = val;
                            if (val != null) {
                              try {
                                final selectedMember = widget.members.firstWhere((m) => m.id == val);
                                // Company Name auto-fill from the receiving member
                                _referralCompanyController.text = selectedMember.company;
                              } catch (e) { /* member not found */ }
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  if (_showValidationErrors && _selectedMemberId == null)
                    _buildErrorText('Please select receiving member'),
                ],
                // Receiving member's mobile number — shown once a member is
                // picked, the same way the category auto-fills, so the
                // number that referral is actually going to is visible
                // before submitting instead of only the name.
                Builder(builder: (context) {
                  if (_selectedMemberId == null) return const SizedBox.shrink();
                  Member? selected;
                  try {
                    selected = widget.members.firstWhere((m) => m.id == _selectedMemberId);
                  } catch (e) {
                    selected = null;
                  }
                  final mobile = selected?.mobile ?? '';
                  if (mobile.isEmpty || mobile == 'N/A') return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(Icons.phone, size: 14, color: AppColors.onModalMuted),
                        const SizedBox(width: 6),
                        Text(mobile,
                            style: TextStyle(color: AppColors.onModalMuted, fontSize: 13)),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),

                // Company Name - displayed directly under Receiving Member
                _buildInputField(
                  'Company Name', 
                  _referralCompanyController, 
                  'Company name or business name',
                ),

                _buildInputField(
                  'Business Category *',
                  _categoryController,
                  '',
                  errorText: (_showValidationErrors && _categoryController.text.trim().isEmpty)
                      ? 'Please enter business category'
                      : null,
                ),
                _buildInputField(
                  'Referral Date *',
                  _dateController,
                  'DD-MM-YYYY',
                  readOnly: true,
                  suffixIcon: Icons.calendar_today_outlined,
                  onTap: _selectActivityDate,
                  errorText: (_showValidationErrors && _dateController.text.trim().isEmpty)
                      ? 'Please select referral date'
                      : null,
                ),
                // Who the referral is actually for - the prospect/client -
                // as opposed to Receiving Member above, which is which
                // fellow member it's being handed to.
                _buildInputField('Referral Name', _referralNameController,
                    'Name of the person or business being referred'),
                _buildInputField(
                  'Referral Phone Number',
                  _referralPhoneController,
                  'Phone number of the referral',
                  keyboardType: TextInputType.phone,
                ),
                _buildInputField('Description', _notesController, 'Details about this referral...', maxLines: 3),
              ],

              if (_selectedCategory == 'cnote') ...[
                // C-Note Member Location Toggle
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Member Location', style: TextStyle(color: AppColors.modalLabel, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                           _cNoteType = 'Same Chapter';
                           _selectedMemberId = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _cNoteType == 'Same Chapter' ? const Color(0xFF1E4A7C) : AppColors.modalInput,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                            border: Border.all(color: AppColors.inputBorder, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.group, size: 16, color: _cNoteType == 'Same Chapter' ? goldColor : AppColors.onModalMuted),
                              const SizedBox(width: 6),
                              Text('Same Chapter', style: TextStyle(color: _cNoteType == 'Same Chapter' ? goldColor : AppColors.onModalMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                           _cNoteType = 'Other Chapter';
                           _selectedChapterForCNote = null;
                           _selectedMemberId = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _cNoteType == 'Other Chapter' ? const Color(0xFF1E4A7C) : AppColors.modalInput,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                            border: Border.all(color: AppColors.inputBorder, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.language, size: 16, color: _cNoteType == 'Other Chapter' ? goldColor : AppColors.onModalMuted),
                              const SizedBox(width: 6),
                              Text('Other Chapter', style: TextStyle(color: _cNoteType == 'Other Chapter' ? goldColor : AppColors.onModalMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Select Chapter (Only if Other Chapter)
                if (_cNoteType == 'Other Chapter') ...[
                  _buildFieldLabel('Select Chapter *'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF102A54) : AppColors.modalInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_showValidationErrors && (_selectedChapterForCNote == null || _selectedChapterForCNote!.isEmpty))
                            ? Colors.redAccent
                            : AppColors.inputBorder,
                        width: 1.5,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (_selectedChapterForCNote != null &&
                                _chapterOptions(excludeMyChapter: true).contains(_selectedChapterForCNote))
                            ? _selectedChapterForCNote
                            : null,
                        hint: Text('-- Select Chapter --', style: TextStyle(color: isDark ? const Color(0xFF7A92B4) : const Color(0xFF6B7280))),
                        dropdownColor: isDark ? const Color(0xFF102A54) : Colors.white,
                        isExpanded: true,
                        iconEnabledColor: isDark ? AppColors.inputBorder : AppColors.primary,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                        items: _chapterOptions(excludeMyChapter: true).map((c) {
                          return DropdownMenuItem<String>(
                            value: c,
                            child: Text(c, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedChapterForCNote = val;
                            _selectedMemberId = null;
                          });
                        },
                      ),
                    ),
                  ),
                  if (_showValidationErrors && (_selectedChapterForCNote == null || _selectedChapterForCNote!.isEmpty))
                    _buildErrorText('Please select a chapter'),
                  const SizedBox(height: 12),
                ],

                // Receiving Member — full width
                _buildFieldLabel('Receiving Member *'),
                const SizedBox(height: 6),
                if (_activeMembers.isEmpty)
                  _buildMembersUnavailable()
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF102A54) : AppColors.modalInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_showValidationErrors && _selectedMemberId == null)
                            ? Colors.redAccent
                            : AppColors.inputBorder,
                        width: 1.5,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _safeMemberValue(_visibleMembers(_cNoteType == 'Other Chapter', _selectedChapterForCNote)),
                        isDense: false,
                        menuWidth: MediaQuery.of(context).size.width - 72,
                        hint: Text('-- Select member --', style: TextStyle(color: isDark ? const Color(0xFF7A92B4) : const Color(0xFF6B7280), fontSize: 14)),
                        dropdownColor: isDark ? const Color(0xFF102A54) : Colors.white,
                        isExpanded: true,
                        iconEnabledColor: isDark ? AppColors.inputBorder : AppColors.primary,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                        items: _visibleMembers(_cNoteType == 'Other Chapter', _selectedChapterForCNote).map((m) {
                          return DropdownMenuItem<int>(
                            value: m.id,
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                  text: m.name, 
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.primary, 
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text: ' (${m.company})', 
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF7A92B4) : Colors.black87,
                                  ),
                                ),
                              ]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() {
                          _selectedMemberId = val;
                          // Auto-fill the company and category from the chosen member.
                          if (val != null) {
                            for (final m in _activeMembers) {
                              if (m.id == val) {
                                _companyController.text = m.company;
                                break;
                              }
                            }
                          }
                        }),
                      ),
                    ),
                  ),
                  if (_showValidationErrors && _selectedMemberId == null)
                    _buildErrorText('Please select receiving member'),
                ],
                const SizedBox(height: 12),
                // Amount — full width below the member dropdown
                _buildInputField(
                  'Amount (₹) *',
                  _amountController,
                  'e.g. 250000',
                  keyboardType: TextInputType.number,
                  errorText: (_showValidationErrors && _amountController.text.trim().isEmpty)
                      ? 'Please enter amount'
                      : null,
                ),
                _buildInputField('Company', _companyController, 'Company Name'),
                _buildInputField('Business Category', _categoryController, ''),
                _buildInputField(
                  'C-Note Date *',
                  _dateController,
                  'DD-MM-YYYY',
                  readOnly: true,
                  suffixIcon: Icons.calendar_today_outlined,
                  onTap: _selectActivityDate,
                  errorText: (_showValidationErrors && _dateController.text.trim().isEmpty)
                      ? 'Please select date'
                      : null,
                ),
                // Description
                _buildInputField('Description', _notesController, 'Details about the business closed...', maxLines: 3),
              ],

              if (_selectedCategory == 'r2r') ...[
                // R2R Member Location Toggle
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Member Location', style: TextStyle(color: AppColors.modalLabel, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                           _r2rType = 'Same Chapter';
                           _selectedMemberId = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _r2rType == 'Same Chapter' ? const Color(0xFF1E4A7C) : AppColors.modalInput,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                            border: Border.all(color: AppColors.inputBorder, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.group, size: 16, color: _r2rType == 'Same Chapter' ? goldColor : AppColors.onModalMuted),
                              const SizedBox(width: 6),
                              Text('Same Chapter', style: TextStyle(color: _r2rType == 'Same Chapter' ? goldColor : AppColors.onModalMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                           _r2rType = 'Other Chapter';
                           _selectedChapterForR2R = null;
                           _selectedMemberId = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _r2rType == 'Other Chapter' ? const Color(0xFF1E4A7C) : AppColors.modalInput,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                            border: Border.all(color: AppColors.inputBorder, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.language, size: 16, color: _r2rType == 'Other Chapter' ? goldColor : AppColors.onModalMuted),
                              const SizedBox(width: 6),
                              Text('Other Chapter', style: TextStyle(color: _r2rType == 'Other Chapter' ? goldColor : AppColors.onModalMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Select Chapter (Only if Other Chapter)
                if (_r2rType == 'Other Chapter') ...[
                  _buildFieldLabel('Select Chapter *'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF102A54) : AppColors.modalInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_showValidationErrors && (_selectedChapterForR2R == null || _selectedChapterForR2R!.isEmpty))
                            ? Colors.redAccent
                            : AppColors.inputBorder,
                        width: 1.5,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (_selectedChapterForR2R != null &&
                                _chapterOptions(excludeMyChapter: true).contains(_selectedChapterForR2R))
                            ? _selectedChapterForR2R
                            : null,
                        hint: Text('-- Select Chapter --', style: TextStyle(color: isDark ? const Color(0xFF7A92B4) : const Color(0xFF6B7280))),
                        dropdownColor: isDark ? const Color(0xFF102A54) : Colors.white,
                        isExpanded: true,
                        iconEnabledColor: isDark ? AppColors.inputBorder : AppColors.primary,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                        items: _chapterOptions(excludeMyChapter: true).map((c) {
                          return DropdownMenuItem<String>(
                            value: c,
                            child: Text(c, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedChapterForR2R = val;
                            _selectedMemberId = null;
                          });
                        },
                      ),
                    ),
                  ),
                  if (_showValidationErrors && (_selectedChapterForR2R == null || _selectedChapterForR2R!.isEmpty))
                    _buildErrorText('Please select a chapter'),
                  const SizedBox(height: 12),
                ],

                // Receiving Member
                _buildFieldLabel('Receiving Member *'),
                const SizedBox(height: 6),
                if (_activeMembers.isEmpty)
                  _buildMembersUnavailable()
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF102A54) : AppColors.modalInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_showValidationErrors && _selectedMemberId == null)
                            ? Colors.redAccent
                            : AppColors.inputBorder,
                        width: 1.5,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _safeMemberValue(_visibleMembers(_r2rType == 'Other Chapter', _selectedChapterForR2R)),
                        hint: Text('-- Select member --', style: TextStyle(color: isDark ? const Color(0xFF7A92B4) : const Color(0xFF6B7280))),
                        dropdownColor: isDark ? const Color(0xFF102A54) : Colors.white,
                        isExpanded: true,
                        iconEnabledColor: isDark ? AppColors.inputBorder : AppColors.primary,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                        items: _visibleMembers(_r2rType == 'Other Chapter', _selectedChapterForR2R).map((m) {
                          return DropdownMenuItem<int>(
                            value: m.id,
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                  text: m.name, 
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.primary, 
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text: ' (${m.company})', 
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF7A92B4) : Colors.black87,
                                  ),
                                ),
                              ]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedMemberId = val),
                      ),
                    ),
                  ),
                  if (_showValidationErrors && _selectedMemberId == null)
                    _buildErrorText('Please select partner member'),
                ],
                const SizedBox(height: 12),

                // Meeting Date
                _buildInputField(
                  'Meeting Date *',
                  _dateController,
                  'DD-MM-YYYY',
                  readOnly: true,
                  suffixIcon: Icons.calendar_today_outlined,
                  onTap: _selectActivityDate,
                  errorText: (_showValidationErrors && _dateController.text.trim().isEmpty)
                      ? 'Please select meeting date'
                      : null,
                ),

                // Location
                _buildInputField(
                  'Location',
                  _locationController,
                  'e.g. Starbucks, Office, Hotel Lobby, etc.',
                  prefixIcon: Icons.location_on_outlined,
                ),
                // Description
                _buildInputField('Description', _notesController, 'What did you discuss?', maxLines: 3),
                
                // Attach Proof
                _buildFieldLabel('Attach Proof *'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.modalInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (_showValidationErrors && _proofBytes == null && widget.initialActivity == null)
                          ? Colors.redAccent
                          : AppColors.inputBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _pickFile,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E3A66) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Choose file',
                            style: TextStyle(
                              color: isDark ? Colors.white : AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedProofFile ?? 'No file chosen',
                          style: TextStyle(
                            color: _selectedProofFile != null ? AppColors.onModal : AppColors.onModalMuted,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showValidationErrors && _proofBytes == null && widget.initialActivity == null)
                  _buildErrorText('Please attach a proof photo'),
                if (_proofBytes != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Image.memory(
                          _proofBytes!,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _proofBytes = null;
                              _selectedProofFile = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Upload a photo/selfie together as proof.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                  ),
                ),
              ],

              if (_selectedCategory == 'testimonial') ...[
                // Member Location Toggle
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Member Location', style: TextStyle(color: AppColors.modalLabel, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                           _testimonialType = 'Same Chapter';
                           _selectedMemberId = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _testimonialType == 'Same Chapter' ? const Color(0xFF1E4A7C) : AppColors.modalInput,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                            border: Border.all(color: AppColors.inputBorder, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.group, size: 16, color: _testimonialType == 'Same Chapter' ? goldColor : AppColors.onModalMuted),
                              const SizedBox(width: 6),
                              Text('Same Chapter', style: TextStyle(color: _testimonialType == 'Same Chapter' ? goldColor : AppColors.onModalMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                           _testimonialType = 'Other Chapter';
                           _selectedChapterForTestimonial = null;
                           _selectedMemberId = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _testimonialType == 'Other Chapter' ? const Color(0xFF1E4A7C) : AppColors.modalInput,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                            border: Border.all(color: AppColors.inputBorder, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.language, size: 16, color: _testimonialType == 'Other Chapter' ? goldColor : AppColors.onModalMuted),
                              const SizedBox(width: 6),
                              Text('Other Chapter', style: TextStyle(color: _testimonialType == 'Other Chapter' ? goldColor : AppColors.onModalMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Select Chapter (Only if Other Chapter)
                if (_testimonialType == 'Other Chapter') ...[
                  _buildFieldLabel('Select Chapter *'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF102A54) : AppColors.modalInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_showValidationErrors && (_selectedChapterForTestimonial == null || _selectedChapterForTestimonial!.isEmpty))
                            ? Colors.redAccent
                            : AppColors.inputBorder,
                        width: 1.5,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (_selectedChapterForTestimonial != null &&
                                _chapterOptions(excludeMyChapter: true).contains(_selectedChapterForTestimonial))
                            ? _selectedChapterForTestimonial
                            : null,
                        hint: Text('-- Select Chapter --', style: TextStyle(color: isDark ? const Color(0xFF7A92B4) : const Color(0xFF6B7280))),
                        dropdownColor: isDark ? const Color(0xFF102A54) : Colors.white,
                        isExpanded: true,
                        iconEnabledColor: isDark ? AppColors.inputBorder : AppColors.primary,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                        items: _chapterOptions(excludeMyChapter: true).map((c) {
                          return DropdownMenuItem<String>(
                            value: c,
                            child: Text(c, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedChapterForTestimonial = val;
                            _selectedMemberId = null;
                          });
                        },
                      ),
                    ),
                  ),
                  if (_showValidationErrors && (_selectedChapterForTestimonial == null || _selectedChapterForTestimonial!.isEmpty))
                    _buildErrorText('Please select a chapter'),
                  const SizedBox(height: 12),
                ],

                // For Member (Dropdown)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('For Member *'),
                    const SizedBox(height: 6),
                    if (_activeMembers.isEmpty)
                      _buildMembersUnavailable()
                    else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF102A54) : AppColors.modalInput,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (_showValidationErrors && _selectedMemberId == null)
                                ? Colors.redAccent
                                : AppColors.inputBorder,
                            width: 1.5,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _safeMemberValue(_visibleMembers(_testimonialType == 'Other Chapter', _selectedChapterForTestimonial)),
                            hint: Text('-- Select member --', style: TextStyle(color: isDark ? const Color(0xFF7A92B4) : const Color(0xFF6B7280))),
                            dropdownColor: isDark ? const Color(0xFF102A54) : Colors.white,
                            isExpanded: true,
                            iconEnabledColor: isDark ? AppColors.inputBorder : AppColors.primary,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                            items: _visibleMembers(_testimonialType == 'Other Chapter', _selectedChapterForTestimonial).map((m) {
                              return DropdownMenuItem<int>(
                                value: m.id,
                                child: Text.rich(
                                  TextSpan(children: [
                                    TextSpan(
                                      text: m.name, 
                                      style: TextStyle(
                                        color: isDark ? Colors.white : AppColors.primary, 
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' (${m.company})', 
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF7A92B4) : Colors.black87,
                                      ),
                                    ),
                                  ]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedMemberId = val),
                          ),
                        ),
                      ),
                      if (_showValidationErrors && _selectedMemberId == null)
                        _buildErrorText('Please select member'),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                
                // Date and Media Type
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildInputField(
                        'Date *',
                        _dateController,
                        'DD-MM-YYYY',
                        readOnly: true,
                        suffixIcon: Icons.calendar_today_outlined,
                        onTap: _selectActivityDate,
                        errorText: (_showValidationErrors && _dateController.text.trim().isEmpty)
                            ? 'Please select date'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Media (Optional)'),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: _pickFile,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.modalInput,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.inputBorder, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.attach_file, color: Color(0xFF6B7280), size: 16),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _selectedProofFile ?? 'Choose file',
                                      style: TextStyle(color: _selectedProofFile != null ? AppColors.onModal : AppColors.onModalMuted, fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInputField('Title', _titleController, ''),
              ],

              if (_selectedCategory == 'visitor') ...[
                _buildInputField(
                  'Visitor Name *',
                  _visitorNameController,
                  'Name',
                  errorText: (_showValidationErrors && _visitorNameController.text.trim().isEmpty)
                      ? 'Please enter visitor name'
                      : null,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildInputField(
                        'Mobile *',
                        _phoneController,
                        'Mobile',
                        keyboardType: TextInputType.phone,
                        errorText: (_showValidationErrors && _phoneController.text.trim().isEmpty)
                            ? 'Please enter mobile number'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInputField(
                        'Visit Date *',
                        _dateController,
                        'DD-MM-YYYY',
                        readOnly: true,
                        suffixIcon: Icons.calendar_today_outlined,
                        onTap: _selectActivityDate,
                        errorText: (_showValidationErrors && _dateController.text.trim().isEmpty)
                            ? 'Please select visit date'
                            : null,
                      ),
                    ),
                  ],
                ),
              ],

              if (_selectedCategory == 'giveask') ...[
                _buildInputField(
                  'Date *',
                  _dateController,
                  '',
                  readOnly: true,
                  suffixIcon: Icons.calendar_today_outlined,
                  onTap: _selectActivityDate,
                  errorText: (_showValidationErrors && _dateController.text.trim().isEmpty)
                      ? 'Please select date'
                      : null,
                ),
                _buildInputField(
                  'Give',
                  _givesController,
                  '',
                  maxLines: 4,
                  errorText: (_showValidationErrors && _givesController.text.trim().isEmpty && _asksController.text.trim().isEmpty)
                      ? 'Please enter at least one Give or Ask'
                      : null,
                ),
                _buildInputField(
                  'Ask',
                  _asksController,
                  '',
                  maxLines: 4,
                  errorText: (_showValidationErrors && _givesController.text.trim().isEmpty && _asksController.text.trim().isEmpty)
                      ? 'Please enter at least one Give or Ask'
                      : null,
                ),
              ],

              if (_selectedCategory == 'testimonial')
                _buildInputField(
                  'Testimonial Content *',
                  _commentsController,
                  'Enter testimonial content...',
                  maxLines: 3,
                  errorText: (_showValidationErrors && (_notesController.text.trim().isEmpty && _commentsController.text.trim().isEmpty))
                      ? 'Please enter testimonial content'
                      : null,
                ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor,
                    foregroundColor: AppColors.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.card, strokeWidth: 2))
                      : Text(
                          _selectedCategory == 'visitor' ? 'Submit Invite' : 'Submit Entry',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGridOptionCard(String category, String title, IconData icon) {
    final goldColor = AppColors.secondary;

    return InkWell(
      onTap: () => setState(() => _selectedCategory = category),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.modalTile,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.cardGradient,
                border: Border.all(color: goldColor.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Icon(icon, color: goldColor, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(color: AppColors.onModal, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryLabel(String cat) {
    switch (cat) {
      case 'referral':
        return 'Referral';
      case 'cnote':
        return 'C-Note';
      case 'r2r':
        return 'R2R Meeting';
      case 'testimonial':
        return 'Testimonial';
      case 'giveask':
        return 'Give & Ask';
      default:
        return 'Visitor';
    }
  }

  Widget _buildFieldLabel(String label) {
    final labelColor = AppColors.modalLabel;
    Widget labelWidget;
    if (label.contains('*')) {
      final parts = label.split('*');
      labelWidget = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: parts[0],
              style: TextStyle(
                color: labelColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const TextSpan(
              text: '*',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            if (parts.length > 1 && parts[1].isNotEmpty)
              TextSpan(
                text: parts[1],
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
          ],
        ),
      );
    } else {
      labelWidget = Text(
        label,
        style: TextStyle(
          color: labelColor,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: labelWidget,
    );
  }

  Widget _buildErrorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 13, color: Colors.redAccent),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? helperText,
    IconData? prefixIcon,
    IconData? suffixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    final primaryColor = AppColors.primary;
    final isDark = AppColors.isDarkMode.value;
    final inputBg = isDark ? const Color(0xFF102A54) : AppColors.modalInput;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? const Color(0xFF7A92B4) : const Color(0xFF6B7280);
    final iconColor = isDark ? AppColors.secondary : primaryColor;
    final hasError = errorText != null && errorText.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(label),
          if (helperText != null) ...[
            const SizedBox(height: 4),
            Text(helperText, style: TextStyle(color: hintColor, fontSize: 13)),
          ],
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasError ? Colors.redAccent : AppColors.inputBorder,
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              readOnly: readOnly,
              onTap: onTap,
              onChanged: (val) {
                if (_showValidationErrors) {
                  setState(() {});
                }
                if (onChanged != null) onChanged(val);
              },
              style: TextStyle(color: textColor, fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: hintColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: iconColor, size: 18) : null,
                suffixIcon: suffixIcon != null
                    ? Icon(suffixIcon, color: iconColor, size: 18)
                    : null,
              ),
            ),
          ),
          if (hasError) _buildErrorText(errorText),
        ],
      ),
    );
  }
}

class _ReferralTypeToggle extends StatefulWidget {
  final String referralType;
  final ValueChanged<String> onChanged;

  const _ReferralTypeToggle({
    required this.referralType,
    required this.onChanged,
  });

  @override
  State<_ReferralTypeToggle> createState() => _ReferralTypeToggleState();
}

class _ReferralTypeToggleState extends State<_ReferralTypeToggle> {
  bool _hoverInternal = false;
  bool _hoverExternal = false;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode.value;
    final goldColor = const Color(0xFFFDB913);
    final isInternal = widget.referralType == 'Internal';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF102A54) : AppColors.modalInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorder, width: 1.5),
      ),
      child: Row(
        children: [
          // Same Chapter (Internal)
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hoverInternal = true),
              onExit: (_) => setState(() => _hoverInternal = false),
              child: GestureDetector(
                onTap: () => widget.onChanged('Internal'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: isInternal
                        ? (isDark ? const Color(0xFF1E4A7C) : AppColors.primary)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.group,
                        size: 16,
                        color: isInternal
                            ? Colors.white
                            : (_hoverInternal
                                ? goldColor
                                : (isDark ? goldColor : AppColors.onModalMuted)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Same Chapter',
                        style: TextStyle(
                          color: isInternal
                              ? Colors.white
                              : (_hoverInternal
                                  ? goldColor
                                  : (isDark ? goldColor : AppColors.onModalMuted)),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Other Chapter (External)
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hoverExternal = true),
              onExit: (_) => setState(() => _hoverExternal = false),
              child: GestureDetector(
                onTap: () => widget.onChanged('External'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: !isInternal
                        ? (isDark ? const Color(0xFF1E4A7C) : AppColors.primary)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.language,
                        size: 16,
                        color: !isInternal
                            ? Colors.white
                            : (_hoverExternal
                                ? goldColor
                                : (isDark ? goldColor : AppColors.onModalMuted)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Other Chapter',
                        style: TextStyle(
                          color: !isInternal
                              ? Colors.white
                              : (_hoverExternal
                                  ? goldColor
                                  : (isDark ? goldColor : AppColors.onModalMuted)),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

