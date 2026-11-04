import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_barrel.dart';

export 'channels/widgets/discover_channels_barrel.dart';

/// Modernized Discover Channels page matching industry standards for fast discovery,
/// high creator productivity, content previewing, and cost-effective pagination.
class DiscoverChannelsPage extends StatelessWidget {
  const DiscoverChannelsPage({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<DiscoverChannelsController>()
        ? Get.find<DiscoverChannelsController>()
        : Get.put(DiscoverChannelsController());

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1.0 - value)),
            child: child,
          ),
        );
      },
      child: _buildResponsiveLayout(context, controller),
    );
  }

  Widget _buildResponsiveLayout(
    BuildContext context,
    DiscoverChannelsController controller,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
        final isTablet =
            constraints.maxWidth >= kMobileBreakpoint &&
            constraints.maxWidth < kDesktopBreakpoint;

        if (isDesktop) {
          return _buildScaffold(
            context,
            controller: controller,
            isDesktop: true,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          );
        } else if (isTablet) {
          return _buildScaffold(
            context,
            controller: controller,
            isTablet: true,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          );
        } else {
          return _buildScaffold(
            context,
            controller: controller,
            isMobile: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          );
        }
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context, {
    required DiscoverChannelsController controller,
    required EdgeInsets padding,
    bool isDesktop = false,
    bool isTablet = false,
    bool isMobile = false,
  }) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: !isDashboard
          ? DiscoverChannelsAppBar(
              isDesktop: isDesktop,
              isTablet: isTablet,
              onRefresh: () => controller.loadChannels(forceRefresh: true),
            )
          : null,
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            if (scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 300) {
              controller.loadMoreChannels();
            }
            return false;
          },
          child: _buildMainContent(
            context,
            controller: controller,
            padding: padding,
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context, {
    required DiscoverChannelsController controller,
    required EdgeInsets padding,
    bool isDesktop = false,
    bool isTablet = false,
    bool isMobile = false,
  }) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Top Header in Dashboard Mode (only when All categories are shown)
        if (isDashboard)
          Obx(() {
            if (controller.selectedCategory.value != 'All') {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return DiscoverChannelsDashboardHeader(
              isDesktop: isDesktop,
              isTablet: isTablet,
              padding: padding,
            );
          }),

        // Main Search Bar - only when All categories are shown
        SliverToBoxAdapter(
          child: Obx(() {
            if (controller.selectedCategory.value != 'All') {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                isDashboard ? 0 : 8,
                padding.right,
                16,
              ),
              child: DiscoverSearchBar(
                controller: controller,
                isMobile: isMobile,
              ),
            );
          }),
        ),

        // Active AI Query & Intent Banner (when AI search is active)
        SliverToBoxAdapter(
          child: Obx(() {
            if (controller.activeAiIntent.value == null) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                0,
                padding.right,
                16,
              ),
              child: DiscoverAiBanner(controller: controller),
            );
          }),
        ),

        // Front-Page Social Shelves: Trending Creators & Top Verified Channels
        // (Visible only on main page when not actively searching)
        SliverToBoxAdapter(
          child: Obx(() {
            if (controller.selectedCategory.value != 'All' ||
                controller.searchQuery.value.trim().isNotEmpty) {
              return const SizedBox.shrink();
            }

            final trending = controller.trendingCreators;
            final topVerified = controller.topVerifiedCreators;

            if (trending.isEmpty && topVerified.isEmpty) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                6,
                padding.right,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (trending.isNotEmpty)
                    DiscoverCreatorsShelf(
                      title: 'Trending Creators',
                      subtitle: 'Leading channels with highest audience engagement',
                      channels: trending,
                      controller: controller,
                      icon: Icons.local_fire_department_rounded,
                      isDashboard: isDashboard,
                    ),
                  if (topVerified.isNotEmpty)
                    DiscoverCreatorsShelf(
                      title: 'Top Verified & Credible Channels',
                      subtitle: 'Channels with highest truth verification track records',
                      channels: topVerified,
                      controller: controller,
                      icon: Icons.verified_rounded,
                      isDashboard: isDashboard,
                    ),
                ],
              ),
            );
          }),
        ),

        // Categories View or Category Detail Hero Header
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding.left),
          sliver: Obx(() {
            final isCategorySelected = controller.selectedCategory.value != 'All';
            final hasSearch = controller.searchQuery.value.trim().isNotEmpty;

            // When searching from main page, hide category grid to show results
            if (!isCategorySelected && hasSearch) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }

            // Category Selected Detail View with Responsive Header
            if (isCategorySelected) {
              return DiscoverSelectedCategoryHeader(
                selectedCategory: controller.selectedCategory.value,
                channelCount: controller.rxIsLoading.value
                    ? null
                    : controller.channels.length,
                onBack: () {
                  controller.clearSearch();
                  controller.selectCategory('All');
                },
              );
            }

            // Main Discover Channels Page Section Heading
            return SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  const Text(
                    'Browse Categories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Explore channels categorized across 30 unified knowledge disciplines',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.60),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          }),
        ),

        // Category Grid (when on main page without search)
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding.left),
          sliver: Obx(() {
            if (controller.selectedCategory.value != 'All' ||
                controller.searchQuery.value.trim().isNotEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }

            return DiscoverCategoryGrid(
              controller: controller,
              isDesktop: isDesktop,
              isTablet: isTablet,
            );
          }),
        ),

        // Creator CTA Banner (shown at bottom of main page)
        SliverToBoxAdapter(
          child: Obx(() {
            if (controller.selectedCategory.value != 'All' ||
                controller.searchQuery.value.trim().isNotEmpty) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                padding.left,
                24,
                padding.right,
                28,
              ),
              child: const DiscoverCreatorBanner(),
            );
          }),
        ),

        // Channels List (Shown when inside a Category OR when active search query)
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            padding.left,
            12,
            padding.right,
            32,
          ),
          sliver: Obx(() {
            final isCategorySelected = controller.selectedCategory.value != 'All';
            final hasSearch = controller.searchQuery.value.trim().isNotEmpty;

            // Only show channels list when a category is selected OR when actively searching
            if (!isCategorySelected && !hasSearch) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }

            if (controller.isLoading) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: primaryText,
                  ),
                ),
              );
            }

            if (controller.channels.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: DiscoverEmptyState(controller: controller),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final channel = controller.channels[index];
                  final subscriberCount =
                      controller.getSubscriberCount(channel);
                  return DiscoverChannelCard(
                    channel: channel,
                    subscriberCount: subscriberCount,
                    isDashboard: isDashboard,
                  );
                },
                childCount: controller.channels.length,
              ),
            );
          }),
        ),

        // Pagination Loader (Shown when fetching next batch)
        SliverToBoxAdapter(
          child: Obx(() {
            if (!controller.isFetchingMore.value) {
              return const SizedBox.shrink();
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
