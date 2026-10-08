import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Video Feed Card matching the uploaded UI:
/// - Rounded dark surface card (`#161618`)
/// - 16:9 video thumbnail with rounded top
/// - Top right index pill badge (e.g. "1/2")
/// - Top left topic badge pill (e.g. "Space & Astronomy")
/// - Bottom right duration pill badge (e.g. "07:35")
/// - Channel / Topic blue rounded square avatar with play/video icon
/// - Bold video title (2 lines max), channel name, views & upload time
/// - 3-dots action menu (opens [VideoOptionsSheet])
/// - Supports both Grid and List layouts and custom [cardWidth]
class FollowingTopicVideoCard extends StatelessWidget {
  const FollowingTopicVideoCard({
    required this.video,
    required this.topic,
    required this.isMobile,
    this.index = 0,
    this.totalCount = 1,
    this.isGrid = true,
    this.cardWidth,
    this.onTopicDetailsTap,
    super.key,
  });

  final Video video;
  final Topic topic;
  final bool isMobile;
  final int index;
  final int totalCount;
  final bool isGrid;
  final double? cardWidth;
  final void Function(Topic topic)? onTopicDetailsTap;

  void _handleVideoTap() {
    MiniplayerNavigationHelper.navigateToVideoScreen(
      video: video,
      routeArguments: {
        'video': video,
        'heroTag': 'topic_${topic.id}_video_${video.id}_$index',
      },
    );
  }

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
    if (!isGrid) {
      return _buildListCard(context);
    }
    final card = _buildGridCard(context);
    if (cardWidth != null) {
      return Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 16),
        child: card,
      );
    }
    return card;
  }

  // ==========================================================================
  // GRID CARD LAYOUT (Matches uploaded UI screenshot)
  // ==========================================================================
  Widget _buildGridCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Thumbnail with Badges
          _buildThumbnailStack(context),

          // 2. Metadata Section Below Thumbnail
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Channel / Topic Avatar (Blue rounded square with play icon)
                _buildChannelAvatar(),
                const SizedBox(width: 10),

                // Video Title, Channel Name, Views & Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        video.channelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF999999),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${FormatUtils.formatCount(video.views)} views • ${_formatUploadDate()}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF777777),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // 3-dots Menu Button
                IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 18,
                    color: Color(0xFFAAAAAA),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => VideoOptionsSheet.show(context, video),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // LIST CARD LAYOUT (Horizontal layout for list view mode)
  // ==========================================================================
  Widget _buildListCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: isMobile
          ? _buildGridCard(context)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 240,
                  child: _buildThumbnailStack(context),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildChannelAvatar(),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    video.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    video.channelName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF999999),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${FormatUtils.formatCount(video.views)} views • ${_formatUploadDate()}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF777777),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.more_vert,
                                size: 20,
                                color: Color(0xFFAAAAAA),
                              ),
                              onPressed: () =>
                                  VideoOptionsSheet.show(context, video),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ==========================================================================
  // THUMBNAIL STACK WITH BADGES
  // ==========================================================================
  Widget _buildThumbnailStack(BuildContext context) {
    return GestureDetector(
      onTap: _handleVideoTap,
      child: Stack(
        children: [
          // 16:9 Image
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: const Color(0xFF222224),
              ),
              errorWidget: (context, url, error) => const ColoredBox(
                color: Color(0xFF222224),
                child: Center(
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    color: Color(0xFF555555),
                    size: 40,
                  ),
                ),
              ),
            ),
          ),

          // Top Left Topic Badge Pill
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
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top Right Badge ("1/2")
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${index + 1}/${totalCount > 0 ? totalCount : 2}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // Fact-Checked Badge (if verified)
          if (video.isFactChecked)
            Positioned(
              top: 36,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Fact Checked',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Right Duration Badge ("07:35")
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                video.duration.isNotEmpty ? video.duration : '07:35',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // CHANNEL / TOPIC AVATAR (Blue square with play icon)
  // ==========================================================================
  Widget _buildChannelAvatar() {
    return GestureDetector(
      onTap: _handleTopicTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF194A8E), // Rich deep blue matching screenshot
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.smart_display_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  String _formatUploadDate() {
    try {
      final date = video.uploadedAt.toDate();
      return timeago.format(date);
    } catch (_) {
      return '2 days ago';
    }
  }
}
