import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Informational card with policy notice regarding plan upgrades and billing cycles.
class PlanNoticeCard extends StatelessWidget {
  const PlanNoticeCard({required this.isDesktop, super.key});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isDesktop ? 8 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4C1D95).withOpacity(0.4),
              border: Border.all(color: const Color(0xFF7C3AED)),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 13,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Note: You can upgrade or switch between Standard and Pro plans anytime from Settings. All plan upgrades and tier changes take effect on your next monthly billing date (next month).',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
