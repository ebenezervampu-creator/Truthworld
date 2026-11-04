import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics_dashboard.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Top performing content card inspired by Channel Wizard design language:
/// dark zinc cards, 16:9 thumbnails, rank indicators, and direct drill-down.
class AnalyticsTopVideosCard extends StatelessWidget {
  const AnalyticsTopVideosCard({
    required this.topVideos,
    required this.channelId,
    super.key,
  });

  final List<Video> topVideos;
  final String channelId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bgSurface),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.bgSurface),
                      ),
                      child: const Icon(
                        Icons.video_library_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top Performing Content',
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Ranked by total views and audience reach',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.bgSurface),
                ),
                child: const Text(
                  'By Views',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Content List
          if (topVideos.isEmpty)
            _buildEmptyState()
          else
            Column(
              children: [
                for (var i = 0; i < topVideos.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _buildVideoItem(topVideos[i], i + 1),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgSurface),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.video_library_outlined,
            color: AppColors.textTertiary,
            size: 38,
          ),
          SizedBox(height: 12),
          Text(
            'No Video Data Available Yet',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Publish your first video to unlock real-time viewer signals and retention statistics.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoItem(Video video, int rank) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgInput,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bgSurface),
          ),
          child: Row(
            children: [
              // Rank indicator
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank == 1
                      ? AppColors.warning.withValues(alpha: 0.2)
                      : AppColors.bgPage,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: rank == 1
                        ? AppColors.warning.withValues(alpha: 0.5)
                        : AppColors.bgSurface,
                  ),
                ),
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: rank == 1 ? AppColors.warning : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Thumbnail
              SizedBox(
                width: 76,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: video.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: video.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, err) =>
                                const ColoredBox(
                                  color: AppColors.bgPage,
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                          )
                        : const ColoredBox(
                            color: AppColors.bgPage,
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Title and metrics
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${NumberFormat.compact().format(video.views)} views',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (video.category.isNotEmpty) ...[
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppColors.textTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            video.category,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Trailing arrow
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
