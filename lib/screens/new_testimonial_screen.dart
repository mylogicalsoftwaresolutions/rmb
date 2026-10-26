import 'package:flutter/material.dart';
import '../models/member.dart';
import '../models/activity_model.dart';
import '../theme/app_colors.dart';

class NewTestimonialScreen extends StatefulWidget {
  final List<Member> members;
  final ActivityModel? existingActivity;
  const NewTestimonialScreen({super.key, required this.members, this.existingActivity});

  @override
  State<NewTestimonialScreen> createState() => _NewTestimonialScreenState();
}

class _NewTestimonialScreenState extends State<NewTestimonialScreen> {
  @override
  void initState() {
    super.initState();
    // Pre-fill logic can be added here when the form is completed.
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
                  const Text('Submit Testimonial', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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

}
