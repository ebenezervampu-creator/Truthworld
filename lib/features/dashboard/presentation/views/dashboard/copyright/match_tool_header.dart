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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Row(
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automated Content Match Engine',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Scans Truthworld for re-uploaded videos matching your original content. Take direct action to request removal or contact uploaders.',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
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
    );
  }
}
