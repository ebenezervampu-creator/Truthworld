import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/advertiser/data/models/advertiser_chart_data.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/widgets/advertiser_campaign_card.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dashboard tab view presenting high-level performance metrics, interactive charts, and recent campaigns.
class AdvertiserDashboardTabView extends StatelessWidget {
  const AdvertiserDashboardTabView({
    required this.controller,
    super.key,
  });

  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroPanel(context, colorScheme),
          const SizedBox(height: 24),
          const Text(
            'Performance Overview',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildOverviewGrid(context, controller),
          const SizedBox(height: 24),
          _buildAnalyticsChartSection(context, controller),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Recent Campaigns',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  controller.selectedIndex.value = 1;
                },
                icon: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 16,
                ),
                label: const Text(
                  'View All',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.brand,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRecentCampaignsSummary(context, controller),
        ],
      ),
    );
  }

  Widget _buildHeroPanel(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF311042)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF27272A),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.brand.withValues(alpha: 0.3),
              ),
            ),
            child: const Text(
              'TRUTHWORLD FOR BUSINESS',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.brand,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Reach Millions of Engaged Viewers',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create skippable video ads, homepage banners, and recommendations targeting active communities on Truthworld.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewGrid(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
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

      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 800
              ? 4
              : (constraints.maxWidth > 480 ? 2 : 1);
          final textScale = MediaQuery.textScalerOf(context).scale(1.0);
          final childAspectRatio = constraints.maxWidth > 800
              ? (textScale > 1.15 ? 1.4 : 1.6)
              : (constraints.maxWidth > 480
                  ? (textScale > 1.15 ? 1.3 : 1.5)
                  : (textScale > 1.15 ? 2.4 : 2.8));
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
            children: [
              _buildInteractiveStatCard(
                controller,
                'Total Spend',
                formatNumber(totalSpend, isCurrency: true),
                Icons.payments_rounded,
                'spend',
              ),
              _buildInteractiveStatCard(
                controller,
                'Impressions',
                formatNumber(totalImpressions),
                Icons.visibility_rounded,
                'impressions',
              ),
              _buildInteractiveStatCard(
                controller,
                'Ad Clicks',
                formatNumber(totalClicks),
                Icons.touch_app_rounded,
                'clicks',
              ),
              _buildInteractiveStatCard(
                controller,
                'Avg. CTR',
                formatNumber(avgCtr, isPercentage: true),
                Icons.trending_up_rounded,
                'ctr',
              ),
            ],
          );
        },
      );
    });
  }

  Widget _buildInteractiveStatCard(
    AdvertiserPortalController controller,
    String label,
    String value,
    IconData icon,
    String metric,
  ) {
    final isSelected = controller.selectedMetric.value == metric;
    return GestureDetector(
      onTap: () {
        controller.selectedMetric.value = metric;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand.withValues(alpha: 0.12)
              : const Color(0xFF161618),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.brand : const Color(0xFF27272A),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Icon(icon, color: Colors.white, size: 20),
              ],
            ),
            Text(
              value,
              style: const TextStyle(
                fontFamily: TWTypography.brandFamily,
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsChartSection(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
    return Obx(() {
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

  Widget _buildRecentCampaignsSummary(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
    return Obx(() {
      final campaigns = AdService.to.customCampaigns
          .where((ad) => ad.userId == AuthService.to.uid)
          .toList();

      if (campaigns.isEmpty) {
        return _buildEmptyCampaignsContainer();
      }

      final recent = campaigns.take(3).toList();
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recent.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => AdvertiserCampaignCard(
          controller: controller,
          campaign: recent[index],
        ),
      );
    });
  }

  Widget _buildEmptyCampaignsContainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.campaign_outlined,
            color: Colors.white,
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            'No Campaigns Launched Yet',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Click "Create Campaign" above to launch your first self-serve ad.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
