import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.icon,
    required this.featureName,
    required this.isDarkMode,
    super.key,
  });
  final IconData icon;
  final String featureName;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceHover,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.bgDivider,
              ),
            ),
            child: Icon(
              icon,
              size: 48,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '$featureName Coming Soon',
            style: const TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This feature is currently under active development.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
