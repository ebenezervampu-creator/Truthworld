import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/category_insights_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

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
    controller = Get.put(CategoryInsightsController());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderCol = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFF6366F1)),
                const SizedBox(height: 16),
                Text(
                  'Fetching real category insights from database...',
                  style: TextStyle(color: textSub, fontSize: 14),
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
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
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
                  controller.errorMessage.value,
                  style: TextStyle(
                    color: textMain,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: controller.fetchCategoryInsights,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.fetchCategoryInsights,
          color: const Color(0xFF6366F1),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Title & Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category Insights & Market Demand',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textMain,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Real-time data on user category likes, untouched channels, and growth opportunities.',
                          style: TextStyle(fontSize: 14, color: textSub),
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: 'Refresh Analytics',
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                      ),
                      onPressed: controller.fetchCategoryInsights,
                      style: IconButton.styleFrom(
                        backgroundColor: cardBg,
                        side: BorderSide(color: borderCol),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Top Metrics Cards Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    return GridView.count(
                      crossAxisCount: isWide ? 4 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      childAspectRatio: isWide ? 1.8 : 1.4,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildMetricCard(
                          title: 'Tracked Categories',
                          value: '${controller.totalTrackedCategories.value}',
                          subtitle: 'Active in system',
                          icon: Icons.category_rounded,
                          accentColor: const Color(0xFF6366F1),
                          cardBg: cardBg,
                          textMain: textMain,
                          textSub: textSub,
                          borderCol: borderCol,
                        ),
                        _buildMetricCard(
                          title: 'Untouched Niches',
                          value: '${controller.untouchedCategoryCount.value}',
                          subtitle: '0 channels operating',
                          icon: Icons.explore_off_rounded,
                          accentColor: const Color(0xFFF59E0B),
                          cardBg: cardBg,
                          textMain: textMain,
                          textSub: textSub,
                          borderCol: borderCol,
                        ),
                        _buildMetricCard(
                          title: 'Top User Liked',
                          value: controller.topLikedCategoryName.value,
                          subtitle: 'Highest user likes',
                          icon: Icons.thumb_up_alt_rounded,
                          accentColor: const Color(0xFF10B981),
                          cardBg: cardBg,
                          textMain: textMain,
                          textSub: textSub,
                          borderCol: borderCol,
                        ),
                        _buildMetricCard(
                          title: 'Fastest Growing',
                          value: controller.fastestGrowingCategoryName.value,
                          subtitle: 'Peak growth momentum',
                          icon: Icons.trending_up_rounded,
                          accentColor: const Color(0xFFEC4899),
                          cardBg: cardBg,
                          textMain: textMain,
                          textSub: textSub,
                          borderCol: borderCol,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Content Gaps Banner Callout
                if (controller.untouchedCategoryCount.value > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4F46E5).withValues(alpha: 0.9),
                          const Color(0xFF7C3AED).withValues(alpha: 0.9),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF4F46E5,
                          ).withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
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
                              const Text(
                                'High Potential Opportunity Alert!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'There are ${controller.untouchedCategoryCount.value} categories with ZERO channels. Creating content in these untouched categories gives your channel a first-mover advantage with zero competition.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.9),
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
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF4F46E5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'View Untouched',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Search & Filter Tabs
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol),
                  ),
                  child: Column(
                    children: [
                      // Search bar
                      TextField(
                        onChanged: (val) => controller.searchQuery.value = val,
                        style: TextStyle(color: textMain, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search categories...',
                          hintStyle: TextStyle(color: textSub, fontSize: 14),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.white,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Filter Pills
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              label: 'All Categories',
                              filter: CategoryInsightsFilter.all,
                              icon: Icons.grid_view_rounded,
                              cardBg: cardBg,
                              textMain: textMain,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Most Liked by Users',
                              filter: CategoryInsightsFilter.mostLiked,
                              icon: Icons.thumb_up_rounded,
                              cardBg: cardBg,
                              textMain: textMain,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Untouched (0 Channels)',
                              filter: CategoryInsightsFilter.untouched,
                              icon: Icons.check_box_outline_blank_rounded,
                              cardBg: cardBg,
                              textMain: textMain,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Content Gaps & Demand',
                              filter: CategoryInsightsFilter.contentGaps,
                              icon: Icons.insights_rounded,
                              cardBg: cardBg,
                              textMain: textMain,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Fastest Growing Userbase',
                              filter: CategoryInsightsFilter.fastestGrowing,
                              icon: Icons.bolt_rounded,
                              cardBg: cardBg,
                              textMain: textMain,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Category List Grid
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
                              style: TextStyle(color: textSub, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: statsList.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = statsList[index];
                      return _buildCategoryDetailCard(
                        item: item,
                        cardBg: cardBg,
                        textMain: textMain,
                        textSub: textSub,
                        borderCol: borderCol,
                        isDark: isDark,
                      );
                    },
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
    required Color accentColor,
    required Color cardBg,
    required Color textMain,
    required Color textSub,
    required Color borderCol,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textSub,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: textSub)),
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
    required Color cardBg,
    required Color textMain,
  }) {
    final isSelected = controller.activeFilter.value == filter;
    return InkWell(
      onTap: () => controller.activeFilter.value = filter,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : const Color(0xFF334155),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDetailCard({
    required CategoryStats item,
    required Color cardBg,
    required Color textMain,
    required Color textSub,
    required Color borderCol,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isUntouched
              ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
              : borderCol,
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
                child: Row(
                  children: [
                    Text(
                      item.category,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (item.isUntouched)
                      _buildBadge(
                        label: 'Untouched (0 Channels)',
                        bgColor: const Color(
                          0xFFF59E0B,
                        ).withValues(alpha: 0.15),
                        textColor: const Color(0xFFF59E0B),
                      )
                    else if (item.opportunityIndex > 10.0)
                      _buildBadge(
                        label: 'High Content Gap Demand',
                        bgColor: const Color(
                          0xFF10B981,
                        ).withValues(alpha: 0.15),
                        textColor: const Color(0xFF10B981),
                      )
                    else if (item.growthRate > 25.0)
                      _buildBadge(
                        label: 'Fast Growing',
                        bgColor: const Color(
                          0xFFEC4899,
                        ).withValues(alpha: 0.15),
                        textColor: const Color(0xFFEC4899),
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
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textMain,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats Metrics Row
          Row(
            children: [
              Expanded(
                child: _buildSubStat(
                  label: 'Channels Operating',
                  value:
                      '${item.channelCount} ${item.channelCount == 1 ? 'channel' : 'channels'}',
                  highlight: item.isUntouched,
                  textMain: textMain,
                  textSub: textSub,
                ),
              ),
              Expanded(
                child: _buildSubStat(
                  label: 'Total Videos Published',
                  value: '${item.videoCount} videos',
                  highlight: false,
                  textMain: textMain,
                  textSub: textSub,
                ),
              ),
              Expanded(
                child: _buildSubStat(
                  label: 'Total User Likes',
                  value: '${item.totalLikes} likes',
                  highlight: false,
                  textMain: textMain,
                  textSub: textSub,
                ),
              ),
              Expanded(
                child: _buildSubStat(
                  label: 'Avg Likes / Video',
                  value: item.avgLikesPerVideo.toStringAsFixed(1),
                  highlight: false,
                  textMain: textMain,
                  textSub: textSub,
                ),
              ),
            ],
          ),

          // Top Liked Videos Section (if available)
          if (item.topLikedVideos.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Top User-Liked Videos in ${item.category}:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textSub,
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
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderCol),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: textMain,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${v['likes']} likes)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF10B981),
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
        style: TextStyle(
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
    required Color textMain,
    required Color textSub,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: textSub)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: highlight ? const Color(0xFFF59E0B) : textMain,
          ),
        ),
      ],
    );
  }
}
