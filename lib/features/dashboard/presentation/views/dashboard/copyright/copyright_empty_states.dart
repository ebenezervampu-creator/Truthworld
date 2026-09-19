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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              'Channel content is claim-free',
              style: AppTextStyles.pageTitle.copyWith(
                fontSize: 18,
                color: isDarkMode ? AppColors.textPrimary : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep up the great work creating original content!',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 14,
                color: isDarkMode
                    ? AppColors.textSecondary
                    : Colors.black,
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
            Icon(
              Icons.error_outline,
              size: 48,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load copyright data',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDarkMode ? AppColors.textPrimary : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to retrieve copyright details. Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                color: isDarkMode
                    ? AppColors.textSecondary
                    : Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
              ),
              child: const Text('Try Again'),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_user_rounded,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              'No unauthorized re-uploads detected',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.textPrimary : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Truthworld continuously scans new video uploads for copyright matches.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode
                    ? AppColors.textSecondary
                    : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
