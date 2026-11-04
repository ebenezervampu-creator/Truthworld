import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/models/topic_categories.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_constants.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_notification_options_sheet.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Instant live search results grid for the Explore Topics overview mode.
/// Displays matched topics with relevance scoring, category tags, video counts,
/// one-tap follow toggles, and direct topic details navigation.
class ExploreTopicsSearchResults extends StatelessWidget {
  const ExploreTopicsSearchResults({
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
    this.isMobile = false,
  });

  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ExploreTopicsController>();

    return Obx(() {
      final isLoading = controller.rxIsLoading.value || controller.isAiSearching.value;
      final topics = controller.topics;
      final query = controller.searchQuery.value.trim();

      if (isLoading && topics.isEmpty) {
        return _buildSkeletonGrid();
      }

      if (topics.isEmpty) {
        return _buildEmptyState(context, controller, query);
      }

      final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);
      final childAspectRatio = isDesktop ? 1.55 : (isTablet ? 1.5 : 1.6);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Results Header
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search Results',
                        style: TextStyle(
                          fontSize: isDesktop ? 22 : (isTablet ? 20 : 18),
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${topics.length} ${topics.length == 1 ? "topic" : "topics"} matching "$query"',
                        style: const TextStyle(
                          fontSize: 13,
                          color: secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    controller.clearSearch();
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: secondaryText,
                    size: 16,
                  ),
                  label: const Text(
                    'Clear Search',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    backgroundColor: buttonBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Responsive Grid of Results
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: topics.length,
            itemBuilder: (context, index) {
              final topic = topics[index];
              return _SearchResultTopicCard(
                topic: topic,
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
                onMoreTap: () {
                  HapticFeedback.lightImpact();
                  _showTopicOptionsSheet(context, topic);
                },
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      );
    });
  }

  Widget _buildSkeletonGrid() {
    final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);
    final childAspectRatio = isDesktop ? 1.55 : (isTablet ? 1.5 : 1.6);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: cardColor,
          highlightColor: buttonBg,
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ExploreTopicsController controller,
    String query,
  ) {
    const popularCategories = ['Faith', 'Technology', 'Science', 'Education', 'Music'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: buttonBg,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: secondaryText,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            query.isNotEmpty ? 'No topics found for "$query"' : 'No topics found',
            style: const TextStyle(
              color: primaryText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Try searching for different keywords or explore popular categories below.',
            style: TextStyle(
              color: secondaryText,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Suggestion Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: popularCategories.map((cat) {
              return ActionChip(
                backgroundColor: buttonBg,
                side: BorderSide(
                  color: AppColors.textPrimary.withValues(alpha: 0.1),
                ),
                label: Text(
                  cat,
                  style: const TextStyle(color: primaryText, fontSize: 12),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  controller.selectCategory(cat);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Clear Search Button (White button MUST have black text and icon)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                controller.clearSearch();
              },
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      color: Colors.black,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Clear Search & Explore All',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTopicOptionsSheet(BuildContext context, Topic topic) {
    final followingController = Get.isRegistered<FollowingTopicsController>()
        ? Get.find<FollowingTopicsController>()
        : Get.put(FollowingTopicsController());

    final isFollowed = followingController.isTopicFollowed(topic.id);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.visibility_outlined,
                    color: primaryText,
                  ),
                  title: const Text(
                    'View Topic',
                    style: TextStyle(color: primaryText, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Get.toNamed<void>(
                      topic.topicRoute,
                      arguments: {
                        'slug': topic.slug,
                        'fromCard': true,
                        'topic': topic,
                      },
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    isFollowed
                        ? Icons.bookmark_remove_outlined
                        : Icons.bookmark_add_outlined,
                    color: primaryText,
                  ),
                  title: Text(
                    isFollowed ? 'Unfollow Topic' : 'Follow Topic',
                    style: const TextStyle(color: primaryText, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isFollowed) {
                      TopicNotificationOptionsSheet.showUnfollowConfirmation(
                        context,
                        topic: topic,
                        controller: followingController,
                      );
                    } else {
                      followingController.toggleFollowTopic(topic);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.notifications_outlined,
                    color: primaryText,
                  ),
                  title: const Text(
                    'Notifications',
                    style: TextStyle(color: primaryText, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    TopicNotificationOptionsSheet.show(
                      context,
                      topic: topic,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined, color: primaryText),
                  title: const Text(
                    'Share',
                    style: TextStyle(color: primaryText, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Share.share(
                      'Check out this topic on TruthWorld: ${topic.name}\nhttps://truthworld.org${topic.topicRoute}',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchResultTopicCard extends StatelessWidget {
  const _SearchResultTopicCard({
    required this.topic,
    required this.onTap,
    required this.onMoreTap,
  });

  final Topic topic;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final followingController = Get.isRegistered<FollowingTopicsController>()
        ? Get.find<FollowingTopicsController>()
        : Get.put(FollowingTopicsController());

    final videoCount = topic.effectiveVideoCount;
    final videoCountLabel = videoCount > 0
        ? '${FormatUtils.formatCount(videoCount)} ${videoCount == 1 ? "video" : "videos"}'
        : '0 videos';

    final categoryObj = TopicCategoriesConfig.getCategory(topic.category);
    final imageUrl = topic.thumbnailUrl?.isNotEmpty == true
        ? topic.thumbnailUrl!
        : (topic.coverImage?.isNotEmpty == true
            ? topic.coverImage!
            : categoryObj.imageUrl);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.1),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Cover Thumbnail with Category & Video Badges
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: buttonBg),
                      errorWidget: (context, url, error) => const ColoredBox(
                        color: buttonBg,
                        child: Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: secondaryText,
                            size: 28,
                          ),
                        ),
                      ),
                    ),

                    // Gradient Scrim
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.5, 1.0],
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),

                    // Top Left: Category Badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          topic.category.isNotEmpty ? topic.category : 'General',
                          style: const TextStyle(
                            color: primaryText,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Top Right: Video Count Badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                              color: primaryText,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              videoCountLabel,
                              style: const TextStyle(
                                color: primaryText,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Info Card
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topic.name,
                            style: const TextStyle(
                              color: primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            topic.description.isNotEmpty
                                ? topic.description
                                : 'Explore discussions and videos in ${topic.name}',
                            style: const TextStyle(
                              color: secondaryText,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Quick Follow Button
                    Obx(() {
                      final isFollowed = followingController.isTopicFollowed(topic.id);

                      return Material(
                        color: isFollowed ? Colors.white : buttonBg,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            followingController.toggleFollowTopic(topic);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isFollowed ? Icons.check_rounded : Icons.add_rounded,
                                  color: isFollowed ? Colors.black : Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isFollowed ? 'Following' : 'Follow',
                                  style: TextStyle(
                                    color: isFollowed ? Colors.black : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    IconButton(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: secondaryText,
                        size: 18,
                      ),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: onMoreTap,
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
}
