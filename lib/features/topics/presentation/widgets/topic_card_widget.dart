import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topic_management_screen.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Unified Responsive Topic Card Widget matching exact Channel Creation page fonts and theme architecture.
/// Guarantees zero overflow errors across Mobile, Tablet, and Desktop with dynamic aspect ratios (16:9, 1:1, etc.).
class TopicCardWidget extends StatelessWidget {
  TopicCardWidget({
    super.key,
    this.topic,
    this.isHero = false,
    this.isDashboard = false,
    this.onFollowToggle,
    this.onExploreTap,
    this.showEditOption = true,
    this.onPreviousTap,
    this.onNextTap,
    this.currentIndex,
    this.totalItems,
    this.accentColor,
    this.trailing,
    this.aspectRatio,
  });

  final Topic? topic;
  final bool isHero;
  final bool isDashboard;
  final VoidCallback? onFollowToggle;
  final VoidCallback? onExploreTap;
  final bool showEditOption;
  final VoidCallback? onPreviousTap;
  final VoidCallback? onNextTap;
  final int? currentIndex;
  final int? totalItems;
  final Color? accentColor;
  final Widget? trailing;
  final double? aspectRatio;

  final ValueNotifier<bool> _isHovered = ValueNotifier<bool>(false);

  FollowingTopicsController get _followingTopicsController =>
      Get.isRegistered<FollowingTopicsController>()
          ? Get.find<FollowingTopicsController>()
          : Get.put(FollowingTopicsController());

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase().trim();
    if (cat.contains('music') ||
        cat.contains('song') ||
        cat.contains('worship') ||
        cat.contains('praise') ||
        cat.contains('audio') ||
        cat.contains('sing')) {
      return Icons.music_note_rounded;
    }
    if (cat.contains('short film') || cat.contains('shortfilm')) {
      return Icons.movie_creation_rounded;
    }
    if (cat.contains('news') ||
        cat.contains('politics') ||
        cat.contains('current') ||
        cat.contains('debate')) {
      return Icons.newspaper_rounded;
    }
    if (cat.contains('tech') ||
        cat.contains('code') ||
        cat.contains('software') ||
        cat.contains('ai') ||
        cat.contains('dev')) {
      return Icons.computer_rounded;
    }
    if (cat.contains('sport') ||
        cat.contains('fitness') ||
        cat.contains('gym') ||
        cat.contains('workout')) {
      return Icons.sports_soccer_rounded;
    }
    if (cat.contains('science') ||
        cat.contains('space') ||
        cat.contains('physics') ||
        cat.contains('nature')) {
      return Icons.science_rounded;
    }
    if (cat.contains('education') ||
        cat.contains('learn') ||
        cat.contains('study') ||
        cat.contains('book')) {
      return Icons.school_rounded;
    }
    if (cat.contains('movie') ||
        cat.contains('film') ||
        cat.contains('cinema') ||
        cat.contains('entertainment')) {
      return Icons.movie_creation_rounded;
    }
    if (cat.contains('business') ||
        cat.contains('finance') ||
        cat.contains('crypto') ||
        cat.contains('money')) {
      return Icons.attach_money_rounded;
    }
    return Icons.topic_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final currentTopic = topic;
    if (currentTopic == null) return const SizedBox.shrink();

    // Guard: Never render empty or invalid topics in public feeds/views.
    // Dashboard views may show them to creator/owner to manage/add videos.
    if (!isDashboard && (!currentTopic.isValidTopic || currentTopic.videoCount <= 0)) {
      return const SizedBox.shrink();
    }

    final exploreController = Get.isRegistered<ExploreTopicsController>()
        ? Get.find<ExploreTopicsController>()
        : null;

    final isOwner = Get.isRegistered<AuthService>() &&
        ((currentTopic.channelId != null &&
                currentTopic.channelId!.isNotEmpty &&
                AuthService.to.userChannel?.id == currentTopic.channelId) ||
            (currentTopic.creatorId != null &&
                currentTopic.creatorId!.isNotEmpty &&
                AuthService.to.uid == currentTopic.creatorId));

    final isOwnerContext = isDashboard || (isOwner && showEditOption);
    final isRejected = currentTopic.status.toLowerCase() == 'verificationrejected' ||
        currentTopic.status.toLowerCase() == 'rejected';
    final isUnderReview = currentTopic.status.toLowerCase() == 'underreview' ||
        currentTopic.status.toLowerCase() == 'pending';

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.hasBoundedHeight;
        final effectiveAspectRatio = aspectRatio ?? (16 / 9);

        final Widget coverImageWidget = ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _isHovered,
                builder: (context, hovered, _) => AnimatedScale(
                  scale: hovered ? 1.04 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: _buildCoverImage(currentTopic),
                ),
              ),
              // Category Pill (Top-Left)
              Positioned(
                top: 8,
                left: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getCategoryIcon(currentTopic.category),
                            color: Colors.white,
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            currentTopic.category.isNotEmpty
                                ? currentTopic.category
                                : 'Topic',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isOwnerContext && isRejected) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: 11,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Action Required',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isOwnerContext && isUnderReview) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.hourglass_empty_rounded,
                              color: Colors.white,
                              size: 11,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Under Review',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Trailing / Video Count Pill (Top-Right)
              Positioned(
                top: 8,
                right: 8,
                child: trailing ??
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${currentTopic.videoCount} ${currentTopic.videoCount == 1 ? 'video' : 'videos'}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
              ),
            ],
          ),
        );

        final topPortion = hasBoundedHeight
            ? Expanded(child: coverImageWidget)
            : AspectRatio(
                aspectRatio: effectiveAspectRatio,
                child: coverImageWidget,
              );

        return MouseRegion(
          onEnter: (_) => _isHovered.value = true,
          onExit: (_) => _isHovered.value = false,
          child: InkWell(
            onTap: () {
              if (onExploreTap != null) {
                onExploreTap!();
              } else {
                exploreController?.preloadTopicDetails(currentTopic);
                Get.toNamed(
                  currentTopic.topicRoute,
                  arguments: {
                    'slug': currentTopic.slug,
                    'fromCard': true,
                    'topic': currentTopic,
                  },
                );
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF14171F),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:
                    hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  // 1. TOP PORTION: Cover Thumbnail Image
                  topPortion,

                  // 2. BOTTOM PORTION: Card Content (Topic Name, Stats Line, Action Buttons Row)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Topic Name
                        Text(
                          currentTopic.name,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.25,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        // Stats Row (Video Count & Followers Count)
                        Row(
                          children: [
                            Text(
                              '${FormatUtils.formatCount(currentTopic.videoCount)} ${currentTopic.videoCount == 1 ? 'Video' : 'Videos'}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              child: Text(
                                '•',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Obx(() {
                                final count = _followingTopicsController
                                    .getFollowerCount(currentTopic);
                                return Text(
                                  '${FormatUtils.formatCount(count)} Followers',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textTertiary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              }),
                            ),
                          ],
                        ),

                        if (isOwnerContext && isRejected) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C1515),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.5),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.error,
                                  size: 13,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    currentTopic.moderationReason?.isNotEmpty == true
                                        ? currentTopic.moderationReason!
                                        : 'Topic rejected by AI moderation. Edit to fix and resubmit.',
                                    style: const TextStyle(
                                      color: Color(0xFFFCA5A5),
                                      fontSize: 10.5,
                                      height: 1.25,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),

                        // Action Buttons Row (Follow Button & Share Button)
                        Row(
                          children: [
                            // Follow / Following / Edit Button
                            Expanded(
                              child: isOwnerContext
                                  ? _buildEditButton(
                                      context,
                                      currentTopic,
                                      isRejected: isRejected,
                                    )
                                  : _buildFollowButton(currentTopic),
                            ),

                            const SizedBox(width: 8),

                            // Share Button Box
                            _buildShareButton(currentTopic),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Cover Image Widget
  Widget _buildCoverImage(Topic currentTopic) {
    final imageSrc = currentTopic.coverImage ?? currentTopic.thumbnailUrl;

    if (imageSrc != null && imageSrc.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageSrc,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        placeholder: (_, _) => _buildFallbackCover(),
        errorWidget: (_, _, _) => _buildFallbackCover(),
      );
    }

    return _buildFallbackCover();
  }

  /// Fallback Image Container
  Widget _buildFallbackCover() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1218),
      ),
      child: Center(
        child: Icon(
          Icons.topic_rounded,
          color: Colors.white.withValues(alpha: 0.4),
          size: 36,
        ),
      ),
    );
  }

  /// Follow Action Button
  Widget _buildFollowButton(Topic currentTopic) {
    return Obx(() {
      final isFollowed =
          _followingTopicsController.isTopicFollowed(currentTopic.id);

      return ElevatedButton.icon(
        onPressed: onFollowToggle ??
            () {
              HapticFeedback.lightImpact();
              _followingTopicsController.toggleFollowTopic(currentTopic);
            },
        icon: Icon(
          isFollowed ? Icons.check_rounded : Icons.play_arrow_rounded,
          size: 14,
          color: isFollowed ? Colors.white : Colors.black,
        ),
        label: Text(
          isFollowed ? 'Following' : 'Follow',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isFollowed ? Colors.white : Colors.black,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowed
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white,
          foregroundColor: isFollowed ? Colors.white : Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: isFollowed
                ? BorderSide(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 0.8,
                  )
                : BorderSide.none,
          ),
        ),
      );
    });
  }

  /// Edit Action Button (for topic creator / owner)
  Widget _buildEditButton(
    BuildContext context,
    Topic currentTopic, {
    bool isRejected = false,
  }) {
    return ElevatedButton.icon(
      onPressed: () {
        final topicManagementController = Get.isRegistered<TopicManagementController>()
            ? Get.find<TopicManagementController>()
            : Get.put(TopicManagementController());

        EditTopicDialog.show(
          context: context,
          topic: currentTopic,
          channelId: currentTopic.channelId ?? '',
          isDarkMode: true,
          controller: topicManagementController,
        );
      },
      icon: Icon(
        isRejected ? Icons.refresh_rounded : Icons.edit_rounded,
        size: 14,
        color: isRejected ? Colors.black : Colors.white,
      ),
      label: Text(
        isRejected ? 'Edit & Resubmit' : 'Edit',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isRejected ? Colors.black : Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isRejected
            ? AppColors.warning
            : Colors.white.withValues(alpha: 0.15),
        foregroundColor: isRejected ? Colors.black : Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isRejected
              ? BorderSide.none
              : BorderSide(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 0.8,
                ),
        ),
      ),
    );
  }

  /// Share Icon Button Box
  Widget _buildShareButton(Topic currentTopic) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.8,
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.reply_rounded,
          color: Colors.white,
          size: 17,
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          final topicUrl = DeepLinkService.topicUrl(currentTopic.slug);
          final currentFollowerCount =
              _followingTopicsController.getFollowerCount(currentTopic);
          ShareBottomSheet.show(
            title: currentTopic.name,
            url: topicUrl,
            thumbnailUrl: currentTopic.coverImage ?? currentTopic.thumbnailUrl,
            followerCount: currentFollowerCount,
            videoCount: currentTopic.videoCount,
            handle: currentTopic.slug,
            type: 'topic',
          );
        },
      ),
    );
  }
}

/// Section Header matching Channel Creation design system
class TopicSectionHeader extends StatelessWidget {
  const TopicSectionHeader({
    super.key,
    this.title = 'Topics',
    this.subtitle = 'Explore topics you love and discover new ones.',
    this.onViewAllTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onViewAllTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (onViewAllTap != null) ...[
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: onViewAllTap,
            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 16),
            label: const Text(
              'View all topics',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF18181B),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: const BorderSide(color: AppColors.bgSurface),
            ),
          ),
        ],
      ],
    );
  }
}

/// Responsive Topic Grid ensuring zero overflow errors on any screen width
class ResponsiveTopicGrid extends StatelessWidget {
  const ResponsiveTopicGrid({
    required this.topics,
    super.key,
    this.onExploreTap,
    this.onFollowToggle,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.aspectRatio,
  });

  final List<Topic> topics;
  final Function(Topic topic)? onExploreTap;
  final Function(Topic topic)? onFollowToggle;
  final bool shrinkWrap;
  final ScrollPhysics physics;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount;
        if (width >= 1200) {
          crossAxisCount = 4;
        } else if (width >= 768) {
          crossAxisCount = 3;
        } else if (width >= 480) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: physics,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.88,
          ),
          itemCount: topics.length,
          itemBuilder: (context, index) {
            final topic = topics[index];
            return TopicCardWidget(
              topic: topic,
              aspectRatio: aspectRatio,
              onExploreTap: onExploreTap != null ? () => onExploreTap!(topic) : null,
              onFollowToggle: onFollowToggle != null ? () => onFollowToggle!(topic) : null,
            );
          },
        );
      },
    );
  }
}
