import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
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
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFF1E1E1E),
          highlightColor: AppColors.bgSurfaceHover,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 180,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
