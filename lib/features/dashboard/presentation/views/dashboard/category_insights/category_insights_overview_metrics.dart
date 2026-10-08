import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/category_insights_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/category_insights/category_insights_metric_card.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Responsive 4-card overview metrics row for category insights.
class CategoryInsightsOverviewMetrics extends StatelessWidget {
  const CategoryInsightsOverviewMetrics({required this.controller, super.key});
  final CategoryInsightsController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final card1 = CategoryInsightsMetricCard(
          title: 'Tracked Categories',
          value: '${controller.totalTrackedCategories.value}',
          subtitle: 'Active in system',
          icon: Icons.category_rounded,
          accentBadgeBg: AppColors.bgPage,
          accentBadgeBorder: AppColors.bgDivider,
        );
        final card2 = CategoryInsightsMetricCard(
          title: 'Untouched Niches',
          value: '${controller.untouchedCategoryCount.value}',
          subtitle: '0 channels operating',
          icon: Icons.explore_off_rounded,
          accentBadgeBg: AppColors.infoContainer,
          accentBadgeBorder: AppColors.info.withValues(alpha: 0.4),
        );
        final card3 = CategoryInsightsMetricCard(
          title: 'Top User Liked',
          value: controller.topLikedCategoryName.value,
          subtitle: 'Highest user likes',
          icon: Icons.thumb_up_alt_rounded,
          accentBadgeBg: AppColors.successContainer,
          accentBadgeBorder: AppColors.success.withValues(alpha: 0.4),
        );
        final card4 = CategoryInsightsMetricCard(
          title: 'Fastest Growing',
          value: controller.fastestGrowingCategoryName.value,
          subtitle: 'Peak growth momentum',
          icon: Icons.trending_up_rounded,
          accentBadgeBg: AppColors.warningContainer,
          accentBadgeBorder: AppColors.warning.withValues(alpha: 0.4),
        );

        final isWide = constraints.maxWidth > 800;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card1),
              const SizedBox(width: 16),
              Expanded(child: card2),
              const SizedBox(width: 16),
              Expanded(child: card3),
              const SizedBox(width: 16),
              Expanded(child: card4),
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: card1),
                const SizedBox(width: 16),
                Expanded(child: card2),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: card3),
                const SizedBox(width: 16),
                Expanded(child: card4),
              ],
            ),
          ],
        );
      },
    );
  }
}
