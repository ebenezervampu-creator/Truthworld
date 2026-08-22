import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ==========================================================================
// YOUTUBE-STYLE THEME COLORS (EXACT MATCH WITH LIBRARY SCREEN)
// ==========================================================================

const Color bgColor = AppColors.bgPage;
const Color surfaceColor = AppColors.bgPage;
const Color cardColor = Color(0xFF1E1E1E);
const Color primaryText = AppColors.textPrimary;
const Color secondaryText = AppColors.textSecondary;
const Color accentColor = AppColors.textPrimary;
const Color buttonBg = AppColors.bgSurfaceHover;

// ==========================================================================
// RESPONSIVE BREAKPOINTS (EXACT MATCH WITH LIBRARY SCREEN)
// ==========================================================================

const double kMobileBreakpoint = 600;
const double kTabletBreakpoint = 1000;
const double kDesktopBreakpoint = 1200;

class ExploreTopicsPage extends StatefulWidget {
  const ExploreTopicsPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  State<ExploreTopicsPage> createState() => _ExploreTopicsPageState();
}

class _ExploreTopicsPageState extends State<ExploreTopicsPage>
    with TickerProviderStateMixin {
  final ExploreTopicsController controller =
      Get.isRegistered<ExploreTopicsController>()
          ? Get.find<ExploreTopicsController>()
          : Get.put(ExploreTopicsController());

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late PageController _pageController;
  final RxInt _currentTopicIndex = 0.obs;
  late Worker _topicsWorker;

  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late AnimationController _scaleAnimationController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

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

    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(
        parent: _scaleAnimationController,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimationController.forward();
    _slideAnimationController.forward();
    _scaleAnimationController.forward();
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _scaleAnimationController.dispose();
    _topicsWorker.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: _buildResponsiveLayout(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponsiveLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
        final isTablet =
            constraints.maxWidth >= kMobileBreakpoint &&
            constraints.maxWidth < kDesktopBreakpoint;
        final isMobile = constraints.maxWidth < kMobileBreakpoint;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: (!widget.isDashboard)
              ? _buildModernAppBar(
                  context,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                )
              : null,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0),
                vertical: 16.0,
              ),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  if (widget.isDashboard)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          children: [
                            Text(
                              'Explore Topics',
                              style: TextStyle(
                                fontSize: isDesktop ? 32 : (isTablet ? 26 : 22),
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                            ),
                            const Spacer(),
                            _buildAppBarAction(
                              icon: Icons.refresh_rounded,
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                controller.initialFetch();
                              },
                              tooltip: 'Refresh Topics',
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Search Bar
                  SliverToBoxAdapter(child: _buildSearchBar(isMobile: isMobile)),

                  // Categories (Grid when 'all', selected header otherwise)
                  Obx(
                    () =>
                        controller.selectedCategory.value.toLowerCase() == 'all'
                        ? _buildCategoryGrid(
                            context,
                            isDesktop: isDesktop,
                            isTablet: isTablet,
                            isMobile: isMobile,
                          )
                        : _buildSelectedCategoryHeader(
                            context,
                            isTablet: isTablet,
                          ),
                  ),

                  // Filters Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: _buildFilterBar(context),
                    ),
                  ),

                  // Topics feed
                  Obx(() {
                    if (controller.isLoading && controller.topics.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _buildLoadingState(
                          isMobile: isMobile,
                          isTablet: isTablet,
                          isDesktop: isDesktop,
                        ),
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
                          return _buildTopicVideoSection(
                            context,
                            topic,
                            isMobile: isMobile,
                            isTablet: isTablet,
                            isDesktop: isDesktop,
                          );
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

  PreferredSizeWidget _buildModernAppBar(
    BuildContext context, {
    bool isTablet = false,
    bool isDesktop = false,
  }) {
    return AppBar(
      backgroundColor: surfaceColor.withValues(alpha: 0.95),
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Navigator.canPop(context)
          ? Container(
              margin: const EdgeInsets.only(left: 8),
              child: _buildAppBarAction(
                icon: Icons.arrow_back_rounded,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Get.back();
                },
                tooltip: 'Back',
              ),
            )
          : null,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.textPrimary,
                  AppColors.textPrimary.withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.explore_rounded,
              color: AppColors.textPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Explore Topics',
            style: TextStyle(
              fontSize: isDesktop ? 26 : (isTablet ? 24 : 20),
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ],
      ),
      actions: [
        _buildAppBarAction(
          icon: Icons.refresh_rounded,
          onPressed: () {
            HapticFeedback.lightImpact();
            controller.initialFetch();
          },
          tooltip: 'Refresh Topics',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: buttonBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: secondaryText, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar({bool isMobile = false}) {
    final flipService = Get.find<FlipCoinService>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: buttonBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.textPrimary.withValues(alpha: 0.08),
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: primaryText, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search topics by name...',
                  hintStyle: const TextStyle(
                    color: secondaryText,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  icon: const Icon(
                    Icons.search_rounded,
                    color: secondaryText,
                    size: 20,
                  ),
                  suffixIcon: Obx(
                    () => controller.searchQuery.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: secondaryText,
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              controller.clearSearch();
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Obx(
            () => FlipCoinWidget(
              isFlipped: flipService.isTopicsFlipped.value,
              showLabel: !isMobile,
              onTap: () {
                HapticFeedback.lightImpact();
                flipService.toggleTopicsFlip();
                controller.loadTopics(reset: true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
    bool isMobile = false,
  }) {
    if (controller.isLoadingCategories.value &&
        controller.availableCategories.isEmpty) {
      return _buildCategorySkeletonGrid(
        context,
        isDesktop: isDesktop,
        isTablet: isTablet,
        isMobile: isMobile,
      );
    }
    final categories = controller.availableCategories;
    if (categories.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : (isTablet ? 3 : 4),
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

  Widget _buildCategorySkeletonGrid(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
    bool isMobile = false,
  }) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : (isTablet ? 3 : 4),
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        return Shimmer.fromColors(
          baseColor: cardColor,
          highlightColor: buttonBg,
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }, childCount: 4),
    );
  }

  Widget _buildCategoryCard(BuildContext context, TopicCategory category) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          controller.selectCategory(category.title);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.08),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: category.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  color: cardColor,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      bgColor.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    category.title,
                    style: const TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedCategoryHeader(
    BuildContext context, {
    bool isTablet = false,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _buildAppBarAction(
              icon: Icons.arrow_back_rounded,
              onPressed: () {
                HapticFeedback.lightImpact();
                controller.selectCategory('All');
              },
              tooltip: 'Back to all categories',
            ),
            const SizedBox(width: 8),
            Text(
              controller.selectedCategory.value,
              style: TextStyle(
                fontSize: isTablet ? 24 : 22,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
          ],
        ),
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
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.textPrimary : buttonBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textPrimary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.bgPage : primaryText,
                    ),
                  ),
                ),
              ),
            );
          });
        }).toList(),
      ),
    );
  }

  Widget _buildLoadingState({
    bool isMobile = false,
    bool isTablet = false,
    bool isDesktop = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHorizontalVideoSkeleton(
            isMobile: isMobile,
            isTablet: isTablet,
            isDesktop: isDesktop,
          ),
          const SizedBox(height: 24),
          _buildHorizontalVideoSkeleton(
            isMobile: isMobile,
            isTablet: isTablet,
            isDesktop: isDesktop,
          ),
        ],
      ),
    );
  }

  Widget _buildTopicVideoSection(
    BuildContext context,
    Topic topic, {
    bool isMobile = false,
    bool isTablet = false,
    bool isDesktop = false,
  }) {
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
                        color: secondaryText,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: primaryText),
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
                                ? Icons.bookmark_remove_outlined
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
            return _buildHorizontalVideoSkeleton(
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
                      color: secondaryText,
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
                return _buildHorizontalVideoCard(
                  context,
                  topic,
                  video,
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

  Widget _buildHorizontalVideoCard(
    BuildContext context,
    Topic topic,
    Video video, {
    bool isMobile = false,
    bool isTablet = false,
    bool isDesktop = false,
  }) {
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
                          color: secondaryText,
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
                IconButton(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 18,
                    color: secondaryText,
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

  Widget _buildHorizontalVideoSkeleton({
    bool isMobile = false,
    bool isTablet = false,
    bool isDesktop = false,
  }) {
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

  Widget _buildTopicsPageView(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < kMobileBreakpoint;
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
                        color: isSelected ? primaryText : secondaryText,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: primaryText.withValues(alpha: 0.5),
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
                color: bgColor.withValues(alpha: 0.5),
                border: Border.all(
                  color: primaryText.withValues(alpha: 0.15),
                ),
              ),
              child: Icon(
                isLeft
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: primaryText,
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
            const Text(
              'Failed to load topics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              controller.errorMessage.isNotEmpty
                  ? controller.errorMessage
                  : 'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: secondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                controller.initialFetch();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.bgPage,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearch = controller.searchQuery.value.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearch ? Icons.search_off_rounded : Icons.explore_off_rounded,
              color: secondaryText,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              isSearch
                  ? 'No topics match "${controller.searchQuery.value}"'
                  : 'No topics available',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: primaryText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try switching explore modes or choose a different category.',
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryText, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicPageViewShimmerWidget extends StatelessWidget {
  const _TopicPageViewShimmerWidget();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < kMobileBreakpoint;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Shimmer.fromColors(
        baseColor: cardColor,
        highlightColor: buttonBg,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 24.0 : 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 100,
                height: 20,
                decoration: BoxDecoration(
                  color: primaryText,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Container(
                width: isMobile ? 200 : 400,
                height: isMobile ? 28 : 40,
                decoration: BoxDecoration(
                  color: primaryText,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 150,
                height: 16,
                decoration: BoxDecoration(
                  color: primaryText,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(height: 16),
                Container(
                  width: 300,
                  height: 14,
                  decoration: BoxDecoration(
                    color: primaryText,
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
                      color: primaryText,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 100,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primaryText,
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
