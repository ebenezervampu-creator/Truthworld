import 'package:fl_chart/fl_chart.dart';
import 'package:truthworld/components/ui/back_symbol.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';

class WatchTimePage extends StatelessWidget {
  const WatchTimePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CreatorAnalyticsController());
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final channelId = args['channelId'] as String? ?? '';
    final videoId = args['videoId'] as String? ?? '';

    // Load analytics on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (videoId.isNotEmpty) {
        controller.selectedVideoId.value = videoId;
      } else if (channelId.isNotEmpty) {
        controller.selectedChannelId.value = channelId;
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: const BackSymbol(color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Watch Time',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
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
                _buildMainMetric(controller, args),
                const SizedBox(height: 24),
                _SectionHeader(title: 'Watch Time Trend'),
                const SizedBox(height: 12),
                _buildTrendChart(controller),
                const SizedBox(height: 24),
                _SectionHeader(title: 'Audience Retention'),
                const SizedBox(height: 12),
                _WatchtimeRetentionCard(controller: controller),
                const SizedBox(height: 24),
                _SectionHeader(title: 'Key Insights'),
                const SizedBox(height: 12),
                _buildInsightsGrid(controller),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMainMetric(CreatorAnalyticsController controller, Map<String, dynamic> args) {
    final watchTimeChange = args['watchTimeChange'] as String? ?? '+0%';
    final isPositive = watchTimeChange.startsWith('+');

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Watch Time',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            controller.totalWatchTime.value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '$watchTimeChange in last 28 days',
                style: TextStyle(
                  color: (isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444))
                      .withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(CreatorAnalyticsController controller) {
    return _GlassCard(
      child: SizedBox(
        height: 240,
        child: SfCartesianChart(
          plotAreaBorderWidth: 0,
          margin: EdgeInsets.zero,
          primaryXAxis: DateTimeAxis(
            majorGridLines: const MajorGridLines(width: 0),
            labelStyle: const TextStyle(color: Colors.white54, fontSize: 10),
            axisLine: const AxisLine(width: 0),
          ),
          primaryYAxis: NumericAxis(
            majorGridLines: MajorGridLines(
              width: 1,
              color: Colors.white.withValues(alpha: 0.05),
              dashArray: const [5, 5],
            ),
            labelStyle: const TextStyle(color: Colors.white54, fontSize: 10),
            axisLine: const AxisLine(width: 0),
            labelFormat: '{value}h',
          ),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <CartesianSeries<WatchTimeTrendModel, DateTime>>[
            SplineAreaSeries<WatchTimeTrendModel, DateTime>(
              dataSource: controller.watchTimeTrendData,
              xValueMapper: (WatchTimeTrendModel data, _) => data.date,
              yValueMapper: (WatchTimeTrendModel data, _) => data.watchTimeHours,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  const Color(0xFF3B82F6).withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderColor: const Color(0xFF3B82F6),
              borderWidth: 2,
              markerSettings: const MarkerSettings(isVisible: false),
              name: 'Watch Time',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsGrid(CreatorAnalyticsController controller) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildInsightItem(
          'Avg Duration',
          controller.averageWatchTime.value,
          Icons.speed,
          const Color(0xFF8B5CF6),
        ),
        _buildInsightItem(
          'Returning',
          '${controller.returningViewerCount.value}',
          Icons.person_add,
          const Color(0xFFEC4899),
        ),
      ],
    );
  }

  Widget _buildInsightItem(String label, String value, IconData icon, Color color) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

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
                  child: Text('No data', style: TextStyle(color: Colors.white38)),
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
          Obx(() {
            return Wrap(
              spacing: 12,
              runSpacing: 8,
              children: controller.watchtimeChartData.map((d) {
                return _LegendItem(
                  color: Color(d.color),
                  label: d.title,
                  value: '${d.value.toInt()} (${d.percentage.toStringAsFixed(1)}%)',
                );
              }).toList(),
            );
          }),
        ],
      ),
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
