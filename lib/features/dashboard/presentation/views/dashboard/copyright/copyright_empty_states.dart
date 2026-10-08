import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Placeholder displayed when a channel has zero copyright strikes or claims.
class CopyrightEmptyState extends StatelessWidget {
  const CopyrightEmptyState({
    required this.isDarkMode,
    super.key,
  });

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: AppColors.success,
            ),
            SizedBox(height: 16),
            Text(
              'Channel content is claim-free',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Keep up the great work creating original content!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder displayed when copyright data cannot be retrieved.
class CopyrightErrorState extends StatelessWidget {
  const CopyrightErrorState({
    required this.onRetry,
    required this.isDarkMode,
    super.key,
  });

  final VoidCallback onRetry;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load copyright data',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unable to retrieve copyright details. Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder displayed when no unauthorized re-uploads are found.
class MatchToolEmptyState extends StatelessWidget {
  const MatchToolEmptyState({
    required this.isDarkMode,
    super.key,
  });

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user_rounded,
              size: 64,
              color: AppColors.success,
            ),
            SizedBox(height: 16),
            Text(
              'No unauthorized re-uploads detected',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Truthworld continuously scans new video uploads for copyright matches.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
