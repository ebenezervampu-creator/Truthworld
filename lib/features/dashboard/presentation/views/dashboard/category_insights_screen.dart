import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/category_insights_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Category Insights & Market Demand Screen in Studio Dashboard.
/// Built with exact fonts, theme, container borders, and dark visual architecture
/// from the Channel Creation page (channel_screen_wizard.dart).
/// Uses sleek dark blue styling for demand & opportunity highlights.
/// Complies 100% with project Icon Color Guidelines (icons always use white / AppColors.textPrimary).
class CategoryInsightsScreen extends StatelessWidget {
  final String channelId;
  final bool isDarkMode;

  const CategoryInsightsScreen({
    required this.channelId,
    required this.isDarkMode,
    super.key,
  });

  CategoryInsightsController get controller =>
      Get.isRegistered<CategoryInsightsController>()
          ? Get.find<CategoryInsightsController>()
          : Get.put(CategoryInsightsController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Obx(() {
        if (controller.isLoading) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Fetching real category insights from database...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        if (controller.errorMessage.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF450A0A),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: controller.fetchCategoryInsights,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF27272A),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF3F3F46)),
                    ),
                  ),
                ),
              ],
            ),
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final card1 = _buildMetricCard(
                      title: 'Tracked Categories',
                      value: '${controller.totalTrackedCategories.value}',
                      subtitle: 'Active in system',
                      icon: Icons.category_rounded,
                      accentBadgeBg: const Color(0xFF27272A),
                      accentBadgeBorder: const Color(0xFF3F3F46),
                    );
                    final card2 = _buildMetricCard(
                      title: 'Untouched Niches',
                      value: '${controller.untouchedCategoryCount.value}',
                      subtitle: '0 channels operating',
                      icon: Icons.explore_off_rounded,
                      accentBadgeBg: const Color(0xFF1E293B),
                      accentBadgeBorder: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                    );
                    final card3 = _buildMetricCard(
                      title: 'Top User Liked',
                      value: controller.topLikedCategoryName.value,
                      subtitle: 'Highest user likes',
                      icon: Icons.thumb_up_alt_rounded,
                      accentBadgeBg: const Color(0xFF064E3B),
                      accentBadgeBorder: const Color(0xFF10B981).withValues(alpha: 0.4),
                    );
                    final card4 = _buildMetricCard(
                      title: 'Fastest Growing',
                      value: controller.fastestGrowingCategoryName.value,
                      subtitle: 'Peak growth momentum',
                      icon: Icons.trending_up_rounded,
                      accentBadgeBg: const Color(0xFF172554),
                      accentBadgeBorder: const Color(0xFF60A5FA).withValues(alpha: 0.4),
                    );

                    final isWide = constraints.maxWidth > 800;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: card1),
                          const SizedBox(width: 16),
                          Expanded(child: card2),
                          const SizedBox(width: 16),
                          Expanded(child: card3),
                          const SizedBox(width: 16),
                          Expanded(child: card4),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: card1),
                            const SizedBox(width: 16),
                            Expanded(child: card2),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: card3),
                            const SizedBox(width: 16),
                            Expanded(child: card4),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Content Gaps Alert Banner Callout
                if (controller.untouchedCategoryCount.value > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161618),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'High Potential Opportunity Alert!',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'There are ${controller.untouchedCategoryCount.value} categories with ZERO channels. Creating content in these untouched categories gives your channel a first-mover advantage with zero competition.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        TextButton.icon(
                          onPressed: () {
                            controller.activeFilter.value =
                                CategoryInsightsFilter.untouched;
                          },
                          icon: const Icon(
                            Icons.explore_off_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'View Untouched',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF27272A),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Color(0xFF3F3F46)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (controller.untouchedCategoryCount.value > 0)
                  const SizedBox(height: 24),

                // Search & Filter Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161618),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Field
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF121212),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF27272A)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          onChanged: (val) => controller.searchQuery.value = val,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Search categories...',
                            hintStyle: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 13,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.white,
                              size: 18,
                            ),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterChip(
                              label: 'All Categories',
                              filter: CategoryInsightsFilter.all,
                              icon: Icons.grid_view_rounded,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Most Liked by Users',
                              filter: CategoryInsightsFilter.mostLiked,
                              icon: Icons.thumb_up_rounded,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Untouched (0 Channels)',
                              filter: CategoryInsightsFilter.untouched,
                              icon: Icons.check_box_outline_blank_rounded,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Content Gaps & Demand',
                              filter: CategoryInsightsFilter.contentGaps,
                              icon: Icons.insights_rounded,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Fastest Growing Userbase',
                              filter: CategoryInsightsFilter.fastestGrowing,
                              icon: Icons.bolt_rounded,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Category Items List
                Obx(() {
                  final statsList = controller.filteredStats;
                  if (statsList.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161618),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF27272A)),
                              ),
                              child: const Icon(
                                Icons.search_off_rounded,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'No categories match your current filter/search.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Try adjusting your search query or selecting another filter.',
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: statsList
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildCategoryDetailCard(item: item),
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentBadgeBg,
    required Color accentBadgeBorder,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentBadgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentBadgeBorder),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required CategoryInsightsFilter filter,
    required IconData icon,
  }) {
    return Obx(() {
      final isSelected = controller.activeFilter.value == filter;
      return InkWell(
        onTap: () => controller.activeFilter.value = filter,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF27272A) : const Color(0xFF121212),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF3F3F46) : const Color(0xFF27272A),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildCategoryDetailCard({
    required CategoryStats item,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isUntouched
              ? const Color(0xFF38BDF8).withValues(alpha: 0.4)
              : const Color(0xFF27272A),
          width: item.isUntouched ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Category Title, Badges & Score Pill
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text(
                      item.category,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (item.isUntouched)
                      _buildStatusBadge(
                        label: 'Untouched (0 Channels)',
                        icon: Icons.explore_off_rounded,
                        badgeBg: const Color(0xFF1E293B),
                        borderColor:
                            const Color(0xFF38BDF8).withValues(alpha: 0.4),
                        textColor: const Color(0xFF38BDF8),
                      )
                    else if (item.opportunityIndex > 10.0)
                      _buildStatusBadge(
                        label: 'High Content Gap Demand',
                        icon: Icons.verified_rounded,
                        badgeBg: const Color(0xFF064E3B),
                        borderColor:
                            const Color(0xFF10B981).withValues(alpha: 0.4),
                        textColor: const Color(0xFF34D399),
                      )
                    else if (item.growthRate > 25.0)
                      _buildStatusBadge(
                        label: 'Fast Growing',
                        icon: Icons.bolt_rounded,
                        badgeBg: const Color(0xFF1E293B),
                        borderColor:
                            const Color(0xFF38BDF8).withValues(alpha: 0.4),
                        textColor: const Color(0xFF38BDF8),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Score: ${item.opportunityIndex.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats Sub-Cards Row / Column
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              final card1 = _buildSubStatCard(
                label: 'Channels Operating',
                value:
                    '${item.channelCount} ${item.channelCount == 1 ? 'channel' : 'channels'}',
                highlight: item.isUntouched,
                icon: Icons.tv,
              );
              final card2 = _buildSubStatCard(
                label: 'Total Videos Published',
                value: '${item.videoCount} videos',
                highlight: false,
                icon: Icons.play_circle_outline,
              );
              final card3 = _buildSubStatCard(
                label: 'Total User Likes',
                value: '${item.totalLikes} likes',
                highlight: false,
                icon: Icons.thumb_up_alt_outlined,
              );
              final card4 = _buildSubStatCard(
                label: 'Avg Likes / Video',
                value: item.avgLikesPerVideo.toStringAsFixed(1),
                highlight: false,
                icon: Icons.auto_graph_rounded,
              );

              if (isSmall) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: card1),
                        const SizedBox(width: 10),
                        Expanded(child: card2),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: card3),
                        const SizedBox(width: 10),
                        Expanded(child: card4),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 10),
                  Expanded(child: card2),
                  const SizedBox(width: 10),
                  Expanded(child: card3),
                  const SizedBox(width: 10),
                  Expanded(child: card4),
                ],
              );
            },
          ),

          // Top Liked Videos Section (if available)
          if (item.topLikedVideos.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFF27272A)),
            const SizedBox(height: 12),
            Text(
              'Top User-Liked Videos in ${item.category}:',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.topLikedVideos.map((v) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.thumb_up_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${v['title']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${v['likes']} likes)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF34D399),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubStatCard({
    required String label,
    required String value,
    required bool highlight,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.white),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: highlight ? const Color(0xFF38BDF8) : Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required IconData icon,
    required Color badgeBg,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
