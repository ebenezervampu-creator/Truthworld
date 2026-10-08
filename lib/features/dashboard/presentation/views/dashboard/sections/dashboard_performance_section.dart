import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class DashboardRecentPerformanceSection extends StatelessWidget {
  final bool isDarkMode;
  final bool isMobile;
  final Animation<double> chartAnimation;
  final List<AnalyticsData> analyticsData;

  const DashboardRecentPerformanceSection({
    required this.isDarkMode,
    required this.isMobile,
    required this.chartAnimation,
    required this.analyticsData,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final performanceContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              'Recent Performance',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: isMobile ? 18 : 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.bgDivider,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Last 28 days',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.bgDivider,
            ),
          ),
          child: DashboardPerformanceChart(
            isDarkMode: isDarkMode,
            analyticsData: analyticsData,
          ),
        ),
      ],
    );

    return AnimatedBuilder(
      animation: chartAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - chartAnimation.value)),
          child: Opacity(
            opacity: chartAnimation.value,
            child: child,
          ),
        );
      },
      child: performanceContent,
    );
  }
}

class DashboardPerformanceChart extends StatelessWidget {
  final bool isDarkMode;
  final List<AnalyticsData> analyticsData;

  const DashboardPerformanceChart({
    required this.isDarkMode,
    required this.analyticsData,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (analyticsData.isEmpty) {
      return const Center(
        child: Text(
          'No analytics data yet.',
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      );
    }

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: const DateTimeAxis(
        majorGridLines: MajorGridLines(width: 0),
        labelStyle: TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
        axisLine: AxisLine(
          color: AppColors.bgDivider,
        ),
      ),
      primaryYAxis: const NumericAxis(
        labelStyle: TextStyle(
          fontFamily: TWTypography.uiFamily,
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
        axisLine: AxisLine(width: 0),
        majorTickLines: MajorTickLines(width: 0),
        majorGridLines: MajorGridLines(
          width: 1,
          color: AppColors.bgDivider,
          dashArray: [5, 5],
        ),
      ),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<AnalyticsData, DateTime>>[
        SplineAreaSeries<AnalyticsData, DateTime>(
          dataSource: analyticsData,
          xValueMapper: (data, _) => data.date,
          yValueMapper: (data, _) => data.views,
          gradient: LinearGradient(
            colors: [
              AppColors.brand.withValues(alpha: 0.25),
              AppColors.brand.withValues(alpha: 0.02),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderColor: AppColors.brand,
          name: 'Views',
        ),
      ],
    );
  }
}
