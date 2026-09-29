import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics/creator_analytics_common_widgets.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Regional traffic breakdown card with pie chart and state-level rankings.
class CreatorGeographicBreakdownCard extends StatelessWidget {
  const CreatorGeographicBreakdownCard({
    required this.controller,
    super.key,
  });

  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return CreatorGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // State pie chart
          if (controller.stateTrafficChartData.isNotEmpty) ...[
            SizedBox(
              height: 190,
              child: Obx(() {
                final data = controller.stateTrafficChartData;
                return SfCircularChart(
                  margin: EdgeInsets.zero,
                  series: <CircularSeries>[
                    DoughnutSeries<dynamic, String>(
                      dataSource: data.take(8).toList(),
                      xValueMapper: (dynamic d, _) => d.title as String,
                      yValueMapper: (dynamic d, _) => d.value as num,
                      pointColorMapper: (dynamic d, _) => Color(d.color as int),
                      dataLabelMapper: (dynamic d, _) {
                        final pct = (d.percentage as num?)?.toDouble() ?? 0.0;
                        return pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '';
                      },
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

/// Top cities card with bar chart and itemized city view rankings.
class CreatorTopCitiesCard extends StatelessWidget {
  const CreatorTopCitiesCard({
    required this.controller,
    super.key,
  });

  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return CreatorGlassCard(
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

              return SfCartesianChart(
                margin: EdgeInsets.zero,
                plotAreaBorderWidth: 0,
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  axisLine: AxisLine(width: 0),
                  labelStyle: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 9,
                  ),
                ),
                primaryYAxis: const NumericAxis(
                  isVisible: false,
                  majorGridLines: MajorGridLines(width: 0),
                ),
                series: <CartesianSeries<dynamic, String>>[
                  ColumnSeries<dynamic, String>(
                    dataSource: data,
                    animationDuration: 0,
                    xValueMapper: (dynamic d, _) {
                      final label = d.label as String;
                      return label.length > 6 ? '${label.substring(0, 5)}..' : label;
                    },
                    yValueMapper: (dynamic d, _) => d.value as num,
                    pointColorMapper: (dynamic d, _) => Color(d.color as int),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                    width: 0.6,
                  ),
                ],
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
