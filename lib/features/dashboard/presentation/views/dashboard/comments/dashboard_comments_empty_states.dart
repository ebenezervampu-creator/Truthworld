import 'package:flutter/material.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Context-aware empty state for Dashboard Comments
/// Matches Consumer App's Library and Settings styling and typography.
class DashboardCommentsEmptyState extends StatelessWidget {
  const DashboardCommentsEmptyState({
    required this.isHeldTab,
    super.key,
  });

  final bool isHeldTab;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isHeldTab
                  ? Icons.rate_review_outlined
                  : Icons.chat_bubble_outline_rounded,
              size: 48,
              color: AppColors.textPrimary,
            ),
            const SizedBox(height: 12),
            Text(
              isHeldTab
                  ? 'No comments held for review'
                  : 'No comments found',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isHeldTab
                  ? 'Comments that need review will appear here.'
                  : 'Try adjusting your search query or filter chips.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading skeleton for comments pane
class DashboardCommentsLoadingSkeleton extends StatelessWidget {
  const DashboardCommentsLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: StudioLoadingIndicator(
          message: 'Loading comments...',
          isFullScreen: false,
        ),
      ),
    );
  }
}
