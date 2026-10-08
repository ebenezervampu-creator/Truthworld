import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/category_insights_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Callout banner alerting creators about untouched high-potential categories.
class CategoryInsightsGapBanner extends StatelessWidget {
  const CategoryInsightsGapBanner({required this.controller, super.key});
  final CategoryInsightsController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.infoContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.info.withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.textPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'High Potential Opportunity Alert!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontFamily: TWTypography.brandFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'There are ${controller.untouchedCategoryCount.value} categories with ZERO channels. Creating content in these untouched categories gives your channel a first-mover advantage with zero competition.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                    fontFamily: TWTypography.uiFamily,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          TextButton.icon(
            onPressed: () {
              controller.activeFilter.value = CategoryInsightsFilter.untouched;
            },
            icon: const Icon(
              Icons.explore_off_rounded,
              size: 14,
              color: AppColors.textPrimary,
            ),
            label: const Text(
              'View Untouched',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: TWTypography.uiFamily,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.bgSurfaceHover,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
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
