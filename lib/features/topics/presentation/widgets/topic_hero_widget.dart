import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_more_options_sheet.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_notification_options_sheet.dart';

/// Topic Hero Banner Widget redesigned to match the high-contrast modern UI.
///
/// Features:
/// 1. Integrated responsive hero card with topic cover/thumbnail artwork.
/// 2. Multi-stop directional gradient ensuring high contrast for all text.
/// 3. Category pill tag, bold title, subtitle/tagline, and expandable description.
/// 4. Stats row: Videos count, Followers count, Comments count (tappable to scroll).
/// 5. High-contrast action row:
///    - Follow/Following button (white pill with black text/icon, Zero White-on-White compliant).
///    - Circular bell button for notifications.
///    - Circular share button.
///    - Circular more options (...) button.
class TopicHeroWidget extends StatelessWidget {
  TopicHeroWidget({
    required this.isDesktop,
    required this.isTablet,
    super.key,
    this.topic,
    this.onCommunityTap,
    this.onCommentsTap,
  });

  final Topic? topic;
  final bool isDesktop;
  final bool isTablet;
  final VoidCallback? onCommunityTap;
  final VoidCallback? onCommentsTap;

  final RxBool _isExpanded = false.obs;

  @override
  Widget build(BuildContext context) {
    final currentTopic = topic;
    if (currentTopic == null) {
      return _buildSkeleton();
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600 || (!isDesktop && !isTablet);

    final horizontalPadding = isDesktop
        ? 48.0
        : (isTablet ? 24.0 : 16.0);
    final verticalPadding = isDesktop ? 16.0 : (isTablet ? 12.0 : 8.0);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF141418),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E1E24),
                    Color(0xFF121215),
                  ],
                ),
                borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 1. Subtle ambient backdrop (only if wide coverImage exists)
                  if (currentTopic.coverImage != null &&
                      currentTopic.coverImage!.isNotEmpty)
                    Positioned.fill(
                      child: _buildBackgroundImage(currentTopic),
                    ),

                  // 2. Multi-stop directional gradient overlays (if coverImage exists)
                  if (currentTopic.coverImage != null &&
                      currentTopic.coverImage!.isNotEmpty)
                    Positioned.fill(
                      child: _buildGradientOverlay(isMobile),
                    ),

                  // 3. Foreground content
                  Padding(
                    padding: EdgeInsets.all(
                      isDesktop ? 36.0 : (isTablet ? 26.0 : 18.0),
                    ),
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildArtworkCard(
                                    currentTopic,
                                    isDesktop,
                                    isTablet,
                                    isMobile,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildCategoryBadge(currentTopic),
                                        const SizedBox(height: 8),
                                        Text(
                                          currentTopic.title,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            height: 1.2,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        _buildSubtitle(currentTopic),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildDescription(currentTopic),
                              const SizedBox(height: 16),
                              _buildStatsRow(context, currentTopic),
                              const SizedBox(height: 18),
                              _buildActionsRow(context, currentTopic),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Dedicated Topic Artwork on left
                              _buildArtworkCard(
                                currentTopic,
                                isDesktop,
                                isTablet,
                                isMobile,
                              ),
                              SizedBox(width: isDesktop ? 32 : 24),
                              // Topic details column on right
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildCategoryBadge(currentTopic),
                                    const SizedBox(height: 12),
                                    Text(
                                      currentTopic.title,
                                      style: TextStyle(
                                        fontSize: isDesktop ? 34 : 26,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1.18,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    _buildSubtitle(currentTopic),
                                    const SizedBox(height: 10),
                                    _buildDescription(currentTopic),
                                    const SizedBox(height: 18),
                                    _buildStatsRow(context, currentTopic),
                                    const SizedBox(height: 20),
                                    _buildActionsRow(context, currentTopic),
                                  ],
                                ),
                              ),
                            ],
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

  /// Dedicated Topic Artwork Card (Rounded thumbnail with border & shadow)
  Widget _buildArtworkCard(
    Topic topic,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final size = isDesktop ? 150.0 : (isTablet ? 120.0 : 88.0);
    final imgUrl = (topic.thumbnailUrl != null && topic.thumbnailUrl!.isNotEmpty)
        ? topic.thumbnailUrl!
        : ((topic.coverImage != null && topic.coverImage!.isNotEmpty)
            ? topic.coverImage!
            : null);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(isMobile ? 14 : 18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isMobile ? 12.5 : 16.5),
        child: imgUrl != null
            ? CachedNetworkImage(
                imageUrl: imgUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildArtworkFallback(size, topic),
                errorWidget: (context, url, error) => _buildArtworkFallback(size, topic),
              )
            : _buildArtworkFallback(size, topic),
      ),
    );
  }

  Widget _buildArtworkFallback(double size, Topic topic) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2C2C36),
            Color(0xFF1A1A22),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.tag_rounded,
          size: size * 0.44,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  /// Background artwork
  Widget _buildBackgroundImage(Topic topic) {
    final bgUrl = topic.coverImage;
    if (bgUrl != null && bgUrl.isNotEmpty) {
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
            Color(0xFF222226),
            Color(0xFF141416),
          ],
        ),
      ),
    );
  }

  /// Gradient overlay for optimal readability
  Widget _buildGradientOverlay(bool isMobile) {
    return Stack(
      children: [
        // Horizontal gradient (dark on left, clear on right)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.96),
                Colors.black.withValues(alpha: 0.88),
                Colors.black.withValues(alpha: 0.50),
                Colors.black.withValues(alpha: 0.15),
              ],
              stops: const [0.0, 0.45, 0.75, 1.0],
            ),
          ),
        ),
        // Vertical gradient for mobile safety
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: isMobile ? 0.90 : 0.65),
                Colors.transparent,
              ],
              stops: const [0.0, 0.70],
            ),
          ),
        ),
      ],
    );
  }

  /// Category badge pill (e.g. MUSIC)
  Widget _buildCategoryBadge(Topic topic) {
    final categoryText = topic.category.trim().isNotEmpty
        ? topic.category.trim().toUpperCase()
        : 'TOPIC';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F24).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        categoryText,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  /// Subtitle / Tagline from tags or first description sentence
  Widget _buildSubtitle(Topic topic) {
    var subtitleText = '';
    final desc = topic.description.trim();

    if (desc.contains('\n')) {
      final firstLine = desc.split('\n').first.trim();
      if (firstLine.isNotEmpty && firstLine != topic.title) {
        subtitleText = firstLine;
      }
    } else if (topic.tags.isNotEmpty) {
      subtitleText = topic.tags
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .take(4)
          .join(' • ');
    }

    if (subtitleText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        subtitleText,
        style: TextStyle(
          fontSize: isDesktop ? 15 : (isTablet ? 14 : 13),
          fontWeight: FontWeight.w500,
          color: const Color(0xFFD6D6D6),
          height: 1.3,
        ),
      ),
    );
  }

  /// Expandable Description with "...more ∨" / "show less ∧"
  Widget _buildDescription(Topic topic) {
    final fullText = topic.description.trim();
    if (fullText.isEmpty) return const SizedBox.shrink();

    // Strip out first line if already displayed in subtitle
    var bodyText = fullText;
    if (fullText.contains('\n')) {
      final parts = fullText.split('\n').where((p) => p.trim().isNotEmpty).toList();
      if (parts.length > 1) {
        bodyText = parts.sublist(1).join(' ');
      }
    }

    return Obx(() {
      final expanded = _isExpanded.value;

      return InkWell(
        onTap: _isExpanded.toggle,
        borderRadius: BorderRadius.circular(6),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bodyText,
              style: TextStyle(
                fontSize: isDesktop ? 14 : 13,
                color: const Color(0xFFAAAAAA),
                height: 1.45,
              ),
              maxLines: expanded ? 100 : 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  expanded ? 'Show less' : '...more',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  /// Stats Row: Videos count, Followers count, Comments count
  Widget _buildStatsRow(BuildContext context, Topic topic) {
    final followingController = Get.isRegistered<FollowingTopicsController>()
        ? Get.find<FollowingTopicsController>()
        : Get.put(FollowingTopicsController());

    return Obx(() {
      final followers = followingController.getFollowerCount(topic);
      final commentsHandler = onCommentsTap ?? onCommunityTap;

      return Wrap(
        spacing: 24,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 1. Videos
          _buildStatItem(
            icon: Icons.ondemand_video_rounded,
            count: '${topic.effectiveVideoCount}',
            label: topic.effectiveVideoCount == 1 ? 'Video' : 'Videos',
          ),

          // 2. Followers
          _buildStatItem(
            icon: Icons.people_outline_rounded,
            count: FormatUtils.formatCount(followers),
            label: followers == 1 ? 'Follower' : 'Followers',
          ),

          // 3. Comments (Tappable to scroll to comments section)
          _buildStatItem(
            icon: Icons.chat_bubble_outline_rounded,
            count: FormatUtils.formatCount(topic.commentCount),
            label: topic.commentCount == 1 ? 'Comment' : 'Comments',
            onTap: commentsHandler,
          ),
        ],
      );
    });
  }

  Widget _buildStatItem({
    required IconData icon,
    required String count,
    required String label,
    VoidCallback? onTap,
  }) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 22,
          color: Colors.white,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: Color(0xFFAAAAAA),
                height: 1.15,
              ),
            ),
          ],
        ),
      ],
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: content,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: content,
    );
  }

  /// Action Buttons Row (Following, Bell, Share, More)
  Widget _buildActionsRow(BuildContext context, Topic topic) {
    final followingController = Get.isRegistered<FollowingTopicsController>()
        ? Get.find<FollowingTopicsController>()
        : Get.put(FollowingTopicsController());

    return Obx(() {
      final isFollowed = followingController.isTopicFollowed(topic.id);
      final currentBellSetting =
          followingController.topicNotificationSettings[topic.id] ?? 'personalized';

      return Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 1. Follow / Following Pill Button (White surface with black text/icon - Zero White-on-White compliant)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                HapticFeedback.lightImpact();
                if (isFollowed) {
                  TopicNotificationOptionsSheet.show(context, topic: topic);
                } else {
                  followingController.toggleFollowTopic(topic);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFollowed ? Icons.check_rounded : Icons.add_rounded,
                      color: Colors.black,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isFollowed ? 'Following' : 'Follow',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Notification Bell Button
          _buildCircularActionButton(
            icon: _getBellIcon(currentBellSetting),
            tooltip: 'Notification options',
            onTap: () {
              TopicNotificationOptionsSheet.show(context, topic: topic);
            },
          ),

          // 3. Share Button
          _buildCircularActionButton(
            icon: Icons.share_outlined,
            tooltip: 'Share topic',
            onTap: () {
              final url = DeepLinkService.topicUrl(topic.slug);
              Clipboard.setData(ClipboardData(text: url));
              ShareBottomSheet.show(title: topic.title, url: url);
            },
          ),

          // 4. More Options (...) Button
          _buildCircularActionButton(
            icon: Icons.more_horiz_rounded,
            tooltip: 'More options',
            onTap: () {
              TopicMoreOptionsBottomSheet.show(context, topic: topic);
            },
          ),
        ],
      );
    });
  }

  Widget _buildCircularActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF242428).withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Center(
              child: Icon(
                icon,
                color: Colors.white,
                size: 19,
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getBellIcon(String setting) {
    switch (setting) {
      case 'all':
        return Icons.notifications_active_rounded;
      case 'none':
        return Icons.notifications_off_outlined;
      case 'personalized':
      default:
        return Icons.notifications_outlined;
    }
  }

  Widget _buildSkeleton() {
    final height = isDesktop ? 360.0 : (isTablet ? 280.0 : 220.0);
    final horizontalPadding = isDesktop ? 48.0 : (isTablet ? 24.0 : 16.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF1E1E22),
        highlightColor: const Color(0xFF2C2C32),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}
