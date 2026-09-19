import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics/creator_analytics_common_widgets.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Summary cards grid displaying high-level performance metrics.
class CreatorSummaryCardsGrid extends StatelessWidget {
  const CreatorSummaryCardsGrid({required this.controller, super.key});

  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final va = controller.videoAnalytics.value;
      final ca = controller.channelAnalytics.value;

      final totalV = (ca?.totalVideoWatches ?? 0) > 0
          ? ca!.totalVideoWatches
          : (controller.channelVideos.isNotEmpty
              ? controller.channelVideos.fold<int>(
                  0,
                  (sum, v) => sum + v.viewCount,
                )
              : 0);
      final views = va?.totalViews ?? totalV;
      final uniqueViewers =
          va?.totalUniqueViewers ??
          (ca?.totalUniqueViewers ?? (totalV > 0 ? totalV : 0));

      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          CreatorMetricCard(
            icon: Icons.visibility_rounded,
            title: 'Total Views',
            value: formatAnalyticsNumber(views),
            subtitle: '$uniqueViewers unique viewers',
          ),
          CreatorMetricCard(
            icon: Icons.schedule_rounded,
            title: 'Watch Time',
            value: controller.totalWatchTime.value,
            subtitle: 'Avg ${controller.averageWatchTime.value}',
          ),
          CreatorMetricCard(
            icon: Icons.trending_up_rounded,
            title: 'Engagement',
            value: '${controller.engagementScore.value.toStringAsFixed(1)}%',
            subtitle:
                '${controller.completionRate.value.toStringAsFixed(1)}% completion',
          ),
          CreatorMetricCard(
            icon: Icons.touch_app_rounded,
            title: 'CTR',
            value: '${controller.ctrValue.value.toStringAsFixed(1)}%',
            subtitle: 'Clicks ÷ Impressions',
          ),
          CreatorMetricCard(
            icon: Icons.people_alt_rounded,
            title: 'Returning',
            value: '${controller.returningViewerCount.value}',
            subtitle: 'Repeat viewers',
          ),
          CreatorMetricCard(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Sub Conv.',
            value:
                '${controller.subscriberConversionRate.value.toStringAsFixed(2)}%',
            subtitle: 'Views → Subscribers',
          ),
        ],
      );
    });
  }
}

/// Single metric tile card in the analytics grid.
class CreatorMetricCard extends StatelessWidget {
  const CreatorMetricCard({
    required this.icon,
    required this.subtitle,
    required this.title,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 44) / 2;
    return Container(
      width: width.clamp(140, 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bgDivider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
