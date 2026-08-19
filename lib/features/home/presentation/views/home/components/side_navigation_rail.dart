import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/views/home/components/home_theme.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

// Constants
const double kSideNavWidth = 280.0;
const double kCompactSideNavWidth = 80.0;

/// Optimized Side Navigation Rail component
/// Extracted from monolithic home.dart for better maintainability
class SideNavigationRail extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onSelectItem;
  final VoidCallback onShowSignInSnackbar;
  final bool isDrawer;
  final bool isCompact;
  final HomeController homeController;

  const SideNavigationRail({
    required this.selectedIndex, required this.onSelectItem, required this.onShowSignInSnackbar, required this.isCompact, required this.homeController, super.key,
    this.isDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isCompact ? kCompactSideNavWidth : kSideNavWidth,
      decoration: BoxDecoration(
        color: HomeTheme.darkSurface,
        border: isDrawer
            ? null
            : Border(
                right: BorderSide(
                  color: HomeTheme.darkSurfaceVariant.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildNavigationItems(context)),
        ],
      ),
    );
  }

  Widget _buildNavigationItems(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 8),
        _buildSection(context, 'EXPLORE', _buildExploreItems(context)),
        Obx(() {
          if (!AuthService.to.isAuthenticated.value) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              _buildDivider(context),
              const SizedBox(height: 4),
              _buildSection(context, 'YOU', _buildPersonalItems(context)),
            ],
          );
        }),
        Obx(() {
          if (!AuthService.to.isAuthenticated.value) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              _buildDivider(context),
              const SizedBox(height: 4),
              _buildSection(context, 'PLAYLISTS', _buildPlaylistItems(context)),
            ],
          );
        }),
        const SizedBox(height: 4),
        _buildDivider(context),
        const SizedBox(height: 4),
        _buildSection(context, 'SUPPORT', _buildSupportItems(context)),
        if (isCompact) ...[
          const SizedBox(height: 16),
          _buildCompactUserInfo(context),
        ],
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> items,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCompact)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
              child: Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white54 : AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ...items,
        ],
      ),
    );
  }

  List<Widget> _buildExploreItems(BuildContext context) {
    return [
      _buildNavItem(
        context,
        Icons.home_rounded,
        Icons.home_outlined,
        'Home',
        HomeController.indexHome,
        route: '/home',
      ),
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
        'Discover Channels',
        HomeController.indexDiscover,
        route: '/discover',
      ),
      _buildNavItem(
        context,
        Icons.info_rounded,
        Icons.info_outline,
        'About',
        HomeController.indexAbout,
        route: '/about',
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
        'Terms of Service',
        HomeController.indexTerms,
        route: '/terms',
      ),
    ];
  }

  List<Widget> _buildPersonalItems(BuildContext context) {
    return [
      _buildNavItem(
        context,
        Icons.video_library_outlined,
        Icons.video_library_rounded,
        'Library',
        HomeController.indexLibrary,
        route: '/library',
      ),
      _buildNavItem(
        context,
        Icons.history_rounded,
        Icons.history_outlined,
        'History',
        HomeController.indexHistory,
        route: '/watchhistory',
      ),
      _buildNavItem(
        context,
        Icons.play_circle_outline_rounded,
        Icons.play_circle_rounded,
        'Your Videos',
        HomeController.indexYourVideos,
        route: '/myvideos',
      ),
      _buildNavItem(
        context,
        Icons.favorite_outline_rounded,
        Icons.favorite_rounded,
        'Liked Videos',
        HomeController.indexLikedVideos,
        route: '/likedvideos',
      ),
      _buildNavItem(
        context,
        Icons.download_rounded,
        Icons.download_outlined,
        'Downloads',
        HomeController.indexDownloads,
        route: '/downloads',
      ),
      _buildNavItem(
        context,
        Icons.content_cut_rounded,
        Icons.content_cut_outlined,
        'Clips',
        HomeController.indexClips,
        route: '/clips',
      ),
    ];
  }

  List<Widget> _buildPlaylistItems(BuildContext context) {
    if (!Get.isRegistered<PlaylistController>()) {
      return [_buildNoPlaylistsItem()];
    }
    final playlistCtrl = Get.find<PlaylistController>();
    final playlists = playlistCtrl.playlists;
    if (playlists.isEmpty) {
      return [_buildNoPlaylistsItem()];
    }
    return playlists.take(5).map((playlist) {
      return _buildNavItem(
        context,
        Icons.playlist_play_rounded,
        Icons.playlist_play_outlined,
        playlist.name,
        HomeController.indexPlaylistDetail,
        onTap: () => homeController.navigateToPlaylistDetail(playlist),
      );
    }).toList();
  }

  Widget _buildNoPlaylistsItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        isCompact ? '—' : 'No playlists yet',
        style: GoogleFonts.roboto(
          fontSize: 13,
          color: HomeTheme.darkOnSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  List<Widget> _buildSupportItems(BuildContext context) {
    return [
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
        Icons.help_outline_rounded,
        Icons.help_rounded,
        'Help',
        HomeController.indexHelp,
        route: '/help',
      ),
      _buildNavItem(
        context,
        Icons.feedback_rounded,
        Icons.feedback_outlined,
        'Feedback',
        HomeController.indexFeedback,
        route: '/feedback',
      ),
    ];
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    IconData outlineIcon,
    String label,
    int index, {
    String? route,
    bool requiresAuth = false,
    VoidCallback? onTap,
  }) {
    final isSelected = selectedIndex == index;
    final size = isCompact ? 48.0 : 56.0;

    return Obx(() {
      final shouldRequireAuth = requiresAuth && !AuthService.to.isAuthenticated.value;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: isSelected
              ? HomeTheme.primaryAccent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: shouldRequireAuth
                ? onShowSignInSnackbar
                : (onTap ?? () => onSelectItem(index)),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              height: size,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 0 : 16,
                ),
                child: Row(
                  mainAxisAlignment: isCompact
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: isCompact ? 56 : 40,
                      child: Icon(
                        isSelected ? icon : outlineIcon,
                        color: isSelected
                            ? HomeTheme.primaryAccent
                            : HomeTheme.darkOnSurfaceVariant,
                        size: 24,
                      ),
                    ),
                    if (!isCompact) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? HomeTheme.primaryAccent
                                : HomeTheme.darkOnSurface,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: isCompact ? 12 : 16,
      endIndent: isCompact ? 12 : 16,
      color: HomeTheme.darkSurfaceVariant.withValues(alpha: 0.3),
    );
  }

  Widget _buildCompactUserInfo(BuildContext context) {
    return Obx(() {
      final user = AuthService.to.currentUser.value;
      if (user == null) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            UserAvatar(
              photoUrl: user.photoURL,
              displayName: user.displayName,
            ),
            const SizedBox(height: 8),
            Text(
              user.displayName ?? 'User',
              style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: HomeTheme.darkOnSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    });
  }
}
