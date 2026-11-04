import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright/copyright_dialogs.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Summary card displaying copyright standing, active strike meter, and channel health.
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
    final hasClaims = totalClaims > 0;
    final statusColor = hasClaims ? AppColors.error : AppColors.success;
    final strikesCount = hasClaims ? (totalClaims > 3 ? 3 : totalClaims) : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section: Channel Standing Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasClaims ? Icons.copyright : Icons.check_circle_outline,
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              hasClaims
                                  ? '$totalClaims Copyright claims'
                                  : 'No copyright strikes',
                              style: TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? AppColors.textPrimary
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: hasClaims
                                  ? AppColors.errorContainer
                                  : AppColors.successContainer,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasClaims
                                      ? Icons.warning_amber_rounded
                                      : Icons.shield_rounded,
                                  size: 13,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasClaims ? 'Action Required' : 'Good Standing',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasClaims
                            ? 'Review details to see how these affect your channel.'
                            : 'Your channel is in good standing.',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 13,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Divider(
              height: 1,
              color: isDarkMode ? AppColors.bgDivider : Colors.grey.shade200,
            ),
            const SizedBox(height: 16),

            // Middle Section: 3-Strike Visual Health Meter (YouTube Studio standard)
            Row(
              children: [
                Text(
                  'STRIKES: $strikesCount OF 3',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: isDarkMode
                        ? AppColors.textTertiary
                        : Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => CopyrightDialogs.showCopyrightEducation(
                    context: context,
                    isDarkMode: isDarkMode,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.help_outline_rounded,
                          size: 13,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'How strikes work',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : Colors.grey.shade700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStrikeSegment(index: 1, currentStrikes: strikesCount),
                const SizedBox(width: 8),
                _buildStrikeSegment(index: 2, currentStrikes: strikesCount),
                const SizedBox(width: 8),
                _buildStrikeSegment(index: 3, currentStrikes: strikesCount),
              ],
            ),
            const SizedBox(height: 12),

            // Policy note footer
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: isDarkMode
                      ? AppColors.textTertiary
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Content ID claims do not count as copyright strikes. Strikes expire after 90 days if received.',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black54,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrikeSegment({
    required int index,
    required int currentStrikes,
  }) {
    final isTriggered = currentStrikes >= index;
    final Color color;
    if (isTriggered) {
      color = index == 1
          ? AppColors.warning
          : (index == 2 ? const Color(0xFFF97316) : AppColors.error);
    } else {
      color = isDarkMode ? AppColors.bgSurfaceHigh : Colors.grey.shade300;
    }

    return Expanded(
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
