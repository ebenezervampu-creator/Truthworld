import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_state_widgets.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Shimmer skeleton loader for horizontal video card rows.
class ChannelHorizontalVideoSkeleton extends StatelessWidget {
  const ChannelHorizontalVideoSkeleton({super.key, this.isMobile = false});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final cardWidth = isMobile ? 280.0 : 320.0;

    return SizedBox(
      height: isMobile ? 260 : 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            width: cardWidth,
            margin: const EdgeInsets.only(right: 16),
            child: Shimmer.fromColors(
              baseColor: const Color(0xFF272727),
              highlightColor: const Color(0xFF3F3F3F),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 14,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 140,
                    height: 12,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 100,
                    height: 12,
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Horizontal video card displayed under a topic section.
class ChannelHorizontalVideoCard extends StatelessWidget {
  const ChannelHorizontalVideoCard({
    required this.topic,
    required this.video,
    required this.cardWidth,
    super.key,
    this.isMobile = false,
  });

  final Topic topic;
  final Video video;
  final bool isMobile;
  final double cardWidth;

  void _navigateToTopicDetails(Topic topic) {
    Get.toNamed<void>(
      topic.topicRoute,
      arguments: {
        'slug': topic.slug,
        'fromCard': true,
        'topic': topic,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              MiniplayerNavigationHelper.navigateToVideoScreen(
                video: video,
                routeArguments: {
                  'video': video,
                  'heroTag': 'channel_topic_${topic.id}_${video.id}',
                  'fromTopic': true,
                  'topic': topic,
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
                Positioned(
                  top: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () => _navigateToTopicDetails(topic),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.topic_rounded,
                            color: AppColors.textPrimary,
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (video.isFactChecked) ...[
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF00E676),
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          video.duration,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: Align(
                    alignment: Alignment.topLeft,
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

/// Horizontal scrolling topic pill filter chips.
class ChannelTopicPills extends GetView<ChannelController> {
  const ChannelTopicPills({
    required this.topics,
    super.key,
  });

  final List<Topic> topics;

  void _navigateToTopicDetails(Topic topic) {
    Get.toNamed<void>(
      topic.topicRoute,
      arguments: {
        'slug': topic.slug,
        'fromCard': true,
        'topic': topic,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.selectedChannelTopic.value;

      return Container(
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: topics.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              final isAllSelected = selected == null;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => controller.selectChannelTopic(null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isAllSelected
                          ? AppColors.textPrimary
                          : const Color(0xFF272727),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'All Topics',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isAllSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isAllSelected
                            ? AppColors.bgPage
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }

            final topic = topics[index - 1];
            final isSelected = selected?.id == topic.id;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  if (isSelected) {
                    _navigateToTopicDetails(topic);
                  } else {
                    controller.selectChannelTopic(topic);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  constraints: const BoxConstraints(maxWidth: 240),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.textPrimary
                        : const Color(0xFF272727),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          topic.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.bgPage
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: AppColors.bgPage,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

/// A section displaying a topic header, horizontal video carousel, and community posts.
class ChannelTopicVideoSection extends GetView<ChannelController> {
  const ChannelTopicVideoSection({
    required this.topic,
    super.key,
    this.isMobile = false,
    this.isTablet = false,
  });

  final Topic topic;
  final bool isMobile;
  final bool isTablet;

  void _navigateToTopicDetails(Topic topic) {
    Get.toNamed<void>(
      topic.topicRoute,
      arguments: {
        'slug': topic.slug,
        'fromCard': true,
        'topic': topic,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = topic.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _navigateToTopicDetails(topic),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          topic.title,
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                color: const Color(0xFF212121),
                onSelected: (value) {
                  if (value == 'view_topic') {
                    _navigateToTopicDetails(topic);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view_topic',
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'View Topic Details',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Obx(() {
          final isLoading = controller.isLoadingVideosMap[key] ?? false;
          final videos = controller.topicVideosMap[key];

          if (isLoading && (videos == null || videos.isEmpty)) {
            return ChannelHorizontalVideoSkeleton(isMobile: isMobile);
          }

          if (videos == null || videos.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: GestureDetector(
                onTap: () => _navigateToTopicDetails(topic),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.topic_rounded,
                        color: AppColors.textPrimary,
                        size: 36,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap to view topic details page',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final sectionHeight = isMobile ? 260.0 : (isTablet ? 290.0 : 310.0);
          final cardWidth = isMobile ? 280.0 : (isTablet ? 320.0 : 360.0);

          return SizedBox(
            height: sectionHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return ChannelHorizontalVideoCard(
                  topic: topic,
                  video: video,
                  isMobile: isMobile,
                  cardWidth: cardWidth,
                );
              },
            ),
          );
        }),

        Obx(() {
          final posts = controller.topicPostsMap[key];
          final isLoadingPosts = controller.isLoadingPostsMap[key] ?? false;

          if (isLoadingPosts && (posts == null || posts.isEmpty)) {
            return const SizedBox.shrink();
          }

          if (posts == null || posts.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.forum_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Community Posts',
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: posts.length.clamp(0, 3),
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: CommunityPostCard(post: posts[index]),
                  );
                },
              ),
            ],
          );
        }),
      ],
    );
  }
}

/// Topics Tab View for Channel Details.
class ChannelTopicsTabView extends GetView<ChannelController> {
  const ChannelTopicsTabView({
    required this.channel,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final Channel channel;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isSubscribed = controller.isSubscribed.value;
    final isOwner = currentUser != null && currentUser.uid == channel.ownerId;
    final isMobile = !isDesktop && !isTablet;

    return StreamBuilder<QuerySnapshot>(
      stream: controller.getTopicsStream(channel.channelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ChannelHorizontalVideoSkeleton(isMobile: isMobile);
        }
        if (snapshot.hasError) {
          return ChannelDetailsStateWidgets.buildErrorState(
            'Unable to load topics. Please try again.',
            () => controller.update(),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return ChannelDetailsStateWidgets.buildEmptyTabState(
            icon: Icons.topic_outlined,
            title: 'No topics yet',
            subtitle: "This channel hasn't created any topics",
          );
        }

        final topics = snapshot.data!.docs
            .map(Topic.fromDocumentSnapshot)
            .where((topic) {
              if (!topic.isValidTopic || topic.videoCount <= 0) return false;
              if (isOwner) return true;
              if (topic.visibilityType == TopicVisibilityType.public) return true;
              if (topic.visibilityType == TopicVisibilityType.channelOnly && isSubscribed) return true;
              return false;
            })
            .toList();

        topics.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (topics.isEmpty) {
          return ChannelDetailsStateWidgets.buildEmptyTabState(
            icon: Icons.topic_outlined,
            title: 'No topics yet',
            subtitle: "This channel hasn't created any topics",
          );
        }

        for (final topic in topics) {
          controller.fetchVideosForChannelTopic(topic);
          controller.fetchPostsForChannelTopic(topic);
        }

        return Obx(() {
          final selected = controller.selectedChannelTopic.value;
          var displayTopics = topics;
          if (selected != null && topics.any((t) => t.id == selected.id)) {
            displayTopics = [selected];
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChannelTopicPills(topics: topics),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayTopics.length,
                  itemBuilder: (context, index) {
                    final topic = displayTopics[index];
                    return ChannelTopicVideoSection(
                      topic: topic,
                      isMobile: isMobile,
                      isTablet: isTablet,
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        });
      },
    );
  }
}
