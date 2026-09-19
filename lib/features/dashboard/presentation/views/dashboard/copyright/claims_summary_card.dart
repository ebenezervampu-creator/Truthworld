import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Summary card displaying the total number of copyright claims and channel standing.
class ClaimsSummaryCard extends StatelessWidget {
  const ClaimsSummaryCard({
    required this.totalClaims,
    required this.isDarkMode,
    super.key,
  });

  final int totalClaims;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final statusColor = totalClaims > 0 ? AppColors.error : AppColors.success;
    final iconColor = isDarkMode ? Colors.white : statusColor;

    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? AppColors.bgDivider : AppColors.textSecondary,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              totalClaims > 0 ? Icons.copyright : Icons.check_circle_outline,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  totalClaims > 0
                      ? '$totalClaims Copyright claims'
                      : 'No copyright strikes',
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontSize: 20,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalClaims > 0
                      ? 'Review details to see how these affect your channel.'
                      : 'Your channel is in good standing.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 14,
                    color: isDarkMode ? AppColors.textSecondary : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
