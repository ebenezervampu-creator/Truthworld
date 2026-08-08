import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Display pie chart for watchtime categories
class WatchtimePieChart extends StatelessWidget {
  WatchtimePieChart({super.key});
  final CreatorAnalyticsController controller = CreatorAnalyticsController.to;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final chartData = controller.watchtimeChartData;

      if (chartData.isEmpty) {
        return _buildEmptyState('No watchtime data available');
      }

      final spots = chartData.asMap().entries.map((e) {
        return PieChartSectionData(
          value: e.value.value,
          title: '${e.value.percentage.toStringAsFixed(1)}%',
          color: Color(e.value.color),
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        );
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'Watchtime Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          // Chart
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 280,
              child: PieChart(
                PieChartData(
                  sections: spots,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ),
          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: chartData.map((data) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color(data.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${data.title}: ${data.value.toInt()} views',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF34495E),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildEmptyState(String message) {
    return SizedBox(
      height: 350,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF95A5A6),
          ),
        ),
      ),
    );
  }
}

/// Display pie chart for state-wise traffic
class StateTrafficChart extends StatelessWidget {
  StateTrafficChart({super.key});
  final CreatorAnalyticsController controller = CreatorAnalyticsController.to;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final chartData = controller.stateTrafficChartData;

      if (chartData.isEmpty) {
        return _buildEmptyState('No traffic data available');
      }

      // Show only top 8 states in pie chart
      final topStates = chartData.take(8).toList();

      final spots = topStates.asMap().entries.map((e) {
        return PieChartSectionData(
          value: e.value.value,
          title: '${e.value.percentage.toStringAsFixed(0)}%',
          color: Color(e.value.color),
          radius: 55,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        );
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'State-wise Traffic Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          // Chart
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 280,
              child: PieChart(
                PieChartData(
                  sections: spots,
                  centerSpaceRadius: 35,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ),
          // Legend table
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('State')),
                  DataColumn(label: Text('Views'), numeric: true),
                  DataColumn(label: Text('Percentage'), numeric: true),
                ],
                rows: topStates.map((data) {
                  return DataRow(
                    cells: [
                      DataCell(Text(data.title)),
                      DataCell(Text('${data.value.toInt()}')),
                      DataCell(Text('${data.percentage.toStringAsFixed(1)}%')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildEmptyState(String message) {
    return SizedBox(
      height: 350,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF95A5A6),
          ),
        ),
      ),
    );
  }
}

/// Summary metrics cards
class AnalyticsSummaryCards extends StatelessWidget {
  AnalyticsSummaryCards({super.key});
  final CreatorAnalyticsController controller = CreatorAnalyticsController.to;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final videoAnalytics = controller.videoAnalytics.value;

      if (videoAnalytics == null || videoAnalytics.totalViews == 0) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          children: [
            _buildMetricCard(
              title: 'Total Views',
              value: '${videoAnalytics.totalViews}',
              icon: Icons.play_circle_outline,
              color: const Color(0xFF3498DB),
            ),
            _buildMetricCard(
              title: 'Unique Viewers',
              value: '${videoAnalytics.totalUniqueViewers}',
              icon: Icons.people_outline,
              color: const Color(0xFF2ECC71),
            ),
            _buildMetricCard(
              title: 'Avg Watch Time',
              value: controller.averageWatchTime.value,
              icon: Icons.timer_outlined,
              color: const Color(0xFFF39C12),
            ),
            _buildMetricCard(
              title: 'Completion Rate',
              value: '${controller.completionRate.value.toStringAsFixed(1)}%',
              icon: Icons.trending_up,
              color: const Color(0xFFE74C3C),
            ),
            _buildMetricCard(
              title: 'Engagement Score',
              value:
                  '${controller.engagementScore.value.toStringAsFixed(1)}/100',
              icon: Icons.stacked_bar_chart,
              color: const Color(0xFF9B59B6),
            ),
            _buildMetricCard(
              title: 'CTR',
              value: '${controller.ctrValue.value.toStringAsFixed(1)}%',
              icon: Icons.touch_app,
              color: const Color(0xFF1ABC9C),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7F8C8D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Top states breakdown
class TopStatesBreakdown extends StatelessWidget {
  TopStatesBreakdown({super.key});
  final CreatorAnalyticsController controller = CreatorAnalyticsController.to;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final states = controller.topStates;

      if (states.isEmpty) {
        return const SizedBox.shrink();
      }

      return Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Top 5 States by Traffic',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
            // State list
            ...states.asMap().entries.map((entry) {
              final index = entry.key;
              final state = entry.value;
              final percentage = state.percentage;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${index + 1}. ${state.stateName}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3498DB),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFECF0F1),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF3498DB),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${state.viewCount} views',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF95A5A6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index < states.length - 1)
                    const Divider(height: 1, color: Color(0xFFECF0F1)),
                ],
              );
            }),
          ],
        ),
      );
    });
  }
}

/// Device breakdown
class DeviceBreakdownWidget extends StatelessWidget {
  DeviceBreakdownWidget({super.key});
  final CreatorAnalyticsController controller = CreatorAnalyticsController.to;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final devices = controller.deviceBreakdownStats;

      if (devices.isEmpty) {
        return const SizedBox.shrink();
      }

      return Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Device Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: devices.map((device) {
                  return Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.deviceType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${device.percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3498DB),
                            ),
                          ),
                          Text(
                            '${device.count} views',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF95A5A6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    });
  }
}
