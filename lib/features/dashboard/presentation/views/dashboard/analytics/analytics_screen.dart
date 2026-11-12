import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics_dashboard.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_header_bar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_kpi_cards_grid.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_top_videos_card.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_viewer_engagement_card.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/recommendation_card_widget.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_controller.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_header_bar.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_kpi_cards_grid.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_top_videos_card.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_viewer_engagement_card.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/recommendation_card_widget.dart';

/// Redesigned Studio Channel Analytics Screen inspired by the Channel Creation page:
/// Modern dark zinc architecture, TruthWorld brand typography, real-time KPI overview,
/// and AI recommendation intelligence with zero-setState declarative reactivity.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({
    required this.channelId,
    required this.isDarkMode,
    super.key,
  });

  final String channelId;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      AnalyticsController(channelId: channelId),
      tag: channelId,
    );

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Obx(() {
        if (controller.rxIsLoading.value && controller.topVideos.isEmpty) {
          return const StudioLoadingIndicator(
            message: 'Loading channel analytics...',
          );
        }

        if (controller.rxErrorMessage.value.isNotEmpty && controller.topVideos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bgSurface),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    controller.rxErrorMessage.value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: controller.refreshAll,
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.black),
                    label: const Text(
                      'Retry',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 960;
            final isMobile = constraints.maxWidth < 650;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 16,
                vertical: isDesktop ? 24 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Header Banner ──
                  AnalyticsHeaderBar(
                    controller: controller,
                    channelId: channelId,
                    isDesktop: isDesktop,
                    isMobile: isMobile,
                  ),
                  const SizedBox(height: 18),

                  // ── Date Range Filter Pills ──
                  _buildDateRangeSelector(controller),
                  const SizedBox(height: 20),

                  // ── Performance KPI Cards Grid ──
                  AnalyticsKpiCardsGrid(
                    controller: controller,
                    isMobile: isMobile,
                  ),
                  const SizedBox(height: 24),

                  // ── Multi-Column Content Layout (Desktop) or Vertical Stack (Mobile) ──
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Top Performing Content & Engagement Window
                        Expanded(
                          flex: 6,
                          child: Column(
                            children: [
                              Obx(
                                () => AnalyticsTopVideosCard(
                                  topVideos: controller.topVideos.toList(),
                                  channelId: channelId,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const AnalyticsViewerEngagementCard(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right Column: Real-Time Recommendation Intelligence
                        Expanded(
                          flex: 6,
                          child: RecommendationCardWidget(
                            isDarkMode: isDarkMode,
                            channelId: channelId,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        RecommendationCardWidget(
                          isDarkMode: isDarkMode,
                          channelId: channelId,
                        ),
                        const SizedBox(height: 20),
                        Obx(
                          () => AnalyticsTopVideosCard(
                            topVideos: controller.topVideos.toList(),
                            channelId: channelId,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const AnalyticsViewerEngagementCard(),
                      ],
                    ),
                  const SizedBox(height: 28),

                  // ── Bottom Detailed Dashboard Action ──
                  _buildBottomDashboardBanner(isMobile),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildDateRangeSelector(AnalyticsController controller) {
    return Obx(() {
      final currentRange = controller.selectedDateRange;
      final ranges = AnalyticsDateRange.values
          .where((r) => r != AnalyticsDateRange.custom)
          .toList();

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ranges.map((range) {
            final isSelected = currentRange == range;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => controller.setDateRange(range),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.brand : AppColors.appBarSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.brand : AppColors.bgSurface,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        range.label,
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: isSelected ? Colors.black : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  Widget _buildBottomDashboardBanner(bool isMobile) {
    return Center(
      child: InkWell(
        onTap: () {
          Get.to<dynamic>(
            () => const CreatorAnalyticsDashboard(),
            arguments: {
              'channelId': channelId,
              'channelName': 'My Channel',
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: isMobile ? double.infinity : null,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: AppColors.appBarSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.bgSurface,
            ),
          ),
          child: Row(
            mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.query_stats_rounded,
                color: Colors.white,
                size: 18,
              ),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Explore Deep Creator Analytics & Audience Retention',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
