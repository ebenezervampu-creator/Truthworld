import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/search/presentation/widgets/voice_search_dialog.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/models/topic_categories.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore/explore_topics_constants.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_notification_options_sheet.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Category Detail View displaying the exact UI of the second uploaded image:
/// - Circular back button
/// - Hero banner with background photograph, category title, count, description, and '+ Follow' button
/// - Category-specific search bar with dynamic hints
/// - Interactive filter pills: Trending, Newest, Popular
/// - 3-column responsive subtopics grid with 16:9 thumbnails, category icon, title, video count, and 3-dots menu
class ExploreCategoryDetailView extends StatelessWidget {
  const ExploreCategoryDetailView({
    required this.categoryName,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
    this.isMobile = false,
  });

  final String categoryName;
  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ExploreTopicsController>();
    final category = TopicCategoriesConfig.getCategory(categoryName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Top Circular Back Button
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  controller.selectCategory('all');
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: buttonBg,
                    border: Border.all(
                      color: AppColors.textPrimary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: primaryText,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 2. Hero Banner
        _buildHeroBanner(context, category),
        const SizedBox(height: 20),

        // 3. Category Search Bar
        _buildCategorySearchBar(context, controller, category),
        const SizedBox(height: 16),

        // 4. Filter Tabs: Trending, Newest, Popular
        _buildFilterTabs(controller),
        const SizedBox(height: 20),

        // 5. Subtopics Grid
        _buildSubtopicsGrid(controller, category),
      ],
    );
  }

  Widget _buildHeroBanner(BuildContext context, TopicCategory category) {
    final controller = Get.isRegistered<ExploreTopicsController>()
        ? Get.find<ExploreTopicsController>()
        : Get.put(ExploreTopicsController());
    final followingController = Get.isRegistered<FollowingTopicsController>()
        ? Get.find<FollowingTopicsController>()
        : Get.put(FollowingTopicsController());

    final heroHeight = isDesktop ? 260.0 : (isTablet ? 230.0 : 220.0);

    return Container(
      height: heroHeight,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Right Side Hero Artwork
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: isMobile ? 180 : (isTablet ? 320 : 440),
            child: CachedNetworkImage(
              imageUrl: category.effectiveHeroImageUrl,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
          ),

          // Gradient Mask from left dark background to transparent right
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                stops: const [0.0, 0.45, 0.75, 1.0],
                colors: [
                  cardColor,
                  cardColor.withValues(alpha: 0.95),
                  cardColor.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Bottom vertical gradient for mobile readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.5, 1.0],
                colors: [
                  Colors.transparent,
                  cardColor.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),

          // Left Hero Metadata and Follow Button
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 20,
              vertical: 20,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: isMobile ? 3 : 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Title
                      Text(
                        category.title,
                        style: TextStyle(
                          fontSize: isDesktop ? 36 : (isTablet ? 30 : 24),
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Topic Count
                      Obx(() {
                        final countText =
                            controller.getAuthenticTopicCountText(category);
                        final subtopicsCount = controller
                            .getSubtopicsForCategory(category.title)
                            .length;
                        final displayCount = countText.isNotEmpty
                            ? countText
                            : (subtopicsCount > 0
                                ? '$subtopicsCount ${subtopicsCount == 1 ? 'topic' : 'topics'}'
                                : 'Topics');

                        return Text(
                          displayCount,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: secondaryText,
                          ),
                        );
                      }),
                      const SizedBox(height: 10),

                      // Description
                      Text(
                        category.description.isNotEmpty
                            ? category.description
                            : 'Explore verified discussions and videos in ${category.title}.',
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 13,
                          color: primaryText.withValues(alpha: 0.85),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),

                      // Follow Action Button (Zero White-on-White: white background MUST have black text and icon)
                      Obx(() {
                        final isFollowed = followingController
                                .followingStates[category.id] ==
                            true ||
                            followingController.followingStates[category.title] ==
                                true;

                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              final newState = !isFollowed;
                              followingController.followingStates[category.id] =
                                  newState;
                              followingController
                                  .followingStates[category.title] = newState;

                              if (newState) {
                                AppSnackbar.success(
                                  'You are now following ${category.title}.',
                                );
                              } else {
                                AppSnackbar.info(
                                  'Unfollowed ${category.title}.',
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isFollowed
                                        ? Icons.check_rounded
                                        : Icons.add_rounded,
                                    color: Colors.black,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isFollowed ? 'Following' : 'Follow',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                if (!isMobile) const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySearchBar(
    BuildContext context,
    ExploreTopicsController controller,
    TopicCategory category,
  ) {
    final hintExamples = category.searchHintExamples.isNotEmpty
        ? category.searchHintExamples
        : '"worship", "gospel", "piano"';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: buttonBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.12),
        ),
      ),
      child: TextField(
        controller: controller.searchController,
        style: const TextStyle(color: primaryText, fontSize: 14),
        decoration: InputDecoration(
          icon: const Icon(
            Icons.search_rounded,
            color: secondaryText,
            size: 20,
          ),
          hintText: isMobile
              ? 'Search topics in ${category.title}...'
              : 'Search topics in ${category.title} (e.g. $hintExamples)...',
          hintStyle: const TextStyle(
            color: secondaryText,
            fontSize: 14,
          ),
          border: InputBorder.none,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.mic_none_rounded,
                  color: primaryText,
                  size: 20,
                ),
                tooltip: 'Voice Search',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Get.dialog(
                    VoiceSearchDialog(
                      onSearch: (query) {
                        controller.searchController.text = query;
                        controller.updateSearchQuery(query);
                      },
                    ),
                  );
                },
              ),
              Obx(
                () => controller.searchQuery.value.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: primaryText,
                          size: 20,
                        ),
                        tooltip: 'Clear',
                        onPressed: controller.clearSearch,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(ExploreTopicsController controller) {
    final categoryModes = [
      (ExploreMode.trending, 'Trending'),
      (ExploreMode.newest, 'Newest'),
      (ExploreMode.popular, 'Popular'),
    ];

    return Obx(() {
      final currentMode = controller.exploreMode.value;

      return Row(
        children: categoryModes.map((entry) {
          final mode = entry.$1;
          final label = entry.$2;
          final isSelected = currentMode == mode;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                controller.setExploreMode(mode);
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : buttonBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : AppColors.textPrimary.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.black : secondaryText,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildSubtopicsGrid(
    ExploreTopicsController controller,
    TopicCategory category,
  ) {
    return Obx(() {
      final subtopics = controller.getSubtopicsForCategory(categoryName);

      if (controller.isLoading && subtopics.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(
              color: AppColors.textPrimary,
              strokeWidth: 2.5,
            ),
          ),
        );
      }

      if (subtopics.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  color: secondaryText,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'No topics found in ${category.title}',
                  style: const TextStyle(
                    color: primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Try searching for different keywords or clear filters.',
                  style: TextStyle(color: secondaryText, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      }

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
        itemCount: subtopics.length,
        itemBuilder: (context, index) {
          final topic = subtopics[index];
          return _SubtopicCard(
            topic: topic,
            category: category,
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
      );
    });
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
                      'Check out this topic on TruthWorld: ${topic.title}\nhttps://truthworld.org${topic.topicRoute}',
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

class _SubtopicCard extends StatelessWidget {
  const _SubtopicCard({
    required this.topic,
    required this.category,
    required this.onTap,
    required this.onMoreTap,
  });

  final Topic topic;
  final TopicCategory category;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final videoCount = topic.effectiveVideoCount;
    final videoCountLabel = videoCount > 0
        ? '${FormatUtils.formatCount(videoCount)} ${videoCount == 1 ? 'video' : 'videos'}'
        : '0 videos';

    final imageUrl = topic.thumbnailUrl?.isNotEmpty == true
        ? topic.thumbnailUrl!
        : (topic.coverImage?.isNotEmpty == true
            ? topic.coverImage!
            : category.imageUrl);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.1),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover Artwork
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const ColoredBox(
                  color: cardColor,
                  child: Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: secondaryText,
                      size: 28,
                    ),
                  ),
                ),
              ),

              // Gradient Overlay at Bottom
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.45, 0.75, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.94),
                    ],
                  ),
                ),
              ),

              // Bottom Bar: Category/Music Icon + Title/Subtitle + 3-dots Menu
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Category Icon (e.g. music note for music)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Icon(
                        category.icon ?? Icons.music_note_rounded,
                        color: primaryText,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Title & Video Count
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topic.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                              letterSpacing: -0.2,
                              shadows: [
                                Shadow(
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            videoCountLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryText.withValues(alpha: 0.75),
                              shadows: const [
                                Shadow(
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // 3-dots Menu Icon
                    IconButton(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: primaryText,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
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
