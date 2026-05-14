import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';

/// Premium Creator Analytics Dashboard — YouTube-grade analytics UI.
///
/// Features:
/// - Date range filter pills (7d / 28d / 90d / 1y / All time)
/// - Summary metric cards (Views, Watchtime, CTR, Engagement, Live viewers)
/// - Watchtime retention distribution (pie chart)
/// - Traffic source breakdown (pie chart)
/// - Geographic breakdown (state pie + city bar + rural/urban donut)
/// - Device & quality breakdown
/// - Subscriber conversion & returning viewers
class CreatorAnalyticsDashboard extends StatelessWidget {
  const CreatorAnalyticsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CreatorAnalyticsController());
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
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: Text(
          videoId.isNotEmpty ? 'Video Analytics' : 'Channel Analytics',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(() {
            final count = controller.liveViewerCount.value;
            if (count > 0) {
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingDot(),
                    const SizedBox(width: 6),
                    Text(
                      '$count watching',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => controller.refreshAnalytics(),
          ),
        ],
      ),
      body: Obx(() {
        final isLoading = controller.isLoadingVideoAnalytics.value ||
            controller.isLoadingChannelAnalytics.value;

        if (isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFDC2626)),
          );
        }

        return RefreshIndicator(
          color: const Color(0xFFDC2626),
          onRefresh: () => controller.refreshAnalytics(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header info
                if (videoId.isNotEmpty) ...[
                  Text(
                    videoTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  Text(
                    channelName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Date range filter pills
                _DateRangeFilterPills(controller: controller),
                const SizedBox(height: 20),

                // Error message
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
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error,
                            style: const TextStyle(
                                color: Colors.amber, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Summary Cards Grid
                _SummaryCardsGrid(controller: controller),
                const SizedBox(height: 24),

                // Watchtime Retention Distribution
                if (controller.watchtimeChartData.isNotEmpty) ...[
                  _SectionHeader(title: 'Audience Retention'),
                  const SizedBox(height: 12),
                  _WatchtimeRetentionCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                // Traffic Sources
                if (controller.trafficSourceChartData.isNotEmpty) ...[
                  _SectionHeader(title: 'Traffic Sources'),
                  const SizedBox(height: 12),
                  _TrafficSourceCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                // Geographic Breakdown
                if (controller.stateTrafficChartData.isNotEmpty ||
                    controller.topStates.isNotEmpty) ...[
                  _SectionHeader(title: 'Geographic Breakdown'),
                  const SizedBox(height: 12),
                  _GeographicBreakdownCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                // City Breakdown
                if (controller.topCities.isNotEmpty) ...[
                  _SectionHeader(title: 'Top Cities'),
                  const SizedBox(height: 12),
                  _TopCitiesCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                // Urban vs Rural
                if (controller.areaTypeChartData.isNotEmpty) ...[
                  _SectionHeader(title: 'Urban vs Rural'),
                  const SizedBox(height: 12),
                  _AreaTypeCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                // Device Breakdown
                if (controller.deviceBreakdownStats.isNotEmpty) ...[
                  _SectionHeader(title: 'Device Breakdown'),
                  const SizedBox(height: 12),
                  _DeviceBreakdownCard(controller: controller),
                  const SizedBox(height: 24),
                ],

                const SizedBox(height: 40),
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
  final CreatorAnalyticsController controller;

  const _DateRangeFilterPills({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: AnalyticsDateRange.values
              .where((r) => r != AnalyticsDateRange.custom)
              .map((range) {
            final isSelected =
                controller.selectedDateRange.value == range;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => controller.setDateRange(range),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFDC2626)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFDC2626)
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    range.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w500 : FontWeight.w400,
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
}

// =============================================================================
// SUMMARY CARDS GRID
// =============================================================================

class _SummaryCardsGrid extends StatelessWidget {
  final CreatorAnalyticsController controller;

  const _SummaryCardsGrid({required this.controller});

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
            icon: Icons.visibility,
            title: 'Total Views',
            value: _formatNumber(views),
            subtitle: '$uniqueViewers unique viewers',
            accentColor: const Color(0xFF3B82F6),
          ),
          _MetricCard(
            icon: Icons.schedule,
            title: 'Watch Time',
            value: controller.totalWatchTime.value,
            subtitle: 'Avg ${controller.averageWatchTime.value}',
            accentColor: const Color(0xFF22C55E),
          ),
          _MetricCard(
            icon: Icons.trending_up,
            title: 'Engagement',
            value: '${controller.engagementScore.value.toStringAsFixed(1)}%',
            subtitle:
                '${controller.completionRate.value.toStringAsFixed(1)}% completion',
            accentColor: const Color(0xFF8B5CF6),
          ),
          _MetricCard(
            icon: Icons.touch_app,
            title: 'CTR',
            value: '${controller.ctrValue.value.toStringAsFixed(1)}%',
            subtitle: 'Clicks ÷ Impressions',
            accentColor: const Color(0xFFF97316),
          ),
          _MetricCard(
            icon: Icons.people,
            title: 'Returning',
            value: '${controller.returningViewerCount.value}',
            subtitle: ReturningViewerDefinition.tooltip,
            accentColor: const Color(0xFF06B6D4),
          ),
          _MetricCard(
            icon: Icons.person_add,
            title: 'Sub Conv.',
            value:
                '${controller.subscriberConversionRate.value.toStringAsFixed(2)}%',
            subtitle: 'Views → Subscribers',
            accentColor: const Color(0xFFEC4899),
          ),
        ],
      );
    });
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;

  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 44) / 2;
    return Container(
      width: width.clamp(140, 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.12),
            accentColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
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
  final CreatorAnalyticsController controller;

  const _WatchtimeRetentionCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: Obx(() {
              final data = controller.watchtimeChartData;
              if (data.isEmpty) {
                return const Center(
                  child: Text('No data',
                      style: TextStyle(color: Colors.white38)),
                );
              }

              return PieChart(
                PieChartData(
                  sections: data.map((d) {
                    return PieChartSectionData(
                      value: d.value,
                      color: Color(d.color),
                      title:
                          '${d.percentage.toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      radius: 80,
                      titlePositionPercentageOffset: 0.55,
                    );
                  }).toList(),
                  centerSpaceRadius: 35,
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
                    value: '${d.value.toInt()} (${d.percentage.toStringAsFixed(1)}%)');
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
  final CreatorAnalyticsController controller;

  const _TrafficSourceCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Obx(() {
              final data = controller.trafficSourceChartData;
              if (data.isEmpty) {
                return const Center(
                  child: Text('No data',
                      style: TextStyle(color: Colors.white38)),
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
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      radius: 75,
                    );
                  }).toList(),
                  centerSpaceRadius: 30,
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
                      Icon(_getTrafficSourceIcon(s.sourceKey),
                          color: Colors.white54, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.source,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      Text(
                        '${s.count}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${s.percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12),
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
        return Icons.search;
      case 'suggested':
        return Icons.recommend;
      case 'direct':
        return Icons.link;
      case 'external':
        return Icons.open_in_new;
      case 'channel_page':
        return Icons.person;
      case 'shorts_feed':
        return Icons.video_library;
      case 'trending':
        return Icons.trending_up;
      default:
        return Icons.public;
    }
  }
}

// =============================================================================
// GEOGRAPHIC BREAKDOWN
// =============================================================================

class _GeographicBreakdownCard extends StatelessWidget {
  final CreatorAnalyticsController controller;

  const _GeographicBreakdownCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // State pie chart
          if (controller.stateTrafficChartData.isNotEmpty) ...[
            SizedBox(
              height: 200,
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
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
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
          ],

          // Top states list
          const Text(
            'Top States',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
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
                              color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      Text(
                        '${s.viewCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: s.percentage / 100,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.1),
                            valueColor:
                                const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${s.percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
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
  final CreatorAnalyticsController controller;

  const _TopCitiesCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // City bar chart
          SizedBox(
            height: 220,
            child: Obx(() {
              final data = controller.cityTrafficChartData;
              if (data.isEmpty) {
                return const Center(
                  child: Text('No city data',
                      style: TextStyle(color: Colors.white38)),
                );
              }

              return BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: data
                          .map((d) => d.value)
                          .reduce((a, b) => a > b ? a : b) *
                      1.2,
                  barGroups: data.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value,
                          color: Color(entry.value.color),
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
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
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              label.length > 6
                                  ? '${label.substring(0, 5)}..'
                                  : label,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 9,
                              ),
                            ),
                          );
                        },
                        reservedSize: 30,
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

          // City details list
          Obx(() {
            return Column(
              children: controller.topCities.take(5).map((c) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.location_city,
                          color: Colors.white38, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.cityName,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      Text(
                        '${c.viewCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${c.percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
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
  final CreatorAnalyticsController controller;

  const _AreaTypeCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        children: [
          // Donut chart
          SizedBox(
            width: 140,
            height: 140,
            child: Obx(() {
              final data = controller.areaTypeChartData;
              if (data.isEmpty) {
                return const Center(
                  child: Text('—', style: TextStyle(color: Colors.white38)),
                );
              }

              return PieChart(
                PieChartData(
                  sections: data.map((d) {
                    return PieChartSectionData(
                      value: d.value,
                      color: Color(d.color),
                      title: '',
                      radius: 30,
                    );
                  }).toList(),
                  centerSpaceRadius: 35,
                  sectionsSpace: 3,
                ),
              );
            }),
          ),
          const SizedBox(width: 24),
          // Stats
          Expanded(
            child: Obx(() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AreaStatRow(
                    label: 'Urban',
                    percentage: controller.urbanPercentage.value,
                    color: const Color(0xFF3B82F6),
                  ),
                  const SizedBox(height: 12),
                  _AreaStatRow(
                    label: 'Rural',
                    percentage: controller.ruralPercentage.value,
                    color: const Color(0xFF22C55E),
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
  final String label;
  final double percentage;
  final Color color;

  const _AreaStatRow({
    required this.label,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              style:
                  const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const Spacer(),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
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
  final CreatorAnalyticsController controller;

  const _DeviceBreakdownCard({required this.controller});

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
                    color: Colors.white54,
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
                              color: Colors.white, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: d.percentage / 100,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.1),
                            valueColor:
                                AlwaysStoppedAnimation(_deviceColor(d.deviceType)),
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
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
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
        return Icons.phone_android;
      case 'desktop':
        return Icons.desktop_windows;
      case 'tablet':
        return Icons.tablet;
      default:
        return Icons.devices;
    }
  }

  Color _deviceColor(String type) {
    switch (type.toLowerCase()) {
      case 'mobile':
        return const Color(0xFF3B82F6);
      case 'desktop':
        return const Color(0xFF22C55E);
      case 'tablet':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFFF97316);
    }
  }
}

// =============================================================================
// SHARED WIDGETS
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $value',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
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
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
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
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// =============================================================================
// HELPER
// =============================================================================

String _formatNumber(int number) {
  if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
  if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
  return number.toString();
}





