import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics_dashboard.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/recommendation_card_widget.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_colors.dart';

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
    );

    final bgPage = isDarkMode ? AppColors.bgPage : AppColors.textPrimary;
    final textPrimary = isDarkMode ? AppColors.textPrimary : AppColors.bgPage;
    final textSecondary = isDarkMode ? AppColors.textSecondary : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bgPage,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }
        if (controller.errorMessage.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 44),
                const SizedBox(height: 12),
                Text(
                  controller.errorMessage.value,
                  style: const TextStyle(color: AppColors.error, fontSize: 14),
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
              // Title & Subtitle Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Channel Analytics',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Real-time overview of channel performance and content insights',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      child: const Row(
                        children: [
                          Icon(Icons.analytics_rounded, color: AppColors.textPrimary, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Full Dashboard',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textPrimary, size: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Real-Time Recommendation Intelligence ──
              RecommendationCardWidget(isDarkMode: isDarkMode),
              const SizedBox(height: 28),

              // ── Top Performing Videos Section ──
              _buildTopVideosSection(controller.topVideos, textPrimary, textSecondary),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.query_stats_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'View Detailed Creator Analytics Dashboard',
                          style: TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
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

  Widget _buildTopVideosSection(List<Video> topVideos, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? AppColors.bgDivider
              : AppColors.textSecondary.withValues(alpha: 0.2),
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
                style: TextStyle(
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
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topVideos.length,
              separatorBuilder: (context, index) => Divider(
                color: isDarkMode
                    ? AppColors.bgDivider
                    : AppColors.textSecondary.withValues(alpha: 0.2),
                height: 20,
              ),
              itemBuilder: (context, index) {
                final video = topVideos[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: video.thumbnailUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: video.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, err) => const ColoredBox(
                                color: AppColors.bgInput,
                                child: Icon(Icons.play_circle_outline, color: Colors.white),
                              ),
                            )
                          : const ColoredBox(color: AppColors.bgInput),
                    ),
                  ),
                  title: Text(
                    video.title,
                    style: TextStyle(
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
                      '${NumberFormat.compact().format(video.views)} views',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.brand,
                  ),
                  onTap: () {
                    Get.to<dynamic>(
                      () => const CreatorAnalyticsDashboard(),
                      arguments: {
                        'channelId': channelId,
                        'videoId': video.id,
                        'videoTitle': video.title,
                      },
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
