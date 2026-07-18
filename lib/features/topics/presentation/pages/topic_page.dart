import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/related_topics_widget.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_comments_section.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_hero_widget.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_video_grid.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Topic Page - /topic/:slug
///
/// Displays:
/// - Topic hero with cover image
/// - Search bar & Sort/View controls
/// - Featured video section
/// - Contributing channels list
/// - Video grid/list with infinite scroll
/// - Related topics
/// - Premium comments and replies
///
/// Responsive: desktop, tablet, mobile
class TopicPage extends StatefulWidget {
  final String? slug;

  const TopicPage({super.key, this.slug});

  @override
  State<TopicPage> createState() => _TopicPageState();
}

class _TopicPageState extends State<TopicPage> {
  final TopicController controller = Get.put(TopicController());
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupInfiniteScroll();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setupInfiniteScroll() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 500) {
        controller.loadMoreVideos();
      }
    });
  }

  void _navigateToChannel(String? channelId) async {
    if (channelId == null || channelId.isEmpty) return;
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
        barrierDismissible: false,
      );
      final doc = await FirebaseFirestore.instance
          .collection('channels')
          .doc(channelId)
          .get();
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      if (doc.exists) {
        final channel = Channel.fromDocumentSnapshot(doc);
        Get.toNamed(channel.channelRoute, arguments: {'channel': channel});
      } else {
        Get.snackbar('Error', 'Channel not found');
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      debugPrint('Error navigating to channel: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 1024;
    final bool isTablet = size.width >= 768 && size.width < 1024;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Obx(() {
        if (controller.isLoading.value && controller.videos.isEmpty) {
          return _buildLoadingState(isDesktop, isTablet);
        }

        if (controller.hasError.value) {
          return _buildErrorState();
        }

        return CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar
            _buildSliverAppBar(isDesktop, isTablet),

            // Hero Section
            SliverToBoxAdapter(
              child: TopicHeroWidget(
                topic: controller.topic.value,
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
            ),

            // Search Bar (if visible)
            SliverToBoxAdapter(
              child: Obx(() => controller.isSearchVisible.value
                  ? Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 48 : (isTablet ? 32 : 16),
                        vertical: 16,
                      ),
                      child: _buildSearchBar(context, isDesktop: isDesktop, isTablet: isTablet),
                    )
                  : const SizedBox.shrink()),
            ),

            // Featured Video Section
            if (controller.featuredVideos.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildFeaturedSection(isDesktop, isTablet),
              ),

            // Contributing Channels List
            SliverToBoxAdapter(
              child: _buildContributingChannelsSection(isDesktop, isTablet),
            ),

            // Related Topics
            if (controller.relatedTopics.isNotEmpty)
              SliverToBoxAdapter(
                child: RelatedTopicsWidget(
                  topics: controller.relatedTopics,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                ),
              ),

            // Video Grid / List
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 48 : (isTablet ? 32 : 16),
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildVideosHeaderRow(isDesktop, isTablet),
                    const SizedBox(height: 12),
                    _buildTopicFilterTabs(),
                    const SizedBox(height: 16),
                    Obx(() {
                      String emptyTitle = 'No videos yet';
                      String emptySubtitle = 'Videos related to this topic will appear here';
                      if (controller.selectedTab.value == 'From Subscribed channels') {
                        emptyTitle = 'No subscribed videos';
                        emptySubtitle = 'Videos from channels you subscribe to will appear here';
                      } else if (controller.selectedTab.value == 'Fact checked') {
                        emptyTitle = 'No fact-checked videos';
                        emptySubtitle = 'Videos with verified fact-checking will appear here';
                      }

                      return TopicVideoGrid(
                        videos: controller.filteredVideos,
                        isLoadingMore: controller.isLoadingMore.value,
                        hasMore: controller.hasMoreVideos.value,
                        isDesktop: isDesktop,
                        isTablet: isTablet,
                        isGrid: controller.selectedView.value == 'Grid',
                        heroPrefix: 'topic_${controller.topicSlug}',
                        onLoadMore: controller.loadMoreVideos,
                        emptyTitle: emptyTitle,
                        emptySubtitle: emptySubtitle,
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Comments and Replies Section
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 48 : (isTablet ? 32 : 16),
              ),
              sliver: SliverToBoxAdapter(
                child: TopicCommentsSection(topic: controller.topic.value!),
              ),
            ),

            // Bottom padding
            SliverToBoxAdapter(
              child: SizedBox(height: isDesktop ? 64 : 32),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSliverAppBar(bool isDesktop, bool isTablet) {
    return SliverAppBar(
      floating: false,
      pinned: true,
      backgroundColor: AppColors.bgPage.withValues(alpha: 0.95),
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.topic_rounded,
            size: 20,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Obx(() => Text(
              controller.topicTitle,
              style: GoogleFonts.roboto(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: isDesktop ? 22 : 18,
              ),
              overflow: TextOverflow.ellipsis,
            )),
          ),
        ],
      ),
      actions: [
        // Search toggle
        Obx(() => IconButton(
          onPressed: () {
            controller.isSearchVisible.value = !controller.isSearchVisible.value;
            if (!controller.isSearchVisible.value) {
              _searchController.clear();
              controller.clearSearch();
            }
          },
          icon: Icon(
            controller.isSearchVisible.value ? Icons.close_rounded : Icons.search_rounded,
            color: AppColors.textPrimary,
          ),
          tooltip: 'Search Videos',
        )),
        // View toggle
        Obx(() => IconButton(
          onPressed: () {
            controller.selectedView.value =
                controller.selectedView.value == 'Grid' ? 'List' : 'Grid';
            HapticFeedback.lightImpact();
          },
          icon: Icon(
            controller.selectedView.value == 'Grid' ? Icons.view_list_rounded : Icons.grid_view_rounded,
            color: AppColors.textPrimary,
          ),
          tooltip: 'Toggle View',
        )),
        // Refresh button
        IconButton(
          onPressed: controller.refreshTopic,
          icon: const Icon(Icons.refresh_rounded),
          color: AppColors.textPrimary,
          tooltip: 'Refresh',
        ),
        SizedBox(width: isDesktop ? 24 : 8),
      ],
    );
  }

  Widget _buildSearchBar(
    BuildContext context, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.bgDivider.withValues(alpha: 0.3),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          controller.searchQuery.value = value;
        },
        style: const TextStyle(
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Search videos in this topic...',
          hintStyle: const TextStyle(
            color: AppColors.textTertiary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textTertiary,
          ),
          suffixIcon: Obx(() => controller.searchQuery.value.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textTertiary,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    controller.clearSearch();
                  },
                )
              : const SizedBox.shrink()),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFeaturedSection(bool isDesktop, bool isTablet) {
    if (controller.featuredVideos.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : (isTablet ? 32 : 16),
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Featured Content', isDesktop, isTablet),
          const SizedBox(height: 16),
          if (controller.featuredVideos.length == 1)
            _buildFeaturedCard(controller.featuredVideos.first, isDesktop, isTablet)
          else
            SizedBox(
              height: isDesktop ? 320.0 : (isTablet ? 260.0 : 200.0),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: controller.featuredVideos.length,
                itemBuilder: (context, index) {
                  final video = controller.featuredVideos[index];
                  return Container(
                    width: isDesktop ? 500.0 : (isTablet ? 380.0 : 300.0),
                    margin: const EdgeInsets.only(right: 16),
                    child: _buildFeaturedCard(video, isDesktop, isTablet),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContributingChannelsSection(bool isDesktop, bool isTablet) {
    final channels = controller.topicChannels;
    if (channels.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : (isTablet ? 32 : 16),
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Contributing Channels', isDesktop, isTablet),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: InkWell(
                    onTap: () => _navigateToChannel(channel['id']),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        UserAvatar(
                          radius: 28,
                          photoUrl: channel['avatarUrl'],
                          displayName: channel['name'] ?? '',
                          backgroundColor: AppColors.brand.withValues(alpha: 0.2),
                          textColor: AppColors.brand,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          channel['name'] ?? '',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideosHeaderRow(bool isDesktop, bool isTablet) {
    return Row(
      children: [
        Expanded(
          child: _buildSectionHeader(
            'Explore ${controller.topicTitle}',
            isDesktop,
            isTablet,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
          onPressed: () {
            controller.refreshTopic();
          },
        ),
      ],
    );
  }

  Widget _buildTopicFilterTabs() {
    return Obx(() {
      final List<String> tabs = [
        'Trending',
        'From Subscribed channels',
        'New',
        'Popular',
      ];
      if (controller.hasFactCheckedVideos) {
        tabs.add('Fact checked');
      }

      return SizedBox(
        height: 38.0,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: tabs.length,
          itemBuilder: (context, index) {
            final tab = tabs[index];
            final isSelected = controller.selectedTab.value == tab;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: () {
                  controller.selectTab(tab);
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : const Color(0xFF272727),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tab,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildFeaturedCard(dynamic video, bool isDesktop, bool isTablet) {
    final height = isDesktop ? 400.0 : (isTablet ? 300.0 : 220.0);

    return InkWell(
      onTap: () => Get.toNamed(
        '/watch?v=${video.id}',
        arguments: {
          'video': video,
          'heroTag': controller.getHeroTag(video.id),
        },
      ),
      child: Hero(
        tag: controller.getHeroTag(video.id),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radius.xl),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radius.xl),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail
                Image.network(
                  video.thumbnailUrl ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.bgSurfaceContainerHighest,
                    child: Icon(
                      Icons.videocam_off_rounded,
                      color: AppColors.textTertiary,
                      size: 48,
                    ),
                  ),
                ),

                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.bgPage.withValues(alpha: 0.8),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),

                // Content info
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Video title
                      Text(
                        video.title,
                        style: GoogleFonts.roboto(
                          fontSize: isDesktop ? 24 : (isTablet ? 20 : 18),
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Channel & meta
                      Text(
                        '${video.channelName} • ${video.views} views',
                        style: GoogleFonts.roboto(
                          fontSize: isDesktop ? 16 : 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Play button
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.textPrimary,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDesktop, bool isTablet) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(bool isDesktop, bool isTablet) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          floating: true,
          pinned: false,
          backgroundColor: AppColors.bgPage,
          title: Text(
            'Loading...',
            style: GoogleFonts.roboto(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: TopicHeroWidget(
            topic: null,
            isDesktop: isDesktop,
            isTablet: isTablet,
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 48 : (isTablet ? 32 : 16),
            vertical: 24,
          ),
          sliver: SliverToBoxAdapter(
            child: TopicVideoGridSkeleton(
              isDesktop: isDesktop,
              isTablet: isTablet,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppTokens.colors.error,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            controller.errorMessage.value,
            style: GoogleFonts.roboto(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: controller.refreshTopic,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}





