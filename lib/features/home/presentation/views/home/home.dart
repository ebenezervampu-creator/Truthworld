import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/layout/global_app_bar.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/features/discover/presentation/views/discover_channels.dart'
    deferred as discover;
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/home_widgets.dart';
import 'package:truthworld/features/library/presentation/views/library/library_screen.dart'
    deferred as lib_feature;
import 'package:truthworld/features/subscriptions/presentation/views/subscriptions/subscriptions.dart'
    deferred as subscriptions;
import 'package:truthworld/features/topics/presentation/pages/explore_topics_page.dart'
    deferred as explore_topics;
import 'package:truthworld/theme/dark_professional_theme.dart';

// Re-exports for 100% backward compatibility
export 'package:truthworld/features/home/presentation/models/home_sidebar_visibility.dart';
export 'package:truthworld/theme/dark_professional_theme.dart';
export 'widgets/home_widgets.dart';

/// Main Home Shell view coordinating navigation rail, app bar, core tabs, and subpages.
class Home extends GetView<HomeController> {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if we need to open a playlist detail
    final args = Get.arguments;
    if (args != null &&
        args['openPlaylist'] != null &&
        controller.selectedPlaylist.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.navigateToPlaylistDetail(args['openPlaylist']);
      });
    }

    return _buildResponsiveLayout(context);
  }

  Widget _buildResponsiveLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
        final isTablet =
            constraints.maxWidth >= kTabletBreakpoint &&
            constraints.maxWidth < kDesktopBreakpoint;
        final isMobile = constraints.maxWidth < kTabletBreakpoint;
        final showSideNav = isDesktop || (isTablet && constraints.maxWidth >= 850);
        final showBottomNav = !showSideNav;
        return Scaffold(
          backgroundColor: modernDarkProfessionalTheme.scaffoldBackgroundColor,
          appBar: _buildGlobalAppBar(context, isMobile, isTablet, isDesktop),
          extendBody: true,
          body: SafeArea(
            bottom: false,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  controller.onScrollNotification(notification);
                }
                return false;
              },
              child: Row(
                children: [
                  if (showSideNav)
                    _buildSideNavigation(context, false),
                  if (showSideNav)
                    _buildVerticalDivider(context),
                  Expanded(
                    child: _buildDashboardContent(
                      context,
                      controller,
                      isMobile,
                      isTablet,
                      isDesktop,
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: showBottomNav
              ? Obx(
                  () => AnimatedSlide(
                    offset: controller.showBottomNav.value
                        ? Offset.zero
                        : const Offset(0, 1),
                    duration: const Duration(milliseconds: 220),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: controller.showBottomNav.value ? 1 : 0,
                      child: _buildBottomNavigation(context),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  bool _isCoreTab(int index) {
    return index == HomeController.indexHome ||
        index == HomeController.indexSubscriptions ||
        index == HomeController.indexDiscover ||
        index == HomeController.indexExploreTopics ||
        index == HomeController.indexLibrary;
  }

  int _mapIndexToTabIndex(int index) {
    switch (index) {
      case HomeController.indexHome:
        return 0;
      case HomeController.indexSubscriptions:
        return 1;
      case HomeController.indexDiscover:
        return 2;
      case HomeController.indexExploreTopics:
        return 3;
      case HomeController.indexLibrary:
        return 4;
      default:
        return 0;
    }
  }

  Widget _buildDashboardContent(
    BuildContext context,
    HomeController controller,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    return Obx(() {
      final index = controller.sideNavSelectedIndex.value;
      final isCore = _isCoreTab(index);
      final activeTabIndex = _mapIndexToTabIndex(index);
      if (isCore) {
        controller.markTabVisited(activeTabIndex);
      }
      final visited = controller.visitedTabIndices;

      return Stack(
        children: [
          // 1. Core tabs kept alive via IndexedStack
          Offstage(
            offstage: !isCore,
            child: IndexedStack(
              index: activeTabIndex,
              children: [
                // Tab 0: Home Feed
                HomeMainContent(
                  key: const PageStorageKey('tab_home'),
                  isMobile: isMobile,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                  homeController: controller,
                  appBarActionsBuilder: (ctx) =>
                      _buildAppBarActions(ctx, !isDesktop),
                ),
                // Tab 1: Subscriptions (Lazy initialized on first user visit)
                if (visited.contains(1))
                  DeferredWidget(
                    key: const PageStorageKey('tab_subscriptions'),
                    loader: subscriptions.loadLibrary,
                    placeholder: const SubscriptionsShimmerPlaceholder(),
                    builder: () =>
                        subscriptions.SubscriptionsPage(isDashboard: true),
                  )
                else
                  const SizedBox.shrink(key: PageStorageKey('tab_subscriptions_placeholder')),
                // Tab 2: Discover Channel (Lazy initialized on first user visit)
                if (visited.contains(2))
                  DeferredWidget(
                    key: const PageStorageKey('tab_discover'),
                    loader: discover.loadLibrary,
                    builder: () =>
                        discover.DiscoverChannelsPage(isDashboard: true),
                  )
                else
                  const SizedBox.shrink(key: PageStorageKey('tab_discover_placeholder')),
                // Tab 3: Explore Topics (Lazy initialized on first user visit)
                if (visited.contains(3))
                  DeferredWidget(
                    key: const PageStorageKey('tab_explore_topics'),
                    loader: explore_topics.loadLibrary,
                    placeholder: const TopicsShimmerPlaceholder(),
                    builder: () =>
                        explore_topics.ExploreTopicsPage(isDashboard: true),
                  )
                else
                  const SizedBox.shrink(key: PageStorageKey('tab_explore_topics_placeholder')),
                // Tab 4: Library (Lazy initialized on first user visit)
                if (visited.contains(4))
                  DeferredWidget(
                    key: const PageStorageKey('tab_library'),
                    loader: lib_feature.loadLibrary,
                    placeholder: const LibraryShimmerPlaceholder(),
                    builder: () => lib_feature.LibraryScreen(isDashboard: true),
                  )
                else
                  const SizedBox.shrink(key: PageStorageKey('tab_library_placeholder')),
              ],
            ),
          ),

          // 2. Sub-pages animated with AnimatedSwitcher
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: isCore
                ? const SizedBox.shrink()
                : ColoredBox(
                    key: ValueKey('subpage_$index'),
                    color: modernDarkProfessionalTheme.scaffoldBackgroundColor,
                    child: _buildSubPageContent(
                      context,
                      controller,
                      index,
                      isMobile,
                      isTablet,
                      isDesktop,
                    ),
                  ),
          ),
        ],
      );
    });
  }

  Widget _buildSubPageContent(
    BuildContext context,
    HomeController controller,
    int index,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    return HomeSubPageRouter.buildSubPage(context, controller, index);
  }

  PreferredSizeWidget? _buildGlobalAppBar(
    BuildContext context,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    return buildGlobalAppBar(
      context,
      isMobile: isMobile,
      isTablet: isTablet,
      isDesktop: isDesktop,
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, bool isMobile) {
    return buildGlobalAppBarActions(context, isMobile);
  }

  Widget _buildSideNavigation(BuildContext context, bool showCompactNavRail) {
    return Obx(
      () => ModernSideNavigationRail(
        selectedIndex: controller.sideNavSelectedIndex.value,
        onSelectItem: controller.onSideNavItemSelect,
        onShowSignInSnackbar: controller.showSignInSnackbar,
        currentUser: controller.currentUser.value,
        isCompact: showCompactNavRail,
        homeController: controller,
      ),
    );
  }

  Widget _buildVerticalDivider(BuildContext context) {
    return Container(width: 1, color: modernDarkProfessionalTheme.dividerColor);
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return HomeBottomNavigation(homeController: controller);
  }
}
