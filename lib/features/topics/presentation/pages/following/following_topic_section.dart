import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/following/following_topic_video_card.dart';
import 'package:truthworld/features/topics/presentation/pages/following/following_topics_empty_states.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_notification_options_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section representing a single followed topic, its horizontal video feed, and community posts.
class FollowingTopicSection extends StatelessWidget {
  const FollowingTopicSection({
    required this.topic,
    required this.controller,
    required this.isMobile,
    this.onTopicDetailsTap,
    super.key,
  });

  final Topic topic;
  final FollowingTopicsController controller;
  final bool isMobile;
  final void Function(Topic topic)? onTopicDetailsTap;

  void _navigateToTopicDetails() {
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
    final key = topic.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Explore Topic Header Row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _navigateToTopicDetails,
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
              Obx(() {
                final setting =
                    controller.topicNotificationSettings[topic.id] ?? 'all';
                final bellIcon = switch (setting) {
                  'personalized' => Icons.notifications_outlined,
                  'none' => Icons.notifications_off_outlined,
                  _ => Icons.notifications_active_rounded,
                };
                return IconButton(
                  icon: Icon(bellIcon, color: AppColors.textPrimary, size: 20),
                  tooltip: 'Notification options',
                  onPressed: () => TopicNotificationOptionsSheet.show(
                    context,
                    topic: topic,
                  ),
                );
              }),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                color: const Color(0xFF212121),
                onSelected: (value) {
                  if (value == 'view_topic') {
                    _navigateToTopicDetails();
                  } else if (value == 'notifications') {
                    TopicNotificationOptionsSheet.show(
                      context,
                      topic: topic,
                    );
                  } else if (value == 'unfollow') {
                    TopicNotificationOptionsSheet.showUnfollowConfirmation(
                      context,
                      topic: topic,
                      controller: controller,
                    );
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
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'unfollow',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_remove_outlined,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Unfollow Topic',
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

        // Horizontal Video Cards List
        Obx(() {
          final isLoading = controller.isLoadingVideosMap[key] ?? false;
          final videos = controller.topicVideosMap[key];

          if (isLoading && (videos == null || videos.isEmpty)) {
            return FollowingTopicsVideoSkeleton(isMobile: isMobile);
          }

          if (videos == null || videos.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: GestureDetector(
                onTap: _navigateToTopicDetails,
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
                        color: Colors.white,
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

          final screenWidth = MediaQuery.of(context).size.width;
          final isTablet = screenWidth >= 600 && screenWidth < 1024;
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
                return FollowingTopicVideoCard(
                  topic: topic,
                  video: video,
                  isMobile: isMobile,
                  cardWidth: cardWidth,
                  onTopicDetailsTap: onTopicDetailsTap,
                );
              },
            ),
          );
        }),

        // Horizontal / Vertical Community Posts Section for Topic
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
