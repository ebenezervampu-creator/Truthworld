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

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              totalClaims > 0 ? Icons.copyright : Icons.check_circle_outline,
              color: statusColor,
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
                  style: const TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalClaims > 0
                      ? 'Review details to see how these affect your channel.'
                      : 'Your channel is in good standing.',
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 13,
                    color: AppColors.textSecondary,
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
