import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/discover/presentation/controllers/discover_channels_controller.dart';
import 'package:truthworld/features/discover/presentation/views/channels/widgets/discover_channels_barrel.dart';

export 'channels/widgets/discover_channels_barrel.dart';

/// Modernized, declarative Discover Channels page.
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
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1.0 - value)),
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
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          );
        } else if (isTablet) {
          return _buildScaffold(
            context,
            controller: controller,
            isTablet: true,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          );
        } else {
          return _buildScaffold(
            context,
            controller: controller,
            isMobile: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              onRefresh: () => controller.loadChannels(),
            )
          : null,
      body: SafeArea(
        child: _buildMainContent(
          context,
          controller: controller,
          padding: padding,
          isDesktop: isDesktop,
          isTablet: isTablet,
          isMobile: isMobile,
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
        // Top Header in Dashboard Mode
        if (isDashboard)
          DiscoverChannelsDashboardHeader(
            isDesktop: isDesktop,
            isTablet: isTablet,
            padding: padding,
          ),

        // Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              isDashboard ? 0 : 8,
              padding.right,
              12,
            ),
            child: DiscoverSearchBar(
              controller: controller,
              isMobile: isMobile,
            ),
          ),
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

        // Categories Header / Grid
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding.left),
          sliver: Obx(() {
            if (controller.searchQuery.value.trim().isNotEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return controller.selectedCategory.value == 'All'
                ? DiscoverCategoryGrid(
                    controller: controller,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                  )
                : DiscoverSelectedCategoryHeader(
                    selectedCategory: controller.selectedCategory.value,
                    onBack: () => controller.selectCategory('All'),
                  );
          }),
        ),

        // Channels List
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            padding.left,
            16,
            padding.right,
            32,
          ),
          sliver: Obx(() {
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
      ],
    );
  }
}
