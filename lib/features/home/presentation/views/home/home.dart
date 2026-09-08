import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/components/layout/global_app_bar.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/core/widgets/ad_widgets.dart';
import 'package:truthworld/core/widgets/deferred_widget.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/about/presentation/views/About/about.dart'
    deferred as about;
import 'package:truthworld/features/advertiser/presentation/views/saved_ads_page.dart'
    deferred as saved_ads;
import 'package:truthworld/features/channel/presentation/views/channel/channel_details_screen.dart'
    deferred as channel_details;
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/community_guidelines.dart'
    deferred as community_guidelines;
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/privacy_polices.dart'
    deferred as privacy;
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/terms.dart'
    deferred as terms;
import 'package:truthworld/features/discover/presentation/views/discover_channels.dart'
    deferred as discover;
import 'package:truthworld/features/feedback/presentation/views/feedback/feedbacks.dart'
    deferred as feedback;
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/home_discovery_controller.dart';
import 'package:truthworld/features/library/presentation/views/library/library_screen.dart'
    deferred as lib_feature;
import 'package:truthworld/features/likedvideos/presentation/views/likedvideos/liked_video_screen.dart'
    deferred as liked_videos;
import 'package:truthworld/features/myvideos/presentation/views/myvideos/my_videos.dart'
    deferred as my_videos;
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_detail_screen.dart'
    deferred as playlist_detail;
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_screen.dart'
    deferred as playlist;
import 'package:truthworld/features/settings/presentation/views/settings/settings.dart'
    deferred as settings;
// Feature Pages for Dashboard (Deferred for YouTube-speed startup)
import 'package:truthworld/features/subscriptions/presentation/views/subscriptions/subscriptions.dart'
    deferred as subscriptions;
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';
import 'package:truthworld/features/topics/presentation/pages/explore_topics_page.dart'
    deferred as explore_topics;
import 'package:truthworld/features/topics/presentation/pages/following_topics_page.dart'
    deferred as following_topics;
import 'package:truthworld/features/trending/presentation/views/trending/trending_page.dart'
    deferred as trending;
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/views/clips/clips_page.dart'
    deferred as clips;
import 'package:truthworld/features/video/presentation/views/downloadpage/download_page.dart'
    deferred as downloads;
import 'package:truthworld/features/watchhistory/presentation/views/watchhistory/watchhistory.dart'
    deferred as history;
import 'package:truthworld/features/watchlater/presentation/views/watchlater/watchlater_screen.dart'
    deferred as watchlater;
import 'package:truthworld/theme/app_theme.dart';
import 'package:universal_html/html.dart' as html;
import 'package:visibility_detector/visibility_detector.dart';

// ==========================================================================
// ENHANCED DARK PROFESSIONAL THEME DEFINITION
// ==========================================================================
const Color darkBackground = AppColors.bgPage; // Deeper black
const Color darkSurface = AppColors.bgInput; // Rich dark surface
const Color darkSurfaceVariant = Color(0xFF1E1E1E); // Elevated surfaces
const Color darkOnSurface = Color(0xFFE8E8E8); // Crisp white text
const Color darkOnSurfaceVariant = Color(0xFFB8B8B8); // Muted text
const Color primaryAccent = Color(0xFF1976D2); // Professional blue
const Color secondaryAccent = Color(0xFF42A5F5); // Lighter blue
const Color tertiaryAccent = Color(0xFF90CAF9); // Subtle blue
ThemeData modernDarkProfessionalTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: primaryAccent,
  colorScheme: ColorScheme.dark(
    primary: primaryAccent,
    onPrimary: Colors.white,
    primaryContainer: primaryAccent.withValues(alpha: 0.12),
    onPrimaryContainer: primaryAccent,
    secondary: secondaryAccent,
    onSecondary: Colors.white,
    secondaryContainer: secondaryAccent.withValues(alpha: 0.12),
    onSecondaryContainer: secondaryAccent,
    tertiary: tertiaryAccent,
    onTertiary: Colors.white,
    tertiaryContainer: tertiaryAccent.withValues(alpha: 0.12),
    onTertiaryContainer: tertiaryAccent,
    onSurface: darkOnSurface,
    surfaceContainerHighest: darkSurfaceVariant,
    onSurfaceVariant: darkOnSurfaceVariant,
    error: const Color(0xFFFF6B6B),
    onError: Colors.white,
    outline: darkSurfaceVariant,
    outlineVariant: darkOnSurfaceVariant.withValues(alpha: 0.3),
    surfaceTint: primaryAccent.withValues(alpha: 0.05),
  ),
  scaffoldBackgroundColor: darkBackground,
  cardColor: darkSurface,
  dividerColor: darkSurfaceVariant.withValues(alpha: 0.3),
  // Enhanced Typography with Roboto
  textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme).copyWith(
    displayLarge: GoogleFonts.roboto(
      fontWeight: FontWeight.w300,
      color: darkOnSurface,
      letterSpacing: -0.5,
    ),
    displayMedium: GoogleFonts.roboto(
      fontWeight: FontWeight.w400,
      color: darkOnSurface,
      letterSpacing: -0.25,
    ),
    displaySmall: GoogleFonts.roboto(
      fontWeight: FontWeight.w500,
      color: darkOnSurface,
    ),
    headlineLarge: GoogleFonts.roboto(
      fontWeight: FontWeight.w500,
      color: darkOnSurface,
      letterSpacing: -0.25,
    ),
    headlineMedium: GoogleFonts.roboto(
      fontWeight: FontWeight.w500,
      color: darkOnSurface,
    ),
    headlineSmall: GoogleFonts.roboto(
      fontWeight: FontWeight.w500,
      color: darkOnSurface,
    ),
    titleLarge: GoogleFonts.roboto(
      fontWeight: FontWeight.bold,
      color: darkOnSurface,
      letterSpacing: 0.15,
    ),
    titleMedium: GoogleFonts.roboto(
      fontWeight: FontWeight.w500,
      color: darkOnSurface,
      letterSpacing: 0.1,
    ),
    titleSmall: GoogleFonts.roboto(
      fontWeight: FontWeight.w500,
      color: darkOnSurface,
      letterSpacing: 0.1,
    ),
    bodyLarge: GoogleFonts.roboto(
      fontWeight: FontWeight.w400,
      color: darkOnSurface,
      letterSpacing: 0.15,
    ),
    bodyMedium: GoogleFonts.roboto(
      fontWeight: FontWeight.w400,
      color: darkOnSurface,
      letterSpacing: 0.25,
    ),
    bodySmall: GoogleFonts.roboto(
      fontWeight: FontWeight.w400,
      color: darkOnSurfaceVariant,
      letterSpacing: 0.4,
    ),
    labelLarge: GoogleFonts.roboto(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    labelMedium: GoogleFonts.roboto(
      fontWeight: FontWeight.w500,
      color: darkOnSurfaceVariant,
      letterSpacing: 0.5,
    ),
    labelSmall: GoogleFonts.roboto(
      fontWeight: FontWeight.w500,
      color: darkOnSurfaceVariant,
      letterSpacing: 0.5,
    ),
  ),
  // Enhanced AppBar Theme
  appBarTheme: AppBarTheme(
    backgroundColor: darkSurface,
    foregroundColor: darkOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: GoogleFonts.roboto(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: darkOnSurface,
      letterSpacing: 0.15,
    ),
    iconTheme: const IconThemeData(color: darkOnSurfaceVariant, size: 24),
    actionsIconTheme: const IconThemeData(
      color: darkOnSurfaceVariant,
      size: 24,
    ),
  ),
  // Enhanced Card Theme
  cardTheme: CardThemeData(
    color: darkSurface,
    elevation: 2,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
  ),
  // Enhanced Button Themes
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: primaryAccent,
      disabledForegroundColor: Colors.white54,
      disabledBackgroundColor: primaryAccent.withValues(alpha: 0.3),
      elevation: 2,
      shadowColor: primaryAccent.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      textStyle: GoogleFonts.roboto(
        fontWeight: FontWeight.w500,
        fontSize: 16,
        letterSpacing: 0.1,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primaryAccent,
      disabledForegroundColor: primaryAccent.withValues(alpha: 0.3),
      side: BorderSide(color: primaryAccent.withValues(alpha: 0.6), width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      textStyle: GoogleFonts.roboto(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.1,
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: primaryAccent,
      disabledForegroundColor: primaryAccent.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      textStyle: GoogleFonts.roboto(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.1,
      ),
    ),
  ),
  // Enhanced Navigation Themes
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: darkSurface.withValues(alpha: 0.95),
    indicatorColor: Colors.grey.withValues(alpha: 0.15),
    elevation: 8,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    surfaceTintColor: Colors.transparent,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(color: Colors.grey, size: 24);
      }
      return const IconThemeData(color: darkOnSurfaceVariant, size: 24);
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final style = GoogleFonts.roboto(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      );
      if (states.contains(WidgetState.selected)) {
        return style.copyWith(color: Colors.grey);
      }
      return style.copyWith(color: darkOnSurfaceVariant);
    }),
  ),
  navigationRailTheme: NavigationRailThemeData(
    backgroundColor: darkSurface,
    indicatorColor: primaryAccent.withValues(alpha: 0.15),
    elevation: 1,
    groupAlignment: -1,
    labelType: NavigationRailLabelType.none,
    selectedLabelTextStyle: GoogleFonts.roboto(
      fontSize: 12,
      color: primaryAccent,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    unselectedLabelTextStyle: GoogleFonts.roboto(
      fontSize: 12,
      color: darkOnSurfaceVariant,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    selectedIconTheme: const IconThemeData(color: primaryAccent, size: 24),
    unselectedIconTheme: const IconThemeData(
      color: darkOnSurfaceVariant,
      size: 24,
    ),
  ),
  // Enhanced Chip Theme
  chipTheme: ChipThemeData(
    backgroundColor: darkSurfaceVariant.withValues(alpha: 0.4),
    selectedColor: primaryAccent.withValues(alpha: 0.15),
    secondarySelectedColor: primaryAccent.withValues(alpha: 0.15),
    labelStyle: GoogleFonts.roboto(
      fontSize: 13,
      color: darkOnSurfaceVariant,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    secondaryLabelStyle: GoogleFonts.roboto(
      fontSize: 13,
      color: primaryAccent,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.1,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    side: BorderSide.none,
    brightness: Brightness.dark,
    elevation: 0,
    pressElevation: 1,
  ),
  // Enhanced Dialog Theme
  dialogTheme: DialogThemeData(
    backgroundColor: darkSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 8,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    titleTextStyle: GoogleFonts.roboto(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: darkOnSurface,
      letterSpacing: 0.15,
    ),
    contentTextStyle: GoogleFonts.roboto(
      fontSize: 16,
      color: darkOnSurfaceVariant,
      letterSpacing: 0.25,
    ),
  ),
  // Enhanced Divider Theme
  dividerTheme: DividerThemeData(
    color: darkSurfaceVariant.withValues(alpha: 0.3),
    thickness: 0.5,
    space: 24,
    indent: 0,
    endIndent: 0,
  ),
  // Enhanced Input Decoration Theme
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: darkSurfaceVariant.withValues(alpha: 0.3),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: darkSurfaceVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: darkSurfaceVariant.withValues(alpha: 0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: primaryAccent, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    hintStyle: GoogleFonts.roboto(
      color: darkOnSurfaceVariant,
      fontWeight: FontWeight.w400,
    ),
    labelStyle: GoogleFonts.roboto(
      color: darkOnSurfaceVariant,
      fontWeight: FontWeight.w500,
    ),
  ),
);
// ==========================================================================
// CONSTANTS
// ==========================================================================
const double kTabletBreakpoint = 600;
const double kDesktopBreakpoint = 1000;
const double kSideNavWidth = 280;
const double kCompactSideNavWidth = 80;
const double kBottomNavBarHeight = kToolbarHeight;

class HomeSidebarVisibility {
  const HomeSidebarVisibility._();

  static List<String> getVisibleEntries({required bool isAuthenticated}) {
    final publicEntries = <String>[
      'Home',
      'Discover Channel',
      'Explore Topics',
      'Settings',
      'Help Center',
      'Feedback',
      'About Truthworld',
      'Privacy Policy',
      'Terms & Conditions',
      'Community Guidelines',
      'Truthworld Studio',
      'Admin Portal',
      'Advertiser Portal',
    ];

    if (!isAuthenticated) {
      return publicEntries;
    }

    return [
      ...publicEntries,
      'Subscriptions',
      'Your channel',
      'History',
      'Playlists',
      'Following Topics',
      'Watch later',
      'Liked videos',
      'Your videos',
      'Your Clips',
      'Downloads',
      'Interacted Ads',
    ];
  }
}

// ==========================================================================
// ENHANCED HOME CONTROLLER
// ==========================================================================
// ==========================================================================
// MODERNIZED HOME WIDGET
// ==========================================================================
class Home extends GetView<HomeController> {
  const Home({super.key});

  void _preloadDeferredLibraries() {
    Future.delayed(const Duration(seconds: 3), () {
      subscriptions.loadLibrary().catchError(
        (e) => debugPrint('Preload subscriptions error: $e'),
      );
      lib_feature.loadLibrary().catchError(
        (e) => debugPrint('Preload library error: $e'),
      );
      saved_ads.loadLibrary().catchError(
        (e) => debugPrint('Preload saved_ads error: $e'),
      );
      explore_topics.loadLibrary().catchError(
        (e) => debugPrint('Preload explore_topics error: $e'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Preload deferred layouts to ensure zero-latency transitions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadDeferredLibraries();
    });

    // Check if we need to open a playlist detail
    final args = Get.arguments;
    if (args != null && args['openPlaylist'] != null) {
      // Defer navigation to after first frame
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
        final showCompactNavRail = isTablet && constraints.maxWidth < 850;
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
                  if (isDesktop || (isTablet && !showCompactNavRail))
                    _buildSideNavigation(context, showCompactNavRail),
                  if (isDesktop || (isTablet && !showCompactNavRail))
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
          bottomNavigationBar: isMobile || isTablet
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

      return Stack(
        children: [
          // 1. Core tabs kept alive via IndexedStack
          Offstage(
            offstage: !isCore,
            child: IndexedStack(
              index: _mapIndexToTabIndex(index),
              children: [
                // Tab 0: Home Feed
                _ModernMainContent(
                  key: const PageStorageKey('tab_home'),
                  isMobile: isMobile,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                  homeController: controller,
                  appBarActionsBuilder: (ctx) =>
                      _buildAppBarActions(ctx, !isDesktop),
                ),
                // Tab 1: Subscriptions
                DeferredWidget(
                  key: const PageStorageKey('tab_subscriptions'),
                  loader: subscriptions.loadLibrary,
                  placeholder: const SubscriptionsShimmerPlaceholder(),
                  builder: () =>
                      subscriptions.SubscriptionsPage(isDashboard: true),
                ),
                // Tab 2: Discover Channel
                DeferredWidget(
                  key: const PageStorageKey('tab_discover'),
                  loader: discover.loadLibrary,
                  builder: () =>
                      discover.DiscoverChannelsPage(isDashboard: true),
                ),
                // Tab 3: Explore Topics
                DeferredWidget(
                  key: const PageStorageKey('tab_explore_topics'),
                  loader: explore_topics.loadLibrary,
                  placeholder: const TopicsShimmerPlaceholder(),
                  builder: () =>
                      explore_topics.ExploreTopicsPage(isDashboard: true),
                ),
                // Tab 4: Library
                DeferredWidget(
                  key: const PageStorageKey('tab_library'),
                  loader: lib_feature.loadLibrary,
                  placeholder: const LibraryShimmerPlaceholder(),
                  builder: () => lib_feature.LibraryScreen(isDashboard: true),
                ),
              ],
            ),
          ),

          // 2. Sub-pages animated with AnimatedSwitcher
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: !isCore
                ? ColoredBox(
                    key: ValueKey(index),
                    color: modernDarkProfessionalTheme.scaffoldBackgroundColor,
                    child: _buildSubPageContent(
                      context,
                      controller,
                      index,
                      isMobile,
                      isTablet,
                      isDesktop,
                    ),
                  )
                : const SizedBox.shrink(),
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
    switch (index) {
      case HomeController.indexTrending:
        return DeferredWidget(
          loader: trending.loadLibrary,
          builder: () => trending.TrendingVideosPage(isDashboard: true),
        );
      case HomeController.indexHistory:
        return DeferredWidget(
          loader: history.loadLibrary,
          builder: () => history.WatchHistory(isDashboard: true),
        );
      case HomeController.indexWatchLater:
        return DeferredWidget(
          loader: watchlater.loadLibrary,
          builder: () => watchlater.WatchLaterScreen(isDashboard: true),
        );
      case HomeController.indexYourVideos:
        return DeferredWidget(
          loader: my_videos.loadLibrary,
          builder: () => my_videos.MyVideos(isDashboard: true),
        );
      case HomeController.indexLikedVideos:
        return DeferredWidget(
          loader: liked_videos.loadLibrary,
          builder: () => liked_videos.LikedVideoScreen(isDashboard: true),
        );
      case HomeController.indexDownloads:
        return DeferredWidget(
          loader: downloads.loadLibrary,
          builder: () => downloads.DownloadsPage(isDashboard: true),
        );
      case HomeController.indexPlaylists:
        return DeferredWidget(
          loader: playlist.loadLibrary,
          builder: () => playlist.PlaylistScreen(isDashboard: true),
        );
      case HomeController.indexFollowingTopics:
        return DeferredWidget(
          loader: following_topics.loadLibrary,
          builder: () =>
              following_topics.FollowingTopicsPage(isDashboard: true),
        );
      case HomeController.indexClips:
        return DeferredWidget(
          loader: clips.loadLibrary,
          builder: () => clips.ClipsPage(isDashboard: true),
        );
      case HomeController.indexAbout:
        return DeferredWidget(
          loader: about.loadLibrary,
          builder: () => about.AboutPage(isDashboard: true),
        );
      case HomeController.indexPrivacy:
        return DeferredWidget(
          loader: privacy.loadLibrary,
          builder: () => privacy.PrivacyPolicyScreen(isDashboard: true),
        );
      case HomeController.indexTerms:
        return DeferredWidget(
          loader: terms.loadLibrary,
          builder: () => terms.TermsAndConditionsPage(isDashboard: true),
        );
      case HomeController.indexCommunityGuidelines:
        return DeferredWidget(
          loader: community_guidelines.loadLibrary,
          builder: () =>
              community_guidelines.CommunityGuidelinesPage(isDashboard: true),
        );
      case HomeController.indexSettings:
        return DeferredWidget(
          loader: settings.loadLibrary,
          builder: () => settings.SettingsScreen(isDashboard: true),
        );
      case HomeController.indexFeedback:
        return DeferredWidget(
          loader: feedback.loadLibrary,
          builder: () => feedback.SendFeedbackPage(isDashboard: true),
        );
      case HomeController.indexPlaylistDetail:
        final p = controller.selectedPlaylist.value;
        if (p == null) {
          return DeferredWidget(
            loader: playlist.loadLibrary,
            builder: () => playlist.PlaylistScreen(isDashboard: true),
          );
        }
        return DeferredWidget(
          loader: playlist_detail.loadLibrary,
          builder: () =>
              playlist_detail.PlaylistDetailScreen(key: ValueKey(p.id)),
        );
      case HomeController.indexChannelDetail:
        final c = controller.selectedChannelForDetail.value;
        if (c == null) {
          return DeferredWidget(
            loader: discover.loadLibrary,
            builder: () => discover.DiscoverChannelsPage(isDashboard: true),
          );
        }
        return DeferredWidget(
          loader: channel_details.loadLibrary,
          builder: () => channel_details.ChannelDetailsPage(
            key: ValueKey(c.channelId),
            channel: c,
            isDashboard: true,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
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
      () => _ModernSideNavigationRail(
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
    return Container(
      decoration: BoxDecoration(
        color: modernDarkProfessionalTheme.navigationBarTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: modernDarkProfessionalTheme.navigationBarTheme
              .copyWith(
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const IconThemeData(color: Colors.grey, size: 24);
                  }
                  return const IconThemeData(
                    color: darkOnSurfaceVariant,
                    size: 24,
                  );
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  final style = GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  );
                  if (states.contains(WidgetState.selected)) {
                    return style.copyWith(color: Colors.grey);
                  }
                  return style.copyWith(color: darkOnSurfaceVariant);
                }),
              ),
        ),
        child: NavigationBar(
          selectedIndex: controller.bottomNavSelectedIndex.value,
          onDestinationSelected: controller.onBottomNavItemTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          height: kBottomNavBarHeight,
          indicatorColor: Colors.grey.withValues(alpha: 0.15),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.interests_outlined),
              selectedIcon: Icon(Icons.interests),
              label: ' Topics',
            ),
            const NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Channels',
            ),
            NavigationDestination(
              icon: (() {
                final user = controller.currentUser.value;
                if (user == null) {
                  return const Icon(Icons.account_circle_outlined);
                }
                return const UserAvatar(
                  radius: 12,
                  showBorder: false,
                );
              })(),
              selectedIcon: (() {
                final user = controller.currentUser.value;
                if (user == null) {
                  return const Icon(Icons.account_circle_rounded);
                }
                return const UserAvatar(
                  radius: 12,
                  borderColor: Colors.white,
                );
              })(),
              label: 'You',
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================================
// MODERNIZED SIDE NAVIGATION RAIL
// ==========================================================================
class _ModernSideNavigationRail extends StatelessWidget {
  const _ModernSideNavigationRail({
    required this.selectedIndex,
    required this.onSelectItem,
    required this.onShowSignInSnackbar,
    required this.currentUser,
    required this.homeController,
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
                  route: '/advertiser',
                  onTap: () {
                    Get.toNamed('/advertiser');
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
          } catch (e) {
            debugPrint('Failed to update URL: $e');
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

          return _ModernChannelListItem(
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
    Get.toNamed(
      channel.channelRoute,
      arguments: {'channel': channel, 'subscribercount': subscriberCount},
    );
    Future.delayed(const Duration(seconds: 1), () {
      homeController.isNavigating.value = false;
    });
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

// ==========================================================================
// MODERNIZED CHANNEL LIST ITEM
// ==========================================================================
class _ModernChannelListItem extends StatelessWidget {
  const _ModernChannelListItem({
    required this.channel,
    required this.onTap,
    required this.isCompact,
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
    return _ModernAvatar(
      imageUrl: channel.avatarUrl,
      radius: radius,
      placeholderText: channel.channelName.safeSubstring(0, 1).toUpperCase(),
    );
  }
}

// ==========================================================================
// MODERNIZED MAIN CONTENT
// ==========================================================================
class _ModernMainContent extends StatelessWidget {
  const _ModernMainContent({
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    required this.homeController,
    required this.appBarActionsBuilder,
    super.key,
  });
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final HomeController homeController;
  final List<Widget> Function(BuildContext) appBarActionsBuilder;
  String _formatViews(int views) {
    if (views < 1000) return views.toString();
    if (views < 1000000) {
      return '${(views / 1000).toStringAsFixed(views % 1000 == 0 ? 0 : (views < 100000 ? 1 : 0))}K';
    }
    if (views < 1000000000) {
      return '${(views / 1000000).toStringAsFixed(views % 1000000 == 0 ? 0 : (views < 100000000 ? 1 : 0))}M';
    }
    return '${(views / 1000000000).toStringAsFixed(views % 1000000000 == 0 ? 0 : (views < 100000000000 ? 1 : 0))}B';
  }

  String _formatTimestamp(Timestamp timestamp) {
    try {
      return timeago.format(timestamp.toDate());
    } catch (e) {
      debugPrint('Error formatting timestamp: $e');
      return 'some time ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 24.0 : 32.0);
    final featuredBannerSection = SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeaturedVideoBanner(horizontalPadding: horizontalPadding),
          const SizedBox(height: 32),
          _PersonalizedPlaylistsSection(
            horizontalPadding: horizontalPadding,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            modernDarkProfessionalTheme.scaffoldBackgroundColor,
            modernDarkProfessionalTheme.scaffoldBackgroundColor.withValues(
              alpha: 0.95,
            ),
          ],
        ),
      ),
      child: Obx(() {
        final isPostsTab =
            homeController.selectedCategory.value == 'Posts';
        final isSubscriptionsTab =
            homeController.selectedCategory.value == 'Subscriptions';
        final isTopicsTab =
            homeController.selectedCategory.value == 'Topics' ||
            homeController.selectedCategory.value == 'Explore Topics';

        return CustomScrollView(
          controller: homeController.scrollController,
          slivers: [
            if (homeController.sideNavSelectedIndex.value ==
                HomeController.indexHome)
              _buildMobileCategoryBar(
                context,
                homeController.availableCategories,
              ),
            if (isSubscriptionsTab)
              SliverFillRemaining(
                child: DeferredWidget(
                  key: const PageStorageKey('subscriptions_category_view'),
                  loader: subscriptions.loadLibrary,
                  placeholder: const SubscriptionsShimmerPlaceholder(),
                  builder: () =>
                      subscriptions.SubscriptionsPage(isDashboard: true),
                ),
              )
            else if (isTopicsTab)
              SliverFillRemaining(
                child: DeferredWidget(
                  key: const PageStorageKey('topics_category_view'),
                  loader: explore_topics.loadLibrary,
                  placeholder: const TopicsShimmerPlaceholder(),
                  builder: () =>
                      explore_topics.ExploreTopicsPage(isDashboard: true),
                ),
              )
            else ...[
              if (homeController.selectedCategory.value == 'All')
                featuredBannerSection
              else
                const SliverToBoxAdapter(
                  child: SizedBox(height: 16),
                ),
              if (homeController.isLoadingVideos.value)
                _ModernVideoGridSection(
                  isMobile: isMobile,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                  videos: const [], // Pass empty list while loading
                  heroPrefix: 'grid_loading',
                  isLoading: true,
                  isPosts: isPostsTab,
                  horizontalPadding: horizontalPadding,
                  formatViews: _formatViews,
                  formatTimestamp: _formatTimestamp,
                )
              else
                _ModernVideoGridSection(
                  isMobile: isMobile,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                  videos: isDesktop && !isPostsTab
                      ? homeController.homeFeedItems
                          .where((item) => item is! CommunityPostModel)
                          .toList()
                      : homeController.homeFeedItems,
                  heroPrefix: 'main_grid',
                  isLoading: false,
                  isPosts: isPostsTab,
                  horizontalPadding: horizontalPadding,
                  formatViews: _formatViews,
                  formatTimestamp: _formatTimestamp,
                ),
              if (homeController.isLoadingMore.value)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: primaryAccent),
                    ),
                  ),
                )
              else
                const SliverToBoxAdapter(child: SizedBox.shrink()),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: isMobile || isTablet ? kBottomNavBarHeight + 16 : 16,
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _buildMobileCategoryBar(
    BuildContext context,
    List<String> categories,
  ) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 0,
      backgroundColor: modernDarkProfessionalTheme.appBarTheme.backgroundColor,
      surfaceTintColor:
          modernDarkProfessionalTheme.appBarTheme.surfaceTintColor,
      bottom: _buildCategoryChipsBar(context, categories),
    );
  }

  PreferredSize _buildCategoryChipsBar(
    BuildContext context,
    List<String> categories,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: modernDarkProfessionalTheme.appBarTheme.backgroundColor,
          border: Border(
            bottom: BorderSide(
              color: modernDarkProfessionalTheme.dividerColor,
              width: 0.5,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            // 📦 ALL CATEGORIES POPUP ICON BUTTON
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showAllCategoriesPopup(context, HomeDiscoveryController.categories);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF272727),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.grid_view_rounded,
                    color: Colors.white, // RULE ENFORCEMENT: White icon
                    size: 18,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return Obx(() {
                    final isSelected =
                        homeController.selectedCategory.value == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          homeController.selectCategory(category);
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
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            category,
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllCategoriesPopup(BuildContext context, List<String> categories) {
    final searchQuery = ''.obs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Obx(() {
          final query = searchQuery.value.toLowerCase();
          final filtered = categories
              .where(
                (c) => c.toLowerCase().contains(query),
              )
              .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: modernDarkProfessionalTheme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(
                  color: modernDarkProfessionalTheme.dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.grid_view_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'All Categories',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search categories...',
                    hintStyle: GoogleFonts.roboto(
                      color: AppColors.textTertiary,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF272727),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => searchQuery.value = val,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.8,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final cat = filtered[idx];
                      final isSelected =
                          homeController.selectedCategory.value == cat;
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          homeController.selectCategory(cat);
                          Navigator.pop(context);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF272727),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: GoogleFonts.roboto(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}

// ==========================================================================
// MODERNIZED VIDEO GRID SECTION
// ==========================================================================
class _ModernVideoGridSection extends StatelessWidget {
  const _ModernVideoGridSection({
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    required this.videos,
    required this.heroPrefix,
    required this.isLoading,
    required this.horizontalPadding,
    required this.formatViews,
    required this.formatTimestamp,
    this.isPosts = false,
  });
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final List<dynamic> videos;
  final String heroPrefix;
  final bool isLoading;
  final double horizontalPadding;
  final String Function(int) formatViews;
  final String Function(Timestamp) formatTimestamp;
  final bool isPosts;
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingGrid(context);
    }
    final displayVideos = (isDesktop && !isPosts)
        ? videos.where((item) => item is! CommunityPostModel).toList()
        : videos;
    if (displayVideos.isEmpty) {
      return _buildEmptyGrid(context);
    }
    return _buildVideoGrid(context, displayVideos);
  }

  Widget _buildVideoGrid(BuildContext context, List<dynamic> videos) {
    if (isMobile) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        sliver: SliverList.separated(
          itemCount: videos.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = videos[index];
            if (item is Video) {
              return VideoCard(video: item, isGrid: true, heroPrefix: heroPrefix);
            } else if (item is CommunityPostModel) {
              return CommunityPostCard(post: item);
            } else if (item is AdItem) {
              return HomepageAdCard(ad: item);
            }
            return const SizedBox.shrink();
          },
        ),
      );
    }

    final crossAxisCount = isTablet ? 2 : 3;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childCount: videos.length,
        itemBuilder: (context, index) {
          final item = videos[index];
          if (item is Video) {
            return VideoCard(video: item, isGrid: true, heroPrefix: heroPrefix);
          } else if (item is CommunityPostModel) {
            return CommunityPostCard(post: item);
          } else if (item is AdItem) {
            return HomepageAdCard(ad: item);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildLoadingGrid(BuildContext context) {
    int crossAxisCount;
    if (isMobile) {
      crossAxisCount = 1;
    } else if (isTablet) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isMobile ? 1.2 : 0.8,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          return Shimmer.fromColors(
            baseColor: modernDarkProfessionalTheme
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            highlightColor: modernDarkProfessionalTheme
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.1),
            child: Container(
              decoration: BoxDecoration(
                color: modernDarkProfessionalTheme
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        }, childCount: 6),
      ),
    );
  }

  Widget _buildEmptyGrid(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPosts
                    ? Icons.dynamic_feed_outlined
                    : Icons.video_library_outlined,
                size: 48,
                color: modernDarkProfessionalTheme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                isPosts ? 'No community posts found' : 'No videos found',
                style: modernDarkProfessionalTheme.textTheme.titleMedium
                    ?.copyWith(
                      color: modernDarkProfessionalTheme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                isPosts
                    ? 'Check back later for new updates from creators'
                    : 'Try selecting a different category',
                style: modernDarkProfessionalTheme.textTheme.bodyMedium
                    ?.copyWith(
                      color: modernDarkProfessionalTheme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// FEATURED VIDEO BANNER
// ==========================================================================
class _FeaturedVideoBanner extends StatefulWidget {
  const _FeaturedVideoBanner({required this.horizontalPadding});
  final double horizontalPadding;

  @override
  State<_FeaturedVideoBanner> createState() => _FeaturedVideoBannerState();
}

class _FeaturedVideoBannerState extends State<_FeaturedVideoBanner> {
  late PageController _pageController;
  Timer? _timer;
  final RxInt _currentIndex = 0.obs;
  final RxBool _isHovering = false.obs;
  final RxBool _isVisible = true.obs;
  static const int _infiniteItems = 10000;

  late final HomeController _homeController;
  late final Worker _topicsWorker;
  late final Worker _forYouTopicsWorker;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _homeController = Get.find<HomeController>();

    // Listen to changes in featuredTopics and forYouTopics to reinitialize PageController
    _topicsWorker = ever(_homeController.featuredTopics, (_) {
      if (mounted) {
        _reinitPageController();
      }
    });

    _forYouTopicsWorker = ever(_homeController.forYouTopics, (_) {
      if (mounted) {
        _reinitPageController();
      }
    });

    // Initialize PageController with cached topics if they are already available
    final initialTopics = (_homeController.featuredTopics.isNotEmpty
            ? _homeController.featuredTopics
            : _homeController.forYouTopics)
        .where((t) => t.isValidTopic && t.videoCount > 0)
        .toList();
    if (initialTopics.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _reinitPageController();
        }
      });
    }
  }

  void _reinitPageController() {
    final topics = (_homeController.featuredTopics.isNotEmpty
            ? _homeController.featuredTopics
            : _homeController.forYouTopics)
        .where((t) => t.isValidTopic && t.videoCount > 0)
        .toList();
    if (topics.isEmpty) return;
    final itemsCount = topics.length;
    final initialPage =
        (_infiniteItems ~/ 2) - ((_infiniteItems ~/ 2) % itemsCount);
    try {
      _pageController.dispose();
    } catch (e) {
      debugPrint('PageController dispose error: $e');
    }
    _pageController = PageController(initialPage: initialPage);
    _currentIndex.value = initialPage % itemsCount;
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (_pageController.hasClients &&
          !_isHovering.value &&
          _isVisible.value) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutQuart,
        );
      }
    });
  }

  @override
  void dispose() {
    _topicsWorker.dispose();
    _forYouTopicsWorker.dispose();
    _timer?.cancel();
    try {
      _pageController.dispose();
    } catch (e) {
      debugPrint('PageController dispose error: $e');
    }
    super.dispose();
  }

  void _navigateToTopic(BuildContext context, Topic topic) {
    if (!topic.isValidTopic || topic.slug.trim().isEmpty) return;
    if (Get.isRegistered<TopicController>()) {
      Get.find<TopicController>().topic.value = topic;
    } else {
      Get.find<TopicController>().topic.value = topic;
    }

    Get.toNamed(
      topic.topicRoute,
      arguments: {'slug': topic.slug, 'fromCard': true, 'topic': topic},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < kTabletBreakpoint;
    final bannerHeight = isMobile ? 320.0 : 460.0;

    return Obx(() {
      final rawTopics = _homeController.featuredTopics.isNotEmpty
          ? _homeController.featuredTopics
          : _homeController.forYouTopics;
      final topics = rawTopics
          .where((t) => t.isValidTopic && t.videoCount > 0)
          .toList();

      if (_homeController.isLoadingFeaturedTopics.value && topics.isEmpty) {
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.horizontalPadding,
            vertical: 16,
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
            child: Container(
              height: bannerHeight,
              decoration: BoxDecoration(
                color: modernDarkProfessionalTheme
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        );
      }

      if (topics.isEmpty) {
        return const SizedBox.shrink();
      }

      final itemsCount = topics.length;
      return VisibilityDetector(
        key: const Key('featured_banner_visibility'),
        onVisibilityChanged: (info) {
          if (!mounted) return;
          final visible = info.visibleFraction > 0.1;
          if (_isVisible.value != visible) {
            _isVisible.value = visible;
          }
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.horizontalPadding,
            vertical: 16,
          ),
          child: MouseRegion(
            onEnter: (_) => _isHovering.value = true,
            onExit: (_) => _isHovering.value = false,
            child: Container(
              height: bannerHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: _infiniteItems,
                      onPageChanged: (index) =>
                          _currentIndex.value = index % itemsCount,
                      itemBuilder: (context, index) {
                        final bannerIndex = index % itemsCount;
                        final bannerWidget = _buildBannerItem(
                          context,
                          topic: topics[bannerIndex],
                          isMobile: isMobile,
                        );
                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double pageOffset = 0;
                            if (_pageController.hasClients) {
                              try {
                                pageOffset = _pageController.page! - index;
                              } catch (e) {
                                pageOffset = 0;
                              }
                            }

                            // Awesome transition effects
                            final scale = (1 - (pageOffset.abs() * 0.3)).clamp(
                              0.7,
                              1.0,
                            );
                            final opacity = (1 - (pageOffset.abs() * 0.5))
                                .clamp(0.0, 1.0);

                            return Opacity(
                              opacity: opacity,
                              child: Transform.scale(
                                scale: scale,
                                child: child,
                              ),
                            );
                          },
                          child: bannerWidget,
                        );
                      },
                    ),

                    // Navigation Buttons (Desktop and Tablets)
                    if (!isMobile && itemsCount > 1) ...[
                      _buildNavButton(
                        isLeft: true,
                        onTap: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOutQuart,
                        ),
                      ),
                      _buildNavButton(
                        isLeft: false,
                        onTap: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOutQuart,
                        ),
                      ),
                    ],

                    // Page Indicators
                    if (itemsCount > 1)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(itemsCount, (index) {
                            return Obx(() {
                              final isSelected = _currentIndex.value == index;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: isSelected ? 28 : 7,
                                height: 5,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white
                                          .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(3),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.white
                                                .withValues(alpha: 0.5),
                                            blurRadius: 6,
                                          ),
                                        ]
                                      : null,
                                ),
                              );
                            });
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildNavButton({required bool isLeft, required VoidCallback onTap}) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: isLeft ? 18 : null,
      right: isLeft ? null : 18,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.45),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isLeft
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerItem(
    BuildContext context, {
    required Topic topic,
    required bool isMobile,
    double pageOffset = 0.0,
  }) {
    return _buildBannerItemContent(
      context,
      topic: topic,
      isMobile: isMobile,
      pageOffset: pageOffset,
    );
  }

  Widget _buildBannerItemContent(
    BuildContext context, {
    required Topic topic,
    required bool isMobile,
    double pageOffset = 0.0,
  }) {
    final followingController = Get.isRegistered<FollowingTopicsController>()
        ? Get.find<FollowingTopicsController>()
        : Get.put(FollowingTopicsController());

    final bannerImageUrl = (topic.coverImage?.isNotEmpty ?? false
            ? topic.coverImage
            : topic.thumbnailUrl?.isNotEmpty ?? false
            ? topic.thumbnailUrl
            : null) ??
        'https://images.unsplash.com/photo-1677442136019-21780ecad995?q=80&w=1932&auto=format&fit=crop';

    return GestureDetector(
      onTap: () => _navigateToTopic(context, topic),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Background Image with subtle Parallax
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(pageOffset * 60, 0),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: bannerImageUrl,
                    memCacheWidth: 1200,
                    maxWidthDiskCache: 1200,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    errorWidget: (context, url, error) =>
                        const ColoredBox(color: AppColors.bgSurface),
                    placeholder: (context, url) =>
                        const ColoredBox(color: AppColors.bgSurface),
                  ),
                  // Left-to-right gradient overlay for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.95),
                          Colors.black.withValues(alpha: 0.80),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 0.72, 1.0],
                      ),
                    ),
                  ),
                  // Subtle bottom gradient for indicators
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.only(
              left: isMobile ? 20 : 84,
              right: isMobile ? 20 : 84,
              top: isMobile ? 20 : 32,
              bottom: isMobile ? 20 : 36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // TOPIC Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'TOPIC',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Title
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 680,
                  ),
                  child: Text(
                    topic.title,
                    style: GoogleFonts.roboto(
                      fontSize: isMobile ? 22 : 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                // Meta Info
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${topic.videoCount} ${topic.videoCount == 1 ? 'video' : 'videos'} • ${timeago.format(topic.createdAt)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (topic.category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          topic.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                if (!isMobile && topic.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Description
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 580),
                    child: Text(
                      topic.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                // Action Buttons
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Obx(() {
                      final isFollowed = followingController.isTopicFollowed(
                        topic.id,
                      );
                      return ElevatedButton.icon(
                        onPressed: () {
                          followingController.toggleFollowTopic(topic);
                        },
                        icon: Icon(
                          isFollowed
                              ? Icons.check_circle_outline_rounded
                              : Icons.person_add_alt_1_outlined,
                          color: isFollowed ? Colors.white : Colors.black,
                          size: 16,
                        ),
                        label: Text(
                          isFollowed ? 'Following' : 'Follow',
                          style: TextStyle(
                            color: isFollowed ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowed
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.white,
                          foregroundColor: isFollowed
                              ? Colors.white
                              : Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: isFollowed
                                ? BorderSide(
                                    color: Colors.white
                                        .withValues(alpha: 0.3),
                                  )
                                : BorderSide.none,
                          ),
                          elevation: 0,
                        ),
                      );
                    }),
                    ElevatedButton.icon(
                      onPressed: () {
                        final slug = topic.slug;
                        final title = topic.title;
                        final imageUrl = topic.coverImage ?? topic.thumbnailUrl;
                        final topicUrl = DeepLinkService.topicUrl(slug);
                        final currentFollowerCount =
                            followingController.getFollowerCount(topic);
                        ShareBottomSheet.show(
                          title: title,
                          url: topicUrl,
                          thumbnailUrl: imageUrl,
                          followerCount: currentFollowerCount,
                          videoCount: topic.videoCount,
                          handle: slug,
                          type: 'topic',
                        );
                      },
                      icon: const Icon(
                        Icons.share_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                      label: const Text(
                        'Share',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Followers Count (Top Right)
          Positioned(
            top: isMobile ? 16 : 24,
            right: isMobile ? 16 : 28,
            child: Obx(() {
              final count = followingController.getFollowerCount(topic);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.people_outline_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_formatCount(count)} ${count == 1 ? 'Follower' : 'Followers'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 0) count = 0;
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

// ==========================================================================
// PERSONALIZED PLAYLISTS SECTION
// ==========================================================================
// ==========================================================================
// REALTIME TAGS & TOPICS ROW
// ======================================================// ==========================================================================
// REALTIME FOR YOU TOPICS ROW
// ==========================================================================
class _PersonalizedPlaylistsSection extends StatelessWidget {
  const _PersonalizedPlaylistsSection({required this.horizontalPadding});
  final double horizontalPadding;

  void _navigateToTagPage(BuildContext context, Topic topic) {
    if (!topic.isValidTopic || topic.slug.trim().isEmpty) return;
    if (Get.isRegistered<TopicController>()) {
      Get.find<TopicController>().topic.value = topic;
    } else {
      Get.find<TopicController>().topic.value = topic;
    }

    unawaited(
      Get.toNamed(
        topic.topicRoute,
        arguments: {'slug': topic.slug, 'fromCard': true, 'topic': topic},
      ),
    );
  }

  double _calculatePersonalizationScore(
    Topic topic,
    UserInterestProfile? profile,
  ) {
    var score = topic.trendingScore > 0
        ? topic.trendingScore
        : (topic.videoCount.toDouble());

    if (profile != null) {
      final slug = topic.slug.toLowerCase();
      if (profile.followedTopicSlugs.contains(slug) ||
          profile.followedTopicSlugs.contains(topic.id)) {
        score += 100.0;
      }
      final topicAffinity =
          profile.topicAffinities[slug] ??
          profile.topicAffinities['topic:$slug'] ??
          0.0;
      score += topicAffinity * 50.0;

      final catAffinity =
          profile.categoryAffinities[topic.category] ??
          profile.categoryAffinities[topic.category.toLowerCase()] ??
          0.0;
      score += catAffinity * 30.0;
    }

    return score;
  }

  @override
  Widget build(BuildContext context) {
    final homeController = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : null;
    final profileService = Get.isRegistered<UserInterestProfileService>()
        ? Get.find<UserInterestProfileService>()
        : null;

    return Obx(() {
      final selectedCategory = homeController?.selectedCategory.value ?? 'All';
      final isFlipCoin = selectedCategory == 'Flip Coin' ||
          selectedCategory == '🪙 Flip Coin';
      final isAll = selectedCategory == 'All' || isFlipCoin;

      final userProfile = profileService?.profile.value;

      final sourceTopics = (homeController?.forYouTopics.isNotEmpty ?? false)
          ? homeController!.forYouTopics
          : ((homeController?.featuredTopics.isNotEmpty ?? false)
              ? homeController!.featuredTopics
              : <Topic>[]);

      final isLoading = (homeController?.isLoadingForYouTopics.value ?? false) &&
          sourceTopics.isEmpty;

      if (isLoading) {
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
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
            child: Container(
              height: 215,
              decoration: BoxDecoration(
                color: modernDarkProfessionalTheme
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      }

      // Filter by category if a specific category is selected
      var topicsList = <Topic>[];
      if (!isAll) {
        final catLower = selectedCategory.toLowerCase().trim();
        topicsList = sourceTopics.where((t) {
          if (!t.isValidTopic || t.videoCount <= 0) return false;
          final tCat = t.category.toLowerCase().trim();
          final tSlug = t.slug.toLowerCase().trim();
          final tTitle = t.title.toLowerCase().trim();
          return tCat == catLower ||
              tCat.contains(catLower) ||
              catLower.contains(tCat) ||
              tSlug.contains(catLower) ||
              tTitle.contains(catLower);
        }).toList();
      } else {
        topicsList = sourceTopics
            .where((t) => t.isValidTopic && t.videoCount > 0)
            .toList();
      }

      if (topicsList.isEmpty) {
        return const SizedBox.shrink();
      }

      // Personalize and sort by user interest score (inverted for Flip Coin opposite perspective)
      topicsList.sort((a, b) {
        final scoreA = _calculatePersonalizationScore(a, userProfile);
        final scoreB = _calculatePersonalizationScore(b, userProfile);
        return isFlipCoin
            ? scoreA.compareTo(scoreB)
            : scoreB.compareTo(scoreA);
      });

      final sectionTitle = isFlipCoin
          ? 'Opposite Perspective Topics'
          : (isAll ? 'For You Topics' : '$selectedCategory Topics');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.topic_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sectionTitle,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00E676).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E676),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: GoogleFonts.roboto(
                          color: const Color(0xFF00E676),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 215,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              itemCount: topicsList.length,
              itemBuilder: (context, index) {
                final topic = topicsList[index];
                final imageUrl = (topic.coverImage?.isNotEmpty ?? false)
                    ? topic.coverImage!
                    : ((topic.thumbnailUrl?.isNotEmpty ?? false)
                          ? topic.thumbnailUrl!
                          : '');

                return Container(
                  width: 270,
                  margin: const EdgeInsets.only(right: 16),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _navigateToTagPage(context, topic),
                      splashColor: Colors.white.withValues(alpha: 0.2),
                      highlightColor: Colors.white.withValues(alpha: 0.1),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppColors.bgSurfaceContainerHighest,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Uncropped Thumbnail Container (Preserves full aspect ratio)
                            Stack(
                              children: [
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(15),
                                    ),
                                    child: imageUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: imageUrl,
                                            memCacheWidth: 480,
                                            maxWidthDiskCache: 480,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                const ColoredBox(color: AppColors.bgSurface),
                                            errorWidget: (context, url, error) =>
                                                const ColoredBox(color: AppColors.bgSurface),
                                          )
                                        : ColoredBox(
                                            color: AppColors.bgSurface,
                                            child: Icon(
                                              Icons.topic_rounded,
                                              color: Colors.white.withValues(alpha: 0.6),
                                              size: 40,
                                            ),
                                          ),
                                  ),
                                ),

                                // Category & Video count Badges Overlay
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  right: 10,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.75),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.25),
                                          ),
                                        ),
                                        child: Text(
                                          topic.category.isNotEmpty
                                              ? topic.category
                                              : 'Topic',
                                          style: GoogleFonts.roboto(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (topic.videoCount > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.75),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.15),
                                            ),
                                          ),
                                          child: Text(
                                            '${topic.videoCount} videos',
                                            style: GoogleFonts.roboto(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Card Footer: Title & Navigation Arrow
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      topic.title,
                                      style: GoogleFonts.roboto(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.white,
                                      size: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

// ==========================================================================
// REUSABLE MODERN AVATAR WIDGET
// ==========================================================================
class _ModernAvatar extends StatelessWidget {
  const _ModernAvatar({
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

extension StringExtension on String {
  String safeSubstring(int start, int end) {
    if (isEmpty) return this;
    if (end > length) end = length;
    return substring(start, end);
  }
}

// ==========================================================================
// SHIMMER PLACEHOLDERS FOR DEFERRED LOADS
// ==========================================================================

class SubscriptionsShimmerPlaceholder extends StatelessWidget {
  const SubscriptionsShimmerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Shimmer.fromColors(
                  baseColor: const Color(0xFF1E1E1E),
                  highlightColor: Colors.white12,
                  child: Container(
                    width: 180,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              // Channel Avatars Shimmer
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Shimmer.fromColors(
                        baseColor: const Color(0xFF1E1E1E),
                        highlightColor: Colors.white12,
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 50,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // Chips Shimmer
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: List.generate(6, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Shimmer.fromColors(
                        baseColor: const Color(0xFF1E1E1E),
                        highlightColor: Colors.white12,
                        child: Container(
                          width: 80,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),
              // Video Grid Shimmer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile ? 1 : 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isMobile ? 1.3 : 0.8,
                  ),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    return Shimmer.fromColors(
                      baseColor: const Color(0xFF1E1E1E),
                      highlightColor: Colors.white12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: 120,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
}

class TopicsShimmerPlaceholder extends StatelessWidget {
  const TopicsShimmerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.fromColors(
                  baseColor: const Color(0xFF1E1E1E),
                  highlightColor: Colors.white12,
                  child: Container(
                    width: 200,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Search Bar Shimmer
                Shimmer.fromColors(
                  baseColor: const Color(0xFF1E1E1E),
                  highlightColor: Colors.white12,
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Category Grid Shimmer
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile ? 2 : 4,
                    childAspectRatio: 1.6,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: isMobile ? 4 : 8,
                  itemBuilder: (context, index) {
                    return Shimmer.fromColors(
                      baseColor: const Color(0xFF1E1E1E),
                      highlightColor: Colors.white12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // PageView Shimmer
                Shimmer.fromColors(
                  baseColor: const Color(0xFF1E1E1E),
                  highlightColor: Colors.white12,
                  child: Container(
                    height: isMobile ? 300 : 450,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
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
}

class LibraryShimmerPlaceholder extends StatelessWidget {
  const LibraryShimmerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header Shimmer
              Shimmer.fromColors(
                baseColor: const Color(0xFF1E1E1E),
                highlightColor: Colors.white12,
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 90,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // List tiles shimmer
              Expanded(
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 8,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Shimmer.fromColors(
                        baseColor: const Color(0xFF1E1E1E),
                        highlightColor: Colors.white12,
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Container(
                              width: 150,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
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
        ),
      ),
    );
  }
}
