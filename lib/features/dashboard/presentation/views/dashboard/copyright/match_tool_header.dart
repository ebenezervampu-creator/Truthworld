import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Informational header banner explaining the Automated Content Match Engine.
class MatchToolHeader extends StatelessWidget {
  const MatchToolHeader({
    required this.isDarkMode,
    super.key,
  });

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? AppColors.bgSurface : Colors.white;
    final primaryTextColor = isDarkMode ? AppColors.textPrimary : Colors.black87;
    final secondaryTextColor =
        isDarkMode ? AppColors.textSecondary : Colors.black54;
    final borderColor =
        isDarkMode ? AppColors.bgDivider : Colors.grey.shade300;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.infoContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.screen_search_desktop_rounded,
                  color: AppColors.info,
                  size: 24,
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
                            'Automated Content Match Engine',
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Scans Truthworld for re-uploaded videos matching your original content. Take direct action to request removal or contact uploaders.',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 13,
                        color: secondaryTextColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
