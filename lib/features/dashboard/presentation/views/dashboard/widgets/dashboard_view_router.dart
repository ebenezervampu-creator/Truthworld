import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audience_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/category_insights_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/chapters_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/copyright_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/creator_intelligence_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/customization_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_comments_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/drafts_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/memberships_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists_management_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/studio_settings_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topic_management_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/trash_restore_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/dashboard_overview_content.dart';

/// Routes active tab index (1 through 20) to the corresponding sub-feature screen
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
      if (viewController.isSelectingDefault.value) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!AuthService.to.hasChannel.value &&
            AuthService.to.userChannel == null) {
          Get.offAllNamed<dynamic>('/channelscreen');
        }
      });
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
        ),
      );
    }

    return FadeTransition(
      opacity: viewController.fadeAnimation,
      child: SlideTransition(
        position: viewController.slideAnimation,
        child: ScaleTransition(
          scale: viewController.scaleAnimation,
          child: Obx(() {
            switch (dashboardController.selectedIndex.value) {
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
                return ContentScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                  searchQuery: dashboardController.searchQuery.value,
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
                return TrashRestoreScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 14:
                return TopicManagementScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                  searchQuery: dashboardController.searchQuery.value,
                );
              case 15:
                return TruthVerificationDashboardPage(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 16:
                final ownerId = viewController.getOwnerId(currentChannel);
                return CreatorIntelligencePage(
                  channelId: channelId,
                  creatorId: ownerId,
                );
              case 17:
                return PlaylistsManagementScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                  searchQuery: dashboardController.searchQuery.value,
                );
              case 18:
                return MembershipsScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 19:
                return CategoryInsightsScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
                );
              case 20:
                return DraftsScreen(
                  channelId: channelId,
                  isDarkMode: isDarkMode,
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
          }),
        ),
      ),
    );
  }
}
