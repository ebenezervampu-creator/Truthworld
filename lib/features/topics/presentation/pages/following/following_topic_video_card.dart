import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Horizontal card displaying video thumbnail, topic badge, metadata, and options.
class FollowingTopicVideoCard extends StatelessWidget {
  const FollowingTopicVideoCard({
    required this.topic,
    required this.video,
    required this.isMobile,
    required this.cardWidth,
    this.onTopicDetailsTap,
    super.key,
  });

  final Topic topic;
  final Video video;
  final bool isMobile;
  final double cardWidth;
  final void Function(Topic topic)? onTopicDetailsTap;

  void _handleTopicTap() {
    if (onTopicDetailsTap != null) {
      onTopicDetailsTap!(topic);
    } else {
      Get.toNamed<void>(
        topic.topicRoute,
        arguments: {
          'slug': topic.slug,
          'fromCard': true,
          'topic': topic,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Thumbnail
          GestureDetector(
            onTap: () {
              MiniplayerNavigationHelper.navigateToVideoScreen(
                video: video,
                routeArguments: {
                  'video': video,
                  'heroTag': 'saved_topic_${topic.id}_${video.id}',
                },
              );
            },
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFF272727),
                      ),
                      errorWidget: (context, url, error) => const ColoredBox(
                        color: Color(0xFF272727),
                        child: Icon(
                          Icons.videocam_off_rounded,
                          color: AppColors.textTertiary,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),

                // Topic Badge (Navigates to Topics Page)
                Positioned(
                  top: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: _handleTopicTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.topic_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            topic.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Fact Checked Badge (if applicable)
                if (video.isFactChecked)
                  Positioned(
                    top: 36,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: AppColors.textPrimary,
                            size: 10,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Fact Checked',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Duration Badge
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Video Title & Options Menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => VideoOptionsSheet.show(context, video),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Channel Name
          Text(
            video.channelName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 2),

          // Views & Upload Time
          Text(
            '${FormatUtils.formatCount(video.views)} views • ${timeago.format(video.uploadedAt.toDate())}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
