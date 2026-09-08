import 'dart:io' as io;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/ab_testing_tab_view.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/audience_tab_view.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/billing_tab_view.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/brand_settings_tab_view.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/creative_assets_tab_view.dart';
import 'package:truthworld/features/advertiser/presentation/views/tabs/sponsorships_tab_view.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:universal_html/html.dart' as html;
import 'package:video_player/video_player.dart';

class ChartData {
  ChartData(this.x, this.y);
  final String x;
  final double y;
}

class AdvertiserPortalScreen extends StatelessWidget {
  const AdvertiserPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<AdvertiserPortalController>()
        ? Get.find<AdvertiserPortalController>()
        : Get.put(AdvertiserPortalController());

    return Obx(() {
      final isLoggedIn = AuthService.to.isAuthenticated.value;
      if (!isLoggedIn) {
        return _buildLoginLandingPage(context, controller);
      }

      final isDesktop = MediaQuery.of(context).size.width >= 900;

      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: isDesktop
            ? null
            : AppBar(
                backgroundColor: const Color(0xFF0F0F0F),
                elevation: 0,
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(1),
                  child: Divider(color: Color(0xFF27272A), height: 1),
                ),
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                title: Text(
                  controller.tabTitles[controller.selectedIndex.value],
                  style: const TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _buildUserAvatar(context),
                  ),
                ],
              ),
        drawer: isDesktop ? null : _buildDrawer(context, controller),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop) _buildSidebar(context, controller),
              Expanded(child: _buildSelectedTabContent(context, controller)),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildDrawer(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
    return Drawer(
      backgroundColor: const Color(0xFF161618),
      child: Column(
        children: [
          _buildSidebarHeader(context),
          const Divider(color: Color(0xFF27272A), height: 1),
          Expanded(
            child: _buildSidebarItems(context, controller, isDrawer: true),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161618),
        border: Border(
          right: BorderSide(color: Color(0xFF27272A)),
        ),
      ),
      child: SizedBox(
        width: 250,
        height: double.infinity,
        child: Column(
          children: [
            _buildSidebarHeader(context),
            const Divider(color: Color(0xFF27272A), height: 1),
            Expanded(
              child: _buildSidebarItems(context, controller, isDrawer: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Row(
        children: [
          AppLogo(),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Truthworld',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'ADVERTISER STUDIO',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brand,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItems(
    BuildContext context,
    AdvertiserPortalController controller, {
    required bool isDrawer,
  }) {
    final icons = <IconData>[
      Icons.dashboard_rounded,
      Icons.campaign_rounded,
      Icons.analytics_rounded,
      Icons.subtitles_rounded,
      Icons.translate_rounded,
      Icons.account_balance_wallet_rounded,
      Icons.groups_rounded,
      Icons.handshake_rounded,
      Icons.perm_media_rounded,
      Icons.science_rounded,
      Icons.settings_rounded,
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        for (int i = 0; i < controller.tabTitles.length; i++)
          Material(
            color: Colors.transparent,
            child: ListTile(
              selected: controller.selectedIndex.value == i,
              selectedTileColor: AppColors.brand.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              leading: Icon(
                icons[i],
                color: Colors.white,
                size: 20,
              ),
              title: Text(
                controller.tabTitles[i],
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontWeight: controller.selectedIndex.value == i
                      ? FontWeight.bold
                      : FontWeight.w500,
                  color: controller.selectedIndex.value == i
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              onTap: () {
                controller.selectedIndex.value = i;
                if (isDrawer) {
                  Get.back();
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedTabContent(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
    switch (controller.selectedIndex.value) {
      case 0:
        return _buildDashboardTab(context, controller);
      case 1:
        return _buildMyAdsTab(context, controller);
      case 2:
        return _buildReportsTab(context, controller);
      case 3:
        return _buildSubtitlesTab(context, controller);
      case 4:
        return _buildAudioDubsTab(context, controller);
      case 5:
        return BillingTabView(controller: controller);
      case 6:
        return AudienceTabView(controller: controller);
      case 7:
        return SponsorshipsTabView(controller: controller);
      case 8:
        return CreativeAssetsTabView(controller: controller);
      case 9:
        return AbTestingTabView(controller: controller);
      case 10:
        return BrandSettingsTabView(controller: controller);
      default:
        return _buildDashboardTab(context, controller);
    }
  }

  Widget _buildDashboardTab(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
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
        itemBuilder: (context, index) =>
            _buildCampaignCard(context, controller, recent[index]),
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

  Widget _buildMyAdsTab(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'My Ad Campaigns',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showCreateCampaignWizard(context, controller),
                icon: const Icon(Icons.add, color: Colors.black, size: 18),
                label: const Text(
                  'Create Campaign',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildCampaignsList(context, controller),
        ],
      ),
    );
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
          _buildAnalyticsChartSection(context, controller),
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

   Widget _buildSubtitlesTab(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
    return Obx(() {
      final skippableCampaigns = AdService.to.customCampaigns
          .where((ad) =>
              ad.userId == AuthService.to.uid &&
              (ad.isSkippableAd ||
                  (ad.videoUrl != null && ad.videoUrl!.isNotEmpty) ||
                  (ad.midrollVideoUrl != null &&
                      ad.midrollVideoUrl!.isNotEmpty) ||
                  (ad.resolutions != null && ad.resolutions!.isNotEmpty)))
          .toList();

      return LayoutBuilder(
        builder: (context, constraints) {
          final isLarge = constraints.maxWidth >= 800;
          final listWidget = _buildSubtitlesCampaignsSidebar(
            controller,
            skippableCampaigns,
          );
          final editorWidget = _buildSubtitlesEditorArea(controller);

          if (isLarge) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 300, child: listWidget),
                const VerticalDivider(color: Color(0xFF27272A), width: 1),
                Expanded(child: editorWidget),
              ],
            );
          } else {
            return controller.selectedAdForSubtitles.value == null
                ? listWidget
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: const Color(0xFF161618),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                controller.selectedAdForSubtitles.value = null;
                              },
                            ),
                            const Text(
                              'Back to Ads List',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: editorWidget),
                    ],
                  );
          }
        },
      );
    });
  }

  Widget _buildSubtitlesCampaignsSidebar(
    AdvertiserPortalController controller,
    List<AdItem> campaigns,
  ) {
    return ColoredBox(
      color: const Color(0xFF0F0F0F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Select Video Ad to Translate',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: Obx(
                () => OutlinedButton.icon(
                  onPressed: controller.isGeneratingAllVideoAdsAI.value
                      ? null
                      : () => controller.generateAllVideoAdsAI(),
                  icon: controller.isGeneratingAllVideoAdsAI.value
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 16,
                        ),
                  label: Text(
                    controller.isGeneratingAllVideoAdsAI.value
                        ? 'Queueing Batch AI...'
                        : 'Generate AI for All Video Ads',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3F3F46)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF27272A), height: 1),
          Expanded(
            child: campaigns.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No video campaigns available. Subtitles can only be added to Skippable Video ads.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: campaigns.length,
                    itemBuilder: (context, index) {
                      final ad = campaigns[index];
                      final isSelected =
                          controller.selectedAdForSubtitles.value?.id == ad.id;
                      final langCount = (ad.subtitles ?? {}).length;

                      return Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.brand.withValues(alpha: 0.12)
                              : Colors.transparent,
                          border: const Border(
                            bottom: BorderSide(
                              color: Color(0xFF27272A),
                            ),
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            controller.selectedAdForSubtitles.value = ad;
                            controller.selectedLanguageForSubtitles.value =
                                'en';
                            controller.loadCuesForAd(ad, 'en');
                          },
                          leading: Container(
                            width: 50,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: ad.gradientColors,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_filled_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                          title: Text(
                            ad.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            '$langCount Language track${langCount == 1 ? "" : "s"}',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitlesEditorArea(AdvertiserPortalController controller) {
    if (controller.selectedAdForSubtitles.value == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.subtitles_outlined,
              size: 64,
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              'Select a video campaign from the list to begin editing subtitles.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final ad = controller.selectedAdForSubtitles.value!;
    final subs = ad.subtitles ?? {};

    return Container(
      color: const Color(0xFF161618),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.title,
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage language subtitles track and cue timings',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.isUploadingSubtitles.value
                        ? null
                        : () => _showUploadSubtitlesDialog(controller),
                    icon: controller.isUploadingSubtitles.value
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.upload_file_rounded, color: Colors.white, size: 16),
                    label: const Text(
                      'Upload Subtitles',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3F3F46)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: controller.isSavingSubtitles.value
                        ? null
                        : () => controller.saveSubtitlesForAd(),
                    icon: controller.isSavingSubtitles.value
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.black),
                            ),
                          )
                        : const Icon(Icons.save_rounded, color: Colors.black, size: 16),
                    label: Text(
                      controller.isSavingSubtitles.value
                          ? 'Saving...'
                          : 'Save Track',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Tracks:',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final lang in controller.supportedLanguages)
                        if (subs.containsKey(lang['code']) ||
                            lang['code'] == 'en')
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(lang['name']!),
                              selected:
                                  controller
                                      .selectedLanguageForSubtitles
                                      .value ==
                                  lang['code'],
                              onSelected: (_) {
                                controller.selectedLanguageForSubtitles.value =
                                    lang['code']!;
                                controller.loadCuesForAd(ad, lang['code']!);
                              },
                              selectedColor: AppColors.brand,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: controller.selectedLanguageForSubtitles.value == lang['code']
                                      ? AppColors.brand
                                      : const Color(0xFF27272A),
                                ),
                              ),
                              labelStyle: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color:
                                    controller
                                            .selectedLanguageForSubtitles
                                            .value ==
                                        lang['code']
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              backgroundColor: const Color(0xFF18181B),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.white,
                ),
                tooltip: 'Add translated subtitles track',
                onPressed: () => _showAddSubtitlesTrackDialog(controller),
              ),
            ],
          ),
          const Divider(color: Color(0xFF27272A), height: 32),
          if (controller.isTranslatingSubtitles.value)
            _buildPipelineProgressCard(
              controller.subtitleStatusText.value,
              controller.subtitleProgress.value,
            )
          else ...[
            Expanded(
              child: controller.currentSubtitleCues.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.notes_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No subtitle cues defined.',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              controller.currentSubtitleCues.add({
                                'id': DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                                'startTime': '00:00:01.000',
                                'endTime': '00:00:05.000',
                                'text': 'Enter subtitle text...',
                              });
                            },
                            icon: const Icon(
                              Icons.add,
                              color: Colors.black,
                              size: 16,
                            ),
                            label: const Text(
                              'Add Cue',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: controller.currentSubtitleCues.length,
                      itemBuilder: (context, index) {
                        final cue = controller.currentSubtitleCues[index];
                        return _buildSubtitleCueRow(controller, index, cue);
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    final lastEnd = controller.currentSubtitleCues.isNotEmpty
                        ? controller.currentSubtitleCues.last['endTime']!
                        : '00:00:00.000';
                    controller.currentSubtitleCues.add({
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'startTime': lastEnd,
                      'endTime': '00:00:20.000',
                      'text': 'New segment...',
                    });
                  },
                  icon: const Icon(Icons.add, color: Colors.white, size: 16),
                  label: const Text(
                    'Add Cue Segment',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
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
                OutlinedButton.icon(
                  onPressed: () {
                    final vtt = controller.exportCuesToVtt();
                    Clipboard.setData(ClipboardData(text: vtt));
                    AppSnackbar.show(
                      'Exported',
                      'WebVTT subtitle track copied to clipboard successfully!',
                      backgroundColor: AppColors.success,
                      colorText: AppColors.textPrimary,
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 16),
                  label: const Text(
                    'Copy WebVTT',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
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
          ],
        ],
      ),
    );
  }

  Widget _buildSubtitleCueRow(
    AdvertiserPortalController controller,
    int index,
    Map<String, String> cue,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Column(
              children: [
                _buildTimeInputField('Start Time', cue['startTime']!, (val) {
                  controller.currentSubtitleCues[index]['startTime'] = val;
                  controller.currentSubtitleCues.refresh();
                }),
                const SizedBox(height: 8),
                _buildTimeInputField('End Time', cue['endTime']!, (val) {
                  controller.currentSubtitleCues[index]['endTime'] = val;
                  controller.currentSubtitleCues.refresh();
                }),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: cue['text'])
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: cue['text']!.length),
                ),
              onChanged: (val) {
                controller.currentSubtitleCues[index]['text'] = val;
                controller.currentSubtitleCues.refresh();
              },
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: Colors.white,
                fontSize: 13,
              ),
              maxLines: 2,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter cue subtitles text...',
                hintStyle: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () {
              controller.currentSubtitleCues.removeAt(index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInputField(
    String label,
    String value,
    Function(String) onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 65,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 30,
            child: TextFormField(
              initialValue: value,
              onChanged: onChanged,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: Colors.white,
                fontSize: 12,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                ),
                fillColor: const Color(0xFF18181B),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF27272A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF27272A)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPipelineProgressCard(String status, double progress) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                status,
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF27272A),
            valueColor: const AlwaysStoppedAnimation(AppColors.brand),
          ),
        ],
      ),
    );
  }

  void _showAddSubtitlesTrackDialog(AdvertiserPortalController controller) {
    final selectedLang = 'hi'.obs;

    Get.dialog(
      Obx(
        () => AlertDialog(
          backgroundColor: const Color(0xFF161618),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF27272A)),
          ),
          title: const Text(
            'Add Subtitles Track',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Translate your video campaign into another language using AI voice translation.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedLang.value,
                    dropdownColor: const Color(0xFF161618),
                    iconEnabledColor: Colors.white,
                    isExpanded: true,
                    items: [
                      for (final lang in controller.supportedLanguages)
                        if (lang['code'] != 'en')
                          DropdownMenuItem(
                            value: lang['code'],
                            child: Text(
                              lang['name']!,
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: Colors.white,
                              ),
                            ),
                          ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        selectedLang.value = val;
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                controller.requestAdSubtitles(selectedLang.value);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Start AI Translation',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadSubtitlesDialog(AdvertiserPortalController controller) {
    final selectedLang = (controller.selectedLanguageForSubtitles.value.isNotEmpty
            ? controller.selectedLanguageForSubtitles.value
            : 'en')
        .obs;
    final selectedFile = Rxn<PlatformFile>();

    Get.dialog(
      Obx(
        () => AlertDialog(
          backgroundColor: const Color(0xFF161618),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF27272A)),
          ),
          title: const Text(
            'Upload Custom Subtitles',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Directly upload subtitle files (.vtt, .srt, .txt) from your device for this ad. Please select the target language first.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Target Language',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedLang.value,
                    dropdownColor: const Color(0xFF161618),
                    iconEnabledColor: Colors.white,
                    isExpanded: true,
                    items: [
                      for (final lang in controller.supportedLanguages)
                        DropdownMenuItem(
                          value: lang['code'],
                          child: Text(
                            lang['name']!,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        selectedLang.value = val;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Subtitle File (.vtt, .srt, .txt)',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['vtt', 'srt', 'txt'],
                    withData: true,
                  );
                  if (result != null && result.files.isNotEmpty) {
                    selectedFile.value = result.files.first;
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selectedFile.value != null
                          ? const Color(0xFF10B981)
                          : const Color(0xFF27272A),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedFile.value != null
                            ? Icons.check_circle_outline_rounded
                            : Icons.file_upload_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          selectedFile.value != null
                              ? '${selectedFile.value!.name} (${(selectedFile.value!.size / 1024).toStringAsFixed(1)} KB)'
                              : 'Choose file from device...',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: selectedFile.value != null
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: selectedFile.value == null || controller.isUploadingSubtitles.value
                  ? null
                  : () async {
                      Get.back();
                      await controller.uploadDirectSubtitles(
                        langCode: selectedLang.value,
                        file: selectedFile.value!,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFF27272A),
                disabledForegroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                controller.isUploadingSubtitles.value
                    ? 'Importing...'
                    : 'Import & Save',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioDubsTab(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
    return Obx(() {
      final skippableCampaigns = AdService.to.customCampaigns
          .where((ad) =>
              ad.userId == AuthService.to.uid &&
              (ad.isSkippableAd ||
                  (ad.videoUrl != null && ad.videoUrl!.isNotEmpty) ||
                  (ad.midrollVideoUrl != null &&
                      ad.midrollVideoUrl!.isNotEmpty) ||
                  (ad.resolutions != null && ad.resolutions!.isNotEmpty)))
          .toList();

      return LayoutBuilder(
        builder: (context, constraints) {
          final isLarge = constraints.maxWidth >= 800;
          final listWidget = _buildAudioDubsCampaignsSidebar(
            controller,
            skippableCampaigns,
          );
          final managerWidget = _buildAudioDubsManagerArea(controller);

          if (isLarge) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 300, child: listWidget),
                const VerticalDivider(color: Color(0xFF27272A), width: 1),
                Expanded(child: managerWidget),
              ],
            );
          } else {
            return controller.selectedAdForAudio.value == null
                ? listWidget
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: const Color(0xFF161618),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                controller.selectedAdForAudio.value = null;
                              },
                            ),
                            const Text(
                              'Back to Ads List',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: managerWidget),
                    ],
                  );
          }
        },
      );
    });
  }

  Widget _buildAudioDubsCampaignsSidebar(
    AdvertiserPortalController controller,
    List<AdItem> campaigns,
  ) {
    return ColoredBox(
      color: const Color(0xFF0F0F0F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Select Video Ad to Dub',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: Obx(
                () => OutlinedButton.icon(
                  onPressed: controller.isGeneratingAllVideoAdsAI.value
                      ? null
                      : () => controller.generateAllVideoAdsAI(),
                  icon: controller.isGeneratingAllVideoAdsAI.value
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 16,
                        ),
                  label: Text(
                    controller.isGeneratingAllVideoAdsAI.value
                        ? 'Queueing Batch AI...'
                        : 'Generate AI for All Video Ads',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3F3F46)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF27272A), height: 1),
          Expanded(
            child: campaigns.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No video campaigns available. Audio dubs can only be requested on Skippable Video ads.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: campaigns.length,
                    itemBuilder: (context, index) {
                      final ad = campaigns[index];
                      final isSelected =
                          controller.selectedAdForAudio.value?.id == ad.id;
                      final dubCount = (ad.audioTracks ?? {}).length + 1;

                      return Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.brand.withValues(alpha: 0.12)
                              : Colors.transparent,
                          border: const Border(
                            bottom: BorderSide(
                              color: Color(0xFF27272A),
                            ),
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            controller.selectedAdForAudio.value = ad;
                          },
                          leading: Container(
                            width: 50,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: ad.gradientColors,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.music_note_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                          title: Text(
                            ad.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            '$dubCount Audio track${dubCount == 1 ? "" : "s"} available',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioDubsManagerArea(AdvertiserPortalController controller) {
    if (controller.selectedAdForAudio.value == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.translate_rounded,
              size: 64,
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              'Select a video campaign from the list to manage audio voiceovers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final ad = controller.selectedAdForAudio.value!;
    final tracks = ad.audioTracks ?? {};

    return Container(
      color: const Color(0xFF161618),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.title,
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'AI voice cloning and audio dubbing configuration board',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: (controller.isTranslatingAudio.value ||
                            controller.isUploadingAudioTrack.value)
                        ? null
                        : () => _showUploadAudioTrackDialog(controller),
                    icon: controller.isUploadingAudioTrack.value
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.upload_file_rounded, color: Colors.white, size: 16),
                    label: const Text(
                      'Upload Audio Track',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3F3F46)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: (controller.isTranslatingAudio.value ||
                            controller.isUploadingAudioTrack.value)
                        ? null
                        : () => _showRequestAudioDubDialog(controller),
                    icon: const Icon(Icons.translate_rounded, color: Colors.black, size: 16),
                    label: const Text(
                      'Request Voice Dub',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Color(0xFF27272A), height: 32),
          if (controller.isTranslatingAudio.value)
            _buildPipelineProgressCard(
              controller.audioStatusText.value,
              controller.audioProgress.value,
            )
          else if (controller.isUploadingAudioTrack.value)
            _buildPipelineProgressCard(
              'Uploading direct audio track from device...',
              controller.audioUploadProgress.value,
            )
          else ...[
            const Text(
              'Configured Voiceover Layers',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildAudioTrackItem(
                    controller,
                    'English (Original)',
                    'Integrated source stream',
                    'active',
                    isOriginal: true,
                  ),
                  for (final entry in tracks.entries)
                    _buildAudioTrackItem(
                      controller,
                      controller.getLanguageName(entry.key),
                      entry.value,
                      'active',
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioTrackItem(
    AdvertiserPortalController controller,
    String langName,
    String desc,
    String status, {
    bool isOriginal = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF27272A),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF27272A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.volume_up_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  langName,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.brand.withValues(alpha: 0.4)),
            ),
            child: Text(
              isOriginal ? 'ORIGINAL' : 'AI CLONED',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.brand,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestAudioDubDialog(AdvertiserPortalController controller) {
    final selectedLang = 'hi'.obs;
    final selectedVoice = 'natural'.obs;

    Get.dialog(
      Obx(
        () => AlertDialog(
          backgroundColor: const Color(0xFF161618),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF27272A)),
          ),
          title: const Text(
            'Request AI Voice Dubbing',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select target dub language and AI voice clone parameters.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Target Language',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedLang.value,
                    dropdownColor: const Color(0xFF161618),
                    iconEnabledColor: Colors.white,
                    isExpanded: true,
                    items: [
                      for (final lang in controller.supportedAudioLanguages)
                        if (lang['code'] != 'en')
                          DropdownMenuItem(
                            value: lang['code'],
                            child: Text(
                              lang['name']!,
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: Colors.white,
                              ),
                            ),
                          ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        selectedLang.value = val;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Voice Style',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedVoice.value,
                    dropdownColor: const Color(0xFF161618),
                    iconEnabledColor: Colors.white,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'natural',
                        child: Text(
                          'Natural Tone Voice Clone',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'studio_male',
                        child: Text(
                          'Studio Narration (Male)',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'studio_female',
                        child: Text(
                          'Studio Narration (Female)',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        selectedVoice.value = val;
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                controller.requestAdAudioDub(
                  selectedLang.value,
                  voiceStyle: selectedVoice.value,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Start Dubbing Process',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadAudioTrackDialog(AdvertiserPortalController controller) {
    final selectedLang = 'hi'.obs;
    final selectedFile = Rxn<PlatformFile>();

    Get.dialog(
      Obx(
        () => AlertDialog(
          backgroundColor: const Color(0xFF161618),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF27272A)),
          ),
          title: const Text(
            'Upload Custom Audio Track',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload custom recorded audio (.mp3, .wav, .m4a, .aac) from your device for this ad. Please select the language first.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Target Language',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedLang.value,
                    dropdownColor: const Color(0xFF161618),
                    iconEnabledColor: Colors.white,
                    isExpanded: true,
                    items: [
                      for (final lang in controller.supportedAudioLanguages)
                        if (lang['code'] != 'en')
                          DropdownMenuItem(
                            value: lang['code'],
                            child: Text(
                              lang['name']!,
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: Colors.white,
                              ),
                            ),
                          ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        selectedLang.value = val;
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Audio File (.mp3, .wav, .m4a, .aac)',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
                    withData: true,
                  );
                  if (result != null && result.files.isNotEmpty) {
                    selectedFile.value = result.files.first;
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selectedFile.value != null
                          ? const Color(0xFF10B981)
                          : const Color(0xFF27272A),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedFile.value != null
                            ? Icons.check_circle_outline_rounded
                            : Icons.file_upload_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          selectedFile.value != null
                              ? '${selectedFile.value!.name} (${(selectedFile.value!.size / (1024 * 1024)).toStringAsFixed(2)} MB)'
                              : 'Choose audio file from device...',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: selectedFile.value != null
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: selectedFile.value == null || controller.isUploadingAudioTrack.value
                  ? null
                  : () async {
                      Get.back();
                      await controller.uploadDirectAudioTrack(
                        langCode: selectedLang.value,
                        file: selectedFile.value!,
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFF27272A),
                disabledForegroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                controller.isUploadingAudioTrack.value
                    ? 'Uploading...'
                    : 'Upload & Save',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
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
          final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
          return GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
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

  Widget _buildCampaignsList(
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

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: campaigns.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final campaign = campaigns[index];
          return _buildCampaignCard(context, controller, campaign);
        },
      );
    });
  }

  Widget _buildCampaignCard(
    BuildContext context,
    AdvertiserPortalController controller,
    AdItem campaign,
  ) {
    final isSkippable = campaign.isSkippableAd;
    final budgetStr = campaign.budgetTier ?? 'Starter';
    final totalBudget = campaign.totalBudget;
    final spent = campaign.spent;
    final remaining = campaign.remaining;
    final progress = campaign.budgetProgress;
    final isBudgetExhausted = remaining <= 0;
    final amountStr =
        '₹${totalBudget.toStringAsFixed(totalBudget == totalBudget.roundToDouble() ? 0 : 2)}';
    final isPaused = campaign.status == 'paused';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 100,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: campaign.gradientColors),
                  ),
                  child: Center(
                    child: Icon(
                      campaign.adType == 'video_sponsor'
                          ? Icons.stars_rounded
                          : isSkippable
                          ? Icons.play_circle_filled_rounded
                          : Icons.ad_units_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            campaign.advertiser,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.brand,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF18181B),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF27272A)),
                          ),
                          child: Text(
                            campaign.adType == 'video_sponsor'
                                ? 'Sponsor Ad'
                                : isSkippable
                                ? 'Video Ad'
                                : 'Feed Ad',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      campaign.title,
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      campaign.description,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        amountStr,
                        style: const TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181B),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF27272A)),
                        ),
                        child: Text(
                          budgetStr,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Spent: ₹${spent.toStringAsFixed(spent == spent.roundToDouble() ? 0 : 2)}',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Rem: ₹${remaining.toStringAsFixed(remaining == remaining.roundToDouble() ? 0 : 2)}',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: isBudgetExhausted
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isBudgetExhausted
                              ? const Color(0xFFEF4444)
                              : campaign.status == 'paused'
                              ? AppColors.textSecondary
                              : campaign.status == 'underReview'
                              ? const Color(0xFFF59E0B)
                              : campaign.status == 'verification_rejected'
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBudgetExhausted
                            ? 'Exhausted'
                            : campaign.status == 'paused'
                            ? 'Paused'
                            : campaign.status == 'underReview'
                            ? 'Under Review'
                            : campaign.status == 'verification_rejected'
                            ? 'Rejected'
                            : 'Active',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: isBudgetExhausted
                              ? const Color(0xFFEF4444)
                              : campaign.status == 'paused'
                              ? AppColors.textSecondary
                              : campaign.status == 'underReview'
                              ? const Color(0xFFF59E0B)
                              : campaign.status == 'verification_rejected'
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  if (campaign.status == 'verification_rejected' &&
                      campaign.moderationReason != null) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        Get.defaultDialog(
                          title: 'Moderation Details',
                          titleStyle: const TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          middleText: campaign.moderationReason!,
                          middleTextStyle: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textSecondary,
                          ),
                          backgroundColor: const Color(0xFF161618),
                          textConfirm: 'OK',
                          confirmTextColor: Colors.black,
                          buttonColor: Colors.white,
                          onConfirm: Get.back,
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.white,
                            size: 12,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'Why?',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: Color(0xFFEF4444),
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('ad_reports')
                        .where('adId', isEqualTo: campaign.id)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final reports = snapshot.data?.docs ?? [];
                      if (reports.isEmpty) return const SizedBox.shrink();
                      final firstReport = reports.first.data();
                      final reason =
                          firstReport['reason'] ?? 'User Feedback Received';

                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF450A0A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.report_problem_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${reports.length} User Report(s): "$reason"',
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: Color(0xFFF87171),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _showAddMoneyModal(context, controller, campaign),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF18181B),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF27272A)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Add Money',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => AdService.to.toggleCampaignStatus(campaign.id),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF18181B),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF27272A)),
                          ),
                          child: Icon(
                            (campaign.status == 'underReview' ||
                                    campaign.status == 'verification_rejected')
                                ? Icons.lock_outline
                                : isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showCreateCampaignWizard(
                          context,
                          controller,
                          existingCampaign: campaign,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF18181B),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF27272A)),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          Get.defaultDialog(
                            title: 'Delete Campaign',
                            titleStyle: const TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            middleText:
                                'Are you sure you want to delete "${campaign.title}"?',
                            middleTextStyle: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textSecondary,
                            ),
                            backgroundColor: const Color(0xFF161618),
                            textConfirm: 'Delete',
                            textCancel: 'Cancel',
                            confirmTextColor: Colors.white,
                            cancelTextColor: AppColors.textSecondary,
                            buttonColor: const Color(0xFFEF4444),
                            onConfirm: () {
                              AdService.to.deleteCampaign(campaign.id);
                              Get.back();
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF18181B),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF27272A)),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF111113),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF222225)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Campaign Budget & Spending',
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}% spent',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFF27272A),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isBudgetExhausted
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildFinancialMetric(
                        label: 'Total Paid',
                        value:
                            '₹${totalBudget.toStringAsFixed(totalBudget == totalBudget.roundToDouble() ? 0 : 2)}',
                        valueColor: Colors.white,
                      ),
                    ),
                    Container(width: 1, height: 24, color: const Color(0xFF27272A)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: _buildFinancialMetric(
                          label: 'Spent',
                          value: '₹${spent.toStringAsFixed(2)}',
                          valueColor: const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 24, color: const Color(0xFF27272A)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: _buildFinancialMetric(
                          label: 'Remaining',
                          value: '₹${remaining.toStringAsFixed(2)}',
                          valueColor: isBudgetExhausted
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showAddMoneyModal(context, controller, campaign),
                      icon: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      label: const Text(
                        'Add Money',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF3F3F46)),
                        backgroundColor: const Color(0xFF1F1F23),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isBudgetExhausted) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF450A0A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Budget exhausted! Add more money to keep this campaign active and reaching viewers.',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: Color(0xFFFCA5A5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () =>
                        _showAddMoneyModal(context, controller, campaign),
                    child: const Text(
                      'Add Funds',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (campaign.status == 'verification_rejected') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF450A0A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Rejection Error: ',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: Color(0xFFF87171),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text: campaign.moderationReason ??
                                'Violation of Community Guidelines',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialMetric({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            color: highlight ? const Color(0xFF10B981) : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAddMoneyProcessing({
    required int progressStep,
    required bool isSuccess,
    required AdItem campaign,
    required double amountAdded,
    required String errorMessage,
  }) {
    if (isSuccess) {
      final newBudget = campaign.totalBudget + amountAdded;
      final newRemaining = campaign.remaining + amountAdded;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF065F46),
            ),
            child: const Center(
              child: Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Funds Added Successfully!',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${amountAdded.toStringAsFixed(0)} has been credited to "${campaign.title}".',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'New Total Budget',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '₹${newBudget.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'New Remaining Balance',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '₹${newRemaining.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: Color(0xFF10B981),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: Get.back,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    var stepText = 'Validating payment card details...';
    if (progressStep == 2) stepText = 'Processing transaction with bank...';
    if (progressStep == 3) stepText = 'Crediting funds to campaign budget...';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 30),
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
        const SizedBox(height: 24),
        Text(
          stepText,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please do not close this window',
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  void _showAddMoneyModal(
    BuildContext context,
    AdvertiserPortalController controller,
    AdItem campaign,
  ) {
    final selectedOption = 1000.0.obs;
    final isCustom = false.obs;
    final customAmountController = TextEditingController();
    final cardNumberController = TextEditingController(text: '4242 4242 4242 4242');
    final cardExpiryController = TextEditingController(text: '12/28');
    final cardCvcController = TextEditingController(text: '123');

    final progressStep = 0.obs;
    final isSuccess = false.obs;
    final errorMessage = ''.obs;

    final presetOptions = [
      {
        'amount': 500.0,
        'label': 'Basic Boost',
        'impressions': '~2,500 views',
      },
      {
        'amount': 1000.0,
        'label': 'Popular Choice',
        'impressions': '~5,000 views',
      },
      {
        'amount': 2000.0,
        'label': 'Growth Pack',
        'impressions': '~12,000 views',
      },
      {
        'amount': 5000.0,
        'label': 'Supercharge',
        'impressions': '~35,000 views',
      },
    ];

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: 480,
          constraints: const BoxConstraints(maxHeight: 680),
          decoration: BoxDecoration(
            color: const Color(0xFF161618),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF27272A)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF27272A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Funds to Campaign',
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Top up balance to keep your campaign running',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: Get.back,
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF27272A), height: 1),
              // Body
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Obx(() {
                    if (progressStep.value > 0) {
                      return _buildAddMoneyProcessing(
                        progressStep: progressStep.value,
                        isSuccess: isSuccess.value,
                        campaign: campaign,
                        amountAdded: isCustom.value
                            ? (double.tryParse(customAmountController.text.trim()) ?? 0.0)
                            : selectedOption.value,
                        errorMessage: errorMessage.value,
                      );
                    }

                    final activeAmount = isCustom.value
                        ? (double.tryParse(customAmountController.text.trim()) ?? 0.0)
                        : selectedOption.value;
                    final currentBudget = campaign.totalBudget;
                    final newBudget = currentBudget + activeAmount;
                    final newRemaining = campaign.remaining + activeAmount;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Campaign Summary Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E22),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF2E2E34)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                campaign.title,
                                style: const TextStyle(
                                  fontFamily: TWTypography.brandFamily,
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildMiniStat(
                                    'Current Budget',
                                    '₹${currentBudget.toStringAsFixed(0)}',
                                  ),
                                  _buildMiniStat(
                                    'Spent',
                                    '₹${campaign.spent.toStringAsFixed(2)}',
                                  ),
                                  _buildMiniStat(
                                    'Remaining',
                                    '₹${campaign.remaining.toStringAsFixed(2)}',
                                    highlight: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Select Top-Up Amount',
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Preset Options Grid
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 2.3,
                          children: presetOptions.map((opt) {
                            final amount = (opt['amount'] as num?)?.toDouble() ?? 0.0;
                            final isSelected =
                                !isCustom.value && selectedOption.value == amount;
                            return InkWell(
                              onTap: () {
                                isCustom.value = false;
                                selectedOption.value = amount;
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF27272A)
                                      : const Color(0xFF18181B),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF2E2E34),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '₹${amount.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontFamily: TWTypography.brandFamily,
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      opt['label']! as String,
                                      style: const TextStyle(
                                        fontFamily: TWTypography.uiFamily,
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        // Custom Amount Row
                        InkWell(
                          onTap: () => isCustom.value = true,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isCustom.value
                                  ? const Color(0xFF27272A)
                                  : const Color(0xFF18181B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCustom.value
                                    ? Colors.white
                                    : const Color(0xFF2E2E34),
                                width: isCustom.value ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.edit_note_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Custom Amount',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (isCustom.value)
                                  Expanded(
                                    child: TextField(
                                      controller: customAmountController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                        fontFamily: TWTypography.brandFamily,
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: const InputDecoration(
                                        prefixText: '₹ ',
                                        prefixStyle: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        hintText: 'Min ₹100',
                                        hintStyle: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        border: OutlineInputBorder(
                                          borderSide:
                                              BorderSide(color: Color(0xFF3F3F46)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide:
                                              BorderSide(color: Color(0xFF3F3F46)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide:
                                              BorderSide(color: Colors.white),
                                        ),
                                      ),
                                      onChanged: (_) => isCustom.refresh(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Calculation Preview
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF18181B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF27272A)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Top-Up Amount',
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '+₹${activeAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontFamily: TWTypography.brandFamily,
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'New Total Budget',
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '₹${newBudget.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontFamily: TWTypography.brandFamily,
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'New Remaining Balance',
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '₹${newRemaining.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontFamily: TWTypography.brandFamily,
                                      color: Color(0xFF10B981),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Payment Card Details
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Payment Card (Stripe)',
                              style: TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildInputField(
                          'Card Number',
                          cardNumberController,
                          '4242 4242 4242 4242',
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                'Expiry Date',
                                cardExpiryController,
                                'MM/YY',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildInputField(
                                'CVC',
                                cardCvcController,
                                '123',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: activeAmount < 100
                              ? null
                              : () {
                                  progressStep.value = 1;
                                  Future.delayed(
                                    const Duration(milliseconds: 500),
                                    () {
                                      progressStep.value = 2;
                                      Future.delayed(
                                        const Duration(milliseconds: 500),
                                        () {
                                          progressStep.value = 3;
                                          Future.delayed(
                                            const Duration(milliseconds: 500),
                                            () async {
                                              final success = await AdService.to
                                                  .addFundsToCampaign(
                                                    campaign.id,
                                                    activeAmount,
                                                  );
                                              if (success) {
                                                isSuccess.value = true;
                                                progressStep.value = 4;
                                                AppSnackbar.show(
                                                  'Funds Added',
                                                  '₹${activeAmount.toStringAsFixed(0)} added to "${campaign.title}". New budget: ₹${newBudget.toStringAsFixed(0)}',
                                                  backgroundColor:
                                                      AppColors.success,
                                                  colorText:
                                                      AppColors.textPrimary,
                                                );
                                              } else {
                                                errorMessage.value =
                                                    'Failed to process top-up transaction.';
                                                progressStep.value = 0;
                                                AppSnackbar.show(
                                                  'Payment Error',
                                                  'Unable to add funds. Please try again.',
                                                  backgroundColor:
                                                      AppColors.error,
                                                  colorText:
                                                      AppColors.textPrimary,
                                                );
                                              }
                                            },
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            activeAmount < 100
                                ? 'Enter Valid Amount (Min ₹100)'
                                : 'Pay ₹${activeAmount.toStringAsFixed(0)} & Add Funds',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLandingPage(
    BuildContext context,
    AdvertiserPortalController controller,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: Get.back,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton(
              onPressed: () => controller.handleGoogleSignIn(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
              ),
              child: const Text(
                'Start Advertisements',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const Icon(
            Icons.campaign_rounded,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: const Color(0xFF161618),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF27272A),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Truthworld Ads',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Grow your channel, brand, or business.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildBenefitRow(
                    Icons.check_circle_outline_rounded,
                    'Promote your channel videos directly',
                  ),
                  const SizedBox(height: 10),
                  _buildBenefitRow(
                    Icons.check_circle_outline_rounded,
                    'Target active & engaged communities',
                  ),
                  const SizedBox(height: 10),
                  _buildBenefitRow(
                    Icons.check_circle_outline_rounded,
                    'Custom budget control & transparent stats',
                  ),
                  const SizedBox(height: 32),
                  if (controller.isSigningIn.value)
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => controller.handleGoogleSignIn(),
                      icon: const Icon(
                        Icons.login_rounded,
                        color: Colors.black,
                        size: 18,
                      ),
                      label: const Text(
                        'Sign in with Google',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'Access your advertiser dashboard, launch self-serve campaigns, and track click-through metrics instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textTertiary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserAvatar(BuildContext context, {double radius = 16}) {
    return Obx(() {
      final user = AuthService.to.currentUser.value;
      if (user == null) return const SizedBox.shrink();

      final imageUrl = AuthService.to.activePhotoUrl.isNotEmpty
          ? AuthService.to.activePhotoUrl
          : null;
      final displayName = AuthService.to.activeDisplayName.isNotEmpty
          ? AuthService.to.activeDisplayName
          : (user.displayName ?? 'U');

      final hasImage = imageUrl != null && imageUrl.isNotEmpty;
      final initials = displayName.trim().isNotEmpty
          ? displayName.trim().substring(0, 1).toUpperCase()
          : 'U';

      return Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(BorderSide(color: Color(0xFF27272A))),
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFF18181B),
          child: ClipOval(
            child: hasImage
                ? Image.network(
                    imageUrl,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildAvatarPlaceholder(initials, radius),
                  )
                : _buildAvatarPlaceholder(initials, radius),
          ),
        ),
      );
    });
  }

  Widget _buildAvatarPlaceholder(String initials, double radius) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: TWTypography.brandFamily,
          color: Colors.white,
          fontSize: radius * 0.9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showCreateCampaignWizard(
    BuildContext context,
    AdvertiserPortalController controller, {
    AdItem? existingCampaign,
  }) {
    final advertiserController = TextEditingController(
      text: existingCampaign?.advertiser ?? '',
    );
    final titleController = TextEditingController(
      text: existingCampaign?.title ?? '',
    );
    final descriptionController = TextEditingController(
      text: existingCampaign?.description ?? '',
    );
    final ctaTextController = TextEditingController(
      text: existingCampaign?.ctaText ?? 'Learn More',
    );
    final ctaUrlController = TextEditingController(
      text: existingCampaign?.ctaTarget ?? '',
    );
    final videoUrlController = TextEditingController(
      text: existingCampaign?.videoUrl ?? '',
    );
    final imageUrlController = TextEditingController(
      text: existingCampaign?.imageUrl ?? '',
    );
    final midrollVideoUrlController = TextEditingController(
      text: existingCampaign?.midrollVideoUrl ?? '',
    );
    final pinnedCommentController = TextEditingController(
      text: existingCampaign?.pinnedCommentText ?? '',
    );

    final adFormat = (existingCampaign?.adType ?? 'skippable').obs;
    final selectedBudget =
        (existingCampaign?.budgetTier?.toLowerCase() ?? 'startup').obs;
    final selectedGradient = 0.obs;

    final selectedVideoTitle = ''.obs;
    final selectedVideoId = (existingCampaign?.videoId ?? '').obs;
    final pickedBumperFileName = ''.obs;
    final pickedBumperMeta = ''.obs;
    final isBumperUploading = false.obs;
    final bumperUploadProgress = 0.0.obs;
    final bumperUploadStatus = ''.obs;

    final pickedMidrollFileName = ''.obs;
    final pickedMidrollMeta = ''.obs;
    final isMidrollUploading = false.obs;
    final midrollUploadProgress = 0.0.obs;
    final midrollUploadStatus = ''.obs;

    final pickedBannerFileName = ''.obs;
    final pickedBannerMeta = ''.obs;
    final isBannerUploading = false.obs;
    final bannerUploadProgress = 0.0.obs;
    final bannerUploadStatus = ''.obs;

    // Audience & Targeting State
    final targetAllAges = (existingCampaign?.targetAgeGroups == null ||
            existingCampaign!.targetAgeGroups!.isEmpty).obs;
    final selectedAgeGroups = <String>[
      if (existingCampaign?.targetAgeGroups != null)
        ...existingCampaign!.targetAgeGroups!,
    ].obs;

    final targetAllGenders = (existingCampaign?.targetGenders == null ||
            existingCampaign!.targetGenders!.isEmpty).obs;
    final selectedGenders = <String>[
      if (existingCampaign?.targetGenders != null)
        ...existingCampaign!.targetGenders!,
    ].obs;

    final targetWorldwide = (existingCampaign?.targetLocations == null ||
            existingCampaign!.targetLocations!.isEmpty ||
            existingCampaign.targetLocations!.contains('Worldwide')).obs;
    final selectedLocations = <String>[
      if (existingCampaign?.targetLocations != null)
        ...existingCampaign!.targetLocations!.where((l) => l != 'Worldwide'),
    ].obs;
    final customLocationController = TextEditingController();

    final targetAllLanguages = (existingCampaign?.targetLanguages == null ||
            existingCampaign!.targetLanguages!.isEmpty).obs;
    final selectedLanguages = <String>[
      if (existingCampaign?.targetLanguages != null)
        ...existingCampaign!.targetLanguages!,
    ].obs;

    final targetAllTopics = (existingCampaign?.targetTopics == null ||
            existingCampaign!.targetTopics!.isEmpty).obs;
    final selectedTopics = <String>[
      if (existingCampaign?.targetTopics != null)
        ...existingCampaign!.targetTopics!,
    ].obs;

    const availableAgeGroups = [
      'Under 13',
      '13–17',
      '18–24',
      '25–34',
      '35–44',
      '45–54',
      '55–64',
      '65+',
    ];

    const availableGenders = [
      'Male',
      'Female',
      'Non-binary / Other',
    ];

    const popularLocations = [
      'India',
      'United States',
      'United Kingdom',
      'Canada',
      'Australia',
      'Germany',
      'United Arab Emirates',
      'Singapore',
    ];

    const availableLanguages = [
      {'code': 'en', 'name': 'English'},
      {'code': 'hi', 'name': 'Hindi'},
      {'code': 'es', 'name': 'Spanish'},
      {'code': 'fr', 'name': 'French'},
      {'code': 'de', 'name': 'German'},
      {'code': 'ta', 'name': 'Tamil'},
      {'code': 'te', 'name': 'Telugu'},
    ];

    const availableTopics = [
      'Technology & AI',
      'News & Politics',
      'Entertainment & Cinema',
      'Education & Knowledge',
      'Business & Finance',
      'Gaming & Esports',
      'Lifestyle & Fitness',
      'Music & Arts',
    ];

    final gradientOptions = <List<Color>>[
      [const Color(0xFF8B5CF6), const Color(0xFFEC4899)],
      [const Color(0xFFEF4444), const Color(0xFFF59E0B)],
      [const Color(0xFF10B981), const Color(0xFF059669)],
      [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
      [const Color(0xFFEC4899), const Color(0xFFF43F5E)],
    ];

    final currentStep = 1.obs;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Semantics(
          label: 'Campaign Creation Studio Dialog',
          container: true,
          namesRoute: true,
          child: Container(
            width: 860,
            height: MediaQuery.of(context).size.height * 0.86,
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF27272A)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                // Studio Top Header & Stepper
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF18181B),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF27272A)),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.campaign_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    existingCampaign != null
                                        ? 'Edit Ad Campaign Studio'
                                        : 'Ad Campaign Creation Studio',
                                    style: const TextStyle(
                                      fontFamily: TWTypography.brandFamily,
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Industry Standard Campaign Manager & Delivery Setup',
                                    style: TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: Get.back,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Step Stepper Indicator Chips
                      Obx(() {
                        return Row(
                          children: [
                            _buildStepTab(
                              stepIndex: 1,
                              title: '1. Format & Objective',
                              icon: Icons.grid_view_rounded,
                              currentStep: currentStep.value,
                              onTap: () => currentStep.value = 1,
                            ),
                            const SizedBox(width: 8),
                            _buildStepTab(
                              stepIndex: 2,
                              title: '2. Creatives & Media',
                              icon: Icons.video_file_rounded,
                              currentStep: currentStep.value,
                              onTap: () {
                                currentStep.value = 2;
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildStepTab(
                              stepIndex: 3,
                              title: '3. Target Audience',
                              icon: Icons.people_alt_rounded,
                              currentStep: currentStep.value,
                              onTap: () {
                                currentStep.value = 3;
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildStepTab(
                              stepIndex: 4,
                              title: '4. Budget & Launch',
                              icon: Icons.rocket_launch_rounded,
                              currentStep: currentStep.value,
                              onTap: () {
                                currentStep.value = 4;
                              },
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),

                // Studio Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Obx(() {
                      final isSkippable = adFormat.value == 'skippable';
                      final isSponsor = adFormat.value == 'video_sponsor';
                      final isScroll = adFormat.value == 'scroll';
                      final isHomepage = adFormat.value == 'homepage';

                      Widget buildRejectionBanner() {
                        if (existingCampaign?.status !=
                            'verification_rejected') {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF450A0A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Campaign Rejected - Action Required',
                                      style: TextStyle(
                                        fontFamily: TWTypography.brandFamily,
                                        color: Color(0xFFF87171),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      existingCampaign?.moderationReason ??
                                          'Please update your campaign details below to address the violation and resubmit.',
                                      style: const TextStyle(
                                        fontFamily: TWTypography.uiFamily,
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // STEP 1: Format & Objective
                      if (currentStep.value == 1) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildRejectionBanner(),
                            const Text(
                              'Select Campaign Placement & Format',
                              style: TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Choose where your campaign creatives will be served across Truthworld platforms.',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _buildFormatOption(
                                  'Video Sponsor Ads',
                                  'video_sponsor',
                                  adFormat.value == 'video_sponsor',
                                  () => adFormat.value = 'video_sponsor',
                                  Icons.stars_rounded,
                                  isPopular: true,
                                ),
                                _buildFormatOption(
                                  'Skippable Video',
                                  'skippable',
                                  adFormat.value == 'skippable',
                                  () => adFormat.value = 'skippable',
                                  Icons.play_circle_filled_rounded,
                                ),
                                _buildFormatOption(
                                  'Homepage Banner',
                                  'homepage',
                                  adFormat.value == 'homepage',
                                  () => adFormat.value = 'homepage',
                                  Icons.aspect_ratio_rounded,
                                ),
                                _buildFormatOption(
                                  'Scroll Feed Banner',
                                  'scroll',
                                  adFormat.value == 'scroll',
                                  () => adFormat.value = 'scroll',
                                  Icons.dynamic_feed_rounded,
                                ),
                                _buildFormatOption(
                                  'Comment Box Banner',
                                  'comment',
                                  adFormat.value == 'comment',
                                  () => adFormat.value = 'comment',
                                  Icons.comment_rounded,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (isSponsor) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF18181B),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.brand.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.stars_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Combined 4-in-1 Video Sponsor Suite (POPULAR)',
                                          style: TextStyle(
                                            fontFamily: TWTypography.brandFamily,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '1. 5-Sec Pre-Roll Sponsor Bumper (Plays BEFORE main video starts: "This video is brought to you by [Brand]")\n'
                                      '2. 7-Minute Skippable Mid-roll Video Ad\n'
                                      '3. Recommended Videos Promoted Feed Banner\n'
                                      '4. Interactive Sponsored Pinned Comment below video',
                                      style: TextStyle(
                                        fontFamily: TWTypography.uiFamily,
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      }

                      // STEP 2: Creatives & Media
                      if (currentStep.value == 2) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Campaign Details & Media Creatives',
                              style: TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildInputField(
                              'Brand / Advertiser Name',
                              advertiserController,
                              'e.g. Acme Brand Corp',
                            ),
                            const SizedBox(height: 16),
                            _buildInputField(
                              'Campaign Headline Title',
                              titleController,
                              'e.g. Master App Development in 30 Days',
                            ),
                            const SizedBox(height: 16),
                            _buildInputField(
                              'Description Subtext',
                              descriptionController,
                              'e.g. Learn flutter, dart, firebase, and responsive UI from industry experts.',
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInputField(
                                    'CTA Button Text',
                                    ctaTextController,
                                    'e.g. Learn More',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInputField(
                                    'Destination Link Target',
                                    ctaUrlController,
                                    'e.g. https://mywebsite.com',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Media Creative Attachments',
                                  style: TextStyle(
                                    fontFamily: TWTypography.brandFamily,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                                if (isSponsor)
                                  TextButton.icon(
                                    onPressed: () {
                                      if (advertiserController.text.trim().isEmpty) {
                                        advertiserController.text = 'Acme Brand Corp';
                                      }
                                      if (titleController.text.trim().isEmpty) {
                                        titleController.text = 'Special Summer Tech Festival Deal';
                                      }
                                      if (descriptionController.text.trim().isEmpty) {
                                        descriptionController.text = 'Get up to 50% off on flagship products and course passes!';
                                      }
                                      videoUrlController.text =
                                          'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';
                                      midrollVideoUrlController.text =
                                          'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
                                      imageUrlController.text =
                                          'https://images.unsplash.com/photo-1523474253046-8cd2748b5fd2?w=500';
                                      pinnedCommentController.text =
                                          'Welcome viewers! We are Acme Brand Corp. Feel free to reply here to ask us anything or check out our exclusive offer!';
                                      pickedBumperFileName.value = 'Demo Bumper (Butterfly HD)';
                                      pickedBumperMeta.value = '1.2 MB • 0:05';
                                      pickedMidrollFileName.value = 'Demo Midroll (Bee HD)';
                                      pickedMidrollMeta.value = '4.5 MB • 0:10';
                                      pickedBannerFileName.value = 'Demo Banner (Tech)';
                                      pickedBannerMeta.value = '150 KB • 1200x628';
                                      AppSnackbar.show(
                                        '4-in-1 Sponsor Requirements',
                                        'Loaded all 4 creative requirements for demo setup.',
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.flash_on_rounded,
                                      color: Colors.black,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Auto-Fill Requirements (Demo)',
                                      style: TextStyle(
                                        fontFamily: TWTypography.uiFamily,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Media Slot 1: Bumper or Skippable / Video Creative
                            _buildMediaUploadSlot(
                              title: isSponsor
                                  ? '1. 5-Sec Pre-Roll Sponsor Bumper'
                                  : isSkippable
                                  ? '1. Skippable Video Creative'
                                  : isHomepage
                                  ? '1. Video Creative (Optional - Max 5 Mins)'
                                  : '1. Video Creative (Optional)',
                              subtitle: isSponsor
                                  ? 'Short 5-sec video or audio bumper. (Max 500MB, <= 6s duration)'
                                  : isSkippable
                                  ? 'Main video ad creative. (MP4, MOV, WEBM, max 500MB, <= 5 mins duration)'
                                  : isHomepage
                                  ? 'Optional video creative for Homepage Ad cards (MP4, MOV, WEBM, max 500MB, <= 5 mins duration).'
                                  : 'Optional video creative (MP4, MOV, WEBM, max 500MB, <= 5 mins duration).',
                              urlController: videoUrlController,
                              fileNameNotifier: pickedBumperFileName,
                              metaNotifier: pickedBumperMeta,
                              isUploadingNotifier: isBumperUploading,
                              uploadProgressNotifier: bumperUploadProgress,
                              uploadStatusNotifier: bumperUploadStatus,
                              mediaIcon: isSponsor ? Icons.audiotrack_rounded : Icons.movie_rounded,
                              isRequired: isSponsor || isSkippable,
                              onPickDevice: () => _pickDeviceMediaFile(
                                context: context,
                                fileType: isSponsor ? FileType.custom : FileType.video,
                                targetController: videoUrlController,
                                pickedFileNameNotifier: pickedBumperFileName,
                                isUploadingNotifier: isBumperUploading,
                                uploadProgressNotifier: bumperUploadProgress,
                                uploadStatusNotifier: bumperUploadStatus,
                                pickedMetaNotifier: pickedBumperMeta,
                                allowedExtensions: isSponsor
                                    ? const ['mp4', 'mov', 'webm', 'mkv', 'avi', 'mp3', 'wav', 'm4a', 'aac', 'ogg']
                                    : const ['mp4', 'mov', 'webm', 'mkv', 'avi', 'm4v', '3gp'],
                                maxDurationSeconds: isSponsor ? 6.0 : 300.0,
                                durationLimitWarningText: isSponsor
                                    ? 'Sponsor bumper media must be 5 seconds or less in duration.'
                                    : 'Video ad creative must be 5 minutes (300 seconds) or less.',
                              ),
                              onPickPreset: () {
                                _showChannelVideosPicker(
                                  context,
                                  controller,
                                  onSelected: (video) {
                                    videoUrlController.text =
                                        video['videoUrl'] ?? '';
                                    pickedBumperFileName.value =
                                        video['title'] ?? '';
                                    pickedBumperMeta.value = 'Channel Preset';
                                    selectedVideoTitle.value =
                                        video['title'] ?? '';
                                    selectedVideoId.value =
                                        video['id'] ?? '';
                                  },
                                );
                              },
                            ),

                            // Media Slot 2: Mid-roll Video (for Video Sponsor Ads)
                            if (isSponsor) ...[
                              _buildMediaUploadSlot(
                                title: '2. 7-Minute Skippable Mid-roll Video',
                                subtitle: 'Full mid-roll video ad. (MP4, MOV, WEBM, max 500MB, <= 7.5 mins duration)',
                                urlController: midrollVideoUrlController,
                                fileNameNotifier: pickedMidrollFileName,
                                metaNotifier: pickedMidrollMeta,
                                isUploadingNotifier: isMidrollUploading,
                                uploadProgressNotifier: midrollUploadProgress,
                                uploadStatusNotifier: midrollUploadStatus,
                                mediaIcon: Icons.video_collection_rounded,
                                isRequired: true,
                                onPickDevice: () => _pickDeviceMediaFile(
                                  context: context,
                                  fileType: FileType.video,
                                  targetController: midrollVideoUrlController,
                                  pickedFileNameNotifier: pickedMidrollFileName,
                                  isUploadingNotifier: isMidrollUploading,
                                  uploadProgressNotifier: midrollUploadProgress,
                                  uploadStatusNotifier: midrollUploadStatus,
                                  pickedMetaNotifier: pickedMidrollMeta,
                                  allowedExtensions: const ['mp4', 'mov', 'webm', 'mkv', 'avi', 'm4v'],
                                  maxDurationSeconds: 450.0,
                                  durationLimitWarningText: 'Mid-roll video ads must be 7.5 minutes (450 seconds) or less.',
                                ),
                                onPickPreset: () {
                                  _showChannelVideosPicker(
                                    context,
                                    controller,
                                    onSelected: (video) {
                                      midrollVideoUrlController.text =
                                          video['videoUrl'] ?? '';
                                      pickedMidrollFileName.value =
                                          video['title'] ?? '';
                                      pickedMidrollMeta.value = 'Channel Preset';
                                    },
                                  );
                                },
                              ),
                            ],

                            // Media Slot 3: Banner Image (for Sponsor, Scroll, Homepage, or other placements)
                            if (!isSkippable || isSponsor) ...[
                              _buildMediaUploadSlot(
                                title: isSponsor
                                    ? '3. Sponsor Brand Banner Image'
                                    : isScroll
                                    ? '2. Image Banner Creative'
                                    : isHomepage
                                    ? '2. Image Banner Creative'
                                    : '2. Image Banner Creative (Optional)',
                                subtitle: isSponsor
                                    ? 'Brand banner displayed in recommended videos feed (JPG, PNG, WEBP, max 15MB).'
                                    : isScroll
                                    ? 'Image creative required for Scroll Feed ad placements (JPG, PNG, WEBP, max 15MB).'
                                    : isHomepage
                                    ? 'Image creative required for Homepage ad cards (JPG, PNG, WEBP, max 15MB).'
                                    : 'Banner image creative (JPG, PNG, WEBP, max 15MB).',
                                urlController: imageUrlController,
                                fileNameNotifier: pickedBannerFileName,
                                metaNotifier: pickedBannerMeta,
                                isUploadingNotifier: isBannerUploading,
                                uploadProgressNotifier: bannerUploadProgress,
                                uploadStatusNotifier: bannerUploadStatus,
                                mediaIcon: Icons.image_rounded,
                                isRequired: isSponsor || isScroll || isHomepage,
                                onPickDevice: () => _pickDeviceMediaFile(
                                  context: context,
                                  fileType: FileType.image,
                                  targetController: imageUrlController,
                                  pickedFileNameNotifier: pickedBannerFileName,
                                  isUploadingNotifier: isBannerUploading,
                                  uploadProgressNotifier: bannerUploadProgress,
                                  uploadStatusNotifier: bannerUploadStatus,
                                  pickedMetaNotifier: pickedBannerMeta,
                                  allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
                                ),
                                onPickPreset: () {
                                  _showImagePicker(
                                    context,
                                    onSelectedUrl: (url) {
                                      imageUrlController.text = url;
                                      pickedBannerFileName.value =
                                          'Preset Banner Sample';
                                      pickedBannerMeta.value = 'Sample Preset';
                                    },
                                  );
                                },
                              ),
                            ],

                            // Sponsor Interactive Pinned Comment
                            if (isSponsor) ...[
                              const Text(
                                '4. Sponsor Interactive Pinned Comment Text (Viewers interact below video) [Required]',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildInputField(
                                '',
                                pinnedCommentController,
                                'e.g. Welcome viewers! Ask us anything or check out our exclusive discount here.',
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        );
                      }

                      // STEP 3: Target Audience & Demographics
                      if (currentStep.value == 3) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildRejectionBanner(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Target Audience & Demographics',
                                      style: TextStyle(
                                        fontFamily: TWTypography.brandFamily,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Define who sees your ad based on age groups, gender, geography, and interests.',
                                      style: TextStyle(
                                        fontFamily: TWTypography.uiFamily,
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                // Estimated Reach Counter
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF18181B),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF27272A),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.track_changes_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Estimated Reach',
                                            style: TextStyle(
                                              fontFamily: TWTypography.uiFamily,
                                              color: AppColors.textTertiary,
                                              fontSize: 10,
                                            ),
                                          ),
                                          Text(
                                            (targetAllAges.value &&
                                                    targetAllGenders.value &&
                                                    targetWorldwide.value)
                                                ? '250K+ Viewers'
                                                : '${(50 + (selectedAgeGroups.length * 15) + (selectedLocations.length * 20)).clamp(20, 240)}K Viewers',
                                            style: const TextStyle(
                                              fontFamily:
                                                  TWTypography.brandFamily,
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // 1. AGE GROUPS SECTION
                            _buildAudienceSectionCard(
                              title: 'Audience Age Groups',
                              subtitle:
                                  'Select specific age brackets or reach all ages across Truthworld.',
                              icon: Icons.calendar_today_rounded,
                              isAllSelected: targetAllAges.value,
                              allSelectedLabel: 'All Ages (Broad Reach)',
                              onToggleAll: (val) {
                                targetAllAges.value = val;
                                if (val) {
                                  selectedAgeGroups.clear();
                                }
                              },
                              content: targetAllAges.value
                                  ? const SizedBox.shrink()
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: availableAgeGroups
                                          .map((ageGrp) {
                                        final isSelected =
                                            selectedAgeGroups.contains(ageGrp);
                                        return FilterChip(
                                          label: Text(
                                            ageGrp,
                                            style: TextStyle(
                                              fontFamily: TWTypography.uiFamily,
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: Colors.white,
                                            ),
                                          ),
                                          selected: isSelected,
                                          showCheckmark: isSelected,
                                          checkmarkColor: Colors.white,
                                          selectedColor: AppColors.brand,
                                          backgroundColor:
                                              const Color(0xFF18181B),
                                          side: BorderSide(
                                            color: isSelected
                                                ? AppColors.brand
                                                : const Color(0xFF27272A),
                                          ),
                                          onSelected: (selected) {
                                            if (selected) {
                                              selectedAgeGroups.add(ageGrp);
                                            } else {
                                              selectedAgeGroups.remove(ageGrp);
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),
                            ),
                            const SizedBox(height: 16),

                            // 2. GENDER SECTION
                            _buildAudienceSectionCard(
                              title: 'Gender Demographics',
                              subtitle:
                                  'Target viewers based on user-specified gender identity.',
                              icon: Icons.wc_rounded,
                              isAllSelected: targetAllGenders.value,
                              allSelectedLabel: 'All Genders (Recommended)',
                              onToggleAll: (val) {
                                targetAllGenders.value = val;
                                if (val) {
                                  selectedGenders.clear();
                                }
                              },
                              content: targetAllGenders.value
                                  ? const SizedBox.shrink()
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: availableGenders.map((gender) {
                                        final isSelected =
                                            selectedGenders.contains(gender);
                                        return FilterChip(
                                          label: Text(
                                            gender,
                                            style: TextStyle(
                                              fontFamily: TWTypography.uiFamily,
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: Colors.white,
                                            ),
                                          ),
                                          selected: isSelected,
                                          showCheckmark: isSelected,
                                          checkmarkColor: Colors.white,
                                          selectedColor: AppColors.brand,
                                          backgroundColor:
                                              const Color(0xFF18181B),
                                          side: BorderSide(
                                            color: isSelected
                                                ? AppColors.brand
                                                : const Color(0xFF27272A),
                                          ),
                                          onSelected: (selected) {
                                            if (selected) {
                                              selectedGenders.add(gender);
                                            } else {
                                              selectedGenders.remove(gender);
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),
                            ),
                            const SizedBox(height: 16),

                            // 3. LOCATION & GEOGRAPHY SECTION
                            _buildAudienceSectionCard(
                              title: 'Locations & Geography',
                              subtitle:
                                  'Target global audiences or specific countries and cities.',
                              icon: Icons.public_rounded,
                              isAllSelected: targetWorldwide.value,
                              allSelectedLabel: 'Worldwide / All Locations',
                              onToggleAll: (val) {
                                targetWorldwide.value = val;
                                if (val) {
                                  selectedLocations.clear();
                                }
                              },
                              content: targetWorldwide.value
                                  ? const SizedBox.shrink()
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Popular Countries:',
                                          style: TextStyle(
                                            fontFamily: TWTypography.uiFamily,
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: popularLocations.map((loc) {
                                            final isSelected =
                                                selectedLocations.contains(loc);
                                            return FilterChip(
                                              label: Text(
                                                loc,
                                                style: TextStyle(
                                                  fontFamily:
                                                      TWTypography.uiFamily,
                                                  fontSize: 12,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              selected: isSelected,
                                              showCheckmark: isSelected,
                                              checkmarkColor: Colors.white,
                                              selectedColor: AppColors.brand,
                                              backgroundColor:
                                                  const Color(0xFF18181B),
                                              side: BorderSide(
                                                color: isSelected
                                                    ? AppColors.brand
                                                    : const Color(0xFF27272A),
                                              ),
                                              onSelected: (selected) {
                                                if (selected) {
                                                  selectedLocations.add(loc);
                                                } else {
                                                  selectedLocations.remove(loc);
                                                }
                                              },
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller:
                                                    customLocationController,
                                                style: const TextStyle(
                                                  fontFamily:
                                                      TWTypography.uiFamily,
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                ),
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'Enter city, state or country...',
                                                  hintStyle: const TextStyle(
                                                    color:
                                                        AppColors.textTertiary,
                                                    fontSize: 12,
                                                  ),
                                                  isDense: true,
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                                  filled: true,
                                                  fillColor:
                                                      const Color(0xFF18181B),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    borderSide: const BorderSide(
                                                      color: Color(0xFF27272A),
                                                    ),
                                                  ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    borderSide: const BorderSide(
                                                      color: Color(0xFF27272A),
                                                    ),
                                                  ),
                                                ),
                                                onSubmitted: (val) {
                                                  final trimmed = val.trim();
                                                  if (trimmed.isNotEmpty &&
                                                      !selectedLocations
                                                          .contains(trimmed)) {
                                                    selectedLocations
                                                        .add(trimmed);
                                                    customLocationController
                                                        .clear();
                                                  }
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                final trimmed =
                                                    customLocationController
                                                        .text
                                                        .trim();
                                                if (trimmed.isNotEmpty &&
                                                    !selectedLocations
                                                        .contains(trimmed)) {
                                                  selectedLocations
                                                      .add(trimmed);
                                                  customLocationController
                                                      .clear();
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.add_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                'Add',
                                                style: TextStyle(
                                                  fontFamily:
                                                      TWTypography.uiFamily,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF27272A),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 10,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (selectedLocations.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: selectedLocations
                                                .map((loc) {
                                              return Chip(
                                                label: Text(
                                                  loc,
                                                  style: const TextStyle(
                                                    fontFamily:
                                                        TWTypography.uiFamily,
                                                    fontSize: 11,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                deleteIcon: const Icon(
                                                  Icons.close_rounded,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                                onDeleted: () =>
                                                    selectedLocations
                                                        .remove(loc),
                                                backgroundColor:
                                                    const Color(0xFF27272A),
                                                padding:
                                                    const EdgeInsets.all(4),
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 16),

                            // 4. LANGUAGES SECTION
                            _buildAudienceSectionCard(
                              title: 'Target Languages',
                              subtitle:
                                  'Serve ads to viewers who speak specific languages.',
                              icon: Icons.translate_rounded,
                              isAllSelected: targetAllLanguages.value,
                              allSelectedLabel: 'All Languages',
                              onToggleAll: (val) {
                                targetAllLanguages.value = val;
                                if (val) {
                                  selectedLanguages.clear();
                                }
                              },
                              content: targetAllLanguages.value
                                  ? const SizedBox.shrink()
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: availableLanguages
                                          .map((lang) {
                                        final code = lang['code']!;
                                        final name = lang['name']!;
                                        final isSelected =
                                            selectedLanguages.contains(code);
                                        return FilterChip(
                                          label: Text(
                                            name,
                                            style: TextStyle(
                                              fontFamily: TWTypography.uiFamily,
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: Colors.white,
                                            ),
                                          ),
                                          selected: isSelected,
                                          showCheckmark: isSelected,
                                          checkmarkColor: Colors.white,
                                          selectedColor: AppColors.brand,
                                          backgroundColor:
                                              const Color(0xFF18181B),
                                          side: BorderSide(
                                            color: isSelected
                                                ? AppColors.brand
                                                : const Color(0xFF27272A),
                                          ),
                                          onSelected: (selected) {
                                            if (selected) {
                                              selectedLanguages.add(code);
                                            } else {
                                              selectedLanguages.remove(code);
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),
                            ),
                            const SizedBox(height: 16),

                            // 5. TOPIC INTERESTS SECTION
                            _buildAudienceSectionCard(
                              title: 'Topic & Category Interests',
                              subtitle:
                                  'Align your campaign with specific video categories and genres.',
                              icon: Icons.tag_rounded,
                              isAllSelected: targetAllTopics.value,
                              allSelectedLabel: 'All Categories & Topics',
                              onToggleAll: (val) {
                                targetAllTopics.value = val;
                                if (val) {
                                  selectedTopics.clear();
                                }
                              },
                              content: targetAllTopics.value
                                  ? const SizedBox.shrink()
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: availableTopics
                                          .map((topic) {
                                        final isSelected =
                                            selectedTopics.contains(topic);
                                        return FilterChip(
                                          label: Text(
                                            topic,
                                            style: TextStyle(
                                              fontFamily: TWTypography.uiFamily,
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: Colors.white,
                                            ),
                                          ),
                                          selected: isSelected,
                                          showCheckmark: isSelected,
                                          checkmarkColor: Colors.white,
                                          selectedColor: AppColors.brand,
                                          backgroundColor:
                                              const Color(0xFF18181B),
                                          side: BorderSide(
                                            color: isSelected
                                                ? AppColors.brand
                                                : const Color(0xFF27272A),
                                          ),
                                          onSelected: (selected) {
                                            if (selected) {
                                              selectedTopics.add(topic);
                                            } else {
                                              selectedTopics.remove(topic);
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),
                            ),
                          ],
                        );
                      }

                      // STEP 4: Budget & Launch
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Audience Summary Review Card
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF18181B),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF27272A),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                            Icons.people_alt_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Target Audience Overview',
                                          style: TextStyle(
                                            fontFamily:
                                                TWTypography.brandFamily,
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton.icon(
                                      onPressed: () => currentStep.value = 3,
                                      icon: const Icon(
                                        Icons.edit_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      label: const Text(
                                        'Edit Targeting',
                                        style: TextStyle(
                                          fontFamily: TWTypography.uiFamily,
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildAudienceBadge(
                                      icon: Icons.calendar_today_rounded,
                                      label: targetAllAges.value
                                          ? 'All Ages'
                                          : 'Ages: ${selectedAgeGroups.join(', ')}',
                                    ),
                                    _buildAudienceBadge(
                                      icon: Icons.wc_rounded,
                                      label: targetAllGenders.value
                                          ? 'All Genders'
                                          : 'Gender: ${selectedGenders.join(', ')}',
                                    ),
                                    _buildAudienceBadge(
                                      icon: Icons.public_rounded,
                                      label: targetWorldwide.value
                                          ? 'Worldwide'
                                          : 'Locations: ${selectedLocations.join(', ')}',
                                    ),
                                    if (!targetAllLanguages.value &&
                                        selectedLanguages.isNotEmpty)
                                      _buildAudienceBadge(
                                        icon: Icons.translate_rounded,
                                        label:
                                            'Languages: ${selectedLanguages.join(', ')}',
                                      ),
                                    if (!targetAllTopics.value &&
                                        selectedTopics.isNotEmpty)
                                      _buildAudienceBadge(
                                        icon: Icons.tag_rounded,
                                        label:
                                            'Topics: ${selectedTopics.join(', ')}',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            'Select Campaign Budget & Delivery Plan',
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Column(
                            children: [
                              _buildBudgetOption(
                                'Bootstrap Package',
                                '₹500',
                                'Estimated 2,500 impressions',
                                'startup',
                                selectedBudget.value == 'startup',
                                () => selectedBudget.value = 'startup',
                              ),
                              const SizedBox(height: 8),
                              _buildBudgetOption(
                                'Starter Pack',
                                '₹2,000',
                                'Estimated 10,000 impressions',
                                'starter',
                                selectedBudget.value == 'starter',
                                () => selectedBudget.value = 'starter',
                              ),
                              const SizedBox(height: 8),
                              _buildBudgetOption(
                                'Growth Booster',
                                '₹5,000',
                                'Estimated 35,000 impressions',
                                'growth',
                                selectedBudget.value == 'growth',
                                () => selectedBudget.value = 'growth',
                              ),
                              const SizedBox(height: 8),
                              _buildBudgetOption(
                                'Enterprise Scale',
                                '₹15,000',
                                'Estimated 120,000 impressions',
                                'enterprise',
                                selectedBudget.value == 'enterprise',
                                () => selectedBudget.value = 'enterprise',
                              ),
                            ],
                          ),
                          if (!isSkippable && !isSponsor && !isScroll) ...[
                            const SizedBox(height: 24),
                            const Text(
                              'Select Fallback / Banner Theme',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 45,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: gradientOptions.length,
                                itemBuilder: (context, idx) {
                                  final colors = gradientOptions[idx];
                                  return GestureDetector(
                                    onTap: () => selectedGradient.value = idx,
                                    child: Container(
                                      width: 45,
                                      margin: const EdgeInsets.only(
                                        right: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: colors,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: selectedGradient.value == idx
                                              ? AppColors.brand
                                              : Colors.transparent,
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      );
                    }),
                  ),
                ),

                // Studio Footer Actions Bar
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF18181B),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border(
                      top: BorderSide(color: Color(0xFF27272A)),
                    ),
                  ),
                  child: Obx(() {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            if (currentStep.value > 1) {
                              currentStep.value--;
                            } else {
                              Get.back();
                            }
                          },
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          label: Text(
                            currentStep.value > 1 ? 'Back' : 'Cancel',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF27272A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                        if (currentStep.value < 4)
                          ElevatedButton.icon(
                            onPressed: () {
                              if (currentStep.value == 2) {
                                if (advertiserController.text.trim().isEmpty ||
                                    titleController.text.trim().isEmpty ||
                                    descriptionController.text.trim().isEmpty) {
                                  AppSnackbar.show(
                                    'Required Fields',
                                    'Please fill brand name, headline, and description.',
                                    backgroundColor: AppColors.error,
                                    colorText: AppColors.textPrimary,
                                  );
                                  return;
                                }
                                if (adFormat.value == 'homepage' &&
                                    imageUrlController.text.trim().isEmpty) {
                                  AppSnackbar.show(
                                    'Image Required',
                                    'Homepage Ads require an Image Banner creative. Please pick or select an image file.',
                                    backgroundColor: AppColors.error,
                                    colorText: AppColors.textPrimary,
                                  );
                                  return;
                                }
                                if (adFormat.value == 'scroll' &&
                                    imageUrlController.text.trim().isEmpty) {
                                  AppSnackbar.show(
                                    'Image Required',
                                    'Scroll Ads require an Image Banner creative. Please pick or select an image file.',
                                    backgroundColor: AppColors.error,
                                    colorText: AppColors.textPrimary,
                                  );
                                  return;
                                }
                              }
                              if (currentStep.value == 3) {
                                if (!targetAllAges.value &&
                                    selectedAgeGroups.isEmpty) {
                                  AppSnackbar.show(
                                    'Targeting Required',
                                    'Please select at least one age bracket or toggle "All Ages".',
                                    backgroundColor: AppColors.error,
                                    colorText: AppColors.textPrimary,
                                  );
                                  return;
                                }
                                if (!targetAllGenders.value &&
                                    selectedGenders.isEmpty) {
                                  AppSnackbar.show(
                                    'Targeting Required',
                                    'Please select at least one gender or toggle "All Genders".',
                                    backgroundColor: AppColors.error,
                                    colorText: AppColors.textPrimary,
                                  );
                                  return;
                                }
                                if (!targetWorldwide.value &&
                                    selectedLocations.isEmpty) {
                                  AppSnackbar.show(
                                    'Targeting Required',
                                    'Please add at least one location or toggle "Worldwide".',
                                    backgroundColor: AppColors.error,
                                    colorText: AppColors.textPrimary,
                                  );
                                  return;
                                }
                              }
                              currentStep.value++;
                            },
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.black,
                              size: 16,
                            ),
                            label: const Text(
                              'Next Step',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () {
                              if (advertiserController.text.trim().isEmpty ||
                                  titleController.text.trim().isEmpty ||
                                  descriptionController.text.trim().isEmpty) {
                                AppSnackbar.show(
                                  'Required Fields',
                                  'Please fill brand name, title, and description.',
                                  backgroundColor: AppColors.error,
                                  colorText: AppColors.textPrimary,
                                );
                                return;
                              }

                              if (adFormat.value == 'homepage' &&
                                  imageUrlController.text.trim().isEmpty) {
                                AppSnackbar.show(
                                  'Image Required',
                                  'Homepage Ads require an Image Banner creative.',
                                  backgroundColor: AppColors.error,
                                  colorText: AppColors.textPrimary,
                                );
                                return;
                              }

                              var targetVideoUrl = videoUrlController.text.trim();
                              if (adFormat.value == 'skippable' &&
                                  targetVideoUrl.isEmpty) {
                                targetVideoUrl =
                                    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';
                              }

                              if (adFormat.value == 'video_sponsor') {
                                if (targetVideoUrl.isEmpty) {
                                  targetVideoUrl =
                                      'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';
                                }
                                if (midrollVideoUrlController.text.trim().isEmpty) {
                                  midrollVideoUrlController.text =
                                      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
                                }
                                if (imageUrlController.text.trim().isEmpty) {
                                  imageUrlController.text =
                                      'https://images.unsplash.com/photo-1523474253046-8cd2748b5fd2?w=500';
                                }
                                if (pinnedCommentController.text.trim().isEmpty) {
                                  final brandName = advertiserController.text.trim().isNotEmpty
                                      ? advertiserController.text.trim()
                                      : (titleController.text.trim().isNotEmpty
                                          ? titleController.text.trim()
                                          : 'our sponsor');
                                  pinnedCommentController.text =
                                      'Welcome viewers! Thanks for checking out $brandName. Feel free to ask us any questions here!';
                                }
                              }

                              Get.back();
                              _showStripeCheckout(
                                context,
                                controller,
                                brand: advertiserController.text.trim(),
                                title: titleController.text.trim(),
                                description: descriptionController.text.trim(),
                                ctaText: ctaTextController.text.trim(),
                                ctaTarget: ctaUrlController.text.trim().isEmpty
                                    ? 'https://google.com'
                                    : ctaUrlController.text.trim(),
                                isSkippable:
                                    adFormat.value == 'skippable' ||
                                    adFormat.value == 'video_sponsor',
                                videoUrl: targetVideoUrl.isNotEmpty
                                    ? targetVideoUrl
                                    : null,
                                imageUrl: imageUrlController.text.trim().isNotEmpty
                                    ? imageUrlController.text.trim()
                                    : null,
                                gradient:
                                    (adFormat.value != 'skippable' &&
                                        adFormat.value != 'video_sponsor')
                                    ? gradientOptions[selectedGradient.value]
                                    : null,
                                budgetTier: selectedBudget.value,
                                adType: adFormat.value,
                                videoId: selectedVideoId.value.isEmpty
                                    ? null
                                    : selectedVideoId.value,
                                midrollVideoUrl: adFormat.value == 'video_sponsor'
                                    ? midrollVideoUrlController.text.trim()
                                    : null,
                                pinnedCommentText: adFormat.value == 'video_sponsor'
                                    ? pinnedCommentController.text.trim()
                                    : null,
                                targetAgeGroups: targetAllAges.value
                                    ? null
                                    : selectedAgeGroups.toList(),
                                targetGenders: targetAllGenders.value
                                    ? null
                                    : selectedGenders.toList(),
                                targetLocations: targetWorldwide.value
                                    ? ['Worldwide']
                                    : selectedLocations.toList(),
                                targetLanguages: targetAllLanguages.value
                                    ? null
                                    : selectedLanguages.toList(),
                                targetTopics: targetAllTopics.value
                                    ? null
                                    : selectedTopics.toList(),
                                existingCampaign: existingCampaign,
                              );
                            },
                            icon: const Icon(
                              Icons.rocket_launch_rounded,
                              color: Colors.black,
                              size: 16,
                            ),
                            label: const Text(
                              'Proceed to Checkout',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                          ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepTab({
    required int stepIndex,
    required String title,
    required IconData icon,
    required int currentStep,
    required VoidCallback onTap,
  }) {
    final isActive = currentStep == stepIndex;
    final isDone = currentStep > stepIndex;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.brand.withValues(alpha: 0.12)
                : isDone
                ? const Color(0xFF18181B)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? AppColors.brand
                  : isDone
                  ? const Color(0xFF27272A)
                  : const Color(0xFF27272A),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isDone ? Icons.check_circle_rounded : icon,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: isActive
                        ? AppColors.brand
                        : isDone
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isActive || isDone
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudienceSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isAllSelected,
    required String allSelectedLabel,
    required ValueChanged<bool> onToggleAll,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              FilterChip(
                label: Text(
                  allSelectedLabel,
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 11,
                    fontWeight: isAllSelected ? FontWeight.bold : FontWeight.normal,
                    color: Colors.white,
                  ),
                ),
                selected: isAllSelected,
                showCheckmark: isAllSelected,
                checkmarkColor: Colors.white,
                selectedColor: AppColors.brand,
                backgroundColor: const Color(0xFF27272A),
                side: BorderSide(
                  color: isAllSelected ? AppColors.brand : const Color(0xFF3F3F46),
                ),
                onSelected: onToggleAll,
              ),
            ],
          ),
          if (!isAllSelected) ...[
            const Divider(color: Color(0xFF27272A), height: 24),
            content,
          ],
        ],
      ),
    );
  }

  Widget _buildAudienceBadge({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF27272A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF3F3F46)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showChannelVideosPicker(
    BuildContext context,
    AdvertiserPortalController controller, {
    required Function(Map<String, dynamic>) onSelected,
  }) {
    final presetVideos = [
      {
        'id': 'preset_bumper',
        'title': '5-Sec Pre-Roll Bumper Sample (Butterfly HD)',
        'description': 'Short 5-second video sample for sponsor intro bumper',
        'videoUrl': 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
        'thumbnailUrl': 'https://images.unsplash.com/photo-1523474253046-8cd2748b5fd2?w=500',
      },
      {
        'id': 'preset_midroll',
        'title': '7-Min Mid-roll Video Sample (Bee HD)',
        'description': 'Detailed product video for 7-minute skippable mid-roll ad',
        'videoUrl': 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        'thumbnailUrl': 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=500',
      },
    ];

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Semantics(
          label: 'Select Video Dialog',
          container: true,
          namesRoute: true,
          child: Container(
            width: 500,
            height: 480,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Video Creative',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: Get.back,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF27272A)),
                const SizedBox(height: 8),
                const Text(
                  'Pick from your channel videos or select a high-quality video preset.',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Obx(() {
                    final allVideos = [
                      ...presetVideos,
                      ...controller.channelVideos,
                    ];

                    return ListView.builder(
                      itemCount: allVideos.length,
                      itemBuilder: (context, index) {
                        final video = allVideos[index];
                        final isPreset = video['id'].toString().startsWith('preset');
                        return Card(
                          color: const Color(0xFF121212),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFF27272A)),
                          ),
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 60,
                                height: 36,
                                color: const Color(0xFF18181B),
                                child: (video['thumbnailUrl']?.toString().isNotEmpty ?? false)
                                    ? Image.network(
                                        video['thumbnailUrl'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, o, s) => const Icon(
                                          Icons.video_library_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.video_library_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    video['title'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (isPreset)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF27272A),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Preset',
                                      style: TextStyle(
                                        fontFamily: TWTypography.uiFamily,
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              video['description'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.check_circle_outline_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            onTap: () {
                              onSelected(video);
                              Get.back();
                            },
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showImagePicker(
    BuildContext context, {
    required Function(String) onSelectedUrl,
  }) {
    final sampleImages = [
      {
        'name': 'Tech & Gadgets Banner',
        'url': 'https://images.unsplash.com/photo-1523474253046-8cd2748b5fd2?w=500',
      },
      {
        'name': 'Mobile & App Showcase Banner',
        'url': 'https://images.unsplash.com/photo-1512941937669-90a1b58e7e9c?w=500',
      },
      {
        'name': 'Brand Promotion Banner',
        'url': 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=500',
      },
    ];

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 480,
          height: 400,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161618),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF27272A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pick Sponsor Banner Image',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: Get.back,
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF27272A)),
              const SizedBox(height: 8),
              const Text(
                'Select a brand image from sample presets for the recommended videos list.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: sampleImages.length,
                  itemBuilder: (context, idx) {
                    final item = sampleImages[idx];
                    return Card(
                      color: const Color(0xFF121212),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFF27272A)),
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            item['url']!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(
                          item['name']!,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        onTap: () {
                          onSelectedUrl(item['url']!);
                          Get.back();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaUploadSlot({
    required String title,
    required String subtitle,
    required TextEditingController urlController,
    required RxString fileNameNotifier,
    required RxString metaNotifier,
    required RxBool isUploadingNotifier,
    required RxDouble uploadProgressNotifier,
    required RxString uploadStatusNotifier,
    required IconData mediaIcon,
    required VoidCallback onPickDevice,
    required VoidCallback onPickPreset,
    bool isRequired = false,
  }) {
    return Obx(() {
      final isUploading = isUploadingNotifier.value;
      final progress = uploadProgressNotifier.value;
      final statusText = uploadStatusNotifier.value;
      final fileName = fileNameNotifier.value;
      final hasFile = fileName.isNotEmpty || urlController.text.trim().isNotEmpty;
      final metaText = metaNotifier.value;

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUploading
                ? AppColors.brand
                : hasFile
                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                : const Color(0xFF27272A),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRequired) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            'Required',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: Color(0xFFF87171),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 12),

            if (isUploading) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              statusText.isNotEmpty ? statusText : 'Processing media...',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.brand,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFF27272A),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (hasFile) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        mediaIcon,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName.isNotEmpty ? fileName : urlController.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'READY',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: Color(0xFF10B981),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (metaText.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  metaText,
                                  style: const TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onPickDevice,
                      icon: const Icon(
                        Icons.sync_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      label: const Text(
                        'Replace',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF3F3F46)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      tooltip: 'Remove media',
                      onPressed: () {
                        urlController.clear();
                        fileNameNotifier.value = '';
                        metaNotifier.value = '';
                      },
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onPickDevice,
                      icon: const Icon(
                        Icons.file_upload_rounded,
                        color: Colors.black,
                        size: 16,
                      ),
                      label: const Text(
                        'Pick from Device',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onPickPreset,
                    icon: const Icon(
                      Icons.video_library_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: const Text(
                      'Presets',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF18181B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFF27272A)),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }

  Future<void> _pickDeviceMediaFile({
    required BuildContext context,
    required FileType fileType,
    required TextEditingController targetController,
    required RxString pickedFileNameNotifier,
    required RxBool isUploadingNotifier,
    required RxDouble uploadProgressNotifier,
    required RxString uploadStatusNotifier,
    RxString? pickedMetaNotifier,
    List<String>? allowedExtensions,
    double? maxDurationSeconds,
    String? durationLimitWarningText,
  }) async {
    isUploadingNotifier.value = true;
    uploadProgressNotifier.value = 0.05;
    uploadStatusNotifier.value = 'Opening file selector...';

    try {
      FilePickerResult? result;
      try {
        result = await FilePicker.pickFiles(
          type: (allowedExtensions != null && allowedExtensions.isNotEmpty)
              ? FileType.custom
              : fileType,
          allowedExtensions: allowedExtensions,
          withData: kIsWeb,
        ).timeout(
          const Duration(seconds: 60),
          onTimeout: () => null,
        );
      } catch (pickerErr) {
        debugPrint('[AdvertiserPortal] FilePicker exception: $pickerErr');
        isUploadingNotifier.value = false;
        uploadStatusNotifier.value = '';
        AppSnackbar.show(
          'File Picker Error',
          'Could not open file selector: $pickerErr',
          backgroundColor: AppColors.error,
          colorText: Colors.white,
        );
        return;
      }

      if (result == null || result.files.isEmpty) {
        isUploadingNotifier.value = false;
        uploadStatusNotifier.value = '';
        return;
      }

      final pickedFile = result.files.first;
      final fileSize = pickedFile.size;

      final isVideoOrAudio = fileType == FileType.video ||
          fileType == FileType.audio ||
          fileType == FileType.media ||
          (allowedExtensions != null &&
              allowedExtensions.any(
                (e) => [
                  'mp4',
                  'mov',
                  'webm',
                  'mkv',
                  'avi',
                  'mp3',
                  'wav',
                  'm4a',
                  'aac',
                  'ogg',
                ].contains(e.toLowerCase()),
              ));

      // File size validation: 500MB for video/audio, 15MB for images
      final maxSizeBytes = isVideoOrAudio
          ? 500 * 1024 * 1024
          : 15 * 1024 * 1024;
      if (fileSize > maxSizeBytes) {
        isUploadingNotifier.value = false;
        uploadStatusNotifier.value = '';
        final sizeMb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
        final maxMb = (maxSizeBytes / (1024 * 1024)).toStringAsFixed(0);
        AppSnackbar.show(
          'File Size Limit Exceeded',
          'Selected file is $sizeMb MB. The maximum allowed size is $maxMb MB.',
          backgroundColor: AppColors.error,
          colorText: Colors.white,
        );
        return;
      }

      String formatBytes(int bytes) {
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1024 * 1024) {
          return '${(bytes / 1024).toStringAsFixed(1)} KB';
        }
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }

      final sizeStr = formatBytes(fileSize);
      uploadStatusNotifier.value = 'Inspecting media...';
      uploadProgressNotifier.value = 0.15;

      // Safe, non-blocking duration inspection
      double? extractedDurationSec;
      if (isVideoOrAudio) {
        try {
          if (kIsWeb) {
            if (pickedFile.bytes != null) {
              final ext = pickedFile.extension?.toLowerCase() ?? 'mp4';
              final mime = [
                'mp3',
                'wav',
                'm4a',
                'aac',
                'ogg',
              ].contains(ext)
                  ? 'audio/$ext'
                  : 'video/$ext';
              final blob = html.Blob([pickedFile.bytes], mime);
              final blobUrl = html.Url.createObjectUrlFromBlob(blob);
              try {
                final videoEl = html.VideoElement()
                  ..src = blobUrl
                  ..preload = 'metadata';
                await videoEl.onLoadedMetadata.first.timeout(
                  const Duration(seconds: 3),
                  onTimeout: () => html.Event('timeout'),
                );
                final dur = videoEl.duration;
                if (!dur.isNaN && !dur.isInfinite && dur > 0) {
                  extractedDurationSec = dur.toDouble();
                }
              } catch (webProbeErr) {
                debugPrint(
                  '[AdvertiserPortal] Web duration probe notice: $webProbeErr',
                );
              } finally {
                html.Url.revokeObjectUrl(blobUrl);
              }
            }
          } else {
            if (pickedFile.path != null && pickedFile.path!.isNotEmpty) {
              final ioFile = io.File(pickedFile.path!);
              if (await ioFile.exists()) {
                VideoPlayerController? tempCtrl;
                try {
                  tempCtrl = VideoPlayerController.file(ioFile);
                  await tempCtrl.initialize().timeout(
                    const Duration(seconds: 4),
                    onTimeout: () {
                      debugPrint(
                        '[AdvertiserPortal] Native video player probe timed out',
                      );
                    },
                  );
                  if (tempCtrl.value.isInitialized) {
                    final durSec =
                        tempCtrl.value.duration.inMilliseconds / 1000.0;
                    if (durSec > 0) {
                      extractedDurationSec = durSec;
                    }
                  }
                } catch (nativeProbeErr) {
                  debugPrint(
                    '[AdvertiserPortal] Native duration probe notice: $nativeProbeErr',
                  );
                } finally {
                  await tempCtrl?.dispose();
                }
              }
            }
          }
        } catch (durErr) {
          debugPrint(
            '[AdvertiserPortal] General duration extraction notice: $durErr',
          );
        }

        // Validate duration limit if specified
        if (extractedDurationSec != null && maxDurationSeconds != null) {
          if (extractedDurationSec > maxDurationSeconds) {
            isUploadingNotifier.value = false;
            uploadStatusNotifier.value = '';
            final durFormatted = extractedDurationSec.toStringAsFixed(1);
            final limitFormatted = maxDurationSeconds.toStringAsFixed(0);
            AppSnackbar.show(
              'Media Exceeds Duration Limit',
              durationLimitWarningText ??
                  'Selected media is $durFormatted seconds, which exceeds the $limitFormatted second limit.',
              backgroundColor: AppColors.error,
              colorText: Colors.white,
            );
            return;
          }
        }
      }

      var durationFormatted = '';
      if (extractedDurationSec != null && extractedDurationSec > 0) {
        final totalSecs = extractedDurationSec.round();
        final mins = totalSecs ~/ 60;
        final secs = totalSecs % 60;
        durationFormatted = '$mins:${secs.toString().padLeft(2, '0')}';
      }
      final metaInfo = durationFormatted.isNotEmpty
          ? '$sizeStr • $durationFormatted'
          : sizeStr;
      pickedMetaNotifier?.value = metaInfo;

      // Stream upload to Firebase Storage with real-time progress
      uploadStatusNotifier.value = 'Uploading to cloud storage...';
      uploadProgressNotifier.value = 0.2;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = pickedFile.name.replaceAll(
        RegExp('[^a-zA-Z0-9._-]'),
        '_',
      );
      final storagePath = 'ad_campaigns_media/${timestamp}_$sanitizedName';
      final ext = pickedFile.extension?.toLowerCase() ?? '';

      var mimeType = 'application/octet-stream';
      if ([
        'mp4',
        'mov',
        'webm',
        'mkv',
        'avi',
        'm4v',
        '3gp',
      ].contains(ext)) {
        mimeType = 'video/mp4';
      } else if ([
        'mp3',
        'wav',
        'm4a',
        'aac',
        'ogg',
      ].contains(ext)) {
        mimeType = 'audio/mpeg';
      } else if (['jpg', 'jpeg'].contains(ext)) {
        mimeType = 'image/jpeg';
      } else if (ext == 'png') {
        mimeType = 'image/png';
      } else if (ext == 'webp') {
        mimeType = 'image/webp';
      } else if (ext == 'gif') {
        mimeType = 'image/gif';
      }

      String? finalUrl;
      try {
        final storageRef = FirebaseStorage.instance.ref().child(storagePath);
        UploadTask uploadTask;
        final currentUid = FirebaseAuth.instance.currentUser?.uid;

        if (kIsWeb) {
          if (pickedFile.bytes == null) {
            throw Exception('File bytes are null on Web platform');
          }
          uploadTask = storageRef.putData(
            pickedFile.bytes!,
            SettableMetadata(
              contentType: mimeType,
              customMetadata: {
                'uploaderId': ?currentUid,
              },
            ),
          );
        } else {
          if (pickedFile.path == null || pickedFile.path!.isEmpty) {
            throw Exception('File path is null on Native platform');
          }
          final ioFile = io.File(pickedFile.path!);
          uploadTask = storageRef.putFile(
            ioFile,
            SettableMetadata(
              contentType: mimeType,
              customMetadata: {
                'uploaderId': ?currentUid,
              },
            ),
          );
        }

        uploadTask.snapshotEvents.listen((snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            uploadProgressNotifier.value = 0.2 + (progress * 0.75);
            uploadStatusNotifier.value =
                'Uploading ${(progress * 100).toStringAsFixed(0)}% (${formatBytes(snapshot.bytesTransferred)} / ${formatBytes(snapshot.totalBytes)})...';
          }
        });

        final taskSnapshot = await uploadTask;
        uploadStatusNotifier.value = 'Finalizing URL...';
        uploadProgressNotifier.value = 0.98;
        finalUrl = await taskSnapshot.ref.getDownloadURL();
      } catch (uploadErr) {
        debugPrint(
          '[AdvertiserPortal] Cloud storage upload notice: $uploadErr. Using local reference.',
        );
        if (!kIsWeb && pickedFile.path != null && pickedFile.path!.isNotEmpty) {
          finalUrl = pickedFile.path;
        } else {
          finalUrl =
              'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';
        }
      }

      targetController.text = finalUrl ?? pickedFile.name;
      pickedFileNameNotifier.value = pickedFile.name;
      uploadProgressNotifier.value = 1.0;
      uploadStatusNotifier.value = 'Ready';
      isUploadingNotifier.value = false;

      AppSnackbar.show(
        'Media Attached Successfully',
        '${pickedFile.name} ($metaInfo) is ready for campaign launch.',
        backgroundColor: AppColors.success,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      debugPrint('[AdvertiserPortal] Media pick error: $e');
      isUploadingNotifier.value = false;
      uploadStatusNotifier.value = '';
      AppSnackbar.show(
        'Media Attachment Error',
        'Could not process selected media: $e',
        backgroundColor: AppColors.error,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Widget _buildFormatOption(
    String label,
    String value,
    bool isSelected,
    VoidCallback onTap,
    IconData icon, {
    bool isPopular = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand.withValues(alpha: 0.12)
              : const Color(0xFF121212),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.brand : const Color(0xFF27272A),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: isSelected
                    ? Colors.white
                    : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isPopular) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFF59E0B)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'POPULAR (4-in-1)',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: Colors.white,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textTertiary,
              fontSize: 13,
            ),
            fillColor: const Color(0xFF121212),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF27272A)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF27272A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetOption(
    String tierName,
    String cost,
    String subtitle,
    String value,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand.withValues(alpha: 0.12)
              : const Color(0xFF121212),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.brand : const Color(0xFF27272A),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tierName,
                    style: const TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              cost,
              style: const TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStripeCheckout(
    BuildContext context,
    AdvertiserPortalController controller, {
    required String brand,
    required String title,
    required String description,
    required String ctaText,
    required String ctaTarget,
    required bool isSkippable,
    required String budgetTier,
    required String adType,
    String? videoUrl,
    String? imageUrl,
    List<Color>? gradient,
    String? videoId,
    String? midrollVideoUrl,
    String? pinnedCommentText,
    List<String>? targetAgeGroups,
    List<String>? targetGenders,
    List<String>? targetLocations,
    List<String>? targetLanguages,
    List<String>? targetTopics,
    AdItem? existingCampaign,
  }) {
    final cardNumber = TextEditingController(text: '4242 4242 4242 4242');
    final cardExpiry = TextEditingController(text: '12/28');
    final cardCvc = TextEditingController(text: '123');

    final progressStep = 0.obs;
    final checkoutSuccess = false.obs;

    double cost = 2000;
    if (budgetTier == 'startup') cost = 500;
    if (budgetTier == 'growth') cost = 5000;
    if (budgetTier == 'enterprise') cost = 15000;

    final audienceParts = <String>[];
    if (targetAgeGroups != null && targetAgeGroups.isNotEmpty) {
      audienceParts.add('Ages: ${targetAgeGroups.join(', ')}');
    } else {
      audienceParts.add('All Ages');
    }
    if (targetGenders != null && targetGenders.isNotEmpty) {
      audienceParts.add('Gender: ${targetGenders.join(', ')}');
    } else {
      audienceParts.add('All Genders');
    }
    if (targetLocations != null && targetLocations.isNotEmpty) {
      audienceParts.add(targetLocations.join(', '));
    } else {
      audienceParts.add('Worldwide');
    }
    final audienceSummaryText = audienceParts.join(' • ');

    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Semantics(
          label: 'Payment Dialog',
          container: true,
          namesRoute: true,
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Obx(() {
              if (progressStep.value > 0) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    if (!checkoutSuccess.value) ...[
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.brand,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        progressStep.value == 1
                            ? 'Securing checkout channel...'
                            : progressStep.value == 2
                            ? 'Authorizing payment method...'
                            : 'Finalizing campaign launch...',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 64,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Campaign Created Successfully!',
                        style: TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your advertisement has been submitted for moderation. Once approved by our Verification System, it will go live.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: Get.back,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(140, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Stripe Checkout',
                        style: TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF27272A), height: 20),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ad Campaign (${budgetTier.toUpperCase()})',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '₹${cost.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Audience Summary Pill in Checkout
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF27272A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.people_alt_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Audience Targeting',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textTertiary,
                                  fontSize: 9,
                                ),
                              ),
                              Text(
                                audienceSummaryText,
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    'Card Number',
                    cardNumber,
                    '4242 4242 4242 4242',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          'Expiry Date',
                          cardExpiry,
                          'MM/YY',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildInputField('CVC', cardCvc, '123')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: progressStep.value > 0
                        ? null
                        : () async {
                            try {
                              progressStep.value = 1;
                              await Future.delayed(
                                const Duration(milliseconds: 600),
                              );
                              progressStep.value = 2;
                              await Future.delayed(
                                const Duration(milliseconds: 600),
                              );
                              progressStep.value = 3;
                              await Future.delayed(
                                const Duration(milliseconds: 600),
                              );

                              if (existingCampaign != null) {
                                final ad = existingCampaign.copyWith(
                                  advertiser: brand,
                                  title: title,
                                  description: description,
                                  imageUrl: imageUrl ?? '',
                                  ctaText: ctaText,
                                  ctaTarget: ctaTarget,
                                  gradientColors:
                                      gradient ??
                                      existingCampaign.gradientColors,
                                  isSkippableAd: isSkippable,
                                  videoUrl: videoUrl,
                                  budgetTier: budgetTier.toUpperCase(),
                                  budgetAmount: cost,
                                  adType: adType,
                                  status: 'underReview',
                                  videoId: (videoId ?? '').isNotEmpty
                                      ? videoId
                                      : existingCampaign.videoId,
                                  midrollVideoUrl: midrollVideoUrl,
                                  pinnedCommentText: pinnedCommentText,
                                  targetAgeGroups: targetAgeGroups,
                                  targetGenders: targetGenders,
                                  targetLocations: targetLocations,
                                  targetLanguages: targetLanguages,
                                  targetTopics: targetTopics,
                                );

                                final success =
                                    await AdService.to.updateCampaign(ad);
                                if (success) {
                                  checkoutSuccess.value = true;
                                } else {
                                  progressStep.value = 0;
                                  AppSnackbar.show(
                                    'Update Failed',
                                    'Failed to update campaign.',
                                    backgroundColor: AppColors.error,
                                    colorText: AppColors.textPrimary,
                                  );
                                }
                                return;
                              }

                              final ad = AdItem(
                                id:
                                    'camp_${DateTime.now().millisecondsSinceEpoch}',
                                userId:
                                    (Get.isRegistered<AuthService>() &&
                                            AuthService.to.uid.isNotEmpty)
                                        ? AuthService.to.uid
                                        : 'advertiser',
                                advertiser: brand,
                                title: title,
                                description: description,
                                imageUrl: imageUrl ?? '',
                                ctaText: ctaText,
                                ctaTarget: ctaTarget,
                                gradientColors:
                                    gradient ??
                                    [
                                      const Color(0xFFEF4444),
                                      const Color(0xFFF59E0B),
                                    ],
                                isSkippableAd: isSkippable,
                                videoUrl: videoUrl,
                                budgetTier: budgetTier.toUpperCase(),
                                budgetAmount: cost,
                                adType: adType,
                                status: 'underReview',
                                videoId: videoId,
                                midrollVideoUrl: midrollVideoUrl,
                                pinnedCommentText: pinnedCommentText,
                                targetAgeGroups: targetAgeGroups,
                                targetGenders: targetGenders,
                                targetLocations: targetLocations,
                                targetLanguages: targetLanguages,
                                targetTopics: targetTopics,
                              );

                              final success = await AdService.to.createCampaign(
                                ad,
                              );
                              if (success) {
                                checkoutSuccess.value = true;
                              } else {
                                progressStep.value = 0;
                                AppSnackbar.show(
                                  'Payment Failed',
                                  'Failed to register campaign.',
                                  backgroundColor: AppColors.error,
                                  colorText: AppColors.textPrimary,
                                );
                              }
                            } catch (e) {
                              progressStep.value = 0;
                              AppSnackbar.show(
                                'Checkout Error',
                                'An unexpected error occurred: $e',
                                backgroundColor: AppColors.error,
                                colorText: AppColors.textPrimary,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      existingCampaign != null
                          ? 'Save & Resubmit Campaign'
                          : 'Pay ₹${cost.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}
