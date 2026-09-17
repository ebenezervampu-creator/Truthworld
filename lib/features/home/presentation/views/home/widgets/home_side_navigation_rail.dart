import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/advertiser/presentation/views/saved_ads_page.dart'
    deferred as saved_ads;
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/models/home_sidebar_visibility.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/dark_professional_theme.dart';
import 'package:universal_html/html.dart' as html;

/// Modernized side navigation rail widget extracted from home.dart
class ModernSideNavigationRail extends StatelessWidget {
  const ModernSideNavigationRail({
    required this.selectedIndex,
    required this.onSelectItem,
    required this.onShowSignInSnackbar,
    required this.currentUser,
    required this.homeController,
    super.key,
    this.isCompact = false,
  });

  final int selectedIndex;
  final Function(int) onSelectItem;
  final VoidCallback onShowSignInSnackbar;
  final User? currentUser;
  final bool isCompact;
  final HomeController homeController;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isCompact ? kCompactSideNavWidth : kSideNavWidth,
      decoration: BoxDecoration(
        color: modernDarkProfessionalTheme.navigationRailTheme.backgroundColor,
        border: Border(
          right: BorderSide(
            color: modernDarkProfessionalTheme.dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //  _buildHeader(context),
          Expanded(child: _buildNavigationItems(context)),
        ],
      ),
    );
  }

  Widget _buildNavigationItems(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final isAuthenticated = AuthService.to.isAuthenticated.value;
      final visibleEntries = HomeSidebarVisibility.getVisibleEntries(
        isAuthenticated: isAuthenticated,
      );
      final shouldShowPersonalSection =
          visibleEntries.contains('Your channel') ||
          visibleEntries.contains('History');

      return ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 8),

          // Main Navigation Section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCompact)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                    child: Text(
                      'EXPLORE',
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? Colors.white54
                            : AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                _buildNavItem(
                  context,
                  Icons.home_rounded,
                  Icons.home_outlined,
                  'Home',
                  HomeController.indexHome,
                  route: '/home',
                ),
                if (isAuthenticated)
                  _buildNavItem(
                    context,
                    Icons.subscriptions_rounded,
                    Icons.subscriptions_outlined,
                    'Subscriptions',
                    HomeController.indexSubscriptions,
                    route: '/subscriptions',
                    requiresAuth: true,
                  ),
                _buildNavItem(
                  context,
                  Icons.explore_rounded,
                  Icons.explore_outlined,
                  'Discover Channel',
                  HomeController.indexDiscover,
                  route: '/discover',
                ),
                _buildNavItem(
                  context,
                  Icons.interests_rounded,
                  Icons.interests_outlined,
                  'Explore Topics',
                  HomeController.indexExploreTopics,
                  route: '/explore-topics',
                ),
                _buildNavItem(
                  context,
                  Icons.workspace_premium_rounded,
                  Icons.workspace_premium_outlined,
                  'Truthworld Premium',
                  997,
                  route: '/premium',
                ),
              ],
            ),
          ),

          if (shouldShowPersonalSection)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _buildDivider(context),
                const SizedBox(height: 4),
                // Personal Section
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 8.0 : 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isCompact)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 4,
                            bottom: 8,
                            top: 4,
                          ),
                          child: Text(
                            'YOU',
                            style: GoogleFonts.roboto(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode
                                  ? Colors.white54
                                  : AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      Obx(() {
                        final authService = Get.find<AuthService>();
                        if (authService.hasChannel.value) {
                          return _buildNavItem(
                            context,
                            Icons.account_circle_rounded,
                            Icons.account_circle_outlined,
                            'Your channel',
                            HomeController.indexChannelDetail,
                            requiresAuth: true,
                            onTap: homeController.navigateToYourChannel,
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                      _buildNavItem(
                        context,
                        Icons.history_rounded,
                        Icons.history_outlined,
                        'History',
                        HomeController.indexHistory,
                        route: '/history',
                        requiresAuth: true,
                      ),
                      _buildNavItem(
                        context,
                        Icons.playlist_play_rounded,
                        Icons.playlist_play_outlined,
                        'Playlists',
                        HomeController.indexPlaylists,
                        route: '/playlistscreen',
                        requiresAuth: true,
                      ),
                      _buildNavItem(
                        context,
                        Icons.check_circle_rounded,
                        Icons.check_circle_outline_rounded,
                        'Following Topics',
                        HomeController.indexFollowingTopics,
                        route: '/following-topics',
                        requiresAuth: true,
                      ),
                      _buildNavItem(
                        context,
                        Icons.watch_later_rounded,
                        Icons.watch_later_outlined,
                        'Watch later',
                        HomeController.indexWatchLater,
                        requiresAuth: true,
                        onTap: homeController.navigateToWatchLater,
                      ),
                      _buildNavItem(
                        context,
                        Icons.favorite_rounded,
                        Icons.favorite_outline,
                        'Liked videos',
                        HomeController.indexLikedVideos,
                        route: '/likedvideos',
                        requiresAuth: true,
                      ),
                      _buildNavItem(
                        context,
                        Icons.slideshow_rounded,
                        Icons.slideshow_outlined,
                        'Your videos',
                        HomeController.indexYourVideos,
                        route: '/myvideos',
                        requiresAuth: true,
                      ),
                      _buildNavItem(
                        context,
                        Icons.content_cut_rounded,
                        Icons.content_cut_outlined,
                        'Your Clips',
                        HomeController.indexClips,
                        route: '/clips',
                        requiresAuth: true,
                      ),
                      _buildNavItem(
                        context,
                        Icons.download_rounded,
                        Icons.download_outlined,
                        'Downloads',
                        HomeController.indexDownloads,
                        route: '/downloads',
                        requiresAuth: true,
                      ),
                      _buildNavItem(
                        context,
                        Icons.bookmark_rounded,
                        Icons.bookmark_outline_rounded,
                        'Interacted Ads',
                        -1,
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
            ),

          if (shouldShowPersonalSection)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _buildDivider(context),
                const SizedBox(height: 8),

                // Subscriptions Section
                _buildSectionHeader(context, 'Following'),
                _buildSubscriptionList(context),
              ],
            ),

          const SizedBox(height: 4),
          _buildDivider(context),
          const SizedBox(height: 4),

          // Support Section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCompact)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                    child: Text(
                      'SUPPORT',
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? Colors.white54
                            : AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                _buildNavItem(
                  context,
                  Icons.settings_rounded,
                  Icons.settings_outlined,
                  'Settings',
                  HomeController.indexSettings,
                  route: '/settings',
                ),
                _buildNavItem(
                  context,
                  Icons.chat_bubble_rounded,
                  Icons.chat_bubble_outline,
                  'Feedback',
                  HomeController.indexFeedback,
                  route: '/feedback',
                  requiresAuth: true,
                ),
                _buildNavItem(
                  context,
                  Icons.info_rounded,
                  Icons.info_outline,
                  'About Truthworld',
                  HomeController.indexAbout,
                  route: '/about',
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),
          _buildDivider(context),
          const SizedBox(height: 4),

          // Legal & Policies Section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCompact)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                    child: Text(
                      'POLICIES',
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? Colors.white54
                            : AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                _buildNavItem(
                  context,
                  Icons.privacy_tip_rounded,
                  Icons.privacy_tip_outlined,
                  'Privacy Policy',
                  HomeController.indexPrivacy,
                  route: '/privacy',
                ),
                _buildNavItem(
                  context,
                  Icons.article_rounded,
                  Icons.article_outlined,
                  'Terms & Conditions',
                  HomeController.indexTerms,
                  route: '/terms',
                ),
                _buildNavItem(
                  context,
                  Icons.gavel_rounded,
                  Icons.gavel_outlined,
                  'Community Guidelines',
                  HomeController.indexCommunityGuidelines,
                  route: '/community-guidelines',
                ),
                _buildNavItem(
                  context,
                  Icons.dashboard_rounded,
                  Icons.dashboard_outlined,
                  'Truthworld Studio',
                  998,
                  route: '/studio',
                  onTap: StudioLauncher.openStudio,
                ),
                _buildNavItem(
                  context,
                  Icons.admin_panel_settings_rounded,
                  Icons.admin_panel_settings_outlined,
                  'Admin Portal',
                  999,
                  route: '/admin/dashboard',
                  onTap: () {
                    Get.toNamed('/admin/dashboard');
                  },
                ),
                _buildNavItem(
                  context,
                  Icons.campaign_rounded,
                  Icons.campaign_outlined,
                  'Advertiser Portal',
                  996,
                  route: '/advertisements',
                  onTap: () {
                    Get.toNamed('/advertisements');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),
          _buildDivider(context),
          const SizedBox(height: 4),

          // Footer Section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Footer
                if (!isCompact)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 4,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        children: [
                          Text(
                            '© 2026 Truthworld',
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.white38
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Made with ',
                                style: GoogleFonts.roboto(
                                  fontSize: 11,
                                  color: isDarkMode
                                      ? Colors.white24
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              const Icon(
                                Icons.favorite,
                                size: 11,
                                color: Colors.white,
                              ),
                              Text(
                                ' for creators',
                                style: GoogleFonts.roboto(
                                  fontSize: 11,
                                  color: isDarkMode
                                      ? Colors.white24
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData selectedIcon,
    IconData unselectedIcon,
    String title,
    int index, {
    String? route,
    bool requiresAuth = false,
    VoidCallback? onTap,
  }) {
    if (requiresAuth && !AuthService.to.isAuthenticated.value) {
      return const SizedBox.shrink();
    }
    final isSelected = (index == HomeController.indexWatchLater)
        ? (selectedIndex == HomeController.indexPlaylistDetail &&
              homeController.selectedPlaylist.value?.playlistName
                      .toLowerCase() ==
                  'watch later')
        : selectedIndex == index;
    final color = isSelected
        ? Colors.white
        : modernDarkProfessionalTheme.colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(isCompact ? 16 : 24),
        child: InkWell(
          onTap: () {
            if (onTap != null) {
              onTap();
            } else {
              _handleNavItemTap(context, index, route, requiresAuth);
            }
          },
          borderRadius: BorderRadius.circular(isCompact ? 16 : 24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 0 : 16,
              vertical: isCompact ? 12 : 12,
            ),
            child: isCompact
                ? _buildCompactNavItem(
                    context,
                    selectedIcon,
                    unselectedIcon,
                    title,
                    color,
                    isSelected,
                  )
                : _buildFullNavItem(
                    context,
                    selectedIcon,
                    unselectedIcon,
                    title,
                    color,
                    isSelected,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactNavItem(
    BuildContext context,
    IconData selectedIcon,
    IconData unselectedIcon,
    String title,
    Color color,
    bool isSelected,
  ) {
    return Tooltip(
      message: title,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isSelected ? selectedIcon : unselectedIcon,
              key: ValueKey(isSelected),
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: modernDarkProfessionalTheme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFullNavItem(
    BuildContext context,
    IconData selectedIcon,
    IconData unselectedIcon,
    String title,
    Color color,
    bool isSelected,
  ) {
    return Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isSelected ? selectedIcon : unselectedIcon,
            key: ValueKey(isSelected),
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: modernDarkProfessionalTheme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _handleNavItemTap(
    BuildContext context,
    int index,
    String? route,
    bool requiresAuth,
  ) {
    if (requiresAuth && currentUser == null) {
      onShowSignInSnackbar();
    } else {
      // DASHBOARD NAVIGATION LOGIC
      // Instead of full page transitions, we just update the index for dashboard-compatible pages
      final isDashboardPage =
          index == HomeController.indexHome ||
          index == HomeController.indexTrending ||
          index == HomeController.indexSubscriptions ||
          index == HomeController.indexDiscover ||
          index == HomeController.indexLibrary ||
          index == HomeController.indexHistory ||
          index == HomeController.indexYourVideos ||
          index == HomeController.indexLikedVideos ||
          index == HomeController.indexDownloads ||
          index == HomeController.indexWatchLater ||
          index == HomeController.indexPlaylists ||
          index == HomeController.indexFollowingTopics ||
          index == HomeController.indexClips ||
          index == HomeController.indexExploreTopics ||
          index == HomeController.indexCommunityGuidelines ||
          index == HomeController.indexPrivacy ||
          index == HomeController.indexTerms ||
          index == HomeController.indexAbout ||
          index == HomeController.indexSettings ||
          index == HomeController.indexFeedback;

      if (isDashboardPage) {
        onSelectItem(index);
        // Update URL bar on Web without pushing a new route for better UX
        if (kIsWeb && route != null && route.isNotEmpty) {
          try {
            html.window.history.pushState(null, '', route);
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'ModernSideNavigationRail.pushState',
            );
          }
        }
      } else {
        if (route != null && Get.currentRoute != route) {
          final isAtHome =
              Get.currentRoute == '/home' || Get.currentRoute == '/';
          if (index == HomeController.indexHome) {
            Get.offAllNamed(route);
          } else {
            if (isAtHome) {
              Get.toNamed(route);
            } else {
              Get.offNamed(route);
            }
          }
        }
      }
    }
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      height: 0.5,
      color: modernDarkProfessionalTheme.dividerColor,
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    if (isCompact) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: modernDarkProfessionalTheme.textTheme.titleSmall?.copyWith(
          color: modernDarkProfessionalTheme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSubscriptionList(BuildContext context) {
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      if (homeController.isLoadingSubscriptions.value) {
        return Column(
          children: List.generate(3, (_) => _buildSubscriptionShimmer(context)),
        );
      }

      final channelsData = homeController.subscribedChannelList;

      if (channelsData.isEmpty) {
        return _buildSubscriptionMessage(
          context,
          isCompact ? '' : 'No subscriptions yet',
          Icons.add_link_rounded,
        );
      }

      return Column(
        children: channelsData.map((data) {
          final channelName = data['name'] ?? '';
          // Convert the simple map back to a Channel object for the UI
          final channel = Channel(
            id: data['id'],
            ownerId: currentUser!.uid, // Required for model
            name: channelName,
            nameLowercase: channelName.toLowerCase(),
            handle: '@${channelName.replaceAll(' ', '').toLowerCase()}',
            handleLowercase:
                '@${channelName.replaceAll(' ', '').toLowerCase()}',
            description: '',
            avatarUrl: data['avatar'],
            bannerUrl: '',
            createdAt: Timestamp.now(),
            updatedAt: Timestamp.now(),
          );

          return ModernChannelListItem(
            channel: channel,
            isCompact: isCompact,
            onTap: () => _handleChannelTap(context, channel, 0),
          );
        }).toList(),
      );
    });
  }

  Future<void> _handleChannelTap(
    BuildContext context,
    Channel channel,
    int subscriberCount,
  ) async {
    if (homeController.isNavigating.value) return;
    homeController.isNavigating.value = true;
    try {
      await Get.toNamed(
        channel.channelRoute,
        arguments: {'channel': channel, 'subscribercount': subscriberCount},
      );
    } finally {
      homeController.isNavigating.value = false;
    }
  }

  Widget _buildSubscriptionShimmer(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 16,
        vertical: 6,
      ),
      child: Shimmer.fromColors(
        baseColor: modernDarkProfessionalTheme
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        highlightColor: modernDarkProfessionalTheme
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.1),
        child: Row(
          mainAxisAlignment: isCompact
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            if (!isCompact) ...[
              const SizedBox(width: 16),
              Container(height: 16, width: 120, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionMessage(
    BuildContext context,
    String message,
    IconData icon,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 16,
        vertical: 16,
      ),
      child: isCompact
          ? Icon(
              icon,
              size: 24,
              color: modernDarkProfessionalTheme.colorScheme.onSurfaceVariant,
            )
          : Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color:
                      modernDarkProfessionalTheme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: modernDarkProfessionalTheme.textTheme.bodyMedium
                        ?.copyWith(
                          color: modernDarkProfessionalTheme
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Modern channel list item widget used in the side navigation rail
class ModernChannelListItem extends StatelessWidget {
  const ModernChannelListItem({
    required this.channel,
    required this.onTap,
    required this.isCompact,
    super.key,
  });

  final Channel channel;
  final VoidCallback onTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 0 : 16,
            vertical: 8,
          ),
          child: isCompact
              ? _buildCompactItem(context)
              : _buildFullItem(context),
        ),
      ),
    );
  }

  Widget _buildCompactItem(BuildContext context) {
    return Tooltip(
      message: channel.channelName,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildChannelAvatar(context, 16),
          const SizedBox(height: 4),
          Text(
            channel.channelName,
            style: modernDarkProfessionalTheme.textTheme.labelSmall?.copyWith(
              color: modernDarkProfessionalTheme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFullItem(BuildContext context) {
    return Row(
      children: [
        _buildChannelAvatar(context, 16),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            channel.channelName,
            style: modernDarkProfessionalTheme.textTheme.bodyMedium?.copyWith(
              color: modernDarkProfessionalTheme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildChannelAvatar(BuildContext context, double radius) {
    return _ModernChannelAvatar(
      imageUrl: channel.avatarUrl,
      radius: radius,
      placeholderText: _safeSubstring(channel.channelName, 0, 1).toUpperCase(),
    );
  }

  String _safeSubstring(String str, int start, int end) {
    if (str.isEmpty) return str;
    if (end > str.length) end = str.length;
    return str.substring(start, end);
  }
}

class _ModernChannelAvatar extends StatelessWidget {
  const _ModernChannelAvatar({
    required this.radius,
    this.imageUrl,
    this.placeholderText,
  });

  final String? imageUrl;
  final double radius;
  final String? placeholderText;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: primaryAccent.withValues(alpha: 0.2),
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor:
            modernDarkProfessionalTheme.colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: hasImage
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  memCacheWidth:
                      (radius * 2 * MediaQuery.of(context).devicePixelRatio)
                          .toInt(),
                  placeholder: (context, url) => _buildPlaceholder(),
                  errorWidget: (context, url, error) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        placeholderText ?? '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Backward-compatibility aliases
typedef HomeSideNavigationRail = ModernSideNavigationRail;
typedef _ModernSideNavigationRail = ModernSideNavigationRail;
typedef _ModernChannelListItem = ModernChannelListItem;
