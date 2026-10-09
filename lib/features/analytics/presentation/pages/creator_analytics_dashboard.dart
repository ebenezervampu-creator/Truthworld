import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics/creator_analytics_components.dart';
import 'package:truthworld/theme/app_colors.dart';

export 'creator_analytics/creator_analytics_components.dart';

/// Premium Industry-Standard Creator Analytics Dashboard.
/// Built with 100% AppColors, AppTheme typography & GetX state management.
class CreatorAnalyticsDashboard extends StatelessWidget {
  const CreatorAnalyticsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CreatorAnalyticsController.to;
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final channelId = args['channelId'] as String? ?? '';
    final channelName = args['channelName'] as String? ?? 'My Channel';
    final videoId = args['videoId'] as String? ?? '';
    final videoTitle = args['videoTitle'] as String? ?? 'Video Analytics';

    // Load analytics on init
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (channelId.isNotEmpty) {
        controller.selectedChannelId.value = channelId;
      }
      if (videoId.isNotEmpty) {
        controller.selectedVideoId.value = videoId;
        await controller.loadVideoAnalytics(videoId, videoTitle: videoTitle);
      } else if (channelId.isNotEmpty) {
        controller.selectedVideoId.value = '';
        await controller.loadChannelAnalytics(channelId, channelName: channelName);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text(
          videoId.isNotEmpty ? 'Video Analytics' : 'Channel Analytics',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Get.back<void>(),
        ),
        actions: [
          Obx(() {
            final count = controller.liveViewerCount.value;
            if (count > 0) {
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CreatorPulsingDot(),
                    const SizedBox(width: 6),
                    Text(
                      '$count watching live',
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: controller.refreshAnalytics,
          ),
        ],
      ),
      body: Obx(() {
        final isLoading =
            controller.isLoadingVideoAnalytics.value ||
            controller.isLoadingChannelAnalytics.value;

        if (isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }

        return RefreshIndicator(
          color: AppColors.brand,
          onRefresh: controller.refreshAnalytics,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header video / channel title badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        videoId.isNotEmpty
                            ? Icons.play_circle_fill_rounded
                            : Icons.sensors_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          videoId.isNotEmpty ? videoTitle : channelName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Live Subscribers of Channel Interactive Banner (when viewing channel)
                if (videoId.isEmpty) ...[
                  CreatorLiveSubscribersBanner(
                    controller: controller,
                    channelId: channelId,
                  ),
                  const SizedBox(height: 14),
                ],

                // Date range filter pills
                CreatorDateRangeFilterPills(controller: controller),
                const SizedBox(height: 20),

                // Error message banner
                Obx(() {
                  final currentVideoId = controller.selectedVideoId.value;
                  final error = currentVideoId.isNotEmpty
                      ? controller.videoLoadingError.value
                      : controller.channelLoadingError.value;

                  if (error.isEmpty) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error,
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Summary Cards Grid
                CreatorSummaryCardsGrid(controller: controller),
                const SizedBox(height: 24),

                // Audience Retention
                if (controller.watchtimeChartData.isNotEmpty) ...[
                  const CreatorSectionHeader(title: 'Audience Retention'),
                  const SizedBox(height: 12),
                  CreatorWatchtimeRetentionCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                // Traffic Sources
                if (controller.trafficSourceChartData.isNotEmpty) ...[
                  const CreatorSectionHeader(title: 'Traffic Sources'),
                  const SizedBox(height: 12),
                  CreatorTrafficSourceCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                // Geographic Breakdown
                if (controller.stateTrafficChartData.isNotEmpty ||
                    controller.topStates.isNotEmpty) ...[
                  const CreatorSectionHeader(title: 'Geographic Breakdown'),
                  const SizedBox(height: 12),
                  CreatorGeographicBreakdownCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                // City Breakdown
                if (controller.topCities.isNotEmpty) ...[
                  const CreatorSectionHeader(title: 'Top Cities'),
                  const SizedBox(height: 12),
                  CreatorTopCitiesCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                // Urban vs Rural
                if (controller.areaTypeChartData.isNotEmpty) ...[
                  const CreatorSectionHeader(title: 'Urban vs Rural Viewers'),
                  const SizedBox(height: 12),
                  CreatorAreaTypeCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                // Device Breakdown
                if (controller.deviceBreakdownStats.isNotEmpty) ...[
                  const CreatorSectionHeader(title: 'Device Breakdown'),
                  const SizedBox(height: 12),
                  CreatorDeviceBreakdownCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      }),
    );
  }
}
