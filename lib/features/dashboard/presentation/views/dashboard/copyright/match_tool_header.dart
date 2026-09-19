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
      padding: const EdgeInsets.all(20),
      color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF3B82F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.screen_search_desktop_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automated Content Match Engine',
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontSize: 18,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scans Truthworld for re-uploaded videos matching your original content. Take direct action to request removal or contact uploaders.',
                  style: TextStyle(
                    fontSize: 13,
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
