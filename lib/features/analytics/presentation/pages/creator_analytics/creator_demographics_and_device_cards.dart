import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics/creator_analytics_common_widgets.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Urban vs Rural demographics card with donut chart and metric bars.
class CreatorAreaTypeCard extends StatelessWidget {
  const CreatorAreaTypeCard({required this.controller, super.key});

  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return CreatorGlassCard(
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

              return SfCircularChart(
                margin: EdgeInsets.zero,
                series: <CircularSeries>[
                  DoughnutSeries<dynamic, String>(
                    dataSource: data,
                    xValueMapper: (dynamic d, _) => d.title as String,
                    yValueMapper: (dynamic d, _) => d.value as num,
                    pointColorMapper: (dynamic d, _) => Color(d.color as int),
                    innerRadius: '60%',
                  ),
                ],
              );
            }),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Obx(() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CreatorAreaStatRow(
                    label: 'Urban Viewers',
                    percentage: controller.urbanPercentage.value,
                    color: AppColors.brand,
                  ),
                  const SizedBox(height: 12),
                  CreatorAreaStatRow(
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

/// Stat row displaying label, percentage, and progress indicator.
class CreatorAreaStatRow extends StatelessWidget {
  const CreatorAreaStatRow({
    required this.color,
    required this.label,
    required this.percentage,
    super.key,
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

/// Device breakdown card displaying distribution across mobile, desktop, tablet.
class CreatorDeviceBreakdownCard extends StatelessWidget {
  const CreatorDeviceBreakdownCard({required this.controller, super.key});

  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return CreatorGlassCard(
      child: Obx(() {
        return Column(
          children: controller.deviceBreakdownStats.map((d) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    getDeviceIcon(d.deviceType),
                    color: Colors.white,
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

  /// Helper returning the icon for each device category.
  static IconData getDeviceIcon(String type) {
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
