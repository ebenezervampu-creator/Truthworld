import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_widgets.dart';

export 'package:truthworld/features/channel/presentation/views/channel/details/channel_details_widgets.dart';

/// Channel Details Page.
class ChannelDetailsPage extends GetView<ChannelController> {
  const ChannelDetailsPage({
    super.key,
    this.channel,
    this.isDashboard = false,
  });

  final Channel? channel;
  final bool isDashboard;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ChannelController>()) {
      Get.put(ChannelController());
    }
    final args = Get.arguments;
    final targetChannel =
        channel ??
        (args != null && args is Map && args['channel'] is Channel
            ? args['channel'] as Channel
            : null);

    // Safely sync channel initialization post-frame to eliminate markNeedsBuild/setState during the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.isClosed) return;

      if (targetChannel != null) {
        if (controller.selectedChannel.value?.channelId != targetChannel.channelId) {
          controller.initForChannelDetails(targetChannel);
          controller.startPageAnimations();
        } else if (!controller.pageFadeAnimationController.isCompleted &&
            !controller.pageFadeAnimationController.isAnimating) {
          controller.startPageAnimations();
        }
      } else {
        final channelTarget =
            Get.parameters['channelId'] ??
            Get.parameters['handle'] ??
            Get.parameters['id'];
        if (channelTarget != null && channelTarget.isNotEmpty) {
          final current = controller.selectedChannel.value;
          final isAlreadyLoaded = current != null &&
              (current.id == channelTarget ||
                  current.channelId == channelTarget ||
                  current.handle == channelTarget ||
                  '@${current.handle}' == channelTarget);
          if (!isAlreadyLoaded) {
            controller.loadChannelFromDeepLink(channelTarget);
            controller.startPageAnimations();
          } else if (!controller.pageFadeAnimationController.isCompleted &&
              !controller.pageFadeAnimationController.isAnimating) {
            controller.startPageAnimations();
          }
        }
      }
    });

    return Obx(() {
      final currentChannel = controller.selectedChannel.value ?? targetChannel;
      if (currentChannel == null) {
        return const ShimmerChannelDetailsScreen();
      }

      return FadeTransition(
        opacity: controller.pageFadeAnimation,
        child: _buildResponsiveLayout(context, currentChannel),
      );
    });
  }

  Widget _buildResponsiveLayout(BuildContext context, Channel channel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
        final isTablet =
            constraints.maxWidth >= kMobileBreakpoint &&
            constraints.maxWidth < kDesktopBreakpoint;

        if (isDesktop) {
          return _buildDesktopLayout(context, channel);
        } else if (isTablet) {
          return _buildTabletLayout(context, channel);
        } else {
          return _buildMobileLayout(context, channel);
        }
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context, Channel channel) {
    return Scaffold(
      backgroundColor: ytBackground,
      body: SafeArea(
        child: _buildMainContent(context, channel, isDesktop: true),
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, Channel channel) {
    return Scaffold(
      backgroundColor: ytBackground,
      body: SafeArea(
        child: _buildMainContent(context, channel, isTablet: true),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, Channel channel) {
    return Scaffold(
      backgroundColor: ytBackground,
      body: SafeArea(
        child: _buildMainContent(context, channel),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    Channel channel, {
    bool isDesktop = false,
    bool isTablet = false,
  }) {
    final activeTabs = controller.activeTabs;
    final tabCount = activeTabs.length;

    return DefaultTabController(
      key: ValueKey(
        'tab-controller-${channel.channelId}-${activeTabs.join(",")}',
      ),
      length: tabCount,
      child: NestedScrollView(
        controller: controller.scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: ChannelBannerWidget(
                channel: channel,
                controller: controller,
                isDesktop: isDesktop,
                isTablet: isTablet,
                isDashboard: isDashboard,
              ),
            ),
            SliverToBoxAdapter(
              child: ChannelHeaderWidget(
                channel: channel,
                controller: controller,
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: ChannelSliverTabBarDelegate(
                _buildChannelTabBar(activeTabs),
                maxHeight: 48,
              ),
            ),
          ];
        },
        body: TabBarView(
          children: activeTabs.map((tabName) {
            switch (tabName) {
              case 'Home':
                return ChannelHomeTabView(
                  channel: channel,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                );
              case 'Videos':
                return ChannelVideosTabView(
                  channel: channel,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                );
              case 'Topics':
                return ChannelTopicsTabView(
                  channel: channel,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                );
              case 'Playlists':
                return ChannelPlaylistsTabView(
                  channel: channel,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                );
              case 'Posts':
                return ChannelPostsTabView(
                  channel: channel,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                );
              default:
                return const SizedBox.shrink();
            }
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildChannelTabBar(List<String> activeTabs) {
    return Container(
      decoration: const BoxDecoration(
        color: ytBackground,
        border: Border(bottom: BorderSide(color: ytBorder)),
      ),
      child: TabBar(
        isScrollable: true,
        indicatorColor: ytTextPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: ytTextPrimary,
        unselectedLabelColor: ytTextSecondary,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        tabs: activeTabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }
}
