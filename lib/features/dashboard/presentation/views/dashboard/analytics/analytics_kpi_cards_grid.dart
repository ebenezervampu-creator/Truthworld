import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/analytics_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Performance KPI Overview Cards displaying channel metrics with
/// TruthWorld design tokens, brand fonts, and high-contrast surfaces.
class AnalyticsKpiCardsGrid extends StatelessWidget {
  const AnalyticsKpiCardsGrid({
    required this.controller,
    required this.isMobile,
    super.key,
  });

  final AnalyticsController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rangeLabel = controller.selectedDateRange.label;
      final items = [
        _KpiMetric(
          title: 'Total Views',
          value: controller.totalViewsFormatted,
          subtitle: 'Viewer watches ($rangeLabel)',
          icon: Icons.visibility_rounded,
          accentColor: AppColors.info,
          trendLabel: '+14% vs prev',
        ),
        _KpiMetric(
          title: 'Watch Time',
          value: controller.totalWatchTimeFormatted,
          subtitle: 'Retention hours ($rangeLabel)',
          icon: Icons.schedule_rounded,
          accentColor: AppColors.success,
          trendLabel: 'High Engagement',
        ),
        _KpiMetric(
          title: 'Subscribers',
          value: controller.subscribersFormatted,
          subtitle: 'Net audience growth ($rangeLabel)',
          icon: Icons.people_alt_rounded,
          accentColor: const Color(0xFFA855F7),
          trendLabel: 'Channel Base',
        ),
        _KpiMetric(
          title: 'Impressions CTR',
          value: controller.ctrFormatted,
          subtitle: 'Feed click conversion',
          icon: Icons.trending_up_rounded,
          accentColor: AppColors.warning,
          trendLabel: 'Optimized',
        ),
      ];

      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Responsive layout: 4 columns on desktop (width >= 900), 2 on tablet, 1 or 2 on phone
          final int crossAxisCount = width >= 900 ? 4 : (width >= 500 ? 2 : 1);
          final cardWidth = crossAxisCount == 4
              ? (width - (12 * 3)) / 4
              : (crossAxisCount == 2
                  ? (width - 12) / 2
                  : width);

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items.map((metric) {
              return SizedBox(
                width: cardWidth,
                child: _buildKpiCard(metric),
              );
            }).toList(),
          );
        },
      );
    });
  }

  Widget _buildKpiCard(_KpiMetric metric) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bgSurface),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: metric.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: metric.accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  metric.icon,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.bgSurface),
                ),
                child: Text(
                  metric.trendLabel,
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: metric.accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            metric.value,
            style: const TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            metric.title,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            metric.subtitle,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _KpiMetric {
  const _KpiMetric({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.trendLabel,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String trendLabel;
}
