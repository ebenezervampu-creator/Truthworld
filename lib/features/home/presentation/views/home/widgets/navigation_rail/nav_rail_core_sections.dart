import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/advertiser/presentation/views/saved_ads_page.dart'
    deferred as saved_ads;
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/navigation_rail/nav_rail_action_handler.dart';
import 'package:truthworld/features/home/presentation/views/home/widgets/navigation_rail/nav_rail_item.dart';

/// Explore section containing core discovery items.
class NavRailExploreSection extends StatelessWidget {
  const NavRailExploreSection({
    required this.selectedIndex,
    required this.isCompact,
    required this.currentUser,
    required this.onSelectItem,
    required this.onShowSignInSnackbar,
    super.key,
  });

  final int selectedIndex;
  final bool isCompact;
  final User? currentUser;
  final Function(int) onSelectItem;
  final VoidCallback onShowSignInSnackbar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NavRailSectionHeader(title: 'EXPLORE', isCompact: isCompact),
          _item(
            context,
            Icons.home_rounded,
            Icons.home_outlined,
            'Home',
            HomeController.indexHome,
            route: '/home',
          ),
          _item(
            context,
            Icons.subscriptions_rounded,
            Icons.subscriptions_outlined,
            'Subscriptions',
            HomeController.indexSubscriptions,
            route: '/subscriptions',
            requiresAuth: true,
          ),
          _item(
            context,
            Icons.explore_rounded,
            Icons.explore_outlined,
            'Discover Channel',
            HomeController.indexDiscover,
            route: '/discover',
          ),
          _item(
            context,
            Icons.interests_rounded,
            Icons.interests_outlined,
            'Explore Topics',
            HomeController.indexExploreTopics,
            route: '/explore-topics',
          ),
          _item(
            context,
            Icons.workspace_premium_rounded,
            Icons.workspace_premium_outlined,
            'Truthworld Premium',
            997,
            route: '/premium',
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData selected,
    IconData unselected,
    String title,
    int index, {
    String? route,
    bool requiresAuth = false,
  }) {
    return NavRailItem(
      selectedIcon: selected,
      unselectedIcon: unselected,
      title: title,
      index: index,
      isSelected: selectedIndex == index,
      isCompact: isCompact,
      requiresAuth: requiresAuth,
      onTap: () => NavRailActionHandler.handleNavItemTap(
        context: context,
        index: index,
        route: route,
        requiresAuth: requiresAuth,
        currentUser: currentUser,
        onSelectItem: onSelectItem,
        onShowSignInSnackbar: onShowSignInSnackbar,
      ),
    );
  }
}

/// Personal 'YOU' section with library, history, playlists, clips, and downloads.
class NavRailPersonalSection extends StatelessWidget {
  const NavRailPersonalSection({
    required this.selectedIndex,
    required this.isCompact,
    required this.currentUser,
    required this.homeController,
    required this.onSelectItem,
    required this.onShowSignInSnackbar,
    super.key,
  });

  final int selectedIndex;
  final bool isCompact;
  final User? currentUser;
  final HomeController homeController;
  final Function(int) onSelectItem;
  final VoidCallback onShowSignInSnackbar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NavRailDivider(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NavRailSectionHeader(title: 'YOU', isCompact: isCompact),
              Obx(() {
                final authService = Get.find<AuthService>();
                if (authService.hasChannel.value) {
                  return NavRailItem(
                    selectedIcon: Icons.account_circle_rounded,
                    unselectedIcon: Icons.account_circle_outlined,
                    title: 'Your channel',
                    index: HomeController.indexChannelDetail,
                    isSelected:
                        selectedIndex == HomeController.indexChannelDetail,
                    isCompact: isCompact,
                    requiresAuth: true,
                    onTap: homeController.navigateToYourChannel,
                  );
                }
                return const SizedBox.shrink();
              }),
              _item(
                context,
                Icons.history_rounded,
                Icons.history_outlined,
                'History',
                HomeController.indexHistory,
                route: '/history',
                requiresAuth: true,
              ),
              _item(
                context,
                Icons.playlist_play_rounded,
                Icons.playlist_play_outlined,
                'Playlists',
                HomeController.indexPlaylists,
                route: '/playlistscreen',
                requiresAuth: true,
              ),
              _item(
                context,
                Icons.check_circle_rounded,
                Icons.check_circle_outline_rounded,
                'Following Topics',
                HomeController.indexFollowingTopics,
                route: '/following-topics',
                requiresAuth: true,
              ),
              NavRailItem(
                selectedIcon: Icons.watch_later_rounded,
                unselectedIcon: Icons.watch_later_outlined,
                title: 'Watch later',
                index: HomeController.indexWatchLater,
                isSelected: selectedIndex == HomeController.indexWatchLater ||
                    (selectedIndex == HomeController.indexPlaylistDetail &&
                        homeController.selectedPlaylist.value?.playlistName
                                .toLowerCase() ==
                            'watch later'),
                isCompact: isCompact,
                requiresAuth: true,
                onTap: homeController.navigateToWatchLater,
              ),
              _item(
                context,
                Icons.favorite_rounded,
                Icons.favorite_outline,
                'Liked videos',
                HomeController.indexLikedVideos,
                route: '/likedvideos',
                requiresAuth: true,
              ),
              _item(
                context,
                Icons.slideshow_rounded,
                Icons.slideshow_outlined,
                'Your videos',
                HomeController.indexYourVideos,
                route: '/myvideos',
                requiresAuth: true,
              ),
              _item(
                context,
                Icons.content_cut_rounded,
                Icons.content_cut_outlined,
                'Your Clips',
                HomeController.indexClips,
                route: '/clips',
                requiresAuth: true,
              ),
              _item(
                context,
                Icons.download_rounded,
                Icons.download_outlined,
                'Downloads',
                HomeController.indexDownloads,
                route: '/downloads',
                requiresAuth: true,
              ),
              NavRailItem(
                selectedIcon: Icons.bookmark_rounded,
                unselectedIcon: Icons.bookmark_outline_rounded,
                title: 'Interacted Ads',
                index: -1,
                isSelected: selectedIndex == -1,
                isCompact: isCompact,
                requiresAuth: true,
                onTap: () async {
                  await saved_ads.loadLibrary();
                  Get.to(() => saved_ads.SavedAdsPage());
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _item(
    BuildContext context,
    IconData selected,
    IconData unselected,
    String title,
    int index, {
    String? route,
    bool requiresAuth = false,
  }) {
    return NavRailItem(
      selectedIcon: selected,
      unselectedIcon: unselected,
      title: title,
      index: index,
      isSelected: selectedIndex == index,
      isCompact: isCompact,
      requiresAuth: requiresAuth,
      onTap: () => NavRailActionHandler.handleNavItemTap(
        context: context,
        index: index,
        route: route,
        requiresAuth: requiresAuth,
        currentUser: currentUser,
        onSelectItem: onSelectItem,
        onShowSignInSnackbar: onShowSignInSnackbar,
      ),
    );
  }
}
