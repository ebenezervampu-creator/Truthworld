import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics_dashboard.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/recommendation_card_widget.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({
    required this.channelId,
    required this.isDarkMode,
    super.key,
  });
  final String channelId;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      AnalyticsController(channelId: channelId),
      tag: channelId,
    );

    const bgPage = AppColors.bgPage;
    const textPrimary = AppColors.textPrimary;
    const textSecondary = AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bgPage,
      body: Obx(() {
        if (controller.rxIsLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }
        if (controller.rxErrorMessage.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 44,
                ),
                const SizedBox(height: 12),
                Text(
                  controller.errorMessage,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.error,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Subtitle Header Banner with responsive wrapping
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Channel Analytics',
                          style: AppTextStyles.pageTitle.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Real-time overview of channel performance and content insights',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      Get.to<dynamic>(
                        () => const CreatorAnalyticsDashboard(),
                        arguments: {
                          'channelId': channelId,
                          'channelName': 'My Channel',
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brand.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.analytics_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Full Dashboard',
                            style: AppTextStyles.buttonText.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Real-Time Recommendation Intelligence ──
              RecommendationCardWidget(
                isDarkMode: isDarkMode,
                channelId: channelId,
              ),
              const SizedBox(height: 28),

              // ── Top Performing Videos Section ──
              _buildTopVideosSection(
                controller.topVideos,
                textPrimary,
                textSecondary,
              ),
              const SizedBox(height: 24),

              // Bottom View Analytics Banner
              Center(
                child: InkWell(
                  onTap: () {
                    Get.to<dynamic>(
                      () => const CreatorAnalyticsDashboard(),
                      arguments: {
                        'channelId': channelId,
                        'channelName': 'My Channel',
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.brand.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.query_stats_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'View Detailed Creator Analytics Dashboard',
                          style: AppTextStyles.buttonText.copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTopVideosSection(
    List<Video> topVideos,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.bgDivider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                'Top Performing Videos (by views)',
                style: AppTextStyles.titleMedium.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (topVideos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No video data available yet.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < topVideos.length; index++) ...[
                  if (index > 0)
                    const Divider(
                      color: AppColors.bgDivider,
                      height: 20,
                    ),
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: topVideos[index].thumbnailUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: topVideos[index].thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, err) =>
                                      const ColoredBox(
                                        color: AppColors.bgInput,
                                        child: Icon(
                                          Icons.play_circle_outline,
                                          color: Colors.white,
                                        ),
                                      ),
                                )
                              : const ColoredBox(color: AppColors.bgInput),
                        ),
                      ),
                      title: Text(
                        topVideos[index].title,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${NumberFormat.compact().format(topVideos[index].views)} views',
                          style: AppTextStyles.caption.copyWith(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      onTap: () {
                        Get.to<dynamic>(
                          () => const CreatorAnalyticsDashboard(),
                          arguments: {
                            'channelId': channelId,
                            'videoId': topVideos[index].id,
                            'videoTitle': topVideos[index].title,
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
