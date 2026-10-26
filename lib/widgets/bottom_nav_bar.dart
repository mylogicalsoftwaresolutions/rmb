import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int index) onTapTab;
  final VoidCallback onOpenSubmitModal;
  final bool isAdmin;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTapTab,
    required this.onOpenSubmitModal,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final goldColor = AppColors.navAccent;
    final navBgColor = AppColors.sidebar;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: goldColor, width: 2),
        ),
      ),
      // A Material of its own so the ink splash lands on the blue bar rather
      // than on whatever surface sits behind it.
      child: Material(
        color: navBgColor,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Filled glyph, matching the notification bell's weight.
                _buildNavItem(0, Icons.home, 'Home'),
                _buildNavItem(
                  1,
                  isAdmin
                      ? Icons.assignment_turned_in_outlined
                      : Icons.bar_chart,
                  isAdmin ? 'Approvals' : 'Stats',
                ),
                _buildSubmitButton(goldColor),
                _buildNavItem(
                  3,
                  isAdmin ? Icons.people_outline : Icons.people,
                  isAdmin ? 'Members' : 'Directory',
                ),
                _buildNavItem(
                  4,
                  isAdmin ? Icons.settings_outlined : Icons.person,
                  isAdmin ? 'More' : 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Gold circle with the plus, matching the other tabs' splash treatment.
  Widget _buildSubmitButton(Color goldColor) {
    return InkResponse(
      onTap: onOpenSubmitModal,
      radius: 34,
      splashColor: goldColor.withValues(alpha: 0.35),
      highlightColor: goldColor.withValues(alpha: 0.18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: goldColor,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 2),
          Text(
            'Submit',
            style: TextStyle(
              color: goldColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final goldColor = AppColors.navAccent;
    final isSelected = currentIndex == index;

    // Every tab is gold; the inactive ones just sit back a little so the
    // selected tab still reads as selected.
    final Color contentColor =
        isSelected ? goldColor : goldColor.withValues(alpha: 0.72);

    return InkWell(
      onTap: () => onTapTab(index),
      borderRadius: BorderRadius.circular(12),
      splashColor: goldColor.withValues(alpha: 0.30),
      highlightColor: goldColor.withValues(alpha: 0.15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: isSelected
            ? BoxDecoration(
                // Soft gold wash behind the active tab.
                color: goldColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: goldColor, width: 1.2),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: contentColor, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: contentColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
