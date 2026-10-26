import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/activity_service.dart';
import '../services/notification_service.dart';
import '../models/member.dart';
import '../models/activity_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';


class NewR2RScreen extends StatefulWidget {
  final List<Member> members;
  final ActivityModel? existingActivity;
  const NewR2RScreen({super.key, required this.members, this.existingActivity});

  @override
  State<NewR2RScreen> createState() => _NewR2RScreenState();
}

class _NewR2RScreenState extends State<NewR2RScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.existingActivity != null) {
      final act = widget.existingActivity!;
      _dateController.text = act.date;
      _locationController.text = (act.rawJson['location'] ??
              act.rawJson['meeting_location'] ??
              act.rawJson['venue'] ??
              act.rawJson['place'] ??
              act.rawJson['meeting_place'] ??
              act.rawJson['location_name'] ??
              '')
          .toString();
      _descriptionController.text = act.description;
      final mId = (act.rawJson['member_id'] ??
              act.rawJson['partner_id'] ??
              act.rawJson['met_with'] ??
              act.rawJson['to_user_id'] ??
              act.rawJson['to_member_id'] ??
              '')
          .toString();
      if (mId.isNotEmpty) {
        _selectedMember = mId;
      }
    }
  }

  bool _isSubmitting = false;

  final _dateController = TextEditingController(
    text: "${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().year}",
  );
  
  String? _selectedMember;
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;

  @override
  void dispose() {
    _dateController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

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
            _selectedFileName = picked.name;
            _selectedFileBytes = bytes;
          });
          return;
        }
      } catch (e) {
        debugPrint('ImagePicker error: $e');
      }
    }

    if (source == null) {
      try {
        final files = await FilePicker.pickFiles(type: FileType.image);
        if (!mounted || files.isEmpty) return;
        final file = files.first;
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedFileName = file.name;
          _selectedFileBytes = bytes;
        });
      } catch (e) {
        debugPrint('FilePicker error: $e');
      }
    }
  }

  List<http.MultipartFile> _buildProofFiles() {
    if (_selectedFileBytes == null || _selectedFileName == null) return const [];
    final name = _selectedFileName!;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpeg';
    final mimeSubtype = (ext == 'png' || ext == 'webp' || ext == 'gif') ? ext : 'jpeg';
    final mediaType = MediaType('image', mimeSubtype);

    return [
      http.MultipartFile.fromBytes(
        'image',
        _selectedFileBytes!,
        filename: name,
        contentType: mediaType,
      ),
    ];
  }

  bool _showValidationErrors = false;

  Future<void> _submitR2R() async {
    if (_isSubmitting) return;
    final memberMissing = _selectedMember == null || _selectedMember!.isEmpty;
    final dateMissing = _dateController.text.trim().isEmpty;
    if (memberMissing || dateMissing) {
      setState(() => _showValidationErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all mandatory fields.'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    setState(() => _showValidationErrors = false);
    setState(() => _isSubmitting = true);
    final memberId = _selectedMember ?? '';
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final desc = _descriptionController.text.trim();
      final body = {
        'user_id': userId ?? '',
        'action': widget.existingActivity != null ? 'update' : 'add',
        if (widget.existingActivity != null) 'id': widget.existingActivity!.id.toString(),
        'member_id': memberId,
        'partner_id': memberId,
        'met_with': memberId,
        'to_user_id': memberId,
        'to_member_id': memberId,
        'date': _dateController.text,
        'meeting_date': _dateController.text,
        // Different deployed r2r.php versions use different venue keys.
        // Send all supported aliases so the saved row can show its location.
        'location': _locationController.text,
        'meeting_location': _locationController.text,
        'venue': _locationController.text,
        'place': _locationController.text,
        'topics_discussed': desc,
        'topic': desc,
        'description': desc,
        'notes': desc,
        'comments': desc,
        'type': 'Internal',
        if (_selectedFileName != null) ...{
          'image': _selectedFileName!,
          'proof_image': _selectedFileName!,
          'proof': _selectedFileName!,
        } else if (widget.existingActivity != null) ...{
          if ((widget.existingActivity!.rawJson['image'] ?? '').toString().trim().isNotEmpty &&
              widget.existingActivity!.rawJson['image'].toString() != 'null')
            'image': widget.existingActivity!.rawJson['image'].toString().trim(),
          if ((widget.existingActivity!.rawJson['proof_image'] ?? '').toString().trim().isNotEmpty &&
              widget.existingActivity!.rawJson['proof_image'].toString() != 'null')
            'proof_image': widget.existingActivity!.rawJson['proof_image'].toString().trim(),
          if ((widget.existingActivity!.rawJson['image_url'] ?? '').toString().trim().isNotEmpty &&
              widget.existingActivity!.rawJson['image_url'].toString() != 'null')
            'image_url': widget.existingActivity!.rawJson['image_url'].toString().trim(),
          if ((widget.existingActivity!.rawJson['proof'] ?? '').toString().trim().isNotEmpty &&
              widget.existingActivity!.rawJson['proof'].toString() != 'null')
            'proof': widget.existingActivity!.rawJson['proof'].toString().trim(),
        },
      };

      await ActivityService.createR2R(body, files: _buildProofFiles());
      
      // Proactively refresh notification list
      NotificationService.getNotifications().ignore();
      
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
                Text('Success', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: const Text('Submitted successfully!', style: TextStyle(color: Colors.white70)),
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
          const SnackBar(content: Text('Failed to log R2R Meeting. Please try again.'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
                  const Text('Submit R2R', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Log R2R Meeting', style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  
                  _buildMemberDropdown(
                    'RMB Member *',
                    _selectedMember,
                    widget.members,
                    (val) => setState(() => _selectedMember = val),
                    errorText: (_showValidationErrors && (_selectedMember == null || _selectedMember!.isEmpty))
                        ? 'Please select partner member'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    'Meeting Date *',
                    _dateController,
                    readOnly: true,
                    suffixIcon: Icons.calendar_today,
                    onTap: () => _selectDate(context),
                    errorText: (_showValidationErrors && _dateController.text.trim().isEmpty)
                        ? 'Please select meeting date'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    'Location',
                    _locationController,
                    prefixIcon: Icons.location_on_outlined,
                    hint: 'e.g. Starbucks, Office, Hotel Lobby, etc.',
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
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        )
                      ],
                    ),
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.black87, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'What did you discuss?',
                        hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.4), fontSize: 11),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Text('Attach Proof (Optional)', style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primaryColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              )
            ],
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _pickFile,
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
                            ),
                            child: const Text('Choose file', style: TextStyle(color: Colors.black87, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Text(
                              _selectedFileName ?? 'No file chosen',
                              style: const TextStyle(color: Colors.black87, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedFileBytes != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Image.memory(
                            _selectedFileBytes!,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _selectedFileBytes = null;
                                _selectedFileName = null;
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
                  const SizedBox(height: 4),
                  const Text('Upload a photo/selfie together as proof (Optional).', style: TextStyle(color: Colors.white54, fontSize: 10)),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _isSubmitting ? null : _submitR2R,
                        icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send, size: 16),
                        label: const Text('Submit Meeting', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white30),
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
    IconData? prefixIcon,
    IconData? suffixIcon,
    String? hint,
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
              color: hasError ? Colors.redAccent : primaryColor.withValues(alpha: 0.2),
              width: hasError ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            onChanged: (val) {
              if (_showValidationErrors) {
                setState(() {});
              }
            },
            style: const TextStyle(color: Colors.black87, fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.4), fontSize: 11),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: primaryColor.withValues(alpha: 0.6), size: 16) : null,
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
              width: hasError ? 1.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: const Text('-- Select member --', style: TextStyle(color: Colors.black38, fontSize: 11)),
              dropdownColor: Colors.white,
              icon: Icon(Icons.arrow_drop_down, color: primaryColor),
              items: items.map((e) => DropdownMenuItem(value: e.id.toString(), child: Text(e.name.trim(), style: const TextStyle(color: Colors.black87, fontSize: 12)))).toList(),
              onChanged: (val) {
                onChanged(val);
                if (_showValidationErrors) {
                  setState(() {});
                }
              },
            ),
          ),
        ),
        if (hasError) _buildErrorText(errorText),
      ],
    );
  }
}
