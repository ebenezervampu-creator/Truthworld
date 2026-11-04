import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/pages/creator_analytics/creator_analytics_common_widgets.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Audience retention pie chart card redesigned with executive layout,
/// animated donut KPI center, progress breakdown bars, and professional colors.
class CreatorWatchtimeRetentionCard extends StatelessWidget {
  const CreatorWatchtimeRetentionCard({
    required this.controller,
    super.key,
  });

  final CreatorAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return CreatorGlassCard(
      child: Obx(() {
        final data = controller.watchtimeChartData;
        if (data.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.bgDivider.withValues(alpha: 0.6),
                    ),
                  ),
                  child: const Icon(
                    Icons.pie_chart_outline_rounded,
                    color: AppColors.textTertiary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No retention data',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Audience retention statistics will populate automatically as viewers watch your videos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        // Calculate summary metrics
        var totalViewers = 0;
        dynamic completionItem;
        for (final d in data) {
          totalViewers += (d.value as num).toInt();
          final titleStr = (d.title as String).toLowerCase();
          if (titleStr.contains('100') || titleStr.contains('complete')) {
            completionItem = d;
          }
        }

        final completionRate = completionItem != null
            ? ((completionItem.percentage as num?)?.toDouble() ?? 0.0)
            : (data.isNotEmpty
                ? ((data.first.percentage as num?)?.toDouble() ?? 0.0)
                : 0.0);
        final completionCount = completionItem != null
            ? (completionItem.value as num).toInt()
            : 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Executive Header with Metric Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          color: Color(0xFF10B981),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Retention Distribution',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              totalViewers > 0
                                  ? '$totalViewers total viewers analyzed'
                                  : 'Engagement across duration milestones',
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (completionRate > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 13,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${completionRate.toStringAsFixed(1)}% Full Watch',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Responsive Layout: 2-column on wider screens, stacked on compact
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 540;

                final chartSection = SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SfCircularChart(
                        margin: EdgeInsets.zero,
                        tooltipBehavior: TooltipBehavior(
                          enable: true,
                          format: 'point.x: point.y (point.percentage%)',
                          textStyle: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          color: AppColors.bgElevated,
                          borderColor: AppColors.bgDivider,
                          borderWidth: 1,
                          elevation: 8,
                          canShowMarker: false,
                        ),
                        series: <CircularSeries>[
                          DoughnutSeries<dynamic, String>(
                            dataSource: data,
                            animationDuration: 1200,
                            animationDelay: 100,
                            xValueMapper: (dynamic d, _) => d.title as String,
                            yValueMapper: (dynamic d, _) => d.value as num,
                            pointColorMapper: (dynamic d, _) => _resolveColor(
                              d.title as String,
                              Color(d.color as int),
                            ),
                            strokeColor: AppColors.bgSurface,
                            strokeWidth: 3,
                            innerRadius: '70%',
                            radius: '95%',
                            explode: true,
                            explodeIndex: 0,
                            explodeOffset: '5%',
                            dataLabelSettings: const DataLabelSettings(
                              isVisible: false,
                            ),
                          ),
                        ],
                      ),
                      // Animated Center KPI
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: completionRate),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, child) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${val.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                completionItem != null
                                    ? 'COMPLETION'
                                    : 'RETENTION',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              if (totalViewers > 0 && completionCount > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '$completionCount / $totalViewers completed',
                                  style: const TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );

                final breakdownList = Column(
                  children: data.map((d) {
                    final title = d.title as String;
                    final value = (d.value as num).toInt();
                    final pct =
                        ((d.percentage as num?)?.toDouble() ?? 0.0).clamp(
                      0.0,
                      100.0,
                    );
                    final color = _resolveColor(title, Color(d.color as int));
                    final friendlyTitle = _getFriendlyTitle(title);
                    final subtitle = _getSubtitle(title);
                    final exactLegendText =
                        '$title: $value (${pct.toStringAsFixed(1)}%)';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.bgDivider.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      friendlyTitle,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      subtitle,
                                      style: const TextStyle(
                                        color: AppColors.textTertiary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Formatted exact value text for clarity and testing
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    exactLegendText,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '${pct.toStringAsFixed(1)}% of total',
                                    style: const TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Animated Horizontal Progress Bar
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: pct / 100.0),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOutCubic,
                            builder: (context, animatedValue, child) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 5,
                                      width: double.infinity,
                                      color: AppColors.bgElevated,
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: animatedValue.clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      child: Container(
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius:
                                              BorderRadius.circular(3),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  color.withValues(alpha: 0.3),
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(child: chartSection),
                      const SizedBox(width: 28),
                      Expanded(child: breakdownList),
                    ],
                  );
                }

                return Column(
                  children: [
                    Center(child: chartSection),
                    const SizedBox(height: 16),
                    breakdownList,
                  ],
                );
              },
            ),
          ],
        );
      }),
    );
  }

  /// Resolve executive, harmonious colors for retention milestones.
  static Color _resolveColor(String title, Color fallback) {
    final clean = title.trim().toLowerCase();
    if (clean == '100%' || clean.contains('complete')) {
      return const Color(0xFF10B981); // Emerald Mint
    } else if (clean.contains('75')) {
      return const Color(0xFF0EA5E9); // Sky Blue
    } else if (clean.contains('50')) {
      return const Color(0xFF8B5CF6); // Deep Iris
    } else if (clean.contains('25')) {
      return const Color(0xFFF59E0B); // Warm Amber
    } else if (clean.contains('20') || clean.contains('bounce')) {
      return const Color(0xFFF43F5E); // Rose Coral
    }
    return fallback;
  }

  /// Returns clear, human-understandable milestone labels.
  static String _getFriendlyTitle(String rawTitle) {
    final clean = rawTitle.trim().toLowerCase();
    if (clean == '100%' || clean.contains('complete')) {
      return 'Completed (100%)';
    } else if (clean.contains('75')) {
      return 'High Retention (50–75%)';
    } else if (clean.contains('50')) {
      return 'Moderate Retention (25–50%)';
    } else if (clean.contains('25')) {
      return 'Early Drop-off (< 25%)';
    } else if (clean.contains('20') || clean.contains('bounce')) {
      return 'Quick Bounce (< 20s)';
    }
    return rawTitle;
  }

  /// Returns descriptive, contextual explanation for each retention tier.
  static String _getSubtitle(String rawTitle) {
    final clean = rawTitle.trim().toLowerCase();
    if (clean == '100%' || clean.contains('complete')) {
      return 'Watched full video to completion';
    } else if (clean.contains('75')) {
      return 'Engaged through most of duration';
    } else if (clean.contains('50')) {
      return 'Watched approximately halfway';
    } else if (clean.contains('25')) {
      return 'Dropped during early segment';
    } else if (clean.contains('20') || clean.contains('bounce')) {
      return 'Left within first 20 seconds';
    }
    return 'Audience engagement tier';
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
                    animationDuration: 0,
                    xValueMapper: (dynamic d, _) => d.title as String,
                    yValueMapper: (dynamic d, _) => d.value as num,
                    pointColorMapper: (dynamic d, _) => Color(d.color as int),
                    dataLabelMapper: (dynamic d, _) {
                      final pct = (d.percentage as num?)?.toDouble() ?? 0.0;
                      return pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '';
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
