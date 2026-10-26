import 'package:flutter/material.dart';
import '../services/visitor_service.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_overlay.dart';

class VisitorsScreen extends StatefulWidget {
  const VisitorsScreen({super.key});

  @override
  State<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends State<VisitorsScreen> {
  List<Map<String, dynamic>>? _visitors;
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      final visitors = await VisitorService.getVisitors();
      if (mounted) {
        setState(() {
          _visitors = visitors;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading visitors: $e')));
        setState(() {
          _visitors = [];
        });
      }
    }
  }

  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Visitor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Visitor Name', labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mobileController,
                decoration: const InputDecoration(hintText: 'Mobile Number', labelText: 'Mobile'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(hintText: 'Email Address', labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _companyController,
                decoration: const InputDecoration(hintText: 'Company Name', labelText: 'Company'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitInvite,
            child: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Invite'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitInvite() async {
    if (_nameController.text.isEmpty || _mobileController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await VisitorService.inviteVisitor(
        visitorName: _nameController.text,
        visitorMobile: _mobileController.text,
        visitorEmail: _emailController.text,
        visitorCompany: _companyController.text,
      );

      if (!mounted) return;
      _nameController.clear();
      _mobileController.clear();
      _emailController.clear();
      _companyController.clear();

      Navigator.pop(context);
      _loadData();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visitor invited successfully!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = AppColors.secondary;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Visitors Invited', style: TextStyle(color: goldColor, fontSize: 20, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _showInviteDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Invite'),
                  style: ElevatedButton.styleFrom(backgroundColor: goldColor),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_visitors == null)
              const SkeletonLoader()
            else if (_visitors!.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add_alt_1, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No visitors invited yet',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the Invite button to invite your first visitor',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _visitors!.length,
                itemBuilder: (context, index) => _buildVisitorCard(_visitors![index], goldColor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitorCard(Map<String, dynamic> visitor, Color goldColor) {
    final name = visitor['visitor_name'] ?? visitor['name'] ?? 'Unknown';
    final mobile = visitor['visitor_mobile'] ?? visitor['mobile'] ?? 'N/A';
    final email = visitor['visitor_email'] ?? visitor['email'] ?? 'N/A';
    final company = visitor['visitor_company'] ?? visitor['company'] ?? '';
    final inviteDate = visitor['invite_date'] ?? visitor['created_at'] ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.primaryLight.withAlpha(89), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: goldColor,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (company.isNotEmpty)
                      Text(
                        company,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(mobile, style: const TextStyle(color: Colors.white70, fontSize: 12))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.email, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(email, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(inviteDate, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    super.dispose();
  }
}
