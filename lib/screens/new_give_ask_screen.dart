import 'package:flutter/material.dart';
import '../models/activity_model.dart';
import '../services/activity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_ui.dart';

class NewGiveAskScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final ActivityModel? existingActivity;

  const NewGiveAskScreen({super.key, this.initialData, this.existingActivity});

  @override
  State<NewGiveAskScreen> createState() => _NewGiveAskScreenState();
}

class _NewGiveAskScreenState extends State<NewGiveAskScreen> {
  bool _isSubmitting = false;
  late TextEditingController _dateController;
  late TextEditingController _giveController;
  late TextEditingController _askController;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _dateController = TextEditingController(
      text: data?['date'] ??
          "${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().year}",
    );
    _giveController = TextEditingController(text: data?['give'] ?? '');
    _askController = TextEditingController(text: data?['ask'] ?? '');
    if (widget.existingActivity != null) {
      final act = widget.existingActivity!;
      _dateController.text = act.date;
      // You can add more prefill logic based on act.rawJson here.
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _giveController.dispose();
    _askController.dispose();
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

  Future<void> _submitGiveAsk() async {
    final dateMissing = _dateController.text.trim().isEmpty;
    final bothEmpty = _giveController.text.trim().isEmpty && _askController.text.trim().isEmpty;
    if (dateMissing || bothEmpty) {
      setState(() => _showValidationErrors = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(dateMissing
              ? 'Please select date.'
              : 'Please enter at least one Give or Ask.'),
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
      final Map<String, String> body = {
        'action': widget.initialData == null ? 'create' : 'update',
        if (widget.initialData != null) 'id': widget.initialData!['id']?.toString() ?? '',
        if (userId != null) 'user_id': userId,
        'date': _dateController.text,
        'entry_date': _dateController.text,
        'give': _giveController.text,
        'ask': _askController.text,
        'what_i_give': _giveController.text,
        'what_i_ask': _askController.text,
        'gives': _giveController.text,
        'asks': _askController.text,
      };

      await ActivityService.createGiveAsk(body);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.initialData == null ? 'Give & Ask submitted successfully!' : 'Give & Ask updated successfully!'), 
            backgroundColor: const Color(0xFF20C997)
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('API Error', style: TextStyle(color: Colors.redAccent)),
            content: SingleChildScrollView(
              child: Text(e.toString()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
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
    final goldColor = AppColors.secondary;
    final isEdit = widget.initialData != null;

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
                  Text(isEdit ? 'Edit Give & Ask' : 'Submit Weekly Give & Ask', style: TextStyle(color: goldColor, fontSize: 16, fontWeight: FontWeight.bold)),
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
              // Top header row removed because it's now in the Dialog title
            const SizedBox(height: 24),
            
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
                  SizedBox(
                    width: 200,
                    child: _buildTextField(
                      'Date *',
                      _dateController,
                      readOnly: true,
                      suffixIcon: Icons.calendar_today,
                      onTap: () => _selectDate(context),
                      errorText: (_showValidationErrors && _dateController.text.trim().isEmpty)
                          ? 'Please select date'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  const Row(
                    children: [
                      Icon(Icons.volunteer_activism, color: Color(0xFF20C997), size: 16),
                      SizedBox(width: 8),
                      Text('Give', style: TextStyle(color: Color(0xFF20C997), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (_showValidationErrors && _giveController.text.trim().isEmpty && _askController.text.trim().isEmpty)
                            ? Colors.redAccent
                            : AppColors.bg,
                        width: (_showValidationErrors && _giveController.text.trim().isEmpty && _askController.text.trim().isEmpty)
                            ? 1.5
                            : 1.0,
                      ),
                    ),
                    child: TextField(
                      controller: _giveController,
                      maxLines: 4,
                      onChanged: (val) {
                        if (_showValidationErrors) setState(() {});
                      },
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  if (_showValidationErrors && _giveController.text.trim().isEmpty && _askController.text.trim().isEmpty)
                    _buildErrorText('Please enter at least one Give or Ask'),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Icon(Icons.handshake, color: goldColor, size: 16),
                      SizedBox(width: 8),
                      Text('Ask', style: TextStyle(color: goldColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (_showValidationErrors && _giveController.text.trim().isEmpty && _askController.text.trim().isEmpty)
                            ? Colors.redAccent
                            : AppColors.bg,
                        width: (_showValidationErrors && _giveController.text.trim().isEmpty && _askController.text.trim().isEmpty)
                            ? 1.5
                            : 1.0,
                      ),
                    ),
                    child: TextField(
                      controller: _askController,
                      maxLines: 4,
                      onChanged: (val) {
                        if (_showValidationErrors) setState(() {});
                      },
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  if (_showValidationErrors && _giveController.text.trim().isEmpty && _askController.text.trim().isEmpty)
                    _buildErrorText('Please enter at least one Give or Ask'),
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
                        onPressed: _isSubmitting ? null : _submitGiveAsk,
                        icon: _isSubmitting 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : const Icon(Icons.send, size: 16),
                        label: Text(isEdit ? 'Update Entry' : 'Submit Give & Ask', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
              if (_showValidationErrors) setState(() {});
            },
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
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
}
