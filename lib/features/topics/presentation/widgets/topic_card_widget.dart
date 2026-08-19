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

/// Unified Responsive Topic Card Widget matching exact mockup design architecture.
/// Guarantees zero overflow errors across Mobile, Tablet, and Desktop.
class TopicCardWidget extends StatefulWidget {
  const TopicCardWidget({
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

  @override
  State<TopicCardWidget> createState() => _TopicCardWidgetState();
}

class _TopicCardWidgetState extends State<TopicCardWidget> {
  late TopicInteractionController _interactionController;
  late final FollowingTopicsController _followingTopicsController;
  final RxBool _isHovered = false.obs;

  Topic? get topic => widget.topic;

  @override
  void initState() {
    super.initState();
    _followingTopicsController = Get.isRegistered<FollowingTopicsController>()
        ? Get.find<FollowingTopicsController>()
        : Get.put(FollowingTopicsController());

    if (widget.topic != null && widget.topic!.id.trim().isNotEmpty) {
      _initControllers(widget.topic!);
    }
  }

  void _initControllers(Topic topicItem) {
    if (topicItem.id.trim().isEmpty) return;
    _interactionController =
        Get.isRegistered<TopicInteractionController>(tag: topicItem.id)
            ? Get.find<TopicInteractionController>(tag: topicItem.id)
            : Get.put(TopicInteractionController(), tag: topicItem.id);
    _interactionController.initializeTopic(topicItem);
  }

  @override
  Widget build(BuildContext context) {
    final currentTopic = topic;
    if (currentTopic == null) return const SizedBox.shrink();

    final exploreController = Get.isRegistered<ExploreTopicsController>()
        ? Get.find<ExploreTopicsController>()
        : null;

    final isOwner =
        widget.showEditOption &&
        Get.isRegistered<AuthService>() &&
        ((currentTopic.channelId != null &&
                currentTopic.channelId!.isNotEmpty &&
                AuthService.to.userChannel?.id == currentTopic.channelId) ||
            (currentTopic.creatorId != null &&
                currentTopic.creatorId!.isNotEmpty &&
                AuthService.to.uid == currentTopic.creatorId));

    return MouseRegion(
      onEnter: (_) => _isHovered.value = true,
      onExit: (_) => _isHovered.value = false,
      child: InkWell(
        onTap: () {
          if (widget.onExploreTap != null) {
            widget.onExploreTap!();
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
            color: const Color(0xFF0F141C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP PORTION: Cover Thumbnail Image (Flexes to fill remaining height)
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Obx(() {
                        final isHovered = _isHovered.value;
                        return AnimatedScale(
                          scale: isHovered ? 1.04 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: _buildCoverImage(currentTopic),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // 2. BOTTOM PORTION: Card Content (Title, Stats Line, Action Buttons Row)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      currentTopic.title,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.15,
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
                        const SizedBox(width: 3),
                        Text(
                          '${FormatUtils.formatCount(currentTopic.videoCount)} Videos',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: Text(
                            '•',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.people_outline_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '${FormatUtils.formatCount(currentTopic.followerCount)} Followers',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Action Buttons Row (Follow Button & Share Button)
                    Row(
                      children: [
                        // Follow / Following / Edit Button
                        Expanded(
                          child: isOwner && widget.showEditOption
                              ? _buildEditButton(currentTopic)
                              : _buildFollowButton(currentTopic),
                        ),

                        const SizedBox(width: 6),

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
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
        onPressed: widget.onFollowToggle ??
            () {
              _followingTopicsController.toggleFollowTopic(currentTopic);
            },
        icon: Icon(
          isFollowed ? Icons.check_rounded : Icons.add_rounded,
          size: 14,
          color: Colors.white,
        ),
        label: Text(
          isFollowed ? 'Following' : 'Follow',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowed
              ? const Color(0xFF1E293B)
              : const Color(0xFF1A2232),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isFollowed
                  ? const Color(0xFF38BDF8)
                  : Colors.white.withValues(alpha: 0.12),
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
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
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
        color: const Color(0xFF1A2232),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
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
          ShareBottomSheet.show(
            title: currentTopic.title,
            url: topicUrl,
            thumbnailUrl: currentTopic.coverImage ?? currentTopic.thumbnailUrl,
            followerCount: currentTopic.followerCount,
            videoCount: currentTopic.videoCount,
            handle: currentTopic.slug,
            type: 'topic',
          );
        },
      ),
    );
  }
}

/// Section Header matching mockup (Title: "Topics", Subtitle: "Explore topics you love...", Button: "View all topics >")
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
                style: AppTextStyles.headlineSmall.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
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
