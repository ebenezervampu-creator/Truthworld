import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audience_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/channel_notifications_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/chapters_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/customization_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_comments_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/memberships_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/studio_settings_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/dashboard_overview_content.dart';

/// Routes active tab index to the corresponding sub-feature screen
/// with animated fade, slide, and scale transitions.
class DashboardViewRouter extends StatelessWidget {
  const DashboardViewRouter({
    required this.viewController,
    required this.dashboardController,
    required this.isDarkMode,
    required this.isMobile,
    required this.isDesktop,
    required this.isTablet,
    required this.horizontalPadding,
    super.key,
  });

  final DashboardViewController viewController;
  final DashboardController dashboardController;
  final bool isDarkMode;
  final bool isMobile;
  final bool isDesktop;
  final bool isTablet;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final currentChannel = viewController.channel;
    final channelId = viewController.getChannelId(currentChannel);
    if (channelId.isEmpty) {
      return _buildRouterSkeleton();
    }

    return FadeTransition(
      opacity: viewController.fadeAnimation,
      child: SlideTransition(
        position: viewController.slideAnimation,
        child: ScaleTransition(
          scale: viewController.scaleAnimation,
          child: Obx(() {
            final activeIndex = dashboardController.selectedIndex.value;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, 0.025),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: slide,
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(activeIndex),
                child: _buildScreen(activeIndex, channelId, currentChannel),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildScreen(int index, String channelId, dynamic currentChannel) {
    switch (index) {
      case 1:
        return DashboardOverviewContent(
          viewController: viewController,
          dashboardController: dashboardController,
          isDarkMode: isDarkMode,
          isMobile: isMobile,
          isDesktop: isDesktop,
          isTablet: isTablet,
          horizontalPadding: horizontalPadding,
        );
      case 2:
        final tabParam = (Get.parameters['tab'] ?? '').toLowerCase();
        final currentRoute = Get.currentRoute.toLowerCase();
        final isTrash = currentRoute.contains('/trash') ||
            tabParam == 'trash' ||
            tabParam == '13';
        final isScheduled = currentRoute.contains('/scheduled') ||
            tabParam == 'scheduled';
        final isDrafts = currentRoute.contains('/drafts') ||
            tabParam == 'drafts' ||
            tabParam == '20';
        final isTopics = currentRoute.contains('/topics') ||
            tabParam == 'topics' ||
            tabParam == '14';
        final isPlaylists = currentRoute.contains('/playlists') ||
            tabParam == 'playlists' ||
            tabParam == '17';
        final isCommunity = currentRoute.contains('/community') ||
            currentRoute.contains('/posts') ||
            tabParam == 'community' ||
            tabParam == 'posts' ||
            tabParam == '19';
        var initialIdx = 0;
        if (isTrash) {
          initialIdx = 6;
        } else if (isScheduled) {
          initialIdx = 5;
        } else if (isDrafts) {
          initialIdx = 4;
        } else if (isTopics) {
          initialIdx = 3;
        } else if (isPlaylists) {
          initialIdx = 2;
        } else if (isCommunity) {
          initialIdx = 1;
        }
        return ContentScreen(
          channelId: channelId,
          isDarkMode: isDarkMode,
          searchQuery: dashboardController.searchQuery.value,
          initialIndex: initialIdx,
        );
      case 3:
        return AnalyticsScreen(
          isDarkMode: isDarkMode,
          channelId: channelId,
        );
      case 4:
        return const DashboardCommentsPage();
      case 5:
        return MonetizationScreen(isDarkMode: isDarkMode);
      case 6:
        final ownerId = viewController.getOwnerId(currentChannel);
        return ChannelCustomizationPage(
          channelId: channelId,
          ownerId: ownerId,
        );
      case 7:
        return AudioTracksPage(
          channelId: channelId,
          isDarkMode: isDarkMode,
        );
      case 8:
        return const StudioSettingsPage();
      case 9:
        return CopyrightScreen(channelId: channelId);
      case 10:
        return SubtitlesPage(
          channelId: channelId,
          isDarkMode: isDarkMode,
        );
      case 11:
        return ChaptersPage(
          channelId: channelId,
          isDarkMode: isDarkMode,
        );
      case 12:
        return AudiencePage(
          channelId: channelId,
          isDarkMode: isDarkMode,
        );
      case 13:
        return ContentScreen(
          channelId: channelId,
          isDarkMode: isDarkMode,
          searchQuery: dashboardController.searchQuery.value,
          initialIndex: 6,
        );
      case 14:
        return ContentScreen(
          channelId: channelId,
          isDarkMode: isDarkMode,
          searchQuery: dashboardController.searchQuery.value,
          initialIndex: 3,
        );
      case 15:
        final vidId = dashboardController.targetVideoId.value.isNotEmpty
            ? dashboardController.targetVideoId.value
            : ((Get.arguments is Map ? Get.arguments['videoId'] as String? : null) ??
                Get.parameters['videoId']);
        return TruthVerificationDashboardPage(
          channelId: channelId,
          isDarkMode: isDarkMode,
          initialVideoId: vidId,
        );
      case 16:
        final ownerId = viewController.getOwnerId(currentChannel);
        return ChannelNotificationsPage(
          channelId: channelId,
          creatorId: ownerId,
        );
      case 17:
        return ContentScreen(
          channelId: channelId,
          isDarkMode: isDarkMode,
          searchQuery: dashboardController.searchQuery.value,
          initialIndex: 2,
        );
      case 18:
        if (!dashboardController.isChannelMonetizationActive) {
          return DashboardOverviewContent(
            viewController: viewController,
            dashboardController: dashboardController,
            isDarkMode: isDarkMode,
            isMobile: isMobile,
            isDesktop: isDesktop,
            isTablet: isTablet,
            horizontalPadding: horizontalPadding,
          );
        }
        return MembershipsScreen(
          channelId: channelId,
          isDarkMode: isDarkMode,
        );
      case 19:
        return ContentScreen(
          channelId: channelId,
          isDarkMode: isDarkMode,
          searchQuery: dashboardController.searchQuery.value,
          initialIndex: 1,
        );
      case 20:
        return ContentScreen(
          channelId: channelId,
          isDarkMode: isDarkMode,
          searchQuery: dashboardController.searchQuery.value,
          initialIndex: 4,
        );
      default:
        return DashboardOverviewContent(
          viewController: viewController,
          dashboardController: dashboardController,
          isDarkMode: isDarkMode,
          isMobile: isMobile,
          isDesktop: isDesktop,
          isTablet: isTablet,
          horizontalPadding: horizontalPadding,
        );
    }
  }

  Widget _buildRouterSkeleton() {
    return const StudioLoadingIndicator();
  }
}
