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

// Feature Pages for Dashboard (Deferred for TruthWorld-speed startup)
import 'package:truthworld/features/subscriptions/presentation/views/subscriptions/subscriptions.dart'
    deferred as subscriptions;
import 'package:truthworld/features/watchhistory/presentation/views/watchhistory/watchhistory.dart'
    deferred as watch_history;
import 'package:truthworld/features/myvideos/presentation/views/myvideos/my_videos.dart'
    deferred as my_videos;
import 'package:truthworld/features/library/presentation/views/library/library_screen.dart'
    deferred as lib_feature;
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
ThemeData darkProfessionalTheme = ThemeData(
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
  // Enhanced Typography with Inter
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
    indicatorColor: primaryAccent.withValues(alpha: 0.15),
    elevation: 8,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    surfaceTintColor: primaryAccent.withValues(alpha: 0.05),
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return IconThemeData(color: primaryAccent, size: 24);
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
        return style.copyWith(color: primaryAccent);
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
// HOME WIDGET
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

    return AnimatedBuilder(
      animation: controller.fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: controller.fadeAnimation,
          child: SlideTransition(
            position: controller.slideAnimation,
            child: ScaleTransition(
              scale: controller.scaleAnimation,
              child: _buildResponsiveLayout(context),
            ),
          ),
        );
      },
    );
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
          backgroundColor: darkProfessionalTheme.scaffoldBackgroundColor,
          appBar: _buildGlobalAppBar(context, isMobile, isTablet, isDesktop),
          drawer: isMobile || isTablet ? _buildDrawer(context) : null,
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

  Widget _buildDashboardContent(
    BuildContext context,
    HomeController controller,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    return Obx(() {
      final int index = controller.sideNavSelectedIndex.value;

      switch (index) {
        case HomeController.indexHome:
          return _MainContent(
            isMobile: isMobile,
            isTablet: isTablet,
            isDesktop: isDesktop,
            homeController: controller,
            appBarActionsBuilder: (ctx) => _buildAppBarActions(ctx, !isDesktop),
          );
        case HomeController.indexDiscover:
          return DeferredWidget(
            loader: discover.loadLibrary,
            builder: () => discover.DiscoverChannelsPage(isDashboard: true),
          );
        case HomeController.indexSubscriptions:
          return DeferredWidget(
            loader: subscriptions.loadLibrary,
            builder: () => subscriptions.SubscriptionsPage(isDashboard: true),
          );
        case HomeController.indexLibrary:
          return DeferredWidget(
            loader: lib_feature.loadLibrary,
            builder: () => lib_feature.LibraryScreen(isDashboard: true),
          );
        case HomeController.indexHistory:
          return DeferredWidget(
            loader: watch_history.loadLibrary,
            builder: () => watch_history.WatchHistory(isDashboard: true),
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
          if (p == null) return playlist.PlaylistScreen(isDashboard: true);
          return DeferredWidget(
            loader: playlist_detail.loadLibrary,
            builder: () =>
                playlist_detail.PlaylistDetailScreen(key: ValueKey(p.id)),
          );
        case HomeController.indexChannelDetail:
          final c = controller.selectedChannelForDetail.value;
          if (c == null)
            return discover.DiscoverChannelsPage(isDashboard: true);
          return DeferredWidget(
            loader: channel_details.loadLibrary,
            builder: () => channel_details.ChannelDetailsPage(
              key: ValueKey(c.channelId),
              channel: c,
              isDashboard: true,
            ),
          );
        default:
          return _MainContent(
            isMobile: isMobile,
            isTablet: isTablet,
            isDesktop: isDesktop,
            homeController: controller,
            appBarActionsBuilder: (ctx) => _buildAppBarActions(ctx, !isDesktop),
          );
      }
    });
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
            darkProfessionalTheme.appBarTheme.backgroundColor,
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
            onTap: () => Get.offAllNamed("/home"),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Image.asset('assets/logo.png', height: 38, width: 38),
                  SizedBox(width: 12),
                  Text(
                    "Truthworld",
                    style: darkProfessionalTheme.textTheme.titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              darkProfessionalTheme.colorScheme.onSurface,
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
                  color: darkProfessionalTheme
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
                            color: darkProfessionalTheme
                                .colorScheme
                                .onSurfaceVariant,
                            size: 22,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Search videos...',
                              style: darkProfessionalTheme
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: darkProfessionalTheme
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
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(
            Icons.menu_rounded,
            color: darkProfessionalTheme.colorScheme.onSurfaceVariant,
          ),
          tooltip: 'Open Navigation Menu',
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      actions: _buildAppBarActions(context, true),
      elevation: 0,
      backgroundColor: darkProfessionalTheme.appBarTheme.backgroundColor,
      surfaceTintColor:
          darkProfessionalTheme.appBarTheme.surfaceTintColor,
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: InkWell(
        onTap: () => Get.offAllNamed("/home"),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/logo.png', height: 30, width: 30),
              const SizedBox(width: 8),
              Text(
                "Truthworld",
                style: darkProfessionalTheme.textTheme.titleLarge
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: darkProfessionalTheme.colorScheme.onSurface,
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
            color: darkProfessionalTheme
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              Icons.search_rounded,
              color: darkProfessionalTheme.colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Search',
            onPressed: () {
              Get.toNamed('/search');
            },
          ),
        ),
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
        color: darkProfessionalTheme.colorScheme.surface,
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
                    style: darkProfessionalTheme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Obx(
                  () => controller.currentUser.value?.email != null
                      ? Text(
                          controller.currentUser.value!.email!,
                          style: darkProfessionalTheme.textTheme.bodySmall
                              ?.copyWith(
                                color: darkProfessionalTheme
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
            color: darkProfessionalTheme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(title, style: darkProfessionalTheme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context, {double radius = 18}) {
    final imageUrl = controller.currentUser.value?.photoURL;
    return _Avatar(
      imageUrl: imageUrl,
      radius: radius,
      placeholderText: controller.currentUser.value?.displayName
          ?.safeSubstring(0, 1)
          .toUpperCase(),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      width: kSideNavWidth,
      backgroundColor: darkProfessionalTheme.colorScheme.surface,
      child: Obx(
        () => _SideNavigationRail(
          selectedIndex: controller.sideNavSelectedIndex.value,
          onSelectItem: controller.onSideNavItemSelect,
          onShowSignInSnackbar: controller.showSignInSnackbar,
          currentUser: controller.currentUser.value,
          isDrawer: true,
          isCompact: false,
          homeController: controller,
        ),
      ),
    );
  }

  Widget _buildSideNavigation(BuildContext context, bool showCompactNavRail) {
    return Obx(
      () => _SideNavigationRail(
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
    return Container(width: 1, color: darkProfessionalTheme.dividerColor);
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return Obx(
      () => Container(
        decoration: BoxDecoration(
          color: darkProfessionalTheme.navigationBarTheme.backgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: controller.bottomNavSelectedIndex.value,
          onDestinationSelected: controller.onBottomNavItemTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          height: kBottomNavBarHeight,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            if (AuthService.to.isAuthenticated.value)
              NavigationDestination(
                icon: Icon(Icons.subscriptions_outlined),
                selectedIcon: Icon(Icons.subscriptions_rounded),
                label: 'Subscriptions',
              ),
            if (AuthService.to.isAuthenticated.value)
              NavigationDestination(
                icon: Icon(Icons.video_library_outlined),
                selectedIcon: Icon(Icons.video_library_rounded),
                label: 'Library',
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
class _SideNavigationRail extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onSelectItem;
  final VoidCallback onShowSignInSnackbar;
  final User? currentUser;
  final bool isDrawer;
  final bool isCompact;
  final HomeController homeController;
  const _SideNavigationRail({
    required this.selectedIndex,
    required this.onSelectItem,
    required this.onShowSignInSnackbar,
    required this.currentUser,
    this.isDrawer = false,
    this.isCompact = false,
    required this.homeController,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: isCompact ? kCompactSideNavWidth : kSideNavWidth,
      decoration: BoxDecoration(
        color: darkProfessionalTheme.navigationRailTheme.backgroundColor,
        border: Border(
          right: BorderSide(
            color: darkProfessionalTheme.dividerColor,
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
                'Discover Channels',
                HomeController.indexDiscover,
                route: "/discover",
              ),
              _buildNavItem(
                context,
                Icons.info_rounded,
                Icons.info_outline,
                'About ',
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
              // Personal Library Section
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
                    _buildNavItem(
                      context,
                      Icons.video_library_rounded,
                      Icons.video_library_outlined,
                      'Library',
                      HomeController.indexLibrary,
                      route: "/library",
                      requiresAuth: true,
                    ),
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
                      Icons.video_collection_rounded,
                      Icons.video_collection_outlined,
                      'Your Videos',
                      HomeController.indexYourVideos,
                      route: "/myvideos",
                      requiresAuth: true,
                    ),
                    _buildNavItem(
                      context,
                      Icons.favorite_rounded,
                      Icons.favorite_outline,
                      'Liked Videos',
                      HomeController.indexLikedVideos,
                      route: "/likedvideos",
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
                    _buildNavItem(
                      context,
                      Icons.content_cut_rounded,
                      Icons.content_cut_outlined,
                      'Your Clips',
                      HomeController.indexClips,
                      route: "/clips",
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
              SizedBox(height: 4),
              // Playlists Section
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
                          'PLAYLISTS',
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
                      Icons.queue_music_rounded,
                      Icons.queue_music_outlined,
                      'All Playlists',
                      HomeController.indexPlaylists,
                      route: "/playlistscreen",
                      requiresAuth: true,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 4),
              _buildDivider(context),
              SizedBox(height: 8),

              // Subscriptions Section
              _buildSectionHeader(
                context,
                'Subscriptions',
                onTap: () => onSelectItem(HomeController.indexSubscriptions),
              ),
              _buildSubscriptionList(context),
            ],
          );
        }),

        SizedBox(height: 4),
        _buildDivider(context),
        SizedBox(height: 4),

        // Support & Info Section
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
              _buildDivider(context),
            ],
          ),
        ),

        SizedBox(height: 4),
        _buildDivider(context),
        SizedBox(height: 4),

        // Legal Section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.0 : 16.0),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCompact)
                Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8, top: 4),
                  child: Text(
                    'ABOUT',
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

              SizedBox(height: 16),
              // Footer
              if (!isCompact)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                  child: Column(
                    children: [
                      Text(
                        'Â© 2026 Truthworld',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: isDarkMode
                              ? Colors.white38
                              : Color(0xFF94A3B8),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Made with  for creators',
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
  }) {
    if (requiresAuth && !AuthService.to.isAuthenticated.value) {
      return const SizedBox.shrink();
    }
    final bool isSelected = selectedIndex == index;
    final color = isSelected
        ? primaryAccent
        : darkProfessionalTheme.colorScheme.onSurfaceVariant;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? primaryAccent.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(isCompact ? 16 : 24),
        child: InkWell(
          onTap: () => _handleNavItemTap(context, index, route, requiresAuth),
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
            style: darkProfessionalTheme.textTheme.labelSmall?.copyWith(
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
            style: darkProfessionalTheme.textTheme.bodyMedium?.copyWith(
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
      if (isDrawer && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    } else {
      // DASHBOARD NAVIGATION LOGIC
      // Instead of full page transitions, we just update the index for dashboard-compatible pages
      final bool isDashboardPage =
          index == HomeController.indexHome ||
          index == HomeController.indexSubscriptions ||
          index == HomeController.indexDiscover ||
          index == HomeController.indexLibrary ||
          index == HomeController.indexHistory ||
          index == HomeController.indexYourVideos ||
          index == HomeController.indexLikedVideos ||
          index == HomeController.indexDownloads ||
          index == HomeController.indexWatchLater ||
          index == HomeController.indexPlaylists ||
          index == HomeController.indexClips;

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

      if (isDrawer && (Scaffold.maybeOf(context)?.isDrawerOpen ?? false)) {
        Navigator.of(context).pop();
      }
    }
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      height: 0.5,
      color: darkProfessionalTheme.dividerColor,
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    VoidCallback? onTap,
  }) {
    if (isCompact) return SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: darkProfessionalTheme.textTheme.titleSmall?.copyWith(
                color: darkProfessionalTheme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: darkProfessionalTheme.colorScheme.onSurfaceVariant,
              ),
          ],
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

          return _ChannelListItem(
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
    if (isDrawer && (Scaffold.maybeOf(context)?.isDrawerOpen ?? false)) {
      Navigator.of(context).pop();
      await Future.delayed(Duration(milliseconds: 300));
    }
    Get.toNamed(
      '/channel-details',
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
        baseColor: darkProfessionalTheme
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        highlightColor: darkProfessionalTheme
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
              color: darkProfessionalTheme.colorScheme.onSurfaceVariant,
            )
          : Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color:
                      darkProfessionalTheme.colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: darkProfessionalTheme.textTheme.bodyMedium
                        ?.copyWith(
                          color: darkProfessionalTheme
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
class _ChannelListItem extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final bool isCompact;
  const _ChannelListItem({
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
            style: darkProfessionalTheme.textTheme.labelSmall?.copyWith(
              color: darkProfessionalTheme.colorScheme.onSurface,
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
            style: darkProfessionalTheme.textTheme.bodyMedium?.copyWith(
              color: darkProfessionalTheme.colorScheme.onSurface,
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
    return _Avatar(
      imageUrl: channel.avatarUrl,
      radius: radius,
      placeholderText: channel.channelName.safeSubstring(0, 1).toUpperCase(),
    );
  }
}

// ==========================================================================
// MAIN CONTENT
// ==========================================================================
class _MainContent extends StatelessWidget {
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final HomeController homeController;
  final List<Widget> Function(BuildContext) appBarActionsBuilder;
  const _MainContent({
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
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 24.0 : 32.0);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            darkProfessionalTheme.scaffoldBackgroundColor,
            darkProfessionalTheme.scaffoldBackgroundColor.withValues(
              alpha: 0.95,
            ),
          ],
        ),
      ),
      child: CustomScrollView(
        controller: homeController.scrollController,
        slivers: [

          Obx(() {
            if (homeController.isLoadingVideos.value) {
              return _VideoGridSection(
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
            return _VideoGridSection(
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
          SliverToBoxAdapter(child: _buildHomeFooter(context)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: isMobile || isTablet ? kBottomNavBarHeight + 16 : 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeFooter(BuildContext context) {
    final colorScheme = darkProfessionalTheme.colorScheme;
    final textTheme = darkProfessionalTheme.textTheme;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 64,
        horizontal: isMobile ? 24 : 64,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(
            color: darkProfessionalTheme.dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryAccent, secondaryAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Truthworld",
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Text(
              "Truthworld is a premium video-sharing platform that integrates automated content validation into the publishing pipeline, allowing creators to share verified stories and viewers to discover trustworthy content.",
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 32,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _buildFooterLink(
                context,
                "Privacy Policy",
                HomeController.indexPrivacy,
              ),
              _buildFooterLink(
                context,
                "Terms of Service",
                HomeController.indexTerms,
              ),
              _buildFooterLink(context, "About Us", HomeController.indexAbout),
              _buildFooterLink(
                context,
                "Feedback",
                HomeController.indexFeedback,
              ),
              _buildFooterLink(
                context,
                "Help Center",
                HomeController.indexHelp,
              ),
            ],
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "© 2026 Truthworld Services (OPC) Private Limited. All rights reserved.",
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(BuildContext context, String text, int index) {
    return InkWell(
      onTap: () {
        homeController.sideNavSelectedIndex.value = index;
        homeController.scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          text,
          style: darkProfessionalTheme.textTheme.bodyMedium?.copyWith(
            color: primaryAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }


}

// ==========================================================================
// MODERNIZED VIDEO GRID SECTION
// ==========================================================================
class _VideoGridSection extends StatelessWidget {
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final List<Video> videos;
  final String heroPrefix;
  final bool isLoading;
  final double horizontalPadding;
  final String Function(int) formatViews;
  final String Function(Timestamp) formatTimestamp;
  const _VideoGridSection({
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
        color: darkProfessionalTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: darkProfessionalTheme.colorScheme.outline.withValues(
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
          _Avatar(
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
                  style: darkProfessionalTheme.textTheme.titleMedium
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
                  style: darkProfessionalTheme.textTheme.bodySmall
                      ?.copyWith(
                        color: darkProfessionalTheme
                            .colorScheme
                            .onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                SizedBox(height: 2),
                Text(
                  '${formatViews(video.views)} views • ${formatTimestamp(video.uploadedAt)}',
                  style: darkProfessionalTheme.textTheme.bodySmall
                      ?.copyWith(
                        color: darkProfessionalTheme
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
              Icons.more_vert_rounded,
              size: 20,
              color: darkProfessionalTheme.colorScheme.onSurfaceVariant,
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
      baseColor: darkProfessionalTheme.colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.3),
      highlightColor: darkProfessionalTheme
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.1),
      child: Container(
        color: darkProfessionalTheme.colorScheme.surfaceContainerHighest,
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
            baseColor: darkProfessionalTheme
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            highlightColor: darkProfessionalTheme
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.1),
            child: Container(
              decoration: BoxDecoration(
                color: darkProfessionalTheme
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
                color: darkProfessionalTheme.colorScheme.onSurfaceVariant,
              ),
              SizedBox(height: 16),
              Text(
                'No videos found',
                style: darkProfessionalTheme.textTheme.titleMedium
                    ?.copyWith(
                      color: darkProfessionalTheme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
              SizedBox(height: 8),
              Text(
                'Try selecting a different category',
                style: darkProfessionalTheme.textTheme.bodyMedium
                    ?.copyWith(
                      color: darkProfessionalTheme
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
  late final PageController _pageController;
  Timer? _timer;
  int _currentIndex = 0;
  bool _isHovering = false;
  bool _isVisible = true;
  static const int _infiniteItems = 10000;

  final List<Map<String, String>> _banners = [
    {
      'title':
          'The Future of AGI: Exclusive Interview with Leading Researchers',
      'subtitle': '2.1M views • LIVE • 4h ago',
      'tag': 'AI Research',
      'description':
          'Join us for an unprecedented deep dive into the latest advancements in Artificial General Intelligence, potential timelines, and the ethical implications for humanity.',
      'image':
          'https://images.unsplash.com/photo-1677442136019-21780ecad995?q=80&w=1932&auto=format&fit=crop',
      'watching': '45,201 watching',
    },
    {
      'title': 'Global Economic Shift: Decoding the 2026 Market Trends',
      'subtitle': '890K views • 2h ago',
      'tag': 'Economics',
      'description':
          'How new financial technologies and shifting geopolitical alliances are reshaping the world economy. Expert panel discussion inside.',
      'image':
          'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?q=80&w=1000&auto=format&fit=crop',
      'watching': '12,405 watching',
    },
    {
      'title': 'SpaceX Mars Mission: First Humans to Land in 2029?',
      'subtitle': '5.4M views • LIVE',
      'tag': 'Space Tech',
      'description':
          'Elon Musk reveals updated plans for the Starship Mars mission. Live coverage of the presentation from Starbase, Texas.',
      'image':
          'https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=1000&auto=format&fit=crop',
      'watching': '156,000 watching',
    },
    {
      'title': 'Quantum Computing: Breaking the RSA Encryption Barrier',
      'subtitle': '1.2M views • 1d ago',
      'tag': 'Cybersecurity',
      'description':
          'What happens when quantum computers can crack modern encryption? We talk to the cryptographers building the post-quantum world.',
      'image':
          'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?q=80&w=1000&auto=format&fit=crop',
      'watching': '8,210 watching',
    },
    {
      'title': 'The Rise of Smart Cities: Urban Life in 2030',
      'subtitle': '450K views • 5h ago',
      'tag': 'Sustainability',
      'description':
          'From autonomous transit to AI-driven energy grids, see how the cities of tomorrow are being built today in Singapore and Dubai.',
      'image':
          'https://images.unsplash.com/photo-1519567241046-7f570eee3ce6?q=80&w=1000&auto=format&fit=crop',
      'watching': '3,540 watching',
    },
    {
      'title': 'The Truth About Deepfakes: Can We Trust Anything?',
      'subtitle': '3.2M views • 12h ago',
      'tag': 'Verified Truth',
      'description':
          'Investigating the alarming rise of generative video and the new verification technologies being developed to protect reality.',
      'image':
          'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?q=80&w=1000&auto=format&fit=crop',
      'watching': '22,100 watching',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Initialize in the middle for seamless two-way infinite scrolling
    final initialPage =
        (_infiniteItems ~/ 2) - ((_infiniteItems ~/ 2) % _banners.length);
    _pageController = PageController(initialPage: initialPage);
    _currentIndex = initialPage % _banners.length;
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (_pageController.hasClients && !_isHovering && _isVisible) {
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
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < kTabletBreakpoint;
    final double bannerHeight = isMobile ? 320 : 520;

    return VisibilityDetector(
      key: const Key('featured_banner_visibility'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        final visible = info.visibleFraction > 0.1;
        if (_isVisible != visible) {
          setState(() {
            _isVisible = visible;
          });
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.horizontalPadding,
          vertical: 16,
        ),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
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
                        setState(() => _currentIndex = index % _banners.length),
                    itemBuilder: (context, index) {
                      final bannerIndex = index % _banners.length;
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
                          final double opacity = (1 - (pageOffset.abs() * 0.5))
                              .clamp(0.0, 1.0);

                          return Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: scale,
                              child: _buildBannerItem(
                                context,
                                _banners[bannerIndex],
                                isMobile,
                                pageOffset,
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
                      children: List.generate(_banners.length, (index) {
                        final bool isSelected = _currentIndex == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isSelected ? 32 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.white38,
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
    BuildContext context,
    Map<String, String> banner,
    bool isMobile,
    double pageOffset,
  ) {
    return Stack(
      children: [
        // Background Image with Parallax
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(pageOffset * 100, 0), // Parallax move
            child: Image.network(banner['image']!, fit: BoxFit.cover),
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
              // LIVE Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
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
                  banner['title']!,
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
              Row(
                children: [
                  Text(
                    banner['subtitle']!,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
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
                      banner['tag']!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
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
                    banner['description']!,
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
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.play_arrow,
                      color: Colors.black,
                      size: 18,
                    ),
                    label: const Text(
                      'Watch Now',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text(
                      'Watch Later',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
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
        // Viewer Count (Top Right)
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
                  Icons.remove_red_eye_outlined,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  banner['watching']!,
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
    );
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
// REUSABLE AVATAR WIDGET
// ==========================================================================
class _Avatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? placeholderText;

  const _Avatar({
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
            darkProfessionalTheme.colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: hasImage
              ? (kIsWeb
                  ? Image.network(
                      imageUrl!,
                      width: radius * 2,
                      height: radius * 2,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildPlaceholder(),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl!,
                      width: radius * 2,
                      height: radius * 2,
                      fit: BoxFit.cover,
                      memCacheWidth:
                          (radius * 2 * MediaQuery.of(context).devicePixelRatio)
                              .toInt(),
                      placeholder: (context, url) => _buildPlaceholder(),
                      errorWidget: (context, url, error) => _buildPlaceholder(),
                    ))
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
