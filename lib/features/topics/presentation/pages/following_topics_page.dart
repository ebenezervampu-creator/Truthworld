import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class FollowingTopicsPage extends StatefulWidget {
  const FollowingTopicsPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  State<FollowingTopicsPage> createState() => _FollowingTopicsPageState();
}

class _FollowingTopicsPageState extends State<FollowingTopicsPage> {
  final FollowingTopicsController controller =
      Get.isRegistered<FollowingTopicsController>()
          ? Get.find<FollowingTopicsController>()
          : Get.put(FollowingTopicsController());
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      controller.updateSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshFollowingTopics() async {
    await controller.fetchFollowingTopics();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top Header (Back button + Search bar only)
            SliverToBoxAdapter(child: _buildHeader(isMobile)),

            // Horizontal Topic Pills (Chips)
            SliverToBoxAdapter(child: _buildTopicPills()),

            // Saved Topics Horizontal Video Content
            Obx(() {
              if (!AuthService.to.isAuthenticated.value) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildAuthRequiredState(),
                );
              }

              if (controller.isLoading) {
                return SliverToBoxAdapter(
                  child: _buildLoadingState(isMobile, isTablet),
                );
              }

              if (controller.errorMessage.isNotEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(),
                );
              }

              var topics = List<Topic>.from(controller.followedTopics);

              // Filter by search query if active
              if (controller.searchQuery.value.isNotEmpty) {
                topics = topics.where((t) {
                  return t.title.toLowerCase().contains(
                    controller.searchQuery.value.toLowerCase(),
                  );
                }).toList();
              }

              if (topics.isEmpty) {
                if (controller.searchQuery.value.isNotEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildNoResultsWidget(),
                  );
                }
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyStateWidget(context),
                );
              }

              // Display active selected topic or all topics
              final selectedTopic = controller.selectedTopic.value;
              var displayTopics = topics;
              if (selectedTopic != null &&
                  topics.any((t) => t.id == selectedTopic.id)) {
                displayTopics = [selectedTopic];
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final topic = displayTopics[index];
                    return _buildTopicVideoSection(context, topic, isMobile);
                  },
                  childCount: displayTopics.length,
                ),
              );
            }),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () {
              if (widget.isDashboard) {
                Get.find<HomeController>().sideNavSelectedIndex.value =
                    HomeController.indexLibrary;
              } else {
                Get.back<void>();
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search followed topics...',
                hintStyle: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, child) {
                    if (value.text.isNotEmpty) {
                      return IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          controller.updateSearchQuery('');
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                filled: true,
                fillColor: const Color(0xFF272727),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildTopicPills() {
    return Obx(() {
      final topics = controller.followedTopics;
      if (topics.isEmpty) return const SizedBox.shrink();

      final selected = controller.selectedTopic.value;

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
                  onTap: () => controller.selectTopic(null),
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
                    controller.selectTopic(topic);
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

  Widget _buildTopicVideoSection(
    BuildContext context,
    Topic topic,
    bool isMobile,
  ) {
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
                  } else if (value == 'unfollow') {
                    controller.toggleFollowTopic(topic);
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
                    value: 'unfollow',
                    child: Row(
                      children: [
                        Icon(
                          Icons.bookmark_remove_outlined,
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
            return _buildHorizontalVideoSkeleton(isMobile);
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
                return _buildHorizontalVideoCard(
                  context,
                  topic,
                  video,
                  isMobile,
                  cardWidth,
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

  Widget _buildHorizontalVideoCard(
    BuildContext context,
    Topic topic,
    Video video,
    bool isMobile,
    double cardWidth,
  ) {
    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Thumbnail
          GestureDetector(
            onTap: () {
              MiniplayerNavigationHelper.navigateToVideoScreen(
                video: video,
                routeArguments: {
                  'video': video,
                  'heroTag': 'saved_topic_${topic.id}_${video.id}',
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

                // Topic Badge (Navigates to Topics Page)
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
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.topic_rounded,
                            color: Colors.white,
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

                // Fact Checked Badge (if applicable)
                if (video.isFactChecked)
                  Positioned(
                    top: 36,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: AppColors.textPrimary,
                            size: 10,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Fact Checked',
                            style: TextStyle(
                              color: AppColors.textPrimary,
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
                      color: AppColors.bgPage.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Video Title & Options Menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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

          // Channel Name
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

          // Views & Upload Time
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

  Widget _buildHorizontalVideoSkeleton(bool isMobile) {
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

  Widget _buildLoadingState(bool isMobile, bool isTablet) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHorizontalVideoSkeleton(isMobile),
          const SizedBox(height: 24),
          _buildHorizontalVideoSkeleton(isMobile),
        ],
      ),
    );
  }

  Widget _buildAuthRequiredState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_person_rounded,
              color: AppColors.textTertiary,
              size: 80,
            ),
            SizedBox(height: 16),
            Text(
              'Sign In Required',
              style: TextStyle(
                fontSize: 20,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please authenticate to follow topics and view saved topic feeds.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              controller.errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshFollowingTopics,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: AppColors.textPrimary,
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateWidget(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF272727),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                size: 50,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No followed topics yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Follow dynamic semantic interest graphs and curated trends to personalize your platform feed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Get.toNamed<void>('/explore-topics'),
              icon: const Icon(
                Icons.explore_rounded,
                color: AppColors.bgPage,
                size: 18,
              ),
              label: const Text(
                'Explore Topics',
                style: TextStyle(
                  color: AppColors.bgPage,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.bgPage,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF272727),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 50,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No topics found',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your search terms',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
