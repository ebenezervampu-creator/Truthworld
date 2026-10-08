import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_constants.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_notification_options_sheet.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Topic video strip section showing topic header row and a horizontal
/// scrollable list of videos associated with the topic.
class ExploreTopicVideoSection extends StatelessWidget {
  const ExploreTopicVideoSection({
    required this.topic,
    super.key,
    this.isMobile = false,
    this.isTablet = false,
    this.isDesktop = false,
  });

  final Topic topic;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ExploreTopicsController>();
    final key = topic.id;
    final followingController = Get.isRegistered<FollowingTopicsController>()
        ? Get.find<FollowingTopicsController>()
        : Get.put(FollowingTopicsController());

    final sectionHeight = isMobile ? 260.0 : (isTablet ? 290.0 : 310.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Explore Topic Header Row
        Padding(
          padding: EdgeInsets.fromLTRB(
            4,
            isMobile ? 16 : 24,
            4,
            isMobile ? 8 : 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    controller.preloadTopicDetails(topic);
                    Get.toNamed<void>(
                      topic.topicRoute,
                      arguments: {
                        'slug': topic.slug,
                        'fromCard': true,
                        'topic': topic,
                      },
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Explore ${topic.title}',
                          style: TextStyle(
                            fontSize: isMobile ? 18 : (isTablet ? 22 : 24),
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textPrimary,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: AppColors.textPrimary.withValues(alpha: 0.08),
                  ),
                ),
                onSelected: (value) {
                  HapticFeedback.lightImpact();
                  if (value == 'view_topic') {
                    controller.preloadTopicDetails(topic);
                    Get.toNamed<void>(
                      topic.topicRoute,
                      arguments: {
                        'slug': topic.slug,
                        'fromCard': true,
                        'topic': topic,
                      },
                    );
                  } else if (value == 'notifications') {
                    TopicNotificationOptionsSheet.show(
                      context,
                      topic: topic,
                    );
                  } else if (value == 'toggle_follow') {
                    if (followingController.isTopicFollowed(topic.id)) {
                      TopicNotificationOptionsSheet.showUnfollowConfirmation(
                        context,
                        topic: topic,
                        controller: followingController,
                      );
                    } else {
                      followingController.toggleFollowTopic(topic);
                    }
                  }
                },
                itemBuilder: (context) {
                  final isFollowed = followingController.isTopicFollowed(
                    topic.id,
                  );
                  return [
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
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isFollowed)
                      const PopupMenuItem(
                        value: 'notifications',
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_outlined,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Notification Options',
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'toggle_follow',
                      child: Row(
                        children: [
                          Icon(
                            isFollowed
                                ? Icons.person_remove_outlined
                                : Icons.bookmark_add_outlined,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isFollowed ? 'Unfollow Topic' : 'Follow Topic',
                            style: const TextStyle(
                              color: primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),

        // Horizontal Video Cards List
        Obx(() {
          final isLoading = controller.isLoadingVideosMap[key] ?? false;
          final videos = controller.topicVideosMap[key];

          if (isLoading && (videos == null || videos.isEmpty)) {
            return HorizontalVideoSkeleton(
              isMobile: isMobile,
              isTablet: isTablet,
              isDesktop: isDesktop,
            );
          }

          if (videos == null || videos.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.textPrimary.withValues(alpha: 0.08),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.ondemand_video_rounded,
                      color: AppColors.textPrimary,
                      size: 36,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No videos found for this topic',
                            style: TextStyle(
                              color: primaryText,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Check back later or tap to view details',
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return SizedBox(
            height: sectionHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return HorizontalVideoCard(
                  topic: topic,
                  video: video,
                  isMobile: isMobile,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

/// Horizontal video card with thumbnail, duration badge, fact-checked badge,
/// and video metadata.
class HorizontalVideoCard extends StatelessWidget {
  const HorizontalVideoCard({
    required this.topic,
    required this.video,
    super.key,
    this.isMobile = false,
    this.isTablet = false,
    this.isDesktop = false,
  });

  final Topic topic;
  final Video video;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final cardWidth = isMobile ? 280.0 : (isTablet ? 320.0 : 360.0);

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          MiniplayerNavigationHelper.navigateToVideoScreen(
            video: video,
            routeArguments: {
              'video': video,
              'heroTag': 'explore_topic_${topic.id}_${video.id}',
            },
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Thumbnail
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: buttonBg,
                      ),
                      errorWidget: (context, url, error) => const ColoredBox(
                        color: cardColor,
                        child: Icon(
                          Icons.videocam_off_rounded,
                          color: AppColors.textPrimary,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),

                // Fact Checked Badge (if applicable)
                if (video.isFactChecked)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successContainer,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.success),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: Colors.white,
                            size: 11,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Fact Checked',
                            style: TextStyle(
                              color: AppColors.success,
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
                      color: bgColor.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: primaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Video Title & Options Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: isMobile ? 38 : 40,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 15,
                          fontWeight: FontWeight.w600,
                          color: primaryText,
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
                    color: AppColors.textPrimary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    VideoOptionsSheet.show(context, video);
                  },
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Channel Name
            Text(
              video.channelName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: secondaryText,
                fontWeight: FontWeight.w400,
              ),
            ),

            const SizedBox(height: 2),

            // Views & Upload Time
            Text(
              '${FormatUtils.formatCount(video.views)} views • ${timeago.format(video.uploadedAt.toDate())}',
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer skeleton loader for horizontal video card rows.
class HorizontalVideoSkeleton extends StatelessWidget {
  const HorizontalVideoSkeleton({
    super.key,
    this.isMobile = false,
    this.isTablet = false,
    this.isDesktop = false,
  });

  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final cardWidth = isMobile ? 280.0 : (isTablet ? 320.0 : 360.0);
    final sectionHeight = isMobile ? 260.0 : (isTablet ? 290.0 : 310.0);

    return SizedBox(
      height: sectionHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            width: cardWidth,
            margin: const EdgeInsets.only(right: 16),
            child: Shimmer.fromColors(
              baseColor: cardColor,
              highlightColor: buttonBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 140,
                    height: 12,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
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
