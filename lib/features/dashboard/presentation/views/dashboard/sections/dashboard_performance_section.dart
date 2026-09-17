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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Performance',
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.textPrimary : Colors.black,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppTheme.colors.surface
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDarkMode
                      ? const Color(0xFF374151)
                      : AppColors.bgDivider,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Last 28 days',
                    style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          height: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? AppTheme.colors.surface : AppColors.textPrimary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? const Color(0xFF374151) : AppColors.bgDivider,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black26 : Colors.black38,
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
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
      return Center(
        child: Text(
          'No analytics data yet.',
          style: TextStyle(
            color: isDarkMode ? AppColors.textSecondary : Colors.black,
          ),
        ),
      );
    }

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: DateTimeAxis(
        majorGridLines: const MajorGridLines(width: 0),
        labelStyle: TextStyle(
          color: isDarkMode ? AppColors.textSecondary : Colors.black,
        ),
        axisLine: AxisLine(
          color: isDarkMode ? const Color(0xFF374151) : AppColors.bgDivider,
        ),
      ),
      primaryYAxis: NumericAxis(
        labelStyle: TextStyle(
          color: isDarkMode ? AppColors.textSecondary : Colors.black,
        ),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(width: 0),
        majorGridLines: MajorGridLines(
          width: 1,
          color: isDarkMode ? const Color(0xFF374151) : AppColors.bgDivider,
          dashArray: const [5, 5],
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
              const Color(0xFF6366F1).withValues(alpha: 0.3),
              const Color(0xFF6366F1).withValues(alpha: 0.1),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderWidth: 3,
          borderColor: const Color(0xFF6366F1),
          name: 'Views',
        ),
      ],
    );
  }
}
