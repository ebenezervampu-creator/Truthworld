import 'package:truthworld/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/sections/sections.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Primary studio overview content (Tab 1) aggregating channel header, verification
/// banners, stats grid, performance analytics, recommendations, latest content, and quick actions.
class DashboardOverviewContent extends StatelessWidget {
  const DashboardOverviewContent({
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
    final currentCh =
        dashboardController.currentChannel.value ?? viewController.channel;

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: AppColors.bgSurface,
      onRefresh: () => dashboardController.refreshData(showFeedback: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(
              () => DashboardHeader(
                isDarkMode: isDarkMode,
                isMobile: isMobile,
                channel: currentCh,
                channelName: viewController.getChannelName(currentCh),
                searchController: viewController.searchController,
                onSearchChanged: dashboardController.setSearchQuery,
                onSearchClear: () => dashboardController.setSearchQuery(''),
                onRefresh: () => dashboardController.refreshData(showFeedback: true),
                isRefreshing: dashboardController.rxIsRefreshing.value,
              ),
            ),
          Obx(
            () => DashboardChannelStatsGrid(
              isDarkMode: isDarkMode,
              isMobile: isMobile,
              isDesktop: isDesktop,
              isTablet: isTablet,
              channel: dashboardController.currentChannel.value ??
                  viewController.channel,
              channelStats: dashboardController.channelStats,
              isLoading: dashboardController.rxIsLoading.value,
              statsAnimation: viewController.statsAnimation,
            ),
          ),
          const SizedBox(height: 32),
          Obx(
            () => DashboardRecentPerformanceSection(
              isDarkMode: isDarkMode,
              isMobile: isMobile,
              chartAnimation: viewController.chartAnimation,
              analyticsData: dashboardController.analyticsData.toList(),
            ),
          ),
          const SizedBox(height: 32),
          Obx(
            () {
              final vmVideos = Get.isRegistered<VideoManagementController>()
                  ? Get.find<VideoManagementController>().channelVideos.toList()
                  : <Video>[];
              final effectiveVideos =
                  dashboardController.recentVideos.isNotEmpty
                      ? dashboardController.recentVideos.toList()
                      : vmVideos;
              return DashboardRecommendationsSection(
                isDarkMode: isDarkMode,
                isMobile: isMobile,
                isDesktop: isDesktop,
                isTablet: isTablet,
                channel: dashboardController.currentChannel.value ??
                    viewController.channel,
                videos: effectiveVideos,
                stats: dashboardController.channelStats,
                controller: dashboardController,
              );
            },
          ),
          const SizedBox(height: 32),
          Obx(
            () {
              final vmVideos = Get.isRegistered<VideoManagementController>()
                  ? Get.find<VideoManagementController>().channelVideos.toList()
                  : <Video>[];
              final effectiveVideos =
                  dashboardController.filteredVideos.isNotEmpty
                      ? dashboardController.filteredVideos
                      : vmVideos;
              return DashboardLatestContentSection(
                isDarkMode: isDarkMode,
                isMobile: isMobile,
                videos: effectiveVideos,
                searchQuery: dashboardController.searchQuery.value,
                onViewAll: () => dashboardController.setSelectedIndex(2),
              );
            },
          ),
          const SizedBox(height: 32),
          DashboardQuickActionsSection(
            isDarkMode: isDarkMode,
            isMobile: isMobile,
            isDesktop: isDesktop,
            isTablet: isTablet,
            onCreateTopic: () =>
                viewController.openCreateTopicDialogFromQuickActions(
              context,
              isDarkMode,
            ),
            onViewAnalytics: () => dashboardController.setSelectedIndex(3),
          ),
        ],
      ),
    ),
  );
}
}
