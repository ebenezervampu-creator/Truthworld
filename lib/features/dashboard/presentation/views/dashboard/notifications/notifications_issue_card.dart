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
    Color iconColor;
    String statusLabel;

    if (statusType == 'PENDING') {
      iconColor = AppColors.textSecondary;
      statusLabel = 'IN PROGRESS';
    } else if (statusType == 'APPROVED') {
      iconColor = AppColors.success;
      statusLabel = 'VERIFIED';
    } else if (statusType == 'FLAGGED') {
      iconColor = AppColors.warning;
      statusLabel = 'NEEDS REVIEW';
    } else if (statusType == 'MANUAL_REVIEW') {
      iconColor = AppColors.textSecondary;
      statusLabel = 'IN REVIEW';
    } else {
      // REJECTED
      iconColor = AppColors.error;
      statusLabel = 'ACTION REQUIRED';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.textSecondary),
                        ),
                      )
                    : Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontFamilyFallback: TWTypography.fallbackFamilies,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: iconColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontFamilyFallback:
                                  TWTypography.fallbackFamilies,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.45,
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
