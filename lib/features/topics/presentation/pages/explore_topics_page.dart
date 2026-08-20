import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/ui/flip_coin_widget.dart';
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/models/topic_categories.dart';
import 'package:truthworld/features/topics/presentation/controllers/explore_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_card_widget.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class ExploreTopicsPage extends StatefulWidget {
  const ExploreTopicsPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  State<ExploreTopicsPage> createState() => _ExploreTopicsPageState();
}

class _ExploreTopicsPageState extends State<ExploreTopicsPage> {
  final ExploreTopicsController controller =
      Get.isRegistered<ExploreTopicsController>()
          ? Get.find<ExploreTopicsController>()
          : Get.put(ExploreTopicsController());

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late PageController _pageController;
  final RxInt _currentTopicIndex = 0.obs;
  late Worker _topicsWorker;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _pageController.addListener(() {
      if (_pageController.hasClients) {
        final page = _pageController.page ?? 0.0;
        final index = page.round();
        if (_currentTopicIndex.value != index) {
          _currentTopicIndex.value = index;
        }
        if (page >= controller.topics.length - 2) {
          controller.loadMoreTopics();
        }
      }
    });

    _topicsWorker = ever(controller.topics, (_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
        _currentTopicIndex.value = 0;
      }
    });

    _searchController.addListener(() {
      controller.updateSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _topicsWorker.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        const backgroundColor = AppColors.bgPage;
        const textColor = AppColors.textPrimary;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: (context.isMobile && !widget.isDashboard)
              ? AppBar(
                  title: const Text(
                    'Explore Topics',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: Get.back,
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: controller.initialFetch,
                    ),
                    const SizedBox(width: 16),
                  ],
                )
              : null,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(context.layoutSpacing),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  if (!context.isMobile || widget.isDashboard)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          children: [
                            const Text(
                              'Explore Topics',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.refresh_rounded,
                                color: AppColors.textPrimary,
                              ),
                              onPressed: controller.initialFetch,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Search Bar
                  SliverToBoxAdapter(child: _buildSearchBar()),

                  // Categories (Grid when 'all', selected header otherwise)
                  Obx(
                    () =>
                        controller.selectedCategory.value.toLowerCase() == 'all'
                        ? _buildCategoryGrid(context)
                        : _buildSelectedCategoryHeader(context),
                  ),

                  // Filters Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: _buildFilterBar(context),
                    ),
                  ),

                  // Topics feed matching FollowingTopicsPage structure
                  Obx(() {
                    if (controller.isLoading &&
                        controller.topics.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _buildLoadingState(),
                      );
                    }

                    if (controller.errorMessage.isNotEmpty &&
                        controller.topics.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Container(
                          height: 300,
                          alignment: Alignment.center,
                          child: _buildErrorState(),
                        ),
                      );
                    }

                    if (controller.topics.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Container(
                          height: 300,
                          alignment: Alignment.center,
                          child: _buildEmptyState(),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final topic = controller.topics[index];
                          return _buildTopicVideoSection(context, topic);
                        },
                        childCount: controller.topics.length,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    final flipService = Get.find<FlipCoinService>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search topics by name...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: Obx(
                  () => controller.searchQuery.value.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            controller.clearSearch();
                          },
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Obx(
            () => FlipCoinWidget(
              isFlipped: flipService.isTopicsFlipped.value,
              showLabel: true,
              onTap: () {
                flipService.toggleTopicsFlip();
                controller.loadTopics(reset: true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context) {
    if (controller.isLoadingCategories.value &&
        controller.availableCategories.isEmpty) {
      return _buildCategorySkeletonGrid(context);
    }
    final categories = controller.availableCategories;
    if (categories.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.isMobile
            ? 2
            : (ResponsiveContext(context).isTablet ? 3 : 4),
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final category = categories[index];
        return _buildCategoryCard(context, category);
      }, childCount: categories.length),
    );
  }

  Widget _buildCategorySkeletonGrid(BuildContext context) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.isMobile
            ? 2
            : (ResponsiveContext(context).isTablet ? 3 : 4),
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFF272727),
          highlightColor: const Color(0xFF3F3F3F),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }, childCount: 4),
    );
  }

  Widget _buildCategoryCard(BuildContext context, TopicCategory category) {
    return InkWell(
      onTap: () => controller.selectCategory(category.title),
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: category.imageUrl,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                color: AppColors.bgSurfaceHover,
              ),
            ),
            Container(
              color: AppColors.bgPage.withValues(alpha: 0.45),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  category.title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: AppColors.bgPage.withValues(alpha: 0.8),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedCategoryHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => controller.selectCategory('All'),
          ),
          Text(
            controller.selectedCategory.value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ExploreMode.values.map((mode) {
          return Obx(() {
            final isSelected = controller.exploreMode.value == mode;
            final label = mode.name.capitalizeFirst ?? mode.name;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) controller.setExploreMode(mode);
                },
                backgroundColor: AppColors.bgSurface,
                selectedColor: AppColors.brand,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          });
        }).toList(),
      ),
    );
  }

  Widget _buildLoadingState() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHorizontalVideoSkeleton(isMobile, isTablet, isDesktop),
          const SizedBox(height: 24),
          _buildHorizontalVideoSkeleton(isMobile, isTablet, isDesktop),
        ],
      ),
    );
  }

  Widget _buildTopicVideoSection(BuildContext context, Topic topic) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;
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
            16,
            isMobile ? 16 : 24,
            16,
            isMobile ? 8 : 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
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
                  child: Text(
                    'Explore ${topic.title}',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : (isTablet ? 22 : 24),
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                color: const Color(0xFF212121),
                onSelected: (value) {
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
                  } else if (value == 'toggle_follow') {
                    followingController.toggleFollowTopic(topic);
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
                            style: TextStyle(color: AppColors.textPrimary),
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
                                ? Icons.bookmark_remove_outlined
                                : Icons.bookmark_add_outlined,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isFollowed ? 'Unfollow Topic' : 'Follow Topic',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
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
            return _buildHorizontalVideoSkeleton(isMobile, isTablet, isDesktop);
          }

          if (videos == null || videos.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.ondemand_video_rounded,
                      color: AppColors.textTertiary,
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
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Check back later or tap to view details',
                            style: TextStyle(
                              color: AppColors.textSecondary,
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return _buildHorizontalVideoCard(
                  context,
                  topic,
                  video,
                  isMobile,
                  isTablet,
                  isDesktop,
                );
              },
            ),
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
    bool isTablet,
    bool isDesktop,
  ) {
    final cardWidth = isMobile ? 280.0 : (isTablet ? 320.0 : 360.0);

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () {
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

                // Fact Checked Badge (if applicable)
                if (video.isFactChecked)
                  Positioned(
                    top: 8,
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
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 15,
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
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),

            const SizedBox(height: 2),

            // Views & Upload Time
            Text(
              '${FormatUtils.formatCount(video.views)} views • ${timeago.format(video.uploadedAt.toDate())}',
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalVideoSkeleton(
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final cardWidth = isMobile ? 280.0 : (isTablet ? 320.0 : 360.0);
    final sectionHeight = isMobile ? 260.0 : (isTablet ? 290.0 : 310.0);
    return SizedBox(
      height: sectionHeight,
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

  Widget _buildTopicsPageView(BuildContext context) {
    final isMobile = context.isMobile;
    final bannerHeight = isMobile ? 360.0 : 540.0;
    final itemsCount = controller.topics.length;
    final totalPages = itemsCount + (controller.isLoadingMore.value ? 1 : 0);

    return Container(
      height: bannerHeight,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: totalPages,
            itemBuilder: (context, index) {
              if (index == itemsCount) {
                return const _TopicPageViewShimmerWidget();
              }

              final topic = controller.topics[index];
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  var pageOffset = 0.0;
                  if (_pageController.hasClients) {
                    try {
                      pageOffset = _pageController.page! - index;
                    } catch (_) {
                      pageOffset = 0.0;
                    }
                  }

                  // Awesome transition effects
                  final scale = (1 - (pageOffset.abs() * 0.12)).clamp(
                    0.88,
                    1.0,
                  );
                  final opacity = (1 - (pageOffset.abs() * 0.4)).clamp(
                    0.0,
                    1.0,
                  );

                  return Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: _buildTopicCardItem(context, topic, pageOffset),
                    ),
                  );
                },
              );
            },
          ),

          // Navigation Buttons (Desktop only or large tablets)
          if (!isMobile && itemsCount > 1) ...[
            _buildNavButton(
              isLeft: true,
              onTap: () {
                if (_pageController.hasClients) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOutCubic,
                  );
                }
              },
            ),
            _buildNavButton(
              isLeft: false,
              onTap: () {
                if (_pageController.hasClients) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOutCubic,
                  );
                }
              },
            ),
          ],

          // Page Indicators
          if (itemsCount > 1)
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Obx(() {
                final currentIndex = _currentTopicIndex.value;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(itemsCount, (index) {
                    final isSelected = currentIndex == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isSelected ? 32 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.textPrimary.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildNavButton({required bool isLeft, required VoidCallback onTap}) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: isLeft ? 24 : null,
      right: isLeft ? null : 24,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bgPage.withValues(alpha: 0.5),
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.15),
                ),
              ),
              child: Icon(
                isLeft
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: AppColors.textPrimary,
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopicCardItem(
    BuildContext context,
    Topic topic,
    double pageOffset,
  ) {
    return TopicCardWidget(topic: topic);
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.brand.withValues(alpha: 0.3),
            AppColors.brand.withValues(alpha: 0.15),
            AppColors.bgPage,
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
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: controller.initialFetch,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearch = controller.searchQuery.value.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearch ? Icons.search_off_rounded : Icons.hub_outlined,
            color: AppColors.textTertiary,
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            isSearch
                ? 'No topics match "${controller.searchQuery.value}"'
                : 'No topics available under this Category',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try switching explore modes or explore different categories.',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _TopicPageViewShimmerWidget extends StatelessWidget {
  const _TopicPageViewShimmerWidget();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
        ),
      ),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF161618),
        highlightColor: const Color(0xFF28282C),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 24.0 : 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 100,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Container(
                width: isMobile ? 200 : 400,
                height: isMobile ? 28 : 40,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 150,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(height: 16),
                Container(
                  width: 300,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 100,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 100,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
