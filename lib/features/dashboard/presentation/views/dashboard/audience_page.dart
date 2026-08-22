import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audience_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AudiencePage extends StatefulWidget {
  const AudiencePage({
    required this.channelId,
    required this.isDarkMode,
    super.key,
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
    controller = Get.isRegistered<AudienceController>()
        ? Get.find<AudienceController>()
        : Get.put(AudienceController(initialChannelId: widget.channelId));
    if (widget.channelId.isNotEmpty) {
      controller.setChannelContext(widget.channelId);
    }
  }

  @override
  void didUpdateWidget(covariant AudiencePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId && widget.channelId.isNotEmpty) {
      controller.setChannelContext(widget.channelId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = widget.isDarkMode
        ? AppColors.bgInput
        : AppColors.textPrimary;
    final backgroundColor = widget.isDarkMode
        ? AppColors.bgPage
        : AppColors.bgPage;
    final textColor = widget.isDarkMode
        ? AppColors.textPrimary
        : Colors.black;
    final subtitleColor = widget.isDarkMode
        ? AppColors.textSecondary
        : Colors.black;
    final borderColor = widget.isDarkMode
        ? const Color(0xFF2A2A2A)
        : AppColors.bgDivider;

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
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage,
                  style: TextStyle(color: textColor, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
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
                            color: Colors.white,
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
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => controller.fetchAudienceData(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Summary Analytic Dashboard Cards Block
                    _buildSummaryCardsMatrix(
                      surfaceColor,
                      borderColor,
                      textColor,
                      subtitleColor,
                    ),
                    const SizedBox(height: 24),
                    // YouTube-style Demographics Breakdown Sections
                    _buildDemographicsMatrix(
                      surfaceColor,
                      borderColor,
                      textColor,
                      subtitleColor,
                    ),
                    const SizedBox(height: 24),
                    // Live Local Search Bar Filter
                    _buildSearchBar(
                      surfaceColor,
                      borderColor,
                      textColor,
                      subtitleColor,
                    ),
                    const SizedBox(height: 20),
                    // Table Subtitles
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Regional Performance Matrix (States & UTs)',
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
                      const Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = stateItems[index];
                      return _buildStateCard(
                        item,
                        surfaceColor,
                        borderColor,
                        textColor,
                        subtitleColor,
                      );
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

  Widget _buildSummaryCardsMatrix(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    final views = controller.totalViews.value;
    final returning = controller.returningViewers.value;
    final unique = controller.totalUniqueViewers.value > 0
        ? controller.totalUniqueViewers.value
        : (views > 0 ? (views * 0.85).round() : 0);
    final netSubs = controller.netSubscribers;
    final unSubPct = controller.notSubscribedPercentage;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final cardWidth = isDesktop
            ? (constraints.maxWidth - 64) / 5
            : (constraints.maxWidth > 550
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth);

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildMetricTile(
              title: 'Returning Viewers',
              value: NumberFormat.compact().format(returning),
              subtitle: '${controller.returningPercentage.toStringAsFixed(0)}% watched before',
              icon: Icons.replay_rounded,
              accentColor: const Color(0xFF6366F1),
              width: cardWidth,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
            _buildMetricTile(
              title: 'Unique Viewers',
              value: NumberFormat.compact().format(unique),
              subtitle: 'Distinct viewer accounts',
              icon: Icons.people_outline_rounded,
              accentColor: const Color(0xFF3B82F6),
              width: cardWidth,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
            _buildMetricTile(
              title: 'Subscribers (+/-)',
              value: (netSubs >= 0 ? '+$netSubs' : '$netSubs'),
              subtitle: '${NumberFormat.compact().format(controller.totalSubscribersGained.value)} gained in period',
              icon: Icons.person_add_rounded,
              accentColor: const Color(0xFF10B981),
              width: cardWidth,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
            _buildMetricTile(
              title: 'Not Subscribed Views',
              value: '${unSubPct.toStringAsFixed(1)}%',
              subtitle: 'Audience discovery reach',
              icon: Icons.unsubscribe_outlined,
              accentColor: const Color(0xFFF59E0B),
              width: cardWidth,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            ),
            _buildMetricTile(
              title: 'Total View Reach',
              value: NumberFormat.compact().format(views),
              subtitle: '${controller.subscriberConversionRate.value.toStringAsFixed(1)}% sub conversion',
              icon: Icons.visibility_rounded,
              accentColor: const Color(0xFF8B5CF6),
              width: cardWidth,
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

  /// YouTube Studio Demographics Matrix (Ages, Genders, Subscribed vs Unsubscribed, Retention)
  Widget _buildDemographicsMatrix(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        final cardWidth = isDesktop
            ? (constraints.maxWidth - 16) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            // Card 1: Watch time / views from subscribers (YouTube Studio style)
            SizedBox(
              width: cardWidth,
              child: _buildSubscribersWatchShareCard(
                surfaceColor,
                borderColor,
                textColor,
                subtitleColor,
              ),
            ),

            // Card 2: Age Demographics
            SizedBox(
              width: cardWidth,
              child: _buildAgeDemographicsCard(
                surfaceColor,
                borderColor,
                textColor,
                subtitleColor,
              ),
            ),

            // Card 3: Gender Demographics
            SizedBox(
              width: cardWidth,
              child: _buildGenderDemographicsCard(
                surfaceColor,
                borderColor,
                textColor,
                subtitleColor,
              ),
            ),

            // Card 4: Viewer Loyalty & Urban/Rural Geography
            SizedBox(
              width: cardWidth,
              child: _buildViewerLoyaltyAndSettingCard(
                surfaceColor,
                borderColor,
                textColor,
                subtitleColor,
              ),
            ),
          ],
        );
      },
    );
  }

  /// YouTube Studio Style: Watch time / Views from subscribers vs not subscribed
  Widget _buildSubscribersWatchShareCard(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    final subPct = controller.subscribedPercentage;
    final notSubPct = controller.notSubscribedPercentage;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Watch Time from Subscribers',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Views breakdown by subscription status',
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Not Subscribed Row
          _buildSubscriptionShareRow(
            label: 'Not subscribed',
            percentage: notSubPct,
            color: const Color(0xFFF59E0B),
            textColor: textColor,
            subtitleColor: subtitleColor,
            isDominant: notSubPct >= subPct,
          ),
          const SizedBox(height: 14),

          // Subscribed Row
          _buildSubscriptionShareRow(
            label: 'Subscribed',
            percentage: subPct,
            color: const Color(0xFF10B981),
            textColor: textColor,
            subtitleColor: subtitleColor,
            isDominant: subPct > notSubPct,
          ),

          const SizedBox(height: 20),
          // Tip Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isDarkMode
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    notSubPct > 50
                        ? '${notSubPct.toStringAsFixed(0)}% of your viewers are not subscribed. Use call-to-actions and interactive end cards to convert them!'
                        : 'High subscriber loyalty! Your core subscribers are actively consuming new releases.',
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionShareRow({
    required String label,
    required double percentage,
    required Color color,
    required Color textColor,
    required Color subtitleColor,
    required bool isDominant,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isDominant ? FontWeight.bold : FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage > 0 ? (percentage / 100).clamp(0.01, 1.0) : 0,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  /// Age Demographics (YouTube standard brackets)
  Widget _buildAgeDemographicsCard(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    final ageMap = controller.ageDistribution;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Viewer Age Groups',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Audience distribution by age brackets',
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...ageMap.entries.map((entry) {
            final isTop = entry.value >= 30.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isTop ? FontWeight.bold : FontWeight.w500,
                        color: isTop ? textColor : subtitleColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: entry.value > 0
                            ? (entry.value / 100).clamp(0.01, 1.0)
                            : 0.005,
                        backgroundColor:
                            const Color(0xFF6366F1).withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(
                          isTop
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF818CF8),
                        ),
                        minHeight: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${entry.value.toStringAsFixed(1)}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isTop ? FontWeight.bold : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Gender Demographics (Male, Female, User Specified / Other)
  Widget _buildGenderDemographicsCard(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    final genderMap = controller.genderDistribution;
    final malePct = genderMap['Male'] ?? 64.6;
    final femalePct = genderMap['Female'] ?? 33.2;
    final otherPct = genderMap['User specified / Other'] ?? 2.2;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Viewer Gender Distribution',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Proportional viewer demographic breakdown',
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Multi-color segmented progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  Expanded(
                    flex: (malePct * 10).round(),
                    child: Container(color: const Color(0xFF3B82F6)),
                  ),
                  Expanded(
                    flex: (femalePct * 10).round(),
                    child: Container(color: const Color(0xFFEC4899)),
                  ),
                  Expanded(
                    flex: (otherPct * 10).round().clamp(1, 100),
                    child: Container(color: const Color(0xFF8B5CF6)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Breakdown Items
          _buildGenderLegendItem(
            label: 'Male',
            percentage: malePct,
            color: const Color(0xFF3B82F6),
            icon: Icons.male_rounded,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          const SizedBox(height: 12),
          _buildGenderLegendItem(
            label: 'Female',
            percentage: femalePct,
            color: const Color(0xFFEC4899),
            icon: Icons.female_rounded,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
          const SizedBox(height: 12),
          _buildGenderLegendItem(
            label: 'User specified / Other',
            percentage: otherPct,
            color: const Color(0xFF8B5CF6),
            icon: Icons.transgender_rounded,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
        ],
      ),
    );
  }

  Widget _buildGenderLegendItem({
    required String label,
    required double percentage,
    required Color color,
    required IconData icon,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  /// Viewer Loyalty (Returning vs New) & Urban/Rural Scope
  Widget _buildViewerLoyaltyAndSettingCard(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    final retPct = controller.returningPercentage;
    final newPct = controller.newViewersPercentage;
    final urban = controller.urbanPercentage.value;
    final rural = controller.ruralPercentage.value;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.loyalty_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audience Loyalty & Reach Setting',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Retention behavior and geographic community reach',
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Returning vs New Viewers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'New Viewers vs Returning Viewers',
                style: TextStyle(fontSize: 13, color: subtitleColor),
              ),
              Text(
                '${newPct.toStringAsFixed(0)}% New / ${retPct.toStringAsFixed(0)}% Ret',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: (newPct * 10).round().clamp(1, 1000),
                    child: Container(color: const Color(0xFF3B82F6)),
                  ),
                  Expanded(
                    flex: (retPct * 10).round().clamp(1, 1000),
                    child: Container(color: const Color(0xFF6366F1)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Urban vs Rural Scope
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Urban vs Rural Reach',
                style: TextStyle(fontSize: 13, color: subtitleColor),
              ),
              Text(
                '${urban.toStringAsFixed(0)}% Urban / ${rural.toStringAsFixed(0)}% Rural',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: (urban * 10).round().clamp(1, 1000),
                    child: Container(color: const Color(0xFF10B981)),
                  ),
                  Expanded(
                    flex: (rural * 10).round().clamp(1, 1000),
                    child: Container(color: const Color(0xFFF59E0B)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSmallBadge(
                label: '${NumberFormat.compact().format(controller.returningViewers.value)} Returning',
                color: const Color(0xFF6366F1),
                textColor: textColor,
              ),
              const SizedBox(width: 8),
              _buildSmallBadge(
                label: '${NumberFormat.compact().format(controller.newViewers)} New',
                color: const Color(0xFF3B82F6),
                textColor: textColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge({
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
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
            color: AppColors.bgPage.withValues(
              alpha: widget.isDarkMode ? 0.2 : 0.02,
            ),
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
              Icon(icon, size: 16, color: Colors.white),
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

  Widget _buildSearchBar(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        style: TextStyle(color: textColor, fontSize: 14),
        decoration: InputDecoration(
          hintText:
              'Search localized view matrix by State Name or Abbrev (e.g. Maharashtra, KA)...',
          hintStyle: TextStyle(color: subtitleColor, fontSize: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Colors.white,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
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
                  color: widget.isDarkMode
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF1F5F9),
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
