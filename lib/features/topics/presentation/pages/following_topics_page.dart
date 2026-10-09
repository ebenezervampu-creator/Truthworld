import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/following/following_topics_barrel.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'following/following_topics_barrel.dart';

/// Following Topics Page matching the modern uploaded UI:
/// - Top header bar with back navigation, pill search bar, and voice search
/// - Horizontal topic filter pills ("All Topics", "Christian songs 2026 >", etc.)
/// - Full-width high-contrast Topic Hero Banner with cover art, stats, and action buttons
/// - Filter & Sort Bar: Filter chips ("Latest", "From followed channels", "Trending", "Popular"),
///   "Sort by" dropdown menu, and responsive Grid/List layout toggle
/// - Responsive Video Feed: 1 col (mobile), 2 cols (tablet), 3-4 cols (desktop) with 1/2 badges,
///   duration badges, and rich blue channel avatars
/// - Zero White-on-White Policy strictly enforced
/// - Full reactivity via GetX (Zero setState)
class FollowingTopicsPage extends GetView<FollowingTopicsController> {
  const FollowingTopicsPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  FollowingTopicsController get controller =>
      Get.isRegistered<FollowingTopicsController>()
          ? Get.find<FollowingTopicsController>()
          : Get.put(FollowingTopicsController());

  Future<void> _refreshFollowingTopics() async {
    await controller.fetchFollowingTopics();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    final isMobileDevice = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    // Responsive columns for video grid
    final crossAxisCount = isMobile
        ? 1
        : (isTablet || isMobileDevice
            ? 2
            : (screenWidth >= 2100
                ? 4
                : (screenWidth >= 1600 ? 3 : 2)));

    // Child aspect ratio ensuring no overflow
    final childAspectRatio = isMobile
        ? 1.18
        : (isTablet ? 1.16 : 1.18);

    final horizontalPadding = isDesktop
        ? 24.0
        : (isTablet ? 20.0 : 12.0);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshFollowingTopics,
          color: Colors.white,
          backgroundColor: const Color(0xFF222224),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // 1. Top Header (Back button + Pill Search bar + Voice search mic)
              SliverToBoxAdapter(
                child: FollowingTopicsHeader(
                  controller: controller,
                  isMobile: isMobile,
                  isDashboard: isDashboard,
                ),
              ),

              // 2. Horizontal Topic Navigation Pills ("All Topics", "Christian songs 2026 >", etc.)
              SliverToBoxAdapter(
                child: FollowingTopicsPills(controller: controller),
              ),

              // 3. Main Content Reactive Body
              Obx(() {
                // Auth Required State
                if (!AuthService.to.isAuthenticated.value) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: FollowingTopicsAuthRequiredState(),
                  );
                }

                // Loading State
                if (controller.isLoading) {
                  return SliverToBoxAdapter(
                    child: FollowingTopicsLoadingState(
                      isMobile: isMobile,
                      isTablet: isTablet,
                    ),
                  );
                }

                // Error State
                if (controller.errorMessage.isNotEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: FollowingTopicsErrorState(
                      errorMessage: controller.errorMessage,
                      onRetry: _refreshFollowingTopics,
                    ),
                  );
                }

                var topics = List<Topic>.from(controller.followedTopics);

                // Search query filter for topics
                if (controller.searchQuery.value.isNotEmpty) {
                  final q = controller.searchQuery.value.toLowerCase();
                  topics = topics.where((t) {
                    return t.title.toLowerCase().contains(q) ||
                        t.category.toLowerCase().contains(q);
                  }).toList();
                }

                // Empty / No Results State
                if (topics.isEmpty) {
                  if (controller.searchQuery.value.isNotEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: FollowingTopicsNoResultsState(),
                    );
                  }
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: FollowingTopicsEmptyState(),
                  );
                }

                // Determine active topic for banner & filtering
                final selectedTopic = controller.selectedTopic.value ?? topics.first;

                // Videos for active topic (or aggregated if 'All Topics')
                final videos = controller.getFilteredVideosForTopic(
                  controller.selectedTopic.value,
                );
                final isLoadingVideos = controller.selectedTopic.value != null &&
                    (controller.isLoadingVideosMap[selectedTopic.id] ?? false);

                final posts = controller.topicPostsMap[selectedTopic.id];

                return SliverMainAxisGroup(
                  slivers: [
                    // A. Topic Hero Banner (Matches uploaded UI banner)
                    SliverToBoxAdapter(
                      child: FollowingTopicHeroBanner(
                        topic: selectedTopic,
                        controller: controller,
                        isMobile: isMobile,
                        totalVideosCount: videos.isNotEmpty ? videos.length : null,
                      ),
                    ),

                    // B. Filter & Sort Bar (Chips, Sort by dropdown, Grid/List toggle)
                    SliverToBoxAdapter(
                      child: FollowingTopicsFilterBar(
                        controller: controller,
                        isMobile: isMobile,
                      ),
                    ),

                    // C. Videos Loading Shimmer
                    if (isLoadingVideos && videos.isEmpty)
                      SliverToBoxAdapter(
                        child: FollowingTopicsGridSkeleton(
                          isMobile: isMobile,
                          crossAxisCount: crossAxisCount,
                        ),
                      ),

                    // D. Empty Videos State
                    if (!isLoadingVideos && videos.isEmpty)
                      SliverToBoxAdapter(
                        child: FollowingTopicsNoVideosState(
                          filterName: controller.activeVideoFilter.value,
                          onResetFilter: () {
                            controller.setVideoFilter('Latest');
                            controller.clearSearch();
                          },
                        ),
                      ),

                    // E. Responsive Video Feed (Grid View)
                    if (videos.isNotEmpty && controller.isGridView.value)
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 6,
                        ),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: childAspectRatio,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return FollowingTopicVideoCard(
                                video: videos[index],
                                topic: selectedTopic,
                                isMobile: isMobile,
                                index: index,
                                totalCount: videos.length,
                              );
                            },
                            childCount: videos.length,
                          ),
                        ),
                      ),

                    // F. Responsive Video Feed (List View)
                    if (videos.isNotEmpty && !controller.isGridView.value)
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 6,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return FollowingTopicVideoCard(
                                video: videos[index],
                                topic: selectedTopic,
                                isMobile: isMobile,
                                index: index,
                                totalCount: videos.length,
                                isGrid: false,
                              );
                            },
                            childCount: videos.length,
                          ),
                        ),
                      ),

                    // G. Community Posts Section for Topic (if any)
                    if (posts != null && posts.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1400),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding,
                                vertical: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 12),
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.forum_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Community Discussions',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: posts.length.clamp(0, 3),
                                    itemBuilder: (context, index) {
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        child: CommunityPostCard(post: posts[index]),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 48)),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
