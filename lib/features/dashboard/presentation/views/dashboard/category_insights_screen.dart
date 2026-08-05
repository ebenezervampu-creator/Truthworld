import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/category_insights_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Industry Standard Category Insights & Market Demand Screen.
/// Built 100% with AppTheme, AppColors, and GoogleFonts.roboto typography.
/// Complies with project Icon Color Guidelines (icons always use white / AppColors.textPrimary).
/// Optimized layout using direct Flex/Column widgets to prevent Flutter Web mouse tracker and hit-test assertions.
class CategoryInsightsScreen extends StatefulWidget {
  final String channelId;
  final bool isDarkMode;

  const CategoryInsightsScreen({
    required this.channelId,
    required this.isDarkMode,
    super.key,
  });

  @override
  State<CategoryInsightsScreen> createState() => _CategoryInsightsScreenState();
}

class _CategoryInsightsScreenState extends State<CategoryInsightsScreen> {
  late final CategoryInsightsController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<CategoryInsightsController>()
        ? Get.find<CategoryInsightsController>()
        : Get.put(CategoryInsightsController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Obx(() {
        if (controller.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppColors.textPrimary),
                const SizedBox(height: 16),
                Text(
                  'Fetching real category insights from database...',
                  style: GoogleFonts.roboto(
                    color: AppColors.textSecondary,
                    fontSize: 14,
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
                  decoration: const BoxDecoration(
                    color: AppColors.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage,
                  style: GoogleFonts.roboto(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: controller.fetchCategoryInsights,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: Text(
                    'Retry',
                    style: GoogleFonts.roboto(
                      color: AppColors.bgPage,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.bgPage,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.fetchCategoryInsights,
          color: AppColors.textPrimary,
          backgroundColor: AppColors.bgSurface,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category Insights & Market Demand',
                            style: GoogleFonts.roboto(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Real-time data on user category likes, untouched channels, and growth opportunities.',
                            style: GoogleFonts.roboto(
                              fontSize: 14,
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
                      ),
                      onPressed: controller.fetchCategoryInsights,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.bgSurface,
                        side: const BorderSide(color: AppColors.bgDivider),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Top Metrics Cards Layout (Flex/Row/Column based without nested Viewport)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final card1 = _buildMetricCard(
                      title: 'Tracked Categories',
                      value: '${controller.totalTrackedCategories.value}',
                      subtitle: 'Active in system',
                      icon: Icons.category_rounded,
                      accentContainer: AppColors.infoContainer,
                    );
                    final card2 = _buildMetricCard(
                      title: 'Untouched Niches',
                      value: '${controller.untouchedCategoryCount.value}',
                      subtitle: '0 channels operating',
                      icon: Icons.explore_off_rounded,
                      accentContainer: AppColors.warningContainer,
                    );
                    final card3 = _buildMetricCard(
                      title: 'Top User Liked',
                      value: controller.topLikedCategoryName.value,
                      subtitle: 'Highest user likes',
                      icon: Icons.thumb_up_alt_rounded,
                      accentContainer: AppColors.successContainer,
                    );
                    final card4 = _buildMetricCard(
                      title: 'Fastest Growing',
                      value: controller.fastestGrowingCategoryName.value,
                      subtitle: 'Peak growth momentum',
                      icon: Icons.trending_up_rounded,
                      accentContainer: AppColors.selectedOverlay,
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurfaceHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppColors.warningContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'High Potential Opportunity Alert!',
                                style: GoogleFonts.roboto(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'There are ${controller.untouchedCategoryCount.value} categories with ZERO channels. Creating content in these untouched categories gives your channel a first-mover advantage with zero competition.',
                                style: GoogleFonts.roboto(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            controller.activeFilter.value =
                                CategoryInsightsFilter.untouched;
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textPrimary,
                            foregroundColor: AppColors.bgPage,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'View Untouched',
                            style: GoogleFonts.roboto(
                              fontWeight: FontWeight.bold,
                              color: AppColors.bgPage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Search & Filter Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        onChanged: (val) => controller.searchQuery.value = val,
                        style: GoogleFonts.roboto(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search categories...',
                          hintStyle: GoogleFonts.roboto(
                            color: AppColors.textTertiary,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.white,
                          ),
                          filled: true,
                          fillColor: AppColors.bgInput,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.bgDivider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
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

                // Category Items List (Direct Column without nested Viewport to avoid web mouse-tracker size issues)
                Obx(() {
                  final statsList = controller.filteredStats;
                  if (statsList.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No categories match your current filter/search.',
                              style: GoogleFonts.roboto(
                                color: AppColors.textSecondary,
                                fontSize: 14,
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
    required Color accentContainer,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
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
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.roboto(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.roboto(
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
    final isSelected = controller.activeFilter.value == filter;
    return InkWell(
      onTap: () => controller.activeFilter.value = filter,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bgElevated : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.textPrimary
                : AppColors.bgDivider,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDetailCard({
    required CategoryStats item,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isUntouched
              ? AppColors.warning.withValues(alpha: 0.6)
              : AppColors.bgDivider,
          width: item.isUntouched ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Category Title & Badges
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      item.category,
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (item.isUntouched)
                      _buildBadge(
                        label: 'Untouched (0 Channels)',
                        bgColor: AppColors.warningContainer,
                        textColor: AppColors.warning,
                      )
                    else if (item.opportunityIndex > 10.0)
                      _buildBadge(
                        label: 'High Content Gap Demand',
                        bgColor: AppColors.successContainer,
                        textColor: AppColors.success,
                      )
                    else if (item.growthRate > 25.0)
                      _buildBadge(
                        label: 'Fast Growing',
                        bgColor: AppColors.infoContainer,
                        textColor: AppColors.info,
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
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Score: ${item.opportunityIndex.toStringAsFixed(1)}',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats Metrics Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              if (isSmall) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildSubStat(
                            label: 'Channels Operating',
                            value:
                                '${item.channelCount} ${item.channelCount == 1 ? 'channel' : 'channels'}',
                            highlight: item.isUntouched,
                          ),
                        ),
                        Expanded(
                          child: _buildSubStat(
                            label: 'Total Videos Published',
                            value: '${item.videoCount} videos',
                            highlight: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSubStat(
                            label: 'Total User Likes',
                            value: '${item.totalLikes} likes',
                            highlight: false,
                          ),
                        ),
                        Expanded(
                          child: _buildSubStat(
                            label: 'Avg Likes / Video',
                            value: item.avgLikesPerVideo.toStringAsFixed(1),
                            highlight: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildSubStat(
                      label: 'Channels Operating',
                      value:
                          '${item.channelCount} ${item.channelCount == 1 ? 'channel' : 'channels'}',
                      highlight: item.isUntouched,
                    ),
                  ),
                  Expanded(
                    child: _buildSubStat(
                      label: 'Total Videos Published',
                      value: '${item.videoCount} videos',
                      highlight: false,
                    ),
                  ),
                  Expanded(
                    child: _buildSubStat(
                      label: 'Total User Likes',
                      value: '${item.totalLikes} likes',
                      highlight: false,
                    ),
                  ),
                  Expanded(
                    child: _buildSubStat(
                      label: 'Avg Likes / Video',
                      value: item.avgLikesPerVideo.toStringAsFixed(1),
                      highlight: false,
                    ),
                  ),
                ],
              );
            },
          ),

          // Top Liked Videos Section (if available)
          if (item.topLikedVideos.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.bgDivider),
            const SizedBox(height: 12),
            Text(
              'Top User-Liked Videos in ${item.category}:',
              style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: item.topLikedVideos.map((v) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.thumb_up_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${v['title']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${v['likes']} likes)',
                        style: GoogleFonts.roboto(
                          fontSize: 11,
                          color: AppColors.success,
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

  Widget _buildBadge({
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.roboto(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildSubStat({
    required String label,
    required String value,
    required bool highlight,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: highlight ? AppColors.warning : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
