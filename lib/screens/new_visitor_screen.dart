import 'package:flutter/material.dart';
import '../models/activity_model.dart';
import '../services/activity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';

class NewVisitorScreen extends StatefulWidget {
  final ActivityModel? existingActivity;
  const NewVisitorScreen({super.key, this.existingActivity});

  @override
  State<NewVisitorScreen> createState() => _NewVisitorScreenState();
}

class _NewVisitorScreenState extends State<NewVisitorScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.existingActivity != null) {
      final act = widget.existingActivity!;
      _dateController.text = act.date;
      // You can add more prefill logic based on act.rawJson here.
    }
  }

  bool _isSubmitting = false;
  final TextEditingController _visitorNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _dateController = TextEditingController(
    text: "${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().year}",
  );
  
  String? _selectedCategory;
  String? _selectedMeeting;
  final List<String> _categories = ['IT Services', 'Marketing', 'Consulting', 'Real Estate', 'Other'];
  final List<String> _meetings = ['Next Chapter Meeting', 'Special Event', 'Open Day'];
  
  String? _proofImageName;

  @override
  void dispose() {
    _visitorNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _cityController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: AppUI.datePickerTheme,
    );
    if (picked != null && mounted) {
      setState(() {
        _dateController.text = "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
      });
    }
  }

  Future<void> _pickFile() async {
    // Placeholder
  }

  bool _showValidationErrors = false;

  Future<void> _submitVisitor() async {
    if (_isSubmitting) return;
    final nameMissing = _visitorNameController.text.trim().isEmpty;
    final mobileMissing = _mobileController.text.trim().isEmpty;
    final dateMissing = _dateController.text.trim().isEmpty;
    if (nameMissing || mobileMissing || dateMissing) {
      setState(() => _showValidationErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all mandatory fields.'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    setState(() => _showValidationErrors = false);
    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      final Map<String, String> body = {
        'action': widget.existingActivity != null ? 'update' : 'create',
        if (widget.existingActivity != null) 'id': widget.existingActivity!.id.toString(),
        'user_id': userId ?? '',
        'visitor_name': _visitorNameController.text,
        'phone': _mobileController.text,
        'date': _dateController.text,
        'mobile': _mobileController.text,
        'email': _emailController.text,
        'company': _companyController.text,
        'category': _selectedCategory ?? '',
        'city': _cityController.text,
        'meeting': _selectedMeeting ?? '',
        'visit_date': _dateController.text,
      };
      
      await ActivityService.createVisitor(body);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visitor invited!'), backgroundColor: Color(0xFF20C997)));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showDialog(context: context, builder: (ctx) => AlertDialog(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = AppColors.secondary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 800,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Invite a Visitor', style: TextStyle(color: goldColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
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
                        color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Invite a Visitor', style: TextStyle(color: goldColor, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  'Visitor Name *',
                                  _visitorNameController,
                                  errorText: (_showValidationErrors && _visitorNameController.text.trim().isEmpty)
                                      ? 'Please enter visitor name'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  'Mobile *',
                                  _mobileController,
                                  keyboardType: TextInputType.phone,
                                  errorText: (_showValidationErrors && _mobileController.text.trim().isEmpty)
                                      ? 'Please enter mobile number'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildTextField('Email', _emailController, keyboardType: TextInputType.emailAddress)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField('Company', _companyController)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildDropdown('Business Category', _selectedCategory, _categories, (val) => setState(() => _selectedCategory = val))),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField('City', _cityController)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildDropdown('Meeting (optional)', _selectedMeeting, _meetings, (val) => setState(() => _selectedMeeting = val))),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  'Visit Date *',
                                  _dateController,
                                  readOnly: true,
                                  suffixIcon: Icons.calendar_today,
                                  onTap: () => _selectDate(context),
                                  errorText: (_showValidationErrors && _dateController.text.trim().isEmpty)
                                      ? 'Please select visit date'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text('Proof Image', style: TextStyle(color: goldColor, fontSize: 11)),
                          const SizedBox(height: 8),
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.bg),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: _pickFile,
                                  child: Container(
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: AppColors.border,
                                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                                    ),
                                    child: const Text('Choose File', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(_proofImageName ?? 'No file chosen', style: TextStyle(color: _proofImageName == null ? Colors.white30 : Colors.white, fontSize: 11), overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text("Optional: photo of visitor's card or check-in (JPG, PNG, WEBP, GIF up to 5MB).", style: TextStyle(color: Colors.white54, fontSize: 10)),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: goldColor,
                                  foregroundColor: AppColors.bg,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                onPressed: _isSubmitting ? null : _submitVisitor,
                                icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send, size: 16),
                                label: const Text('Submit Invite', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
    final goldColor = AppColors.secondary;
    if (label.contains('*')) {
      final parts = label.split('*');
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: parts[0],
              style: TextStyle(color: goldColor, fontSize: 11),
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
                style: TextStyle(color: goldColor, fontSize: 11),
              ),
          ],
        ),
      );
    }
    return Text(label, style: TextStyle(color: goldColor, fontSize: 11));
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
    String? hint,
    TextInputType? keyboardType,
    VoidCallback? onTap,
    String? errorText,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        const SizedBox(height: 8),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasError ? Colors.redAccent : AppColors.bg,
              width: hasError ? 1.5 : 1.0,
            ),
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
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Colors.white54, size: 16) : null,
            ),
          ),
        ),
        if (hasError) _buildErrorText(errorText),
      ],
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.secondary, fontSize: 11)),
        const SizedBox(height: 8),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.bg),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: const Text('-- Select category --', style: TextStyle(color: Colors.white30, fontSize: 11)),
              dropdownColor: AppColors.bg,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 12)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
