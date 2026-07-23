import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AudiencePage extends StatefulWidget {

  const AudiencePage({
    required this.channelId, required this.isDarkMode, super.key,
  });
  final String channelId;
  final bool isDarkMode;

  @override
  State<AudiencePage> createState() => _AudiencePageState();
}

class _AudiencePageState extends State<AudiencePage> {
  late final AudienceController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(AudienceController(channelId: widget.channelId));
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = widget.isDarkMode ? AppColors.bgInput : AppColors.textPrimary;
    final backgroundColor = widget.isDarkMode ? AppColors.bgPage : AppColors.bgPage;
    final textColor = widget.isDarkMode ? AppColors.textPrimary : AppColors.textPrimary;
    final subtitleColor = widget.isDarkMode ? AppColors.textSecondary : AppColors.textSecondary;
    final borderColor = widget.isDarkMode ? const Color(0xFF2A2A2A) : AppColors.bgDivider;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Obx(() {
        if (controller.state == ViewState.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }

        if (controller.state == ViewState.error) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.brand),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage,
                  style: TextStyle(color: textColor, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  onPressed: () => controller.fetchAudienceData(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final stateItems = controller.filteredStateItems;

        return CustomScrollView(
          slivers: [
            // Module Title Header Banner
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.public_rounded,
                            color: AppColors.brand,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Audience Geography & Insights',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Track geographical viewers reach and localized subscriber conversions by state.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh Metrics',
                          icon: Icon(Icons.refresh_rounded, color: subtitleColor),
                          onPressed: () => controller.fetchAudienceData(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Summary Analytic Dashboard Cards Block
                    _buildSummaryCardsMatrix(surfaceColor, borderColor, textColor, subtitleColor),
                    const SizedBox(height: 24),
                    // Live Local Search Bar Filter
                    _buildSearchBar(surfaceColor, borderColor, textColor, subtitleColor),
                    const SizedBox(height: 20),
                    // Table Subtitles
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Regional Performance Matrix',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Showing ${stateItems.length} regions',
                          style: TextStyle(
                            fontSize: 13,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Dynamic State Audience Breakdown Matrix List
            if (stateItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: subtitleColor.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'No matching states or regions found.',
                        style: TextStyle(color: subtitleColor, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = stateItems[index];
                      return _buildStateCard(item, surfaceColor, borderColor, textColor, subtitleColor);
                    },
                    childCount: stateItems.length,
                  ),
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        );
      }),
    );
  }

  Widget _buildSummaryCardsMatrix(Color surfaceColor, Color borderColor, Color textColor, Color subtitleColor) {
    final views = controller.totalViews.value;
    final subs = controller.totalSubscribersGained.value;
    final conv = controller.subscriberConversionRate.value;
    final urban = controller.urbanPercentage.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 600;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildMetricTile(
              title: 'Total Tracked Viewers',
              value: NumberFormat.compact().format(views),
              subtitle: 'Accumulated active watch reach',
              icon: Icons.visibility_rounded,
              accentColor: const Color(0xFF3B82F6),
              width: isDesktop ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
            _buildMetricTile(
              title: 'Subscribers Generated',
              value: NumberFormat.compact().format(subs),
              subtitle: 'Direct regional retention',
              icon: Icons.person_add_rounded,
              accentColor: AppColors.brand,
              width: isDesktop ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
            _buildMetricTile(
              title: 'Conversion Ratio',
              value: '${conv.toStringAsFixed(1)}%',
              subtitle: 'Views to subscriber efficiency',
              icon: Icons.trending_up_rounded,
              accentColor: const Color(0xFF10B981),
              width: isDesktop ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
            _buildMetricTile(
              title: 'Urban Demographics',
              value: '${urban.toStringAsFixed(0)}%',
              subtitle: '${(100 - urban).toStringAsFixed(0)}% rural distribution scope',
              icon: Icons.location_city_rounded,
              accentColor: const Color(0xFF8B5CF6),
              width: isDesktop ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required double width,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: widget.isDarkMode ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: accentColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: subtitleColor.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Color surfaceColor, Color borderColor, Color textColor, Color subtitleColor) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        style: TextStyle(color: textColor, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search localized view matrix by State Name or Abbrev (e.g. Maharashtra, KA)...',
          hintStyle: TextStyle(color: subtitleColor, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: subtitleColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (val) => controller.updateSearchQuery(val),
      ),
    );
  }

  Widget _buildStateCard(
    StateAudienceItem item,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row Header: State name & tag
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.stateCode,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: subtitleColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.stateName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Viewers bar meter breakdown
          _buildGaugeRow(
            label: 'Regional Viewers',
            count: item.viewers,
            percentage: item.viewerPercentage,
            color: const Color(0xFF3B82F6),
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          const SizedBox(height: 12),
          // Subscribers bar meter breakdown
          _buildGaugeRow(
            label: 'Mapped Subscribers',
            count: item.subscribers,
            percentage: item.subscriberPercentage,
            color: AppColors.brand,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeRow({
    required String label,
    required int count,
    required double percentage,
    required Color color,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 13, color: subtitleColor),
            ),
            Row(
              children: [
                Text(
                  NumberFormat.decimalPattern().format(count),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage > 0 ? (percentage / 100).clamp(0.01, 1.0) : 0,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}






