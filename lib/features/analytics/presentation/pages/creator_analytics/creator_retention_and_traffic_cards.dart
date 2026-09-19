import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics/creator_analytics_common_widgets.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Audience retention pie chart card.
class CreatorWatchtimeRetentionCard extends StatelessWidget {
  const CreatorWatchtimeRetentionCard({
    required this.controller,
    super.key,
  });

  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return CreatorGlassCard(
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

              return SfCircularChart(
                margin: EdgeInsets.zero,
                series: <CircularSeries>[
                  DoughnutSeries<dynamic, String>(
                    dataSource: data,
                    xValueMapper: (dynamic d, _) => d.title as String,
                    yValueMapper: (dynamic d, _) => d.value as num,
                    pointColorMapper: (dynamic d, _) => Color(d.color as int),
                    dataLabelMapper: (dynamic d, _) =>
                        '${(d.percentage as double).toStringAsFixed(0)}%',
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    innerRadius: '45%',
                    radius: '85%',
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          Obx(() {
            return Wrap(
              spacing: 12,
              runSpacing: 8,
              children: controller.watchtimeChartData.map((d) {
                return CreatorLegendItem(
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

/// Traffic source breakdown card with pie chart and detailed source rows.
class CreatorTrafficSourceCard extends StatelessWidget {
  const CreatorTrafficSourceCard({
    required this.controller,
    super.key,
  });

  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return CreatorGlassCard(
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

              return SfCircularChart(
                margin: EdgeInsets.zero,
                series: <CircularSeries>[
                  DoughnutSeries<dynamic, String>(
                    dataSource: data,
                    xValueMapper: (dynamic d, _) => d.title as String,
                    yValueMapper: (dynamic d, _) => d.value as num,
                    pointColorMapper: (dynamic d, _) => Color(d.color as int),
                    dataLabelMapper: (dynamic d, _) =>
                        (d.percentage as double) >= 5
                            ? '${(d.percentage as double).toStringAsFixed(0)}%'
                            : '',
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    innerRadius: '45%',
                    radius: '85%',
                  ),
                ],
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
                        getTrafficSourceIcon(s.sourceKey),
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

  /// Helper returning the icon for each traffic source type.
  static IconData getTrafficSourceIcon(String key) {
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
