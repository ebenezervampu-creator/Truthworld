import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/models/advertiser_chart_data.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Reports tab for Truthworld Advertiser Studio.
class AdvertiserReportsTab extends StatelessWidget {
  const AdvertiserReportsTab({
    required this.controller,
    this.analyticsChart,
    super.key,
  });

  final AdvertiserPortalController controller;
  final Widget? analyticsChart;

  @override
  Widget build(BuildContext context) {
    return _buildReportsTab(context, controller);
  }

  Widget _buildReportsTab(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Performance Reports',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Analyze click-through rates, format performance, and download detailed metrics.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          analyticsChart ?? _buildAnalyticsChartSection(context, controller),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Performance Breakdown by Format',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _simulateExportReport,
                icon: const Icon(
                  Icons.download_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  'Export CSV',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF27272A)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFormatPerformanceTable(context),
        ],
      ),
    );
  }

  void _simulateExportReport() {
    final myCampaigns = AdService.to.customCampaigns
        .where((ad) => ad.userId == AuthService.to.uid)
        .toList();

    final buffer = StringBuffer();
    buffer.writeln(
      'Ad Campaign,Ad Format,Budget,Spent,Impressions,Clicks,CTR,Status',
    );

    for (final ad in myCampaigns) {
      final rawType = ad.adType;
      var typeLabel = 'Homepage Ad';
      if (rawType == 'skippable') typeLabel = 'Skippable Video';
      if (rawType == 'scroll' || rawType == 'search') typeLabel = 'Scroll Feed';
      if (rawType == 'comment') typeLabel = 'Comment Box';
      if (rawType == 'video_sponsor') typeLabel = 'Video Sponsor';

      final budget = ad.budgetAmount ?? 2000.0;
      final imps = ad.impressions;
      final clicks = ad.clicks;
      final calculatedSpend = (imps * 0.15) + (clicks * 2.0);
      final actualSpend = calculatedSpend > budget ? budget : calculatedSpend;
      final ctr = imps > 0 ? (clicks / imps) * 100 : 0.0;

      buffer.writeln(
        '"${ad.title.replaceAll('"', '""')}",'
        '$typeLabel,'
        '₹${budget.toStringAsFixed(0)},'
        '₹${actualSpend.toStringAsFixed(2)},'
        '$imps,'
        '$clicks,'
        '${ctr.toStringAsFixed(2)}%,'
        '${ad.status}',
      );
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    AppSnackbar.show(
      'Export Successful',
      'Real-time CSV Report copied to clipboard successfully.',
      backgroundColor: AppColors.success,
      colorText: AppColors.textPrimary,
    );
  }

  Widget _buildFormatPerformanceTable(BuildContext context) {
    return Obx(() {
      final myCampaigns = AdService.to.customCampaigns
          .where((ad) => ad.userId == AuthService.to.uid)
          .toList();

      final spentMap = <String, double>{};
      final impMap = <String, int>{};
      final clickMap = <String, int>{};

      for (final ad in myCampaigns) {
        final rawType = ad.adType;
        var typeLabel = 'Homepage Ad';
        if (rawType == 'skippable') typeLabel = 'Skippable Video';
        if (rawType == 'scroll' || rawType == 'search') typeLabel = 'Scroll Feed';
        if (rawType == 'comment') typeLabel = 'Comment Box';
        if (rawType == 'video_sponsor') typeLabel = 'Video Sponsor';

        final imps = ad.impressions;
        final clicks = ad.clicks;
        final calculatedSpend = (imps * 0.15) + (clicks * 2.0);
        final budget = ad.budgetAmount ?? 2000.0;
        final actualSpend = calculatedSpend > budget ? budget : calculatedSpend;

        spentMap[typeLabel] = (spentMap[typeLabel] ?? 0.0) + actualSpend;
        impMap[typeLabel] = (impMap[typeLabel] ?? 0) + imps;
        clickMap[typeLabel] = (clickMap[typeLabel] ?? 0) + clicks;
      }

      final formatsList = [
        'Skippable Video',
        'Homepage Ad',
        'Scroll Feed',
        'Comment Box',
      ];

      String formatNumber(
        num val, {
        bool isCurrency = false,
        bool isPercentage = false,
      }) {
        if (isPercentage) {
          return '${val.toStringAsFixed(2)}%';
        }
        final intVal = val.toInt();
        final str = intVal.toString();
        final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
        final formatted = str.replaceAllMapped(
          reg,
          (m) => '${m[1]},',
        );
        return isCurrency ? '₹$formatted' : formatted;
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 650),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1.2),
                4: FlexColumnWidth(1.2),
                5: FlexColumnWidth(1.2),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F1F23),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  children: [
                    _buildTableHeader('Ad Format'),
                    _buildTableHeader('Spent'),
                    _buildTableHeader('Impressions'),
                    _buildTableHeader('Clicks'),
                    _buildTableHeader('CTR'),
                    _buildTableHeader('Conversions'),
                  ],
                ),
                for (final fmt in formatsList)
                  () {
                    final spent = spentMap[fmt] ?? 0.0;
                    final imps = impMap[fmt] ?? 0;
                    final clicks = clickMap[fmt] ?? 0;
                    final ctr = imps > 0 ? (clicks / imps) * 100 : 0.0;
                    final conv = (clicks * 0.03).round();

                    return TableRow(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF27272A)),
                        ),
                      ),
                      children: [
                        _buildTableCell(fmt, isBold: true),
                        _buildTableCell(formatNumber(spent, isCurrency: true)),
                        _buildTableCell(formatNumber(imps)),
                        _buildTableCell(formatNumber(clicks)),
                        _buildTableCell(formatNumber(ctr, isPercentage: true)),
                        _buildTableCell(formatNumber(conv)),
                      ],
                    );
                  }(),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: TWTypography.uiFamily,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: isBold ? Colors.white : AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildAnalyticsChartSection(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
    var metricTitle = 'Spend Trend';
    var metricColor = AppColors.brand;
    if (controller.selectedMetric.value == 'impressions') {
      metricTitle = 'Impressions Trend';
      metricColor = const Color(0xFF38BDF8);
    }
    if (controller.selectedMetric.value == 'clicks') {
      metricTitle = 'Clicks Trend';
      metricColor = const Color(0xFFF59E0B);
    }
    if (controller.selectedMetric.value == 'ctr') {
      metricTitle = 'Click-Through Rate (CTR) Trend';
      metricColor = const Color(0xFFEC4899);
    }

    return Obx(() {
      final myCampaigns = AdService.to.customCampaigns
          .where((ad) => ad.userId == AuthService.to.uid)
          .toList();

      var totalSpend = 0.0;
      var totalImpressions = 0;
      var totalClicks = 0;

      for (final ad in myCampaigns) {
        totalImpressions += ad.impressions;
        totalClicks += ad.clicks;
        final calculatedSpend = (ad.impressions * 0.15) + (ad.clicks * 2.0);
        final budget = ad.budgetAmount ?? 2000.0;
        totalSpend += calculatedSpend > budget ? budget : calculatedSpend;
      }

      final avgCtr = totalImpressions > 0
          ? (totalClicks / totalImpressions) * 100
          : 0.0;

      var selectedMetricTotal = 0.0;
      if (controller.selectedMetric.value == 'spend') {
        selectedMetricTotal = totalSpend;
      } else if (controller.selectedMetric.value == 'impressions') {
        selectedMetricTotal = totalImpressions.toDouble();
      } else if (controller.selectedMetric.value == 'clicks') {
        selectedMetricTotal = totalClicks.toDouble();
      } else if (controller.selectedMetric.value == 'ctr') {
        selectedMetricTotal = avgCtr;
      }

      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final weights = [0.08, 0.12, 0.10, 0.15, 0.13, 0.22, 0.20];
      final chartData = List<ChartData>.generate(7, (i) {
        return ChartData(days[i], selectedMetricTotal * weights[i]);
      });

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$metricTitle (Last 7 Days)',
              style: const TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              width: double.infinity,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  labelStyle: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                  ),
                ),
                primaryYAxis: const NumericAxis(
                  axisLine: AxisLine(width: 0),
                  majorTickLines: MajorTickLines(size: 0),
                  majorGridLines: MajorGridLines(color: Color(0xFF27272A)),
                  labelStyle: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                  ),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<ChartData, String>>[
                  AreaSeries<ChartData, String>(
                    dataSource: chartData,
                    xValueMapper: (data, _) => data.x,
                    yValueMapper: (data, _) => data.y,
                    name: metricTitle,
                    color: metricColor.withValues(alpha: 0.25),
                    borderColor: metricColor,
                    gradient: LinearGradient(
                      colors: [
                        metricColor.withValues(alpha: 0.35),
                        metricColor.withValues(alpha: 0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Backward compatibility alias
typedef AdvertiserReportsTabView = AdvertiserReportsTab;
