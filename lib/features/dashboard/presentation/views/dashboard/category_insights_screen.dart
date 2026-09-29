import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/category_insights_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/category_insights/category_insights_detail_card.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/category_insights/category_insights_gap_banner.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/category_insights/category_insights_overview_metrics.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/category_insights/category_insights_search_filters.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/category_insights/category_insights_status_states.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Category Insights & Market Demand Screen in Studio Dashboard.
/// Built with exact fonts, theme, container borders, and dark visual architecture
/// from the Channel Creation page (channel_screen_wizard.dart).
/// Uses sleek dark blue styling for demand & opportunity highlights.
/// Complies 100% with project Icon Color Guidelines (icons always use white / AppColors.textPrimary).
class CategoryInsightsScreen extends GetView<CategoryInsightsController> {
  final String channelId;
  final bool isDarkMode;

  const CategoryInsightsScreen({
    required this.channelId,
    required this.isDarkMode,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Obx(() {
        if (controller.isLoading) {
          return const CategoryInsightsLoadingView();
        }

        if (controller.errorMessage.isNotEmpty) {
          return CategoryInsightsErrorView(
            errorMessage: controller.errorMessage,
            onRetry: controller.fetchCategoryInsights,
          );
        }

        return RefreshIndicator(
          onRefresh: controller.fetchCategoryInsights,
          color: Colors.white,
          backgroundColor: const Color(0xFF161618),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Title & Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category Insights & Market Demand',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Real-time data on user category likes, untouched channels, and growth opportunities.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      tooltip: 'Refresh Analytics',
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: controller.fetchCategoryInsights,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF161618),
                        side: const BorderSide(color: Color(0xFF27272A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Top Metrics Cards Layout
                CategoryInsightsOverviewMetrics(controller: controller),
                const SizedBox(height: 24),

                // Content Gaps Alert Banner Callout
                if (controller.untouchedCategoryCount.value > 0) ...[
                  CategoryInsightsGapBanner(controller: controller),
                  const SizedBox(height: 24),
                ],

                // Search & Filter Bar
                CategoryInsightsSearchFilters(controller: controller),
                const SizedBox(height: 24),

                // Category Items List
                Obx(() {
                  final statsList = controller.filteredStats;
                  if (statsList.isEmpty) {
                    return const CategoryInsightsEmptyView();
                  }

                  return Column(
                    children: statsList
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: CategoryInsightsDetailCard(item: item),
                          ),
                        )
                        .toList(),
                  );
                }),
              ],
            ),
          ),
        );
      }),
    );
  }
}
