import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/monetization_ai_features_modal.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/monetization_card_container.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Target threshold in watch hours required for unlocking per-video cash-outs.
const double kCashOutWatchHoursThreshold = 10.0;

/// Target threshold in view count required for unlocking per-video cash-outs.
const int kCashOutViewsThreshold = 1000;

/// Section showing per-video progress toward the 1,000 views and 10-hour cash-out threshold.
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
            title: 'Video Cash-Out Eligibility (1,000 Views & 10 Hours)',
          ),
          const SizedBox(height: 8),
          const Text(
            'Track views and watch hours per video. Once any video reaches 1,000 views & 10 hours watch time and KYC is completed, channel monetization is ON and all videos generate revenue. Earnings become withdrawable per video after reaching 1,000 views and 10 hours of watch time; otherwise, wait or spend immediately on TruthWorld AI features (dubbing, subtitles, etc.)!',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final videos = controller.recentVideos;
            if (videos.isEmpty) {
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
                color: AppColors.bgInput,
                child: video.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        fit: BoxFit.cover,
                        width: 50,
                        height: 35,
                        placeholder: (context, url) =>
                            const ColoredBox(color: AppColors.bgInput),
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
                    '${NumberFormat.compact().format(video.viewCount)}/1K views • ${watchHours.toStringAsFixed(1)}/10.0 hrs watch time',
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
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEligibleForCashOut
                      ? Colors.green.withValues(alpha: 0.4)
                      : Colors.orange.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                isEligibleForCashOut
                    ? 'Cash-Out Ready'
                    : (watchHours < 10.0 && video.viewCount < 1000
                        ? 'Locked (<1K views & <10h)'
                        : (watchHours < 10.0
                            ? 'Locked (${watchHours.toStringAsFixed(1)}h/10h)'
                            : 'Locked (${video.viewCount}/1K views)')),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isEligibleForCashOut ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: LinearPercentIndicator(
                lineHeight: 6,
                percent: progress,
                progressColor: isEligibleForCashOut
                    ? Colors.green
                    : AppColors.brand,
                backgroundColor: AppColors.bgInput,
                barRadius: const Radius.circular(3),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () =>
                  SpendRevenueBottomSheet.show(context, controller, video),
              child: const Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Use for AI Tools',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
