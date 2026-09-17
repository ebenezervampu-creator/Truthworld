import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
import 'package:truthworld/features/topics/presentation/controllers/topic_interaction_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Unified Responsive Topic Card Widget matching exact Channel Creation page fonts and theme architecture.
/// Guarantees zero overflow errors across Mobile, Tablet, and Desktop.
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

  final RxBool _isHovered = false.obs;

  FollowingTopicsController get _followingTopicsController =>
      Get.find<FollowingTopicsController>();

  TopicInteractionController? get _interactionController {
    if (topic == null || topic!.id.trim().isEmpty) return null;
    final ctrl = Get.isRegistered<TopicInteractionController>(tag: topic!.id)
        ? Get.find<TopicInteractionController>(tag: topic!.id)
        : Get.put(TopicInteractionController(), tag: topic!.id);
    ctrl.initializeTopic(topic!);
    return ctrl;
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

    final isOwner =
        showEditOption &&
        Get.isRegistered<AuthService>() &&
        ((currentTopic.channelId != null &&
                currentTopic.channelId!.isNotEmpty &&
                AuthService.to.userChannel?.id == currentTopic.channelId) ||
            (currentTopic.creatorId != null &&
                currentTopic.creatorId!.isNotEmpty &&
                AuthService.to.uid == currentTopic.creatorId));

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.hasBoundedHeight;

        final Widget coverImageWidget = ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Obx(
                () => AnimatedScale(
                  scale: _isHovered.value ? 1.04 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: _buildCoverImage(currentTopic),
                ),
              ),
              if (trailing != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: trailing!,
                ),
            ],
          ),
        );

        final topPortion = hasBoundedHeight
            ? Expanded(child: coverImageWidget)
            : AspectRatio(
                aspectRatio: 16 / 9,
                child: coverImageWidget,
              );

        return MouseRegion(
          onEnter: (_) {
            if (!_isHovered.value) {
              _isHovered.value = true;
            }
          },
          onExit: (_) {
            if (_isHovered.value) {
              _isHovered.value = false;
            }
          },
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
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161618),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF27272A),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:
                    hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  // 1. TOP PORTION: Cover Thumbnail Image
                  topPortion,

                  // 2. BOTTOM PORTION: Card Content (Title, Stats Line, Action Buttons Row)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        Text(
                          currentTopic.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        // Stats Row (Video Count & Followers Count)
                        Row(
                          children: [
                            const Icon(
                              Icons.play_circle_outline_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${FormatUtils.formatCount(currentTopic.videoCount)} Videos',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '•',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.people_outline_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Obx(() {
                                final count = _followingTopicsController
                                    .getFollowerCount(currentTopic);
                                return Text(
                                  '${FormatUtils.formatCount(count)} Followers',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              }),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Action Buttons Row (Follow Button & Share Button)
                        Row(
                          children: [
                            // Follow / Following / Edit Button
                            Expanded(
                              child: isOwner && showEditOption
                                  ? _buildEditButton(currentTopic)
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
        color: Color(0xFF18181B),
      ),
      child: const Center(
        child: Icon(Icons.topic_rounded, color: Colors.white, size: 36),
      ),
    );
  }

  /// Follow Action Button
  Widget _buildFollowButton(Topic currentTopic) {
    return Obx(() {
      final isFollowed = _followingTopicsController.isTopicFollowed(currentTopic.id);

      return ElevatedButton.icon(
        onPressed: onFollowToggle ??
            () {
              _followingTopicsController.toggleFollowTopic(currentTopic);
            },
        icon: Icon(
          isFollowed ? Icons.check_rounded : Icons.add_rounded,
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
              ? const Color(0xFF18181B)
              : Colors.white,
          foregroundColor: isFollowed ? Colors.white : Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isFollowed
                  ? const Color(0xFF27272A)
                  : Colors.transparent,
            ),
          ),
        ),
      );
    });
  }

  /// Edit Action Button (for topic creator / owner)
  Widget _buildEditButton(Topic currentTopic) {
    return ElevatedButton.icon(
      onPressed: () {
        final topicManagementController = Get.isRegistered<TopicManagementController>()
            ? Get.find<TopicManagementController>()
            : Get.put(TopicManagementController());

        Get.dialog(
          EditTopicDialog(
            topic: currentTopic,
            channelId: currentTopic.channelId ?? '',
            isDarkMode: true,
            controller: topicManagementController,
          ),
        );
      },
      icon: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
      label: const Text(
        'Edit',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF18181B),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
      ),
    );
  }

  /// Share Icon Button Box
  Widget _buildShareButton(Topic currentTopic) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF27272A),
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.share_outlined,
          color: Colors.white,
          size: 16,
        ),
        onPressed: () {
          final topicUrl = DeepLinkService.topicUrl(currentTopic.slug);
          final currentFollowerCount =
              _followingTopicsController.getFollowerCount(currentTopic);
          ShareBottomSheet.show(
            title: currentTopic.title,
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
              side: const BorderSide(color: Color(0xFF27272A)),
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
  });

  final List<Topic> topics;
  final Function(Topic topic)? onExploreTap;
  final Function(Topic topic)? onFollowToggle;
  final bool shrinkWrap;
  final ScrollPhysics physics;

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
              onExploreTap: onExploreTap != null ? () => onExploreTap!(topic) : null,
              onFollowToggle: onFollowToggle != null ? () => onFollowToggle!(topic) : null,
            );
          },
        );
      },
    );
  }
}
