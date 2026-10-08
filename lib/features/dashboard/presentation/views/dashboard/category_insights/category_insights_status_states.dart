import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Loading view for category insights with structured Shimmer skeleton.
class CategoryInsightsLoadingView extends StatelessWidget {
  const CategoryInsightsLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E1E1E),
      highlightColor: AppColors.bgSurfaceHover,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Overview Banner Skeleton
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.bgDivider),
              ),
            ),
            const SizedBox(height: 24),
            // Metrics Cards Row
            Row(
              children: List.generate(
                3,
                (index) => Expanded(
                  child: Container(
                    height: 90,
                    margin: EdgeInsets.only(
                      right: index < 2 ? 14 : 0,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.bgDivider),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Insights Detail Cards Skeletons
            ...List.generate(
              3,
              (index) => Container(
                height: 140,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bgDivider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error view with retry action for category insights.
class CategoryInsightsErrorView extends StatelessWidget {
  const CategoryInsightsErrorView({
    required this.errorMessage,
    required this.onRetry,
    super.key,
  });

  final String errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            errorMessage,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: TWTypography.brandFamily,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textPrimary,
              size: 18,
            ),
            label: const Text(
              'Retry',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: TWTypography.uiFamily,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.bgSurfaceHover,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.bgDivider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state when no categories match the active filter or query.
class CategoryInsightsEmptyView extends StatelessWidget {
  const CategoryInsightsEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF1E1E1E),
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.bgDivider),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 32,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(height: 14),
            Text(
              'No categories match your current filter/search.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: TWTypography.brandFamily,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Try adjusting your search query or selecting another filter.',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
                fontFamily: TWTypography.uiFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
