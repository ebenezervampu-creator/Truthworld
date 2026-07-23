import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Retention funnel bar chart widget.
///
/// Renders a horizontal bar chart showing the full viewer journey:
/// Impressions → Starts → Drop on Start → 25% → 50% → 75% → 100%
///
/// Each bar is color-coded with percentage labels for quick visual scanning.
class RetentionFunnelChartWidget extends StatelessWidget {

  const RetentionFunnelChartWidget({required this.funnel, super.key});
  final RetentionFunnelModel funnel;

  @override
  Widget build(BuildContext context) {
    final stages = [
      _FunnelStage('Impressions', funnel.impressions, const Color(0xFF3B82F6)),
      _FunnelStage('Starts', funnel.start, const Color(0xFF22C55E)),
      _FunnelStage('Drop <30s', funnel.dropOnStart, const Color(0xFFEF4444)),
      _FunnelStage('25%', funnel.d25, const Color(0xFF8B5CF6)),
      _FunnelStage('50%', funnel.d50, const Color(0xFF06B6D4)),
      _FunnelStage('75%', funnel.d75, const Color(0xFFF97316)),
      _FunnelStage('100%', funnel.d100, const Color(0xFF22C55E)),
    ];

    final maxVal = stages
        .map((s) => s.value)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final safeMax = maxVal > 0 ? maxVal * 1.15 : 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Retention Funnel',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          // Rate summary row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _RatePill(
                'Start Rate',
                funnel.startRate,
                const Color(0xFF22C55E),
              ),
              _RatePill(
                'Drop Rate',
                funnel.dropOnStartRate,
                const Color(0xFFEF4444),
              ),
              _RatePill(
                'Completion',
                funnel.completionRate,
                const Color(0xFF8B5CF6),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: safeMax,
                barGroups: stages.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.value.toDouble(),
                        color: entry.value.color,
                        width: 22,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatCount(value.toInt()),
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
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= stages.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            stages[idx].label,
                            style: TextStyle(
                              color: AppColors.textPrimary.withValues(alpha: 0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  topTitles: const AxisTitles(
                    
                  ),
                  rightTitles: const AxisTitles(
                    
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.textPrimary.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => const Color(0xFF1A1A2E),
                    tooltipBorder: BorderSide(
                      color: AppColors.textPrimary.withValues(alpha: 0.1),
                    ),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final stage = stages[groupIndex];
                      return BarTooltipItem(
                        '${stage.label}\n${stage.value}',
                        const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
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

  String _formatCount(int n) {
    if (n < 0) n = 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _FunnelStage {

  const _FunnelStage(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class _RatePill extends StatelessWidget {

  const _RatePill(this.label, this.rate, this.color);
  final String label;
  final double rate;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: ${rate.toStringAsFixed(1)}%',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
