import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/monetization_card_container.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Target threshold in watch hours required for unlocking per-video cash-outs.
const double kCashOutWatchHoursThreshold = 30.0;

/// Target threshold in view count required for unlocking per-video cash-outs.
const int kCashOutViewsThreshold = 1000;

/// Section showing per-video progress toward the 1,000 views and 30-hour cash-out threshold.
/// Styled with exact Library theme and monochrome metrics.
class PerVideoWithdrawalSection extends StatelessWidget {
  const PerVideoWithdrawalSection({
    required this.controller,
    super.key,
  });

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return MonetizationCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MonetizationSectionTitle(
            title: 'Video Cash-Out Eligibility (1,000 Views & 30 Hours)',
          ),
          const SizedBox(height: 8),
          const Text(
            'Track views and watch hours per video. Once any video reaches 1,000 views & 30 hours watch time and KYC is completed, channel monetization is ON and all videos generate revenue. Earnings become withdrawable per video after reaching 1,000 views and 30 hours of watch time.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final videos = controller.recentVideos.isNotEmpty
                ? controller.recentVideos
                : (Get.isRegistered<VideoManagementController>() &&
                        Get.find<VideoManagementController>().channelVideos.isNotEmpty
                    ? Get.find<VideoManagementController>().channelVideos
                    : (Get.isRegistered<CreatorAnalyticsController>() &&
                            Get.find<CreatorAnalyticsController>().channelVideos.isNotEmpty
                        ? Get.find<CreatorAnalyticsController>().channelVideos
                        : controller.recentVideos));
            if (videos.isEmpty) {
              if (controller.rxIsLoading.value) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                );
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                controller.ensureVideosLoaded();
              });
              return Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: const Text(
                  'No uploaded videos found yet.\nUpload videos to start generating revenue from Day 1!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: videos.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: AppColors.bgDivider, height: 16),
              itemBuilder: (context, index) {
                final video = videos[index];
                return VideoWithdrawalRow(
                  controller: controller,
                  video: video,
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

/// Row displaying video thumbnail, title, watch hours progress, and AI feature spending option.
class VideoWithdrawalRow extends StatelessWidget {
  const VideoWithdrawalRow({
    required this.controller,
    required this.video,
    super.key,
  });

  final DashboardController controller;
  final Video video;

  @override
  Widget build(BuildContext context) {
    final watchHours = controller.getVideoWatchHours(video);
    final isEligibleForCashOut = controller.isVideoWithdrawalEligible(video);
    final hoursProgress =
        (watchHours / kCashOutWatchHoursThreshold).clamp(0.0, 1.0);
    final viewsProgress =
        (video.viewCount / kCashOutViewsThreshold).clamp(0.0, 1.0);
    final progress = ((hoursProgress + viewsProgress) / 2.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 50,
                height: 35,
                color: AppColors.bgPage,
                child: video.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        fit: BoxFit.cover,
                        width: 50,
                        height: 35,
                        placeholder: (context, url) =>
                            const ColoredBox(color: AppColors.bgPage),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      )
                    : const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title.isNotEmpty ? video.title : 'Untitled Video',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${NumberFormat.compact().format(video.viewCount)}/1K views • ${watchHours.toStringAsFixed(1)}/30.0 hrs watch time',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isEligibleForCashOut
                    ? Colors.white.withValues(alpha: 0.12)
                    : AppColors.bgSurfaceHover,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEligibleForCashOut
                      ? Colors.white.withValues(alpha: 0.3)
                      : AppColors.bgDivider,
                ),
              ),
              child: Text(
                isEligibleForCashOut
                    ? 'Cash-Out Ready'
                    : (watchHours < 30.0 && video.viewCount < 1000
                        ? 'Locked (<1K views & <30h)'
                        : (watchHours < 30.0
                            ? 'Locked (${watchHours.toStringAsFixed(1)}h/30h)'
                            : 'Locked (${video.viewCount}/1K views)')),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isEligibleForCashOut ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearPercentIndicator(
          lineHeight: 6,
          percent: progress,
          progressColor: Colors.white,
          backgroundColor: AppColors.bgSurface,
          barRadius: const Radius.circular(3),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
