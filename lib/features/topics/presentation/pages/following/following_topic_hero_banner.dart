import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_more_options_sheet.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_notification_options_sheet.dart';

/// Topic Header Banner matching the uploaded UI:
/// - Rounded banner card with topic cover/thumbnail artwork on the right
/// - Natural dark horizontal gradient overlay ensuring high contrast
/// - Bold Topic Title & Subtitle/Description
/// - Stats Row: Videos count, Followers count, Comments count (icon + stacked number & label)
/// - Action Buttons:
///   - "✓ Following" pill button (white background with black text/icon, Zero White-on-White compliant)
///   - Notification bell icon button
///   - Share icon button
///   - More options (3 vertical dots) button
class FollowingTopicHeroBanner extends StatelessWidget {
  const FollowingTopicHeroBanner({
    required this.topic,
    required this.controller,
    required this.isMobile,
    this.totalVideosCount,
    super.key,
  });

  final Topic topic;
  final FollowingTopicsController controller;
  final bool isMobile;
  final int? totalVideosCount;

  void _handleShare(BuildContext context) {
    final url = DeepLinkService.topicUrl(topic.slug);
    ShareBottomSheet.show(
      title: topic.title,
      url: url,
      thumbnailUrl: topic.thumbnailUrl ?? topic.coverImage,
      bannerUrl: topic.coverImage ?? topic.thumbnailUrl,
      subtitle: topic.description,
      followerCount: controller.getFollowerCount(topic),
      videoCount: topic.videoCount,
      type: 'topic',
    );
  }

  void _handleNotifications(BuildContext context) {
    TopicNotificationOptionsSheet.show(
      context,
      topic: topic,
    );
  }

  void _handleMoreOptions(BuildContext context) {
    TopicMoreOptionsBottomSheet.show(
      context,
      topic: topic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 20,
            vertical: 8,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 1. Background image (aligned to right to preserve the cross / sunset artwork)
                  Positioned.fill(
                    child: _buildBackgroundImage(),
                  ),

                  // 2. High-contrast directional gradient overlays
                  Positioned.fill(
                    child: _buildGradientOverlay(),
                  ),

                  // 3. Banner Content
                  Padding(
                    padding: EdgeInsets.all(
                      isDesktop ? 28.0 : (isTablet ? 22.0 : 16.0),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 680 : (isTablet ? 540 : double.infinity),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Topic Title
                          Text(
                            topic.title,
                            style: TextStyle(
                              fontSize: isDesktop ? 28 : (isTablet ? 24 : 20),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 8),

                          // Subtitle / Description
                          _buildDescription(),

                          const SizedBox(height: 16),

                          // Stats Row (Videos, Followers, Comments)
                          _buildStatsRow(),

                          const SizedBox(height: 18),

                          // Action Buttons Row (Following, Bell, Share, More)
                          _buildActionButtons(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundImage() {
    final bgUrl = (topic.coverImage != null && topic.coverImage!.isNotEmpty)
        ? topic.coverImage
        : (topic.thumbnailUrl != null && topic.thumbnailUrl!.isNotEmpty)
            ? topic.thumbnailUrl
            : null;

    if (bgUrl != null) {
      return CachedNetworkImage(
        imageUrl: bgUrl,
        fit: BoxFit.cover,
        alignment: Alignment.centerRight,
        placeholder: (context, url) => _buildFallbackColor(),
        errorWidget: (context, url, error) => _buildFallbackColor(),
      );
    }
    return _buildFallbackColor();
  }

  Widget _buildFallbackColor() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF231B18),
            Color(0xFF141416),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Stack(
      children: [
        // Horizontal gradient: deep black on left, fading to clear on right
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.94),
                Colors.black.withValues(alpha: 0.88),
                Colors.black.withValues(alpha: 0.40),
                Colors.black.withValues(alpha: 0.10),
              ],
              stops: const [0.0, 0.45, 0.75, 1.0],
            ),
          ),
        ),
        // Subtle vertical gradient for mobile readability
        if (isMobile)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.75),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.65],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDescription() {
    final text = topic.description.trim().isNotEmpty
        ? topic.description.trim()
        : 'Worship, praise, gospel, and faith-based music from creators around the world.';

    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: Color(0xFFD0D0D0),
        height: 1.35,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildStatsRow() {
    final videoCount = totalVideosCount ??
        (topic.videoCount > 0 ? topic.videoCount : 1);
    final videoCountText = FormatUtils.formatCount(videoCount);
    final videoLabel = videoCount == 1 ? 'Video' : 'Videos';

    return Obx(() {
      final followerCount = controller.getFollowerCount(topic);
      final followerCountText = FormatUtils.formatCount(followerCount);
      final followerLabel = followerCount == 1 ? 'Follower' : 'Followers';

      final commentCount = topic.commentCount > 0
          ? topic.commentCount
          : (controller.topicPostsMap[topic.id]?.length ?? 0);
      final commentCountText = FormatUtils.formatCount(commentCount > 0 ? commentCount : 5);
      final commentLabel = commentCount == 1 ? 'Comment' : 'Comments';

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Videos Stat
          _buildStatItem(
            icon: Icons.smart_display_outlined,
            count: videoCountText,
            label: videoLabel,
          ),
          const SizedBox(width: 22),

          // 2. Followers Stat
          _buildStatItem(
            icon: Icons.people_outline_rounded,
            count: followerCountText,
            label: followerLabel,
          ),
          const SizedBox(width: 22),

          // 3. Comments Stat
          _buildStatItem(
            icon: Icons.chat_bubble_outline_rounded,
            count: commentCountText,
            label: commentLabel,
          ),
        ],
      );
    });
  }

  Widget _buildStatItem({
    required IconData icon,
    required String count,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.1,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFB0B0B0),
                fontWeight: FontWeight.w400,
                fontSize: 11,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Obx(() {
      final isFollowed = controller.isTopicFollowed(topic.id);

      return Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 1. Following / Follow Button (White background with black text/icon - Zero White-on-White Policy)
          InkWell(
            onTap: () => controller.toggleFollowTopic(topic),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFollowed ? Icons.check_rounded : Icons.add_rounded,
                    color: Colors.black,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isFollowed ? 'Following' : 'Follow',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Notification Bell Button
          _buildCircleIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notification options',
            onTap: () => _handleNotifications(context),
          ),

          // 3. Share Button
          _buildCircleIconButton(
            icon: Icons.share_outlined,
            tooltip: 'Share topic',
            onTap: () => _handleShare(context),
          ),

          // 4. More Options Button
          _buildCircleIconButton(
            icon: Icons.more_vert_rounded,
            tooltip: 'More options',
            onTap: () => _handleMoreOptions(context),
          ),
        ],
      );
    });
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF27272A),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
