import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Premium Industry-Standard Creator Analytics Dashboard.
/// Built with 100% AppColors, AppTheme typography & GetX state management.
class CreatorAnalyticsDashboard extends StatelessWidget {
  const CreatorAnalyticsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CreatorAnalyticsController.to;
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final channelId = args['channelId'] as String? ?? '';
    final channelName = args['channelName'] as String? ?? 'My Channel';
    final videoId = args['videoId'] as String? ?? '';
    final videoTitle = args['videoTitle'] as String? ?? 'Video Analytics';

    // Load analytics on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (videoId.isNotEmpty) {
        controller.selectedVideoId.value = videoId;
        controller.loadVideoAnalytics(videoId, videoTitle: videoTitle);
      }
      if (channelId.isNotEmpty) {
        controller.selectedChannelId.value = channelId;
        controller.loadChannelAnalytics(channelId, channelName: channelName);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text(
          videoId.isNotEmpty ? 'Video Analytics' : 'Channel Analytics',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Get.back<void>(),
        ),
        actions: [
          Obx(() {
            final count = controller.liveViewerCount.value;
            if (count > 0) {
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingDot(),
                    const SizedBox(width: 6),
                    Text(
                      '$count watching live',
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: controller.refreshAnalytics,
          ),
        ],
      ),
      body: Obx(() {
        final isLoading =
            controller.isLoadingVideoAnalytics.value ||
            controller.isLoadingChannelAnalytics.value;

        if (isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }

        return RefreshIndicator(
          color: AppColors.brand,
          onRefresh: controller.refreshAnalytics,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header video / channel title badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        videoId.isNotEmpty
                            ? Icons.play_circle_fill_rounded
                            : Icons.sensors_rounded,
                        color: AppColors.brand,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          videoId.isNotEmpty ? videoTitle : channelName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Date range filter pills (100% AppColors styling)
                _DateRangeFilterPills(controller: controller),
                const SizedBox(height: 20),

                // Error message banner
                Obx(() {
                  final videoId = controller.selectedVideoId.value;
                  final error = videoId.isNotEmpty
                      ? controller.videoLoadingError.value
                      : controller.channelLoadingError.value;

                  if (error.isEmpty) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error,
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Summary Cards Grid (Standardized with 100% AppColors & AppTheme)
                _SummaryCardsGrid(controller: controller),
                const SizedBox(height: 24),

                // Audience Retention
                if (controller.watchtimeChartData.isNotEmpty) ...[
                  const _SectionHeader(title: 'Audience Retention'),
                  const SizedBox(height: 12),
                  _WatchtimeRetentionCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                // Traffic Sources
                if (controller.trafficSourceChartData.isNotEmpty) ...[
                  const _SectionHeader(title: 'Traffic Sources'),
                  const SizedBox(height: 12),
                  _TrafficSourceCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                // Geographic Breakdown
                if (controller.stateTrafficChartData.isNotEmpty ||
                    controller.topStates.isNotEmpty) ...[
                  const _SectionHeader(title: 'Geographic Breakdown'),
                  const SizedBox(height: 12),
                  _GeographicBreakdownCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                // City Breakdown
                if (controller.topCities.isNotEmpty) ...[
                  const _SectionHeader(title: 'Top Cities'),
                  const SizedBox(height: 12),
                  _TopCitiesCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                // Urban vs Rural
                if (controller.areaTypeChartData.isNotEmpty) ...[
                  const _SectionHeader(title: 'Urban vs Rural Viewers'),
                  const SizedBox(height: 12),
                  _AreaTypeCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                // Device Breakdown
                if (controller.deviceBreakdownStats.isNotEmpty) ...[
                  const _SectionHeader(title: 'Device Breakdown'),
                  const SizedBox(height: 12),
                  _DeviceBreakdownCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// =============================================================================
// DATE RANGE FILTER PILLS
// =============================================================================

class _DateRangeFilterPills extends StatelessWidget {
  const _DateRangeFilterPills({required this.controller});
  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: AnalyticsDateRange.values
              .where((r) => r != AnalyticsDateRange.custom)
              .map((range) {
                final isSelected = controller.selectedDateRange.value == range;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => controller.setDateRange(range),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.brand
                            : AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.brand
                              : AppColors.bgDivider,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.brand.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        range.label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(),
        ),
      );
    });
  }
}

// =============================================================================
// SUMMARY CARDS GRID (100% AppColors System)
// =============================================================================

class _SummaryCardsGrid extends StatelessWidget {
  const _SummaryCardsGrid({required this.controller});
  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final va = controller.videoAnalytics.value;
      final ca = controller.channelAnalytics.value;

      final views = va?.totalViews ?? ca?.totalVideoWatches ?? 0;
      final uniqueViewers =
          va?.totalUniqueViewers ?? ca?.totalUniqueViewers ?? 0;

      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricCard(
            icon: Icons.visibility_rounded,
            title: 'Total Views',
            value: _formatNumber(views),
            subtitle: '$uniqueViewers unique viewers',
          ),
          _MetricCard(
            icon: Icons.schedule_rounded,
            title: 'Watch Time',
            value: controller.totalWatchTime.value,
            subtitle: 'Avg ${controller.averageWatchTime.value}',
          ),
          _MetricCard(
            icon: Icons.trending_up_rounded,
            title: 'Engagement',
            value: '${controller.engagementScore.value.toStringAsFixed(1)}%',
            subtitle:
                '${controller.completionRate.value.toStringAsFixed(1)}% completion',
          ),
          _MetricCard(
            icon: Icons.touch_app_rounded,
            title: 'CTR',
            value: '${controller.ctrValue.value.toStringAsFixed(1)}%',
            subtitle: 'Clicks ÷ Impressions',
          ),
          _MetricCard(
            icon: Icons.people_alt_rounded,
            title: 'Returning',
            value: '${controller.returningViewerCount.value}',
            subtitle: 'Repeat viewers',
          ),
          _MetricCard(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Sub Conv.',
            value:
                '${controller.subscriberConversionRate.value.toStringAsFixed(2)}%',
            subtitle: 'Views → Subscribers',
          ),
        ],
      );
    });
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 44) / 2;
    return Container(
      width: width.clamp(140, 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bgDivider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WATCHTIME RETENTION CARD
// =============================================================================

class _WatchtimeRetentionCard extends StatelessWidget {
  const _WatchtimeRetentionCard({required this.controller});
  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Obx(() {
              final data = controller.watchtimeChartData;
              if (data.isEmpty) {
                return const Center(
                  child: Text(
                    'No retention data',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                );
              }

              return PieChart(
                PieChartData(
                  sections: data.map((d) {
                    return PieChartSectionData(
                      value: d.value,
                      color: Color(d.color),
                      title: '${d.percentage.toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      radius: 75,
                      titlePositionPercentageOffset: 0.55,
                    );
                  }).toList(),
                  centerSpaceRadius: 32,
                  sectionsSpace: 2,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // Legend
          Obx(() {
            return Wrap(
              spacing: 12,
              runSpacing: 8,
              children: controller.watchtimeChartData.map((d) {
                return _LegendItem(
                  color: Color(d.color),
                  label: d.title,
                  value:
                      '${d.value.toInt()} (${d.percentage.toStringAsFixed(1)}%)',
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }
}

// =============================================================================
// TRAFFIC SOURCE CARD
// =============================================================================

class _TrafficSourceCard extends StatelessWidget {
  const _TrafficSourceCard({required this.controller});
  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: Obx(() {
              final data = controller.trafficSourceChartData;
              if (data.isEmpty) {
                return const Center(
                  child: Text(
                    'No traffic data',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                );
              }

              return PieChart(
                PieChartData(
                  sections: data.map((d) {
                    return PieChartSectionData(
                      value: d.value,
                      color: Color(d.color),
                      title: d.percentage >= 5
                          ? '${d.percentage.toStringAsFixed(0)}%'
                          : '',
                      titleStyle: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      radius: 70,
                    );
                  }).toList(),
                  centerSpaceRadius: 28,
                  sectionsSpace: 2,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Obx(() {
            return Column(
              children: controller.trafficSourceStats.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        _getTrafficSourceIcon(s.sourceKey),
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.source,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '${s.count}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${s.percentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  IconData _getTrafficSourceIcon(String key) {
    switch (key) {
      case 'search':
        return Icons.search_rounded;
      case 'suggested':
        return Icons.auto_awesome_rounded;
      case 'direct':
        return Icons.link_rounded;
      case 'external':
        return Icons.open_in_new_rounded;
      case 'channel_page':
        return Icons.person_rounded;
      case 'shorts_feed':
        return Icons.video_library_rounded;
      case 'trending':
        return Icons.trending_up_rounded;
      default:
        return Icons.public_rounded;
    }
  }
}

// =============================================================================
// GEOGRAPHIC BREAKDOWN
// =============================================================================

class _GeographicBreakdownCard extends StatelessWidget {
  const _GeographicBreakdownCard({required this.controller});
  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // State pie chart
          if (controller.stateTrafficChartData.isNotEmpty) ...[
            SizedBox(
              height: 190,
              child: Obx(() {
                final data = controller.stateTrafficChartData;
                return PieChart(
                  PieChartData(
                    sections: data.take(8).map((d) {
                      return PieChartSectionData(
                        value: d.value,
                        color: Color(d.color),
                        title: d.percentage >= 8
                            ? '${d.percentage.toStringAsFixed(0)}%'
                            : '',
                        titleStyle: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        radius: 65,
                      );
                    }).toList(),
                    centerSpaceRadius: 26,
                    sectionsSpace: 2,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
          ],

          const Text(
            'Top Region Performance',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Obx(() {
            return Column(
              children: controller.topStates.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.stateName,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '${s.viewCount}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: s.percentage / 100,
                            backgroundColor: AppColors.bgInput,
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.brand,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${s.percentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }
}

// =============================================================================
// TOP CITIES CARD
// =============================================================================

class _TopCitiesCard extends StatelessWidget {
  const _TopCitiesCard({required this.controller});
  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            child: Obx(() {
              final data = controller.cityTrafficChartData;
              if (data.isEmpty) {
                return const Center(
                  child: Text(
                    'No city data',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                );
              }

              return BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY:
                      data.map((d) => d.value).reduce((a, b) => a > b ? a : b) *
                      1.2,
                  barGroups: data.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value,
                          color: Color(entry.value.color),
                          width: 14,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= data.length) {
                            return const SizedBox.shrink();
                          }
                          final label = data[idx].label;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              label.length > 6
                                  ? '${label.substring(0, 5)}..'
                                  : label,
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 9,
                              ),
                            ),
                          );
                        },
                        reservedSize: 26,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Obx(() {
            return Column(
              children: controller.topCities.take(5).map((c) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_city_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.cityName,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '${c.viewCount}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${c.percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }
}

// =============================================================================
// AREA TYPE CARD (Urban vs Rural)
// =============================================================================

class _AreaTypeCard extends StatelessWidget {
  const _AreaTypeCard({required this.controller});
  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Obx(() {
              final data = controller.areaTypeChartData;
              if (data.isEmpty) {
                return const Center(
                  child: Text(
                    '—',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                );
              }

              return PieChart(
                PieChartData(
                  sections: data.map((d) {
                    return PieChartSectionData(
                      value: d.value,
                      color: Color(d.color),
                      title: '',
                      radius: 28,
                    );
                  }).toList(),
                  centerSpaceRadius: 30,
                  sectionsSpace: 3,
                ),
              );
            }),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Obx(() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AreaStatRow(
                    label: 'Urban Viewers',
                    percentage: controller.urbanPercentage.value,
                    color: AppColors.brand,
                  ),
                  const SizedBox(height: 12),
                  _AreaStatRow(
                    label: 'Rural Viewers',
                    percentage: controller.ruralPercentage.value,
                    color: AppColors.success,
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _AreaStatRow extends StatelessWidget {
  const _AreaStatRow({
    required this.label,
    required this.percentage,
    required this.color,
  });
  final String label;
  final double percentage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: AppColors.bgInput,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// DEVICE BREAKDOWN CARD
// =============================================================================

class _DeviceBreakdownCard extends StatelessWidget {
  const _DeviceBreakdownCard({required this.controller});
  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Obx(() {
        return Column(
          children: controller.deviceBreakdownStats.map((d) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    _deviceIcon(d.deviceType),
                    color: AppColors.brand,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.deviceType.capitalize ?? d.deviceType,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: d.percentage / 100,
                            backgroundColor: AppColors.bgInput,
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.brand,
                            ),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${d.percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      }),
    );
  }

  IconData _deviceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'mobile':
        return Icons.phone_android_rounded;
      case 'desktop':
        return Icons.desktop_windows_rounded;
      case 'tablet':
        return Icons.tablet_android_rounded;
      default:
        return Icons.devices_rounded;
    }
  }
}

// =============================================================================
// SHARED WIDGETS
// =============================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $value',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.brand,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

String _formatNumber(int number) {
  if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
  if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
  return number.toString();
}
