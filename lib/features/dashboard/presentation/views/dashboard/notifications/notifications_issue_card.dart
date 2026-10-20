import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Specialized issue notification card with status-specific badge accents.
class ChannelNotificationsIssueCard extends StatelessWidget {
  const ChannelNotificationsIssueCard({
    required this.title,
    required this.description,
    required this.statusType,
    required this.icon,
    this.isLoading = false,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String description;
  final String statusType;
  final IconData icon;
  final bool isLoading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    Color badgeBg;
    Color borderColor;

    if (statusType == 'PENDING') {
      badgeBg = AppColors.infoContainer;
      borderColor = AppColors.info.withValues(alpha: 0.4);
    } else if (statusType == 'APPROVED') {
      badgeBg = AppColors.successContainer;
      borderColor = AppColors.success.withValues(alpha: 0.4);
    } else if (statusType == 'FLAGGED') {
      badgeBg = AppColors.warningContainer;
      borderColor = AppColors.warning.withValues(alpha: 0.4);
    } else if (statusType == 'MANUAL_REVIEW') {
      badgeBg = AppColors.infoContainer;
      borderColor = AppColors.info.withValues(alpha: 0.4);
    } else {
      // REJECTED
      badgeBg = AppColors.errorContainer;
      borderColor = AppColors.error.withValues(alpha: 0.4);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
