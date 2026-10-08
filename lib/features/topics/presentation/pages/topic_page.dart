import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';
import 'package:truthworld/features/topics/presentation/widgets/related_topics_widget.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_comments_section.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_hero_widget.dart';
import 'package:truthworld/features/topics/presentation/widgets/topic_video_grid.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Topic Page - /topic/:slug
///
/// Redesigned to match the high-contrast modern UI:
/// - Responsive hero banner with integrated cover artwork & gradient overlay
/// - Section header indicators with white vertical accent bar
/// - Contributing channels section with electric blue ring cards
/// - Explore topic videos section with interactive filter tab pills
/// - Video cards with duration/index badges and 3-dots menus
/// - "No more videos" status card
/// - Comments section with rounded input box, image attachment icon, and thread replies
/// - Fully responsive across mobile, tablet, desktop, and ultra-wide displays
class TopicPage extends StatelessWidget {
  const TopicPage({super.key, this.slug});
  final String? slug;

  TopicController get controller => Get.find<TopicController>();
  ScrollController get _scrollController => controller.scrollController;
  TextEditingController get _searchController => controller.searchController;

  void _navigateToChannel(String? channelId) {
    if (channelId == null || channelId.isEmpty) return;
    final cached = DeepLinkService.instance.getChannelFromCache(channelId);
    if (cached != null) {
      Get.toNamed(cached.channelRoute, arguments: {'channel': cached});
    } else {
      DeepLinkService.instance.handleUrl('/channel/$channelId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 600 && size.width < 1024;
    final horizontalPadding = isDesktop ? 48.0 : (isTablet ? 24.0 : 16.0);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Obx(() {
        if (controller.rxIsLoading.value && controller.videos.isEmpty) {
          return _buildLoadingState(isDesktop, isTablet);
        }

        if (controller.hasError.value) {
          return _buildErrorState();
        }

        return CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top Sliver App Bar
            _buildSliverAppBar(isDesktop, isTablet),

            // Hero Banner Section
            SliverToBoxAdapter(
              child: TopicHeroWidget(
                topic: controller.topic.value,
                isDesktop: isDesktop,
                isTablet: isTablet,
                onCommentsTap: () {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                onCommunityTap: () {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
              ),
            ),

            // Search Bar (if activated)
            SliverToBoxAdapter(
              child: controller.isSearchVisible.value
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 12,
                          ),
                          child: _buildSearchBar(
                            context,
                            isDesktop: isDesktop,
                            isTablet: isTablet,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Contributing Channels Section
            SliverToBoxAdapter(
              child: _buildContributingChannelsSection(isDesktop, isTablet),
            ),

            // Featured Video Section (if any)
            if (controller.featuredVideos.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildFeaturedSection(isDesktop, isTablet),
              ),

            // Related Topics Section (if any)
            if (controller.relatedTopics.isNotEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: RelatedTopicsWidget(
                      topics: controller.relatedTopics,
                      isDesktop: isDesktop,
                      isTablet: isTablet,
                    ),
                  ),
                ),
              ),

            // Explore Topic Videos Section
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildVideosHeaderRow(isDesktop, isTablet),
                        const SizedBox(height: 14),
                        _buildTopicFilterTabs(),
                        const SizedBox(height: 16),
                        TopicVideoGrid(
                          videos: controller.filteredVideos,
                          isLoadingMore: controller.isLoadingMore.value,
                          hasMore: controller.hasMoreVideos.value,
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                          heroPrefix: 'topic_${controller.topicSlug}',
                          onLoadMore: controller.loadMoreVideos,
                          emptyTitle: controller.selectedTab.value == 'From Subscribed channels'
                              ? 'No subscribed videos'
                              : (controller.selectedTab.value == 'Fact checked'
                                  ? 'No fact-checked videos'
                                  : 'No videos yet'),
                          emptySubtitle: controller.selectedTab.value == 'From Subscribed channels'
                              ? 'Videos from channels you subscribe to will appear here'
                              : (controller.selectedTab.value == 'Fact checked'
                                  ? 'Videos with verified fact-checking will appear here'
                                  : 'Videos related to this topic will appear here'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Related Community Posts Section (if available)
            if (controller.relatedPosts.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Community Posts', isDesktop, isTablet),
                          const SizedBox(height: 12),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: controller.relatedPosts.length.clamp(0, 3),
                            itemBuilder: (context, index) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: CommunityPostCard(
                                  post: controller.relatedPosts[index],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Comments and Replies Section
            if (controller.topic.value != null)
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: TopicCommentsSection(topic: controller.topic.value!),
                    ),
                  ),
                ),
              ),

            // Bottom breathing room
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
      pinned: true,
      backgroundColor: AppColors.bgPage.withValues(alpha: 0.95),
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF242428).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: Get.back,
        ),
      ),
      actions: [
        Obx(
          () => IconButton(
            onPressed: () {
              controller.isSearchVisible.value =
                  !controller.isSearchVisible.value;
              if (!controller.isSearchVisible.value) {
                _searchController.clear();
                controller.clearSearch();
              }
            },
            icon: Icon(
              controller.isSearchVisible.value
                  ? Icons.close_rounded
                  : Icons.search_rounded,
              color: Colors.white,
            ),
            tooltip: 'Search Videos',
          ),
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
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF28282C),
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
          suffixIcon: Obx(
            () => controller.searchQuery.value.isNotEmpty
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
                : const SizedBox.shrink(),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedSection(bool isDesktop, bool isTablet) {
    if (controller.featuredVideos.isEmpty) return const SizedBox.shrink();

    final horizontalPadding = isDesktop ? 48.0 : (isTablet ? 24.0 : 16.0);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Featured Content', isDesktop, isTablet),
              const SizedBox(height: 16),
              if (controller.featuredVideos.length == 1)
                _buildFeaturedCard(
                  controller.featuredVideos.first,
                  isDesktop,
                  isTablet,
                )
              else
                SizedBox(
                  height: isDesktop ? 320.0 : (isTablet ? 260.0 : 200.0),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
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
        ),
      ),
    );
  }

  /// Contributing channels section with electric blue ring cards
  Widget _buildContributingChannelsSection(bool isDesktop, bool isTablet) {
    final channels = controller.topicChannels;
    if (channels.isEmpty) return const SizedBox.shrink();

    final horizontalPadding = isDesktop ? 48.0 : (isTablet ? 24.0 : 16.0);
    final isSingleChannel = channels.length == 1;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Contributing Channels', isDesktop, isTablet),
              const SizedBox(height: 14),
              if (isSingleChannel)
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: _buildChannelCard(channels.first),
                  ),
                )
              else
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: channels.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return SizedBox(
                        width: isDesktop ? 340 : (isTablet ? 300 : 280),
                        child: _buildChannelCard(channels[index]),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelCard(Map<String, String> channel) {
    final channelId = channel['id'];
    final channelName = channel['name'] ?? 'Channel';
    final avatarUrl = channel['avatarUrl'];

    // Authentic video count from controller
    final count = controller.videos.where((v) => v.channelId == channelId).length;
    final videoCountText = '$count ${count == 1 ? 'video' : 'videos'}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF28282C),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToChannel(channelId),
          child: Row(
            children: [
              // Avatar with electric blue border ring matching screenshot
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF007BFF),
                    width: 2,
                  ),
                ),
                child: UserAvatar(
                  photoUrl: avatarUrl,
                  displayName: channelName,
                  backgroundColor: const Color(0xFF1E1E24),
                  textColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              // Channel Name & video count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      channelName,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      videoCountText,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFAAAAAA),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Vertical 3-dots menu button
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 19,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _navigateToChannel(channelId),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideosHeaderRow(bool isDesktop, bool isTablet) {
    return _buildSectionHeader(
      'Explore ${controller.topicTitle}',
      isDesktop,
      isTablet,
    );
  }

  Widget _buildTopicFilterTabs() {
    final tabs = <String>[
      'Trending',
      'From Subscribed channels',
      'New',
      'Popular',
    ];
    if (controller.hasFactCheckedVideos) {
      tabs.add('Fact checked');
    }

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = controller.selectedTab.value == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                controller.selectTab(tab);
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF272727),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: isSelected
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedCard(dynamic video, bool isDesktop, bool isTablet) {
    final height = isDesktop ? 400.0 : (isTablet ? 300.0 : 220.0);

    return InkWell(
      onTap: () {
        MiniplayerNavigationHelper.navigateToVideoScreen(
          video: video as Video,
          routeArguments: {
            'video': video,
            'heroTag': controller.getHeroTag(video.id),
          },
        );
      },
      child: Hero(
        tag: controller.getHeroTag(video.id),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radius.xl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
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
                CachedNetworkImage(
                  imageUrl: video.thumbnailUrl ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const ColoredBox(
                    color: AppColors.bgSurfaceContainerHighest,
                  ),
                  errorWidget: (context, url, error) => const ColoredBox(
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
                      Text(
                        video.title,
                        style: TextStyle(
                          fontSize: isDesktop ? 24 : (isTablet ? 20 : 18),
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${video.channelName} • ${video.views} views',
                        style: TextStyle(
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
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.black,
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

  /// Section header with vertical white accent bar matching screenshot
  Widget _buildSectionHeader(String title, bool isDesktop, bool isTablet) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3.5,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              fontSize: isDesktop ? 22 : (isTablet ? 20 : 18),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
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
          backgroundColor: AppColors.bgPage,
          title: Text(
            'Loading...',
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: TopicHeroWidget(
            isDesktop: isDesktop,
            isTablet: isTablet,
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 48 : (isTablet ? 24 : 16),
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
            controller.rxErrorMessage.value,
            style: const TextStyle(
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
              foregroundColor: Colors.black,
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
