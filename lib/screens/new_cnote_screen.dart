import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../models/member.dart';
import '../models/activity_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';

class NewCNoteScreen extends StatefulWidget {
  final List<Member> members;
  final ActivityModel? existingActivity;
  const NewCNoteScreen({super.key, required this.members, this.existingActivity});

  @override
  State<NewCNoteScreen> createState() => _NewCNoteScreenState();
}

class _NewCNoteScreenState extends State<NewCNoteScreen> {
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

  final _dateController = TextEditingController(
    text: "${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().year}",
  );
  
  String? _selectedMember;
  final _amountController = TextEditingController();
  final _companyController = TextEditingController();
  final _categoryController = TextEditingController();
  final _commentsController = TextEditingController();

  @override
  void dispose() {
    _dateController.dispose();
    _amountController.dispose();
    _companyController.dispose();
    _categoryController.dispose();
    _commentsController.dispose();
    super.dispose();
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

  Future<void> _submitCNote() async {
    if (_isSubmitting) return;
    final memberMissing = _selectedMember == null || _selectedMember!.isEmpty;
    final amountMissing = _amountController.text.trim().isEmpty;
    final dateMissing = _dateController.text.trim().isEmpty;
    if (memberMissing || amountMissing || dateMissing) {
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

      final body = {
        'user_id': userId ?? '',
        'action': widget.existingActivity != null ? 'update' : 'create',
        if (widget.existingActivity != null) 'id': widget.existingActivity!.id.toString(),
        'received_by': _selectedMember ?? '',
        'to_member_id': _selectedMember ?? '',
        'receiver_id': _selectedMember ?? '',
        'amount': _amountController.text,
        'company': _companyController.text,
        'company_name': _companyController.text,
        'business_name': _companyController.text,
        'companyName': _companyController.text,
        'client_company': _companyController.text,
        'business_category': _categoryController.text,
        'category': _categoryController.text,
        'date': _dateController.text,
        'type': 'Internal', // Defaulted to internal since type isn't selectable here
        'comments': _commentsController.text,
      };

      await ActivityService.createCNote(body);
      
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
          const SnackBar(content: Text('Failed to submit C-Note. Please try again.'), backgroundColor: Colors.redAccent),
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
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 5,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor,
                border: Border(bottom: BorderSide(color: AppColors.primaryLight)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Submit C-Note', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                  Text('New C-Note', style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildMemberDropdown(
                          'Received By (Member) *',
                          _selectedMember,
                          widget.members,
                          (val) {
                            setState(() {
                              _selectedMember = val;
                              if (val != null) {
                                for (final m in widget.members) {
                                  if (m.id.toString() == val) {
                                    _companyController.text = m.company;
                                    break;
                                  }
                                }
                              }
                            });
                          },
                          errorText: (_showValidationErrors && (_selectedMember == null || _selectedMember!.isEmpty))
                              ? 'Please select member'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          'Amount (₹) *',
                          _amountController,
                          keyboardType: TextInputType.number,
                          errorText: (_showValidationErrors && _amountController.text.trim().isEmpty)
                              ? 'Please enter amount'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Company', _companyController)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Business Category', _categoryController)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    'Date *',
                    _dateController,
                    readOnly: true,
                    suffixIcon: Icons.calendar_today,
                    onTap: () => _selectDate(context),
                    errorText: (_showValidationErrors && _dateController.text.trim().isEmpty)
                        ? 'Please select date'
                        : null,
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
                        onPressed: _isSubmitting ? null : _submitCNote,
                        icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Icon(Icons.send, size: 16),
                        label: const Text('Submit C-Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
    TextInputType? keyboardType,
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
            keyboardType: keyboardType,
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
              items: items.map((e) => DropdownMenuItem(value: e.id.toString(), child: Text(e.name.trim(), style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500)))).toList(),
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
