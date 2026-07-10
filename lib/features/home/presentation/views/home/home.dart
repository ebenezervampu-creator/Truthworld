import 'package:truthworld/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
// import 'package:truthworld/features/home/presentation/views/home/search/search.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/notification.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';

// Feature Pages for Dashboard (Deferred for YouTube-speed startup)
import 'package:truthworld/features/subscriptions/presentation/views/subscriptions/subscriptions.dart'
    deferred as subscriptions;
import 'package:truthworld/features/watchhistory/presentation/views/watchhistory/watchhistory.dart'
    deferred as history;
import 'package:truthworld/features/myvideos/presentation/views/myvideos/my_videos.dart'
    deferred as my_videos;
import 'package:truthworld/features/library/presentation/views/library/library_screen.dart'
    deferred as lib_feature;
import 'package:truthworld/features/trending/presentation/views/trending/trending_page.dart'
    deferred as trending;
import 'package:truthworld/features/about/presentation/views/About/about.dart'
    deferred as about;
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/privacy_polices.dart'
    deferred as privacy;
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/terms.dart'
    deferred as terms;
import 'package:truthworld/features/settings/presentation/views/settings/settings.dart'
    deferred as settings;
import 'package:truthworld/features/feedback/presentation/views/feedback/help.dart'
    deferred as help;
import 'package:truthworld/features/video/presentation/views/clips/clips_page.dart'
    deferred as clips;
import 'package:truthworld/features/feedback/presentation/views/feedback/feedbacks.dart'
    deferred as feedback;
import 'package:truthworld/features/likedvideos/presentation/views/likedvideos/liked_video_screen.dart'
    deferred as liked_videos;
import 'package:truthworld/features/video/presentation/views/downloadpage/download_page.dart'
    deferred as downloads;
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_screen.dart'
    deferred as playlist;
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_detail_screen.dart'
    deferred as playlist_detail;
import 'package:truthworld/features/discover/presentation/views/discover_channels.dart'
    deferred as discover;
import 'package:truthworld/features/channel/presentation/views/channel/channel_details_screen.dart'
    deferred as channel_details;
import 'package:truthworld/features/topics/presentation/pages/explore_topics_page.dart'
    deferred as explore_topics;
import 'package:truthworld/features/topics/presentation/pages/following_topics_page.dart'
    deferred as following_topics;
import 'package:truthworld/features/content/presentation/views/mvp/privacy-policy/community_guidelines.dart'
    deferred as community_guidelines;

import 'package:truthworld/core/widgets/deferred_widget.dart';

// ==========================================================================
// ENHANCED DARK PROFESSIONAL THEME DEFINITION
// ==========================================================================
final Color darkBackground = AppColors.bgPage; // Deeper black
final Color darkSurface = AppColors.bgInput; // Rich dark surface
final Color darkSurfaceVariant = Color(0xFF1E1E1E); // Elevated surfaces
final Color darkOnSurface = Color(0xFFE8E8E8); // Crisp white text
final Color darkOnSurfaceVariant = Color(0xFFB8B8B8); // Muted text
final Color primaryAccent = Color(0xFF1976D2); // Professional blue
final Color secondaryAccent = Color(0xFF42A5F5); // Lighter blue
final Color tertiaryAccent = Color(0xFF90CAF9); // Subtle blue
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
    surface: darkSurface,
    onSurface: darkOnSurface,
    surfaceContainerHighest: darkSurfaceVariant,
    onSurfaceVariant: darkOnSurfaceVariant,
    error: Color(0xFFFF6B6B),
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
    scrolledUnderElevation: 1,
    surfaceTintColor: primaryAccent.withValues(alpha: 0.05),
    titleTextStyle: GoogleFonts.roboto(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: darkOnSurface,
      letterSpacing: 0.15,
    ),
    iconTheme: IconThemeData(color: darkOnSurfaceVariant, size: 24),
    actionsIconTheme: IconThemeData(color: darkOnSurfaceVariant, size: 24),
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
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        return IconThemeData(color: Colors.grey, size: 24);
      }
      return IconThemeData(color: darkOnSurfaceVariant, size: 24);
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
    groupAlignment: -1.0,
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
    selectedIconTheme: IconThemeData(color: primaryAccent, size: 24),
    unselectedIconTheme: IconThemeData(color: darkOnSurfaceVariant, size: 24),
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
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      borderSide: BorderSide(color: darkSurfaceVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: darkSurfaceVariant.withValues(alpha: 0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: primaryAccent, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Color(0xFFFF6B6B)),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
const double kTabletBreakpoint = 600.0;
const double kDesktopBreakpoint = 1000.0;
const double kSideNavWidth = 280.0;
const double kCompactSideNavWidth = 80.0;
const double kBottomNavBarHeight = kToolbarHeight;

// ==========================================================================
// ENHANCED HOME CONTROLLER
// ==========================================================================
// ==========================================================================
// MODERNIZED HOME WIDGET
// ==========================================================================
class Home extends GetView<HomeController> {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
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
        final bool isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
        final bool isTablet =
            constraints.maxWidth >= kTabletBreakpoint &&
            constraints.maxWidth < kDesktopBreakpoint;
        final bool isMobile = constraints.maxWidth < kTabletBreakpoint;
        final bool showCompactNavRail = isTablet && constraints.maxWidth < 850;
        return Scaffold(
          backgroundColor: modernDarkProfessionalTheme.scaffoldBackgroundColor,
          appBar: _buildGlobalAppBar(context, isMobile, isTablet, isDesktop),
          drawer: null,
          body: Row(
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
          bottomNavigationBar: isMobile || isTablet
              ? _buildBottomNavigation(context)
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
      final int index = controller.sideNavSelectedIndex.value;
      final bool isCore = _isCoreTab(index);

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
                  builder: () =>
                      explore_topics.ExploreTopicsPage(isDashboard: true),
                ),
                // Tab 4: Library
                DeferredWidget(
                  key: const PageStorageKey('tab_library'),
                  loader: lib_feature.loadLibrary,
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
                ? Container(
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
          builder: () => following_topics.FollowingTopicsPage(isDashboard: true),
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
      case HomeController.indexHelp:
        return DeferredWidget(
          loader: help.loadLibrary,
          builder: () => help.HelpPage(isDashboard: true),
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
    if (isMobile || isTablet) return _buildMobileAppBar(context);

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 10),
      child: AppBar(
        backgroundColor:
            modernDarkProfessionalTheme.appBarTheme.backgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: _buildDesktopHeader(context),
        actions: _buildAppBarActions(context, false),
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        children: [
          InkWell(
            onTap: () => Get.offAllNamed("/"),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryAccent, secondaryAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    "Truthworld",
                    style: modernDarkProfessionalTheme.textTheme.titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              modernDarkProfessionalTheme.colorScheme.onSurface,
                        ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 40),
          Expanded(
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: 650),
                height: 44,
                child: Material(
                  borderRadius: BorderRadius.circular(22),
                  color: modernDarkProfessionalTheme
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  child: InkWell(
                    onTap: () {
                      Get.toNamed('/search');
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: modernDarkProfessionalTheme
                                .colorScheme
                                .onSurfaceVariant,
                            size: 22,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Search videos...',
                              style: modernDarkProfessionalTheme
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: modernDarkProfessionalTheme
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    return AppBar(
      title: _buildMobileHeader(context),
      titleSpacing: 0,
      actions: _buildAppBarActions(context, true),
      elevation: 0,
      backgroundColor: modernDarkProfessionalTheme.appBarTheme.backgroundColor,
      surfaceTintColor:
          modernDarkProfessionalTheme.appBarTheme.surfaceTintColor,
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: InkWell(
        onTap: () => Get.offAllNamed("/"),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryAccent, secondaryAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Truthworld",
                style: modernDarkProfessionalTheme.textTheme.titleLarge
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: modernDarkProfessionalTheme.colorScheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, bool isMobile) {
    return [
      if (isMobile)
        Container(
          margin: EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: modernDarkProfessionalTheme
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              Icons.search_rounded,
              color: modernDarkProfessionalTheme.colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Search',
            onPressed: () {
              Get.toNamed('/search');
            },
          ),
        ),
      if (isMobile) _buildNotificationLogo(context),
      if (!isMobile)
        Obx(
          () => controller.currentUser.value == null
              ? _buildSignInButton(context)
              : Row(
                  children: [
                    _buildNotificationLogo(context),

                    _buildUserMenu(context),
                  ],
                ),
        ),
    ];
  }

  Widget _buildNotificationLogo(BuildContext context) {
    // Ensure controller is initialized
    if (!Get.isRegistered<VideoFeedNotificationController>()) {
      Get.put(VideoFeedNotificationController());
    }
    final controller = Get.find<VideoFeedNotificationController>();
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Obx(() {
        final count = controller.unseenCount;
        return Stack(
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                size: 24,
                color: Colors.white70,
              ),
              onPressed: () {
                Get.toNamed('/notifications');
              },
              tooltip: 'Notifications',
            ),
            if (count > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildSignInButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Obx(
        () => OutlinedButton.icon(
          icon: Icon(
            Icons.account_circle_outlined,
            size: 18,
            color: primaryAccent,
          ),
          label: Text(
            controller.isLoadingAuth.value ? "Signing In..." : "Sign In",
            style: TextStyle(color: primaryAccent, fontWeight: FontWeight.w500),
          ),
          onPressed: controller.isLoadingAuth.value
              ? null
              : controller.signInWithGoogle,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: primaryAccent.withValues(alpha: 0.6),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
    );
  }

  Widget _buildUserMenu(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0, left: 4.0),
      child: PopupMenuButton<String>(
        tooltip: "Account",
        offset: const Offset(0, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        color: modernDarkProfessionalTheme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        onSelected: (value) {
          switch (value) {
            case 'studio':
              if (AuthService.to.hasChannel.value) {
                Get.toNamed('/studio');
              } else {
                Get.toNamed('/channelscreen');
              }
              break;
          }
        },
        itemBuilder: (context) => [
          _buildUserInfoMenuItem(context),
          const PopupMenuDivider(height: 1),

          _buildPopupMenuItem(
            context,
            Icons.analytics_outlined,
            'Studio',
            'studio',
          ),
        ],
        child: Obx(() => _buildUserAvatar(context)),
      ),
    );
  }

  PopupMenuItem<String> _buildUserInfoMenuItem(BuildContext context) {
    return PopupMenuItem(
      value: 'user_info',
      enabled: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Obx(() => _buildUserAvatar(context, radius: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(
                  () => Text(
                    controller.currentUser.value?.displayName ?? 'User',
                    style: modernDarkProfessionalTheme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Obx(
                  () => controller.currentUser.value?.email != null
                      ? Text(
                          controller.currentUser.value!.email!,
                          style: modernDarkProfessionalTheme.textTheme.bodySmall
                              ?.copyWith(
                                color: modernDarkProfessionalTheme
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                          overflow: TextOverflow.ellipsis,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    String value,
  ) {
    return PopupMenuItem(
      value: value,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: modernDarkProfessionalTheme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(title, style: modernDarkProfessionalTheme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context, {double radius = 18}) {
    final imageUrl = controller.currentUser.value?.photoURL;
    return _ModernAvatar(
      imageUrl: imageUrl,
      radius: radius,
      placeholderText: controller.currentUser.value?.displayName
          ?.safeSubstring(0, 1)
          .toUpperCase(),
    );
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
    return Obx(
      () => Container(
        decoration: BoxDecoration(
          color: modernDarkProfessionalTheme.navigationBarTheme.backgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: modernDarkProfessionalTheme.navigationBarTheme
                .copyWith(
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return IconThemeData(color: Colors.grey, size: 24);
                    }
                    return IconThemeData(color: darkOnSurfaceVariant, size: 24);
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
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.interests_outlined),
                selectedIcon: Icon(Icons.interests),
                label: ' Topics',
              ),
              NavigationDestination(
                icon: Icon(Icons.subscriptions_outlined),
                selectedIcon: Icon(Icons.subscriptions),
                label: 'Subscriptions',
              ),
              NavigationDestination(
                icon: (() {
                  final user = controller.currentUser.value;
                  if (user != null &&
                      user.photoURL != null &&
                      user.photoURL!.isNotEmpty) {
                    return CircleAvatar(
                      radius: 12,
                      backgroundImage: NetworkImage(user.photoURL!),
                    );
                  } else if (user != null) {
                    final initial =
                        user.displayName != null && user.displayName!.isNotEmpty
                        ? user.displayName![0].toUpperCase()
                        : (user.email != null && user.email!.isNotEmpty
                              ? user.email![0].toUpperCase()
                              : 'E');
                    return CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.blue,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const Icon(Icons.account_circle_outlined);
                })(),
                selectedIcon: (() {
                  final user = controller.currentUser.value;
                  if (user != null &&
                      user.photoURL != null &&
                      user.photoURL!.isNotEmpty) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: CircleAvatar(
                        radius: 11,
                        backgroundImage: NetworkImage(user.photoURL!),
                      ),
                    );
                  } else if (user != null) {
                    final initial =
                        user.displayName != null && user.displayName!.isNotEmpty
                        ? user.displayName![0].toUpperCase()
                        : (user.email != null && user.email!.isNotEmpty
                              ? user.email![0].toUpperCase()
                              : 'E');
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.blue,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }
                  return const Icon(Icons.account_circle_rounded);
                })(),
                label: 'You',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// MODERNIZED SIDE NAVIGATION RAIL
// ==========================================================================
class _ModernSideNavigationRail extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onSelectItem;
  final VoidCallback onShowSignInSnackbar;
  final User? currentUser;
  final bool isCompact;
  final HomeController homeController;
  const _ModernSideNavigationRail({
    required this.selectedIndex,
    required this.onSelectItem,
    required this.onShowSignInSnackbar,
    required this.currentUser,
    this.isCompact = false,
    required this.homeController,
  });
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

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(height: 8),

        // Main Navigation Section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCompact)
                Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8, top: 4),
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
                route: "/home",
              ),
              _buildNavItem(
                context,
                Icons.subscriptions_rounded,
                Icons.subscriptions_outlined,
                'Subscriptions',
                HomeController.indexSubscriptions,
                route: "/subscriptions",
                requiresAuth: true,
              ),
              _buildNavItem(
                context,
                Icons.explore_rounded,
                Icons.explore_outlined,
                'Discover Channel',
                HomeController.indexDiscover,
                route: "/discover",
              ),
              _buildNavItem(
                context,
                Icons.interests_rounded,
                Icons.interests_outlined,
                'Explore Topics',
                HomeController.indexExploreTopics,
                route: "/explore-topics",
              ),
            ],
          ),
        ),

        Obx(() {
          if (!AuthService.to.isAuthenticated.value) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              _buildDivider(context),
              SizedBox(height: 4),
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
                        padding: EdgeInsets.only(left: 4, bottom: 8, top: 4),
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
                          onTap: () => homeController.navigateToYourChannel(),
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
                      route: "/history",
                      requiresAuth: true,
                    ),
                    _buildNavItem(
                      context,
                      Icons.playlist_play_rounded,
                      Icons.playlist_play_outlined,
                      'Playlists',
                      HomeController.indexPlaylists,
                      route: "/playlistscreen",
                      requiresAuth: true,
                    ),
                    _buildNavItem(
                      context,
                      Icons.check_circle_rounded,
                      Icons.check_circle_outline_rounded,
                      'Following Topics',
                      HomeController.indexFollowingTopics,
                      route: "/following-topics",
                      requiresAuth: true,
                    ),
                    _buildNavItem(
                      context,
                      Icons.watch_later_rounded,
                      Icons.watch_later_outlined,
                      'Watch later',
                      HomeController.indexWatchLater,
                      requiresAuth: true,
                      onTap: () => homeController.navigateToWatchLater(),
                    ),
                    _buildNavItem(
                      context,
                      Icons.favorite_rounded,
                      Icons.favorite_outline,
                      'Liked videos',
                      HomeController.indexLikedVideos,
                      route: "/likedvideos",
                      requiresAuth: true,
                    ),
                    _buildNavItem(
                      context,
                      Icons.slideshow_rounded,
                      Icons.slideshow_outlined,
                      'Your videos',
                      HomeController.indexYourVideos,
                      route: "/myvideos",
                      requiresAuth: true,
                    ),
                    _buildNavItem(
                      context,
                      Icons.content_cut_rounded,
                      Icons.content_cut_outlined,
                      'Your Clips',
                      HomeController.indexClips,
                      route: "/clips",
                      requiresAuth: true,
                    ),
                    _buildNavItem(
                      context,
                      Icons.download_rounded,
                      Icons.download_outlined,
                      'Downloads',
                      HomeController.indexDownloads,
                      route: "/downloads",
                      requiresAuth: true,
                    ),
                  ],
                ),
              ),
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
              SizedBox(height: 4),
              _buildDivider(context),
              SizedBox(height: 8),

              // Subscriptions Section
              _buildSectionHeader(context, 'Following'),
              _buildSubscriptionList(context),
            ],
          );
        }),

        SizedBox(height: 4),
        _buildDivider(context),
        SizedBox(height: 4),

        // Support Section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCompact)
                Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8, top: 4),
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
                route: "/settings",
              ),
              _buildNavItem(
                context,
                Icons.help_rounded,
                Icons.help_outline,
                'Help Center',
                HomeController.indexHelp,
                route: "/help",
              ),
              _buildNavItem(
                context,
                Icons.chat_bubble_rounded,
                Icons.chat_bubble_outline,
                'Feedback',
                HomeController.indexFeedback,
                route: "/feedback",
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

        SizedBox(height: 4),
        _buildDivider(context),
        SizedBox(height: 4),

        // Legal & Policies Section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCompact)
                Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8, top: 4),
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
                Icons.admin_panel_settings_rounded,
                Icons.admin_panel_settings_outlined,
                'Admin Portal',
                999,
                route: '/admin/login',
                onTap: () {
                  Get.toNamed('/admin/login');
                },
              ),
            ],
          ),
        ),

        SizedBox(height: 4),
        _buildDivider(context),
        SizedBox(height: 4),

        // Footer Section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16),
              // Footer
              if (!isCompact)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                  child: Column(
                    children: [
                      Text(
                        '© 2026 Truthworld',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: isDarkMode
                              ? Colors.white38
                              : Color(0xFF94A3B8),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Made with ❤️ for creators',
                        style: GoogleFonts.roboto(
                          fontSize: 11,
                          color: isDarkMode
                              ? Colors.white24
                              : Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
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
    final bool isSelected = (index == HomeController.indexWatchLater)
        ? (selectedIndex == HomeController.indexPlaylistDetail &&
              homeController.selectedPlaylist.value?.playlistName
                      .toLowerCase() ==
                  'watch later')
        : selectedIndex == index;
    final color = isSelected
        ? Colors.white
        : modernDarkProfessionalTheme.colorScheme.onSurfaceVariant;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 2),
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
            duration: Duration(milliseconds: 200),
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
            duration: Duration(milliseconds: 200),
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
          duration: Duration(milliseconds: 200),
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
      final bool isDashboardPage =
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
          index == HomeController.indexHelp ||
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
          final bool isAtHome =
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
      margin: EdgeInsets.symmetric(vertical: 16),
      height: 0.5,
      color: modernDarkProfessionalTheme.dividerColor,
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    if (isCompact) return SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
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
            subscriberCount: 0,
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
      arguments: {"channel": channel, 'subscribercount': subscriberCount},
    );
    Future.delayed(Duration(seconds: 1), () {
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
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            if (!isCompact) ...[
              SizedBox(width: 16),
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
                SizedBox(width: 8),
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
  final Channel channel;
  final VoidCallback onTap;
  final bool isCompact;
  const _ModernChannelListItem({
    required this.channel,
    required this.onTap,
    required this.isCompact,
  });
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
          SizedBox(height: 4),
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
        SizedBox(width: 16),
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
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final HomeController homeController;
  final List<Widget> Function(BuildContext) appBarActionsBuilder;
  const _ModernMainContent({
    super.key,
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    required this.homeController,
    required this.appBarActionsBuilder,
  });
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
      debugPrint("Error formatting timestamp: $e");
      return "some time ago";
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      'All',
      'Education',
      'Entertainment',
      'Music',
      'News',
      'Sports',
      'Gaming',
      'Technology',
      'Science',
      'Travel',
      'Lifestyle',
      'Comedy',
      'Documentary',
      'Movies',
      'TV Shows',
      'Vlogs',
      'DIY & How-to',
      'Health & Fitness',
      'Fashion & Beauty',
      'Food & Cooking',
      'Business & Finance',
      'Animation',
      'Short Films',
      'Motivation',
      'History',
      'Art & Design',
      'Automotive',
      'Animals & Pets',
      'Spirituality',
      'Nature & Wildlife',
      'Kids & Family',
    ];
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 24.0 : 32.0);
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
      child: CustomScrollView(
        controller: homeController.scrollController,
        slivers: [
          if (homeController.sideNavSelectedIndex.value ==
              HomeController.indexHome)
            _buildMobileCategoryBar(context, categories),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FeaturedVideoBanner(horizontalPadding: horizontalPadding),
                SizedBox(height: 32),
                _PersonalizedPlaylistsSection(
                  horizontalPadding: horizontalPadding,
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
          Obx(() {
            if (homeController.isLoadingVideos.value) {
              return _ModernVideoGridSection(
                isMobile: isMobile,
                isTablet: isTablet,
                isDesktop: isDesktop,
                videos: [], // Pass empty list while loading
                heroPrefix: 'grid_loading',
                isLoading: true,
                horizontalPadding: horizontalPadding,
                formatViews: _formatViews,
                formatTimestamp: _formatTimestamp,
              );
            }
            return _ModernVideoGridSection(
              isMobile: isMobile,
              isTablet: isTablet,
              isDesktop: isDesktop,
              videos: homeController.videos,
              heroPrefix: 'main_grid',
              isLoading: false,
              horizontalPadding: horizontalPadding,
              formatViews: _formatViews,
              formatTimestamp: _formatTimestamp,
            );
          }),
          Obx(() {
            if (homeController.isLoadingMore.value) {
              return SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: primaryAccent),
                  ),
                ),
              );
            }
            return SliverToBoxAdapter(child: SizedBox.shrink());
          }),
          SliverToBoxAdapter(
            child: SizedBox(
              height: isMobile || isTablet ? kBottomNavBarHeight + 16 : 16,
            ),
          ),
        ],
      ),
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
    final bool isMobile = MediaQuery.of(context).size.width < kTabletBreakpoint;
    return PreferredSize(
      preferredSize: Size.fromHeight(isMobile ? 64.0 : 72.0),
      child: Container(
        height: isMobile ? 64.0 : 72.0,
        decoration: BoxDecoration(
          color: modernDarkProfessionalTheme.appBarTheme.backgroundColor,
          border: Border(
            bottom: BorderSide(
              color: modernDarkProfessionalTheme.dividerColor,
              width: 0.5,
            ),
          ),
        ),
        padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8.0 : 16.0),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return Obx(() {
              final isSelected =
                  homeController.selectedCategory.value == category;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 4.0 : 6.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      homeController.selectCategory(category);
                      Get.toNamed(
                        "/category",
                        arguments: {"category": category},
                      );
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Row(
                      children: [
                        if (index == 0 && isMobile)
                          Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.category_rounded,
                              color: isSelected
                                  ? primaryAccent
                                  : modernDarkProfessionalTheme
                                        .colorScheme
                                        .onSurfaceVariant,
                              size: 20,
                            ),
                          ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 20,
                            vertical: isMobile ? 10 : 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(0xFF2A2A2A)
                                : Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Checkmark for selected
                              if (isSelected) ...[
                                Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: isMobile ? 14 : 16,
                                ),
                                SizedBox(width: 6),
                              ],
                              // Category text - show full text
                              Text(
                                category,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: isMobile ? 13 : 14,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            });
          },
        ),
      ),
    );
  }
}

// ==========================================================================
// MODERNIZED VIDEO GRID SECTION
// ==========================================================================
class _ModernVideoGridSection extends StatelessWidget {
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final List<Video> videos;
  final String heroPrefix;
  final bool isLoading;
  final double horizontalPadding;
  final String Function(int) formatViews;
  final String Function(Timestamp) formatTimestamp;
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
  });
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingGrid(context);
    }
    if (videos.isEmpty) {
      return _buildEmptyGrid(context);
    }
    return _buildVideoGrid(context, videos);
  }

  Widget _buildVideoGrid(BuildContext context, List<Video> videos) {
    int crossAxisCount = isMobile ? 1 : 3;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childCount: videos.length,
        itemBuilder: (context, index) {
          // ðŸ’¡ PRE-CACHE NEXT ITEMS AHEAD
          if (index + 2 < videos.length) {
            final nextThumb = videos[index + 2].thumbnailUrl;
            if (nextThumb.isNotEmpty) {
              precacheImage(CachedNetworkImageProvider(nextThumb), context);
            }
          }
          return _buildGridVideoCard(context, videos[index]);
        },
      ),
    );
  }

  Widget _buildGridVideoCard(BuildContext context, Video video) {
    return Container(
      decoration: BoxDecoration(
        color: modernDarkProfessionalTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: modernDarkProfessionalTheme.colorScheme.outline.withValues(
            alpha: 0.1,
          ),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Navigate to video screen using miniplayer-aware navigation
            // The miniplayer will be pre-loaded and ready to show when user navigates away
            MiniplayerNavigationHelper.navigateToVideoScreen(
              video: video,
              routeArguments: {'video': video},
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGridVideoThumbnail(context, video),
              _buildGridVideoInfo(context, video),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridVideoThumbnail(BuildContext context, Video video) {
    return Hero(
      tag: '${heroPrefix}_${video.id}',
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: video.thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildThumbnailShimmer(context),
                errorWidget: (context, url, error) =>
                    _buildThumbnailError(context),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    video.duration,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridVideoInfo(BuildContext context, Video video) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ModernAvatar(
            imageUrl: video.channelImage,
            radius: 18,
            placeholderText: video.channelName
                .safeSubstring(0, 1)
                .toUpperCase(),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: modernDarkProfessionalTheme.textTheme.titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                        fontSize: 15,
                      ),
                ),
                SizedBox(height: 6),
                Text(
                  video.channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: modernDarkProfessionalTheme.textTheme.bodySmall
                      ?.copyWith(
                        color: modernDarkProfessionalTheme
                            .colorScheme
                            .onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                SizedBox(height: 2),
                Text(
                  '${formatViews(video.views)} views • ${formatTimestamp(video.uploadedAt)}',
                  style: modernDarkProfessionalTheme.textTheme.bodySmall
                      ?.copyWith(
                        color: modernDarkProfessionalTheme
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert,
              size: 20,
              color: modernDarkProfessionalTheme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: modernDarkProfessionalTheme.colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.3),
      highlightColor: modernDarkProfessionalTheme
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.1),
      child: Container(
        color: modernDarkProfessionalTheme.colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _buildThumbnailError(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryAccent.withValues(alpha: 0.3),
            secondaryAccent.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          size: 48,
          color: Colors.white,
        ),
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
                Icons.video_library_outlined,
                size: 48,
                color: modernDarkProfessionalTheme.colorScheme.onSurfaceVariant,
              ),
              SizedBox(height: 16),
              Text(
                'No videos found',
                style: modernDarkProfessionalTheme.textTheme.titleMedium
                    ?.copyWith(
                      color: modernDarkProfessionalTheme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
              SizedBox(height: 8),
              Text(
                'Try selecting a different category',
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
  final double horizontalPadding;
  const _FeaturedVideoBanner({required this.horizontalPadding});

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

  final RxList<Topic> _dbTopics = <Topic>[].obs;
  final RxBool _isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchTopicsFromFirestore();
  }

  Future<void> _fetchTopicsFromFirestore() async {
    try {
      _isLoading.value = true;
      final snapshot = await FirebaseFirestore.instance
          .collection('topics')
          .where('isFeatured', isEqualTo: true)
          .limit(6)
          .get();

      List<Topic> topics = [];
      if (snapshot.docs.isNotEmpty) {
        topics = snapshot.docs
            .map((doc) => Topic.fromDocumentSnapshot(doc))
            .toList();
      }

      if (topics.isEmpty) {
        final fallbackSnapshot = await FirebaseFirestore.instance
            .collection('topics')
            .orderBy('videoCount', descending: true)
            .limit(6)
            .get();
        if (fallbackSnapshot.docs.isNotEmpty) {
          topics = fallbackSnapshot.docs
              .map((doc) => Topic.fromDocumentSnapshot(doc))
              .toList();
        }
      }

      if (mounted) {
        _dbTopics.value = topics;
        _reinitPageController();
      }
    } catch (e) {
      debugPrint('Error fetching topics from Firestore for home banner: $e');
    } finally {
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }

  void _reinitPageController() {
    if (_dbTopics.isEmpty) return;
    final int itemsCount = _dbTopics.length;
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
    _timer?.cancel();
    try {
      _pageController.dispose();
    } catch (e) {
      debugPrint('PageController dispose error: $e');
    }
    super.dispose();
  }

  void _navigateToTopic(BuildContext context, Topic topic) {
    if (Get.isRegistered<TopicController>()) {
      Get.find<TopicController>().topic.value = topic;
    } else {
      Get.put(TopicController()).topic.value = topic;
    }

    Get.toNamed(
      topic.topicRoute,
      arguments: {'slug': topic.slug, 'fromCard': true, 'topic': topic},
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < kTabletBreakpoint;
    final double bannerHeight = isMobile ? 320 : 520;

    return Obx(() {
      if (_isLoading.value) {
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

      if (_dbTopics.isEmpty) {
        return const SizedBox.shrink();
      }

      final int itemsCount = _dbTopics.length;
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
                    offset: Offset(0, 10),
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
                            final double scale = (1 - (pageOffset.abs() * 0.3))
                                .clamp(0.7, 1.0);
                            final double opacity =
                                (1 - (pageOffset.abs() * 0.5)).clamp(0.0, 1.0);

                            return Opacity(
                              opacity: opacity,
                              child: Transform.scale(
                                scale: scale,
                                child: _buildBannerItem(
                                  context,
                                  topic: _dbTopics[bannerIndex],
                                  isMobile: isMobile,
                                  pageOffset: pageOffset,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    // Navigation Buttons (Desktop only or large tablets)
                    if (!isMobile) ...[
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
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(itemsCount, (index) {
                          return Obx(() {
                            final bool isSelected =
                                _currentIndex.value == index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: isSelected ? 32 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white38,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.white.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 8,
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
      left: isLeft ? 16 : null,
      right: isLeft ? null : 16,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                isLeft
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: Colors.white,
                size: 32,
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
    required double pageOffset,
  }) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('topics')
          .doc(topic.id)
          .snapshots(),
      builder: (context, snapshot) {
        Topic currentTopic = topic;
        if (snapshot.hasData && snapshot.data!.exists) {
          currentTopic = Topic.fromDocumentSnapshot(snapshot.data!);
        }
        return _buildBannerItemContent(
          context,
          topic: currentTopic,
          isMobile: isMobile,
          pageOffset: pageOffset,
        );
      },
    );
  }

  Widget _buildBannerItemContent(
    BuildContext context, {
    required Topic topic,
    required bool isMobile,
    required double pageOffset,
  }) {
    final followingController = Get.isRegistered<FollowingTopicsController>()
        ? Get.find<FollowingTopicsController>()
        : Get.put(FollowingTopicsController());

    final double btnPaddingH = isMobile ? 12 : 20;
    final double btnPaddingV = isMobile ? 8 : 12;
    final double btnFontSize = isMobile ? 13 : 15;
    final double btnIconSize = isMobile ? 16 : 18;

    return GestureDetector(
      onTap: () => _navigateToTopic(context, topic),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Background Image with Parallax
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(pageOffset * 100, 0), // Parallax move
              child: Image.network(
                (topic.coverImage?.isNotEmpty == true
                        ? topic.coverImage
                        : topic.thumbnailUrl?.isNotEmpty == true
                        ? topic.thumbnailUrl
                        : null) ??
                    'https://images.unsplash.com/photo-1677442136019-21780ecad995?q=80&w=1932&auto=format&fit=crop',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.network(
                    'https://images.unsplash.com/photo-1677442136019-21780ecad995?q=80&w=1932&auto=format&fit=crop',
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
          ),
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(isMobile ? 24 : 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // TOPIC Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bookmark_outline_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'TOPIC',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                SizedBox(
                  width: isMobile ? double.infinity : 700,
                  child: Text(
                    topic.title,
                    style: GoogleFonts.roboto(
                      fontSize: isMobile ? 24 : 48,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Meta Info
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${topic.videoCount} videos • ${timeago.format(topic.createdAt)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        topic.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isMobile) ...[
                  const SizedBox(height: 16),
                  // Description
                  SizedBox(
                    width: 550,
                    child: Text(
                      topic.description,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                // Buttons
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Obx(() {
                      final isFollowed = followingController.isTopicFollowed(topic.id);
                      return ElevatedButton.icon(
                        onPressed: () {
                          followingController.toggleFollowTopic(topic);
                        },
                        icon: Icon(
                          isFollowed
                              ? Icons.check_circle_outline_rounded
                              : Icons.person_add_alt_1_outlined,
                          color: isFollowed ? Colors.white : Colors.black,
                          size: btnIconSize,
                        ),
                        label: Text(
                          isFollowed ? 'Following' : 'Follow',
                          style: TextStyle(
                            color: isFollowed ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w500,
                            fontSize: btnFontSize,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowed
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.white,
                          foregroundColor: isFollowed
                              ? Colors.white
                              : Colors.black,
                          padding: EdgeInsets.symmetric(
                            horizontal: btnPaddingH,
                            vertical: btnPaddingV,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: isFollowed
                                ? BorderSide(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1,
                                  )
                                : BorderSide.none,
                          ),
                          elevation: 0,
                        ),
                      );
                    }),
                    ElevatedButton.icon(
                      onPressed: () {
                        final String slug = topic.slug;
                        final String title = topic.title;
                        final String? imageUrl =
                            topic.coverImage ?? topic.thumbnailUrl;
                        final topicUrl = DeepLinkService.topicUrl(slug);
                        ShareBottomSheet.show(
                          title: title,
                          url: topicUrl,
                          thumbnailUrl: imageUrl,
                          followerCount: topic.followerCount,
                          videoCount: topic.videoCount,
                          handle: slug,
                          type: 'topic',
                        );
                      },
                      icon: Icon(
                        Icons.share_rounded,
                        color: Colors.white,
                        size: btnIconSize,
                      ),
                      label: Text(
                        'Share',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: btnFontSize,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: btnPaddingH,
                          vertical: btnPaddingV,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
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
            top: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.people_outline_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatCount(topic.followerCount)} Followers',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
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
class _PersonalizedPlaylistsSection extends StatelessWidget {
  final double horizontalPadding;
  const _PersonalizedPlaylistsSection({required this.horizontalPadding});

  @override
  Widget build(BuildContext context) {
    final playlists = [
      {
        'title': 'AI & Tech',
        'image':
            'https://images.unsplash.com/photo-1677442136019-21780ecad995?q=80&w=1000&auto=format&fit=crop',
      },
      {
        'title': 'Deep Research',
        'image':
            'https://images.unsplash.com/photo-1532094349884-543bc11b234d?q=80&w=1000&auto=format&fit=crop',
      },
      {
        'title': 'Verified Truths',
        'image':
            'https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=1000&auto=format&fit=crop',
      },
      {
        'title': 'Geopolitics',
        'image':
            'https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?q=80&w=1000&auto=format&fit=crop',
      },
      {
        'title': 'Economics',
        'image':
            'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?q=80&w=1000&auto=format&fit=crop',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return Container(
                width: 240,
                margin: EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: NetworkImage(playlist['image']!),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.3),
                      BlendMode.darken,
                    ),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: EdgeInsets.all(16),
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    playlist['title']!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==========================================================================
// REUSABLE MODERN AVATAR WIDGET
// ==========================================================================
class _ModernAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? placeholderText;

  const _ModernAvatar({
    this.imageUrl,
    required this.radius,
    this.placeholderText,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: primaryAccent.withValues(alpha: 0.2),
          width: 1,
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
