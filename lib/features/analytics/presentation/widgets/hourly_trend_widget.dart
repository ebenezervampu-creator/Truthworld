import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Hourly view trend line chart widget.
///
/// Displays a 24-hour distribution of views using fl_chart LineChart.
/// Accepts raw hourly data as `List<Map<String, dynamic>>` where each entry
/// contains `hour` (0-23) and `views` (int).
///
/// Features:
/// - Curved line with gradient fill below
/// - Smart hour labels (12 AM, 3 AM, 6 AM, ..., 9 PM)
/// - Touch tooltip showing exact view count
/// - Empty state with icon
class HourlyTrendWidget extends StatelessWidget {
  const HourlyTrendWidget({required this.hourlyData, super.key});
  final List<Map<String, dynamic>> hourlyData;

  @override
  Widget build(BuildContext context) {
    if (hourlyData.isEmpty) {
      return _buildEmptyState();
    }

    final spots = hourlyData.asMap().entries.map((entry) {
      return FlSpot(
        (entry.value['hour'] as num?)?.toDouble() ?? entry.key.toDouble(),
        (entry.value['views'] as num?)?.toDouble() ?? 0,
      );
    }).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final safeMaxY = maxY > 0 ? maxY * 1.2 : 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Views — Last 24 Hours',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.textPrimary.withValues(alpha: 0.06),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: AppColors.textPrimary.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        final hour = value.toInt();
                        if (hour < 0 || hour > 23) {
                          return const SizedBox.shrink();
                        }
                        final label = hour == 0
                            ? '12 AM'
                            : hour < 12
                            ? '$hour AM'
                            : hour == 12
                            ? '12 PM'
                            : '${hour - 12} PM';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.5,
                              ),
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 23,
                minY: 0,
                maxY: safeMaxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: const Color(0xFF00D2FF),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00D2FF).withValues(alpha: 0.3),
                          const Color(0xFF00D2FF).withValues(alpha: 0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => const Color(0xFF1A1A2E),
                    tooltipBorder: BorderSide(
                      color: AppColors.textPrimary.withValues(alpha: 0.1),
                    ),
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toInt()} views',
                          const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timeline,
              color: AppColors.textPrimary.withValues(alpha: 0.3),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'No hourly data available yet',
              style: TextStyle(
                color: AppColors.textPrimary.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
