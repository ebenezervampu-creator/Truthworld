import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/storage_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';
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
                leading: Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                title: Text(
                  controller.tabTitles[controller.selectedIndex.value],
                  style: AppTextStyles.pageTitle.copyWith(
                    color: AppColors.textPrimary,
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
      backgroundColor: const Color(0xFF161616),
      child: Column(
        children: [
          _buildSidebarHeader(context),
          const Divider(color: AppColors.bgDivider),
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
    return Material(
      color: const Color(0xFF161616),
      child: SizedBox(
        width: 250,
        height: double.infinity,
        child: Column(
          children: [
            _buildSidebarHeader(context),
            const Divider(color: AppColors.bgDivider),
            Expanded(
              child: _buildSidebarItems(context, controller, isDrawer: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: AppColors.warning,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Truthworld',
                style: context.typography.logo.copyWith(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Advertiser Studio',
                style: AppTextStyles.badge.copyWith(
                  color: AppColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
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
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        for (int i = 0; i < controller.tabTitles.length; i++)
          Material(
            color: Colors.transparent,
            child: ListTile(
              selected: controller.selectedIndex.value == i,
              selectedTileColor: AppColors.warning.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              leading: Icon(
                icons[i],
                color: controller.selectedIndex.value == i
                    ? AppColors.warning
                    : AppColors.textSecondary,
                size: 20,
              ),
              title: Text(
                controller.tabTitles[i],
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: controller.selectedIndex.value == i
                      ? AppColors.warning
                      : AppColors.textSecondary,
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
          Text(
            'Performance Overview',
            style: AppTextStyles.sectionHeader.copyWith(
              fontSize: 18,
              color: AppColors.textPrimary,
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
              Expanded(
                child: Text(
                  'Recent Campaigns',
                  style: AppTextStyles.sectionHeader.copyWith(
                    fontSize: 18,
                    color: AppColors.textPrimary,
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
                  color: AppColors.warning,
                  size: 16,
                ),
                label: const Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
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
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.campaign_outlined,
            color: AppColors.textDisabled,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No Campaigns Launched Yet',
            style: AppTextStyles.sectionHeader.copyWith(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create and pay for a campaign to display it on Truthworld.',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textTertiary,
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
              Expanded(
                child: Text(
                  'My Ad Campaigns',
                  style: AppTextStyles.pageTitle.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showCreateCampaignWizard(context, controller),
                icon: const Icon(Icons.add, color: AppColors.bgPage, size: 18),
                label: const Text(
                  'Create Campaign',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: AppColors.bgPage,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
          Text(
            'Detailed Performance Reports',
            style: AppTextStyles.pageTitle.copyWith(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analyze click-through rates, format performance, and download detailed metrics.',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          _buildAnalyticsChartSection(context, controller),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Performance Breakdown by Format',
                  style: AppTextStyles.sectionHeader.copyWith(
                    fontSize: 18,
                    color: AppColors.textPrimary,
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
                  color: AppColors.warning,
                ),
                label: const Text(
                  'Export CSV',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.warning),
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
      if (rawType == 'scroll') typeLabel = 'Scroll Feed';
      if (rawType == 'search') typeLabel = 'Search Result';
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
        if (rawType == 'scroll') typeLabel = 'Scroll Feed';
        if (rawType == 'search') typeLabel = 'Search Result';
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
        'Search Result',
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
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.bgDivider),
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
                    color: AppColors.bgDivider,
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
                          bottom: BorderSide(color: AppColors.bgDivider),
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
        style: AppTextStyles.labelLarge.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.warning,
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
        style: AppTextStyles.labelLarge.copyWith(
          fontWeight: FontWeight.bold,
          color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
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
          .where((ad) => ad.userId == AuthService.to.uid && ad.isSkippableAd)
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
                const VerticalDivider(color: AppColors.bgDivider, width: 1),
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
                        color: const Color(0xFF161616),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: AppColors.textPrimary,
                              ),
                              onPressed: () {
                                controller.selectedAdForSubtitles.value = null;
                              },
                            ),
                            const Text(
                              'Back to Ads List',
                              style: TextStyle(
                                color: AppColors.textPrimary,
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select Video Ad to Translate',
              style: AppTextStyles.sectionHeader.copyWith(
                fontSize: 16,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(color: AppColors.bgDivider, height: 1),
          Expanded(
            child: campaigns.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No video campaigns available. Subtitles can only be added to Skippable Video ads.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textTertiary,
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
                              ? AppColors.warning.withValues(alpha: 0.08)
                              : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.05,
                              ),
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
                                color: AppColors.textPrimary,
                                size: 16,
                              ),
                            ),
                          ),
                          title: Text(
                            ad.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? AppColors.warning
                                  : AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '$langCount Language track${langCount == 1 ? "" : "s"}',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textTertiary,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.subtitles_outlined,
              size: 64,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a video campaign from the list to begin editing subtitles.',
              textAlign: TextAlign.center,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    final ad = controller.selectedAdForSubtitles.value!;
    final subs = ad.subtitles ?? {};

    return Container(
      color: const Color(0xFF161616),
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
                      style: AppTextStyles.sectionHeader.copyWith(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage language subtitles track and cue timings',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
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
                          valueColor: AlwaysStoppedAnimation(AppColors.bgPage),
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 16),
                label: Text(
                  controller.isSavingSubtitles.value
                      ? 'Saving...'
                      : 'Save Track',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: AppColors.bgPage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Tracks:',
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
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
                              selectedColor: AppColors.warning,
                              labelStyle: AppTextStyles.badge.copyWith(
                                color:
                                    controller
                                            .selectedLanguageForSubtitles
                                            .value ==
                                        lang['code']
                                    ? AppColors.bgPage
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              backgroundColor: const Color(0xFF1E1E1E),
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
                  color: AppColors.warning,
                ),
                tooltip: 'Add translated subtitles track',
                onPressed: () => _showAddSubtitlesTrackDialog(controller),
              ),
            ],
          ),
          const Divider(color: AppColors.bgDivider, height: 32),
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
                            color: AppColors.textDisabled,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No subtitle cues defined.',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
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
                              color: AppColors.warning,
                            ),
                            label: const Text(
                              'Add Cue',
                              style: TextStyle(
                                color: AppColors.warning,
                              ),
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
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Cue Segment'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.textDisabled),
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
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy WebVTT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.textDisabled),
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
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
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
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter cue subtitles text...',
                hintStyle: TextStyle(color: AppColors.textDisabled),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
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
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 30,
            child: TextFormField(
              initialValue: value,
              onChanged: onChanged,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 6,
                ),
                fillColor: Colors.black26,
                filled: true,
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPipelineProgressCard(String status, double progress) {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  status,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.bgDivider,
              valueColor: const AlwaysStoppedAnimation(AppColors.warning),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSubtitlesTrackDialog(AdvertiserPortalController controller) {
    String? selectedLang = 'hi';

    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161616),
          title: const Text(
            'Add Subtitles Track',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Translate your video campaign into another language using AI voice translation.',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgDivider,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedLang,
                    dropdownColor: const Color(0xFF161616),
                    iconEnabledColor: AppColors.warning,
                    isExpanded: true,
                    items: [
                      for (final lang in controller.supportedLanguages)
                        if (lang['code'] != 'en')
                          DropdownMenuItem(
                            value: lang['code'],
                            child: Text(
                              lang['name']!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedLang = val;
                      });
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
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                if (selectedLang != null) {
                  controller.startSubtitleTranslationSimulation(selectedLang!);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.bgPage,
              ),
              child: const Text('Translate Subtitles'),
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
          .where((ad) => ad.userId == AuthService.to.uid && ad.isSkippableAd)
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
                const VerticalDivider(color: AppColors.bgDivider, width: 1),
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
                        color: const Color(0xFF161616),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: AppColors.textPrimary,
                              ),
                              onPressed: () {
                                controller.selectedAdForAudio.value = null;
                              },
                            ),
                            const Text(
                              'Back to Ads List',
                              style: TextStyle(
                                color: AppColors.textPrimary,
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select Video Ad to Dub',
              style: AppTextStyles.sectionHeader.copyWith(
                fontSize: 16,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(color: AppColors.bgDivider, height: 1),
          Expanded(
            child: campaigns.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No video campaigns available. Audio dubs can only be requested on Skippable Video ads.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textTertiary,
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
                              ? AppColors.warning.withValues(alpha: 0.08)
                              : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.05,
                              ),
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
                                color: AppColors.textPrimary,
                                size: 16,
                              ),
                            ),
                          ),
                          title: Text(
                            ad.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? AppColors.warning
                                  : AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '$dubCount Audio track${dubCount == 1 ? "" : "s"} available',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textTertiary,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.translate_rounded,
              size: 64,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a video campaign from the list to manage audio voiceovers.',
              textAlign: TextAlign.center,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    final ad = controller.selectedAdForAudio.value!;
    final tracks = ad.audioTracks ?? {};

    return Container(
      color: const Color(0xFF161616),
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
                      style: AppTextStyles.sectionHeader.copyWith(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI voice cloning and audio dubbing configuration board',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: controller.isTranslatingAudio.value
                    ? null
                    : () => _showRequestAudioDubDialog(controller),
                icon: const Icon(Icons.translate_rounded, size: 16),
                label: const Text('Request Voice Dub'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: AppColors.bgPage,
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.bgDivider, height: 32),
          if (controller.isTranslatingAudio.value)
            _buildPipelineProgressCard(
              controller.audioStatusText.value,
              controller.audioProgress.value,
            )
          else ...[
            Text(
              'Configured Voiceover Layers',
              style: AppTextStyles.sectionHeader.copyWith(
                fontSize: 16,
                color: AppColors.textSecondary,
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
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.volume_up_rounded,
              color: AppColors.warning,
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
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isOriginal ? 'ORIGINAL' : 'AI CLONED',
              style: AppTextStyles.badge.copyWith(color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestAudioDubDialog(AdvertiserPortalController controller) {
    String? selectedLang = 'hi';
    String? selectedVoice = 'natural';

    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161616),
          title: const Text(
            'Request AI Voice Dubbing',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select target dub language and AI voice clone parameters.',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Target Language',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgDivider,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedLang,
                    dropdownColor: const Color(0xFF161616),
                    iconEnabledColor: AppColors.warning,
                    isExpanded: true,
                    items: [
                      for (final lang in controller.supportedLanguages)
                        if (lang['code'] != 'en')
                          DropdownMenuItem(
                            value: lang['code'],
                            child: Text(
                              lang['name']!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedLang = val;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Voice Style',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgDivider,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedVoice,
                    dropdownColor: const Color(0xFF161616),
                    iconEnabledColor: AppColors.warning,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'natural',
                        child: Text(
                          'Natural Tone Voice Clone',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'studio_male',
                        child: Text(
                          'Studio Narration (Male)',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'studio_female',
                        child: Text(
                          'Studio Narration (Female)',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedVoice = val;
                      });
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
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Get.back();
                if (selectedLang != null) {
                  controller.startAudioDubbingSimulation(selectedLang!);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.bgPage,
              ),
              child: const Text('Request Dubbing'),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.indigo.shade800.withValues(alpha: 0.5),
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
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'TRUTHWORLD FOR BUSINESS',
              style: AppTextStyles.badge.copyWith(
                color: AppColors.warning,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Reach Millions of Engaged Viewers',
            style: AppTextStyles.displaySmall.copyWith(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create skippable video ads, homepage banners, and recommendations targeting active communities on Truthworld.',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
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
                AppColors.success,
                'spend',
              ),
              _buildInteractiveStatCard(
                controller,
                'Impressions',
                formatNumber(totalImpressions),
                Icons.visibility_rounded,
                Colors.cyanAccent,
                'impressions',
              ),
              _buildInteractiveStatCard(
                controller,
                'Ad Clicks',
                formatNumber(totalClicks),
                Icons.touch_app_rounded,
                AppColors.brandHover,
                'clicks',
              ),
              _buildInteractiveStatCard(
                controller,
                'Avg. CTR',
                formatNumber(avgCtr, isPercentage: true),
                Icons.trending_up_rounded,
                Colors.pinkAccent,
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
    Color color,
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
              ? const Color(0xFF1E1B4B).withValues(alpha: 0.3)
              : const Color(0xFF161616),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.indigoAccent : AppColors.bgDivider,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.indigo.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : null,
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
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Text(
              value,
              style: AppTextStyles.pageTitle.copyWith(
                color: AppColors.textPrimary,
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
    var metricColor = AppColors.success;
    if (controller.selectedMetric.value == 'impressions') {
      metricTitle = 'Impressions Trend';
      metricColor = Colors.cyanAccent;
    }
    if (controller.selectedMetric.value == 'clicks') {
      metricTitle = 'Clicks Trend';
      metricColor = AppColors.brandHover;
    }
    if (controller.selectedMetric.value == 'ctr') {
      metricTitle = 'Click-Through Rate (CTR) Trend';
      metricColor = Colors.pinkAccent;
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
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bgDivider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$metricTitle (Last 7 Days)',
              style: AppTextStyles.sectionHeader.copyWith(
                fontSize: 16,
                color: AppColors.textPrimary,
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
                  labelStyle: TextStyle(color: AppColors.textTertiary),
                ),
                primaryYAxis: const NumericAxis(
                  axisLine: AxisLine(width: 0),
                  majorTickLines: MajorTickLines(size: 0),
                  majorGridLines: MajorGridLines(color: AppColors.bgDivider),
                  labelStyle: TextStyle(color: AppColors.textTertiary),
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
    final amountStr = campaign.budgetAmount != null
        ? '₹${campaign.budgetAmount!.toStringAsFixed(0)}'
        : '₹2,000';
    final isPaused = campaign.status == 'paused';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
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
                            style: AppTextStyles.badge.copyWith(
                              color: AppColors.warning,
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
                            color: AppColors.bgDivider,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            campaign.adType == 'video_sponsor'
                                ? 'Sponsor Ad'
                                : isSkippable
                                ? 'Video Ad'
                                : 'Feed Ad',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      campaign.title,
                      style: AppTextStyles.sectionHeader.copyWith(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      campaign.description,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
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
                  Text(
                    amountStr,
                    style: AppTextStyles.sectionHeader.copyWith(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    budgetStr,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        color: campaign.status == 'paused'
                            ? AppColors.textSecondary
                            : campaign.status == 'underReview'
                            ? AppColors.warning
                            : campaign.status == 'verification_rejected'
                            ? AppColors.error
                            : AppColors.success,
                        size: 8,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        campaign.status == 'paused'
                            ? 'Paused'
                            : campaign.status == 'underReview'
                            ? 'Under Review'
                            : campaign.status == 'verification_rejected'
                            ? 'Rejected'
                            : 'Active',
                        style: AppTextStyles.badge.copyWith(
                          color: campaign.status == 'paused'
                              ? AppColors.textTertiary
                              : campaign.status == 'underReview'
                              ? AppColors.warning
                              : campaign.status == 'verification_rejected'
                              ? AppColors.error
                              : AppColors.success,
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
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          middleText: campaign.moderationReason!,
                          middleTextStyle: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                          backgroundColor: const Color(0xFF161616),
                          textConfirm: 'OK',
                          confirmTextColor: AppColors.bgPage,
                          buttonColor: AppColors.warning,
                          onConfirm: Get.back,
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Why?',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.error,
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
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.report_problem_rounded,
                              color: AppColors.error,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${reports.length} User Report(s): "$reason"',
                                style: const TextStyle(
                                  color: AppColors.error,
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
                        onTap: () => AdService.to.toggleCampaignStatus(campaign.id),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.bgDivider,
                            borderRadius: BorderRadius.circular(4),
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
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.bgDivider,
                            borderRadius: BorderRadius.circular(4),
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
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            middleText:
                                'Are you sure you want to delete "${campaign.title}"?',
                            middleTextStyle: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            backgroundColor: const Color(0xFF161616),
                            textConfirm: 'Delete',
                            textCancel: 'Cancel',
                            confirmTextColor: AppColors.bgPage,
                            cancelTextColor: AppColors.textPrimary,
                            buttonColor: AppColors.error,
                            onConfirm: () {
                              AdService.to.deleteCampaign(campaign.id);
                              Get.back();
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.bgDivider,
                            borderRadius: BorderRadius.circular(4),
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
          if (campaign.status == 'verification_rejected') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.35),
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
                          TextSpan(
                            text: 'Rejection Error: ',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: campaign.moderationReason ??
                                'Violation of Community Guidelines',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textPrimary,
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
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: Get.back,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton(
              onPressed: () => controller.handleGoogleSignIn(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.bgPage,
                elevation: 4,
                shadowColor: AppColors.warning.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
              ),
              child: Text(
                'Start Advertisements',
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const Icon(
            Icons.campaign_rounded,
            color: AppColors.textPrimary,
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
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.bgDivider),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bgPage.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade900.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.indigoAccent.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.campaign_rounded,
                        color: AppColors.textPrimary,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Truthworld Ads',
                    style: context.typography.hero.copyWith(
                      fontSize: 28,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Grow your channel, brand, or business.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.warning,
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
                        AppColors.warning,
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => controller.handleGoogleSignIn(),
                      icon: const Icon(
                        Icons.login_rounded,
                        color: AppColors.bgPage,
                        size: 18,
                      ),
                      label: Text(
                        'Sign in with Google',
                        style: AppTextStyles.sectionHeader.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        foregroundColor: AppColors.bgPage,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'Access your advertiser dashboard, launch self-serve campaigns, and track click-through metrics instantly.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textTertiary,
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
        Icon(icon, color: AppColors.success, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.labelLarge.copyWith(
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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.textDisabled),
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.bgDivider,
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
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.textPrimary,
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
    final pickedMidrollFileName = ''.obs;
    final pickedBannerFileName = ''.obs;

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
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2A2A2A)),
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
                    color: Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF2A2A2A)),
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
                                  color: AppColors.warning.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
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
                                    style: AppTextStyles.pageTitle.copyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    'Industry Standard Campaign Manager & Delivery Setup',
                                    style: AppTextStyles.labelMedium.copyWith(
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
                              title: '3. Budget & Launch',
                              icon: Icons.rocket_launch_rounded,
                              currentStep: currentStep.value,
                              onTap: () {
                                currentStep.value = 3;
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

                      Widget buildRejectionBanner() {
                        if (existingCampaign?.status !=
                            'verification_rejected') {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.4),
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
                                    Text(
                                      'Campaign Rejected - Action Required',
                                      style: AppTextStyles.labelLarge.copyWith(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      existingCampaign?.moderationReason ??
                                          'Please update your campaign details below to address the violation and resubmit.',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textPrimary,
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
                            Text(
                              'Select Campaign Placement & Format',
                              style: AppTextStyles.sectionHeader.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Choose where your campaign creatives will be served across Truthworld platforms.',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textSecondary,
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
                                  'Search Result Banner',
                                  'search',
                                  adFormat.value == 'search',
                                  () => adFormat.value = 'search',
                                  Icons.search_rounded,
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
                                  color: const Color(0xFF2D1B69).withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.stars_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Combined 4-in-1 Video Sponsor Suite (POPULAR)',
                                          style: AppTextStyles.labelLarge.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '1. 5-Sec Pre-Roll Sponsor Bumper (Plays BEFORE main video starts: "This video is brought to you by [Brand]")\n'
                                      '2. 7-Minute Skippable Mid-roll Video Ad\n'
                                      '3. Recommended Videos Promoted Feed Banner\n'
                                      '4. Interactive Sponsored Pinned Comment below video',
                                      style: AppTextStyles.labelMedium.copyWith(
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
                            Text(
                              'Campaign Details & Media Creatives',
                              style: AppTextStyles.sectionHeader.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
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
                                Text(
                                  'Media Creative Attachments',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
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
                                      pickedMidrollFileName.value = 'Demo Midroll (Bee HD)';
                                      pickedBannerFileName.value = 'Demo Banner (Tech)';
                                      AppSnackbar.show(
                                        '4-in-1 Sponsor Requirements',
                                        'Loaded all 4 creative requirements for demo setup.',
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.flash_on_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    label: const Text('Auto-Fill Requirements (Demo)'),
                                    style: TextButton.styleFrom(
                                      backgroundColor: AppColors.warning,
                                      foregroundColor: AppColors.bgPage,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Video input (Input 1)
                            Text(
                              isSponsor
                                  ? '1. 5-Sec Pre-Roll Sponsor Bumper (Pick Video or Audio from Device) [Required]'
                                  : isSkippable
                                  ? 'Video Creative (Pick from Device) [Required]'
                                  : 'Video Creative (Pick from Device) [Optional]',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInputField(
                                    '',
                                    videoUrlController,
                                    'Selected video/audio file path',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _pickDeviceMediaFile(
                                    context: context,
                                    fileType: FileType.any,
                                    targetController: videoUrlController,
                                    pickedFileNameNotifier: pickedBumperFileName,
                                    maxDurationSeconds: 5.0,
                                  ),
                                  icon: const Icon(
                                    Icons.file_upload_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  label: const Text('Pick File (Device)'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.warning,
                                    foregroundColor: AppColors.bgPage,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _showChannelVideosPicker(
                                      context,
                                      controller,
                                      onSelected: (video) {
                                        videoUrlController.text =
                                            video['videoUrl'] ?? '';
                                        pickedBumperFileName.value =
                                            video['title'] ?? '';
                                        selectedVideoTitle.value =
                                            video['title'] ?? '';
                                        selectedVideoId.value =
                                            video['id'] ?? '';
                                      },
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.video_library_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  label: const Text('Presets'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.bgDivider,
                                    foregroundColor: AppColors.textPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Obx(() {
                              if (pickedBumperFileName.value.isNotEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '📁 Selected media: ${pickedBumperFileName.value}',
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }),
                            const SizedBox(height: 16),

                            // Sponsor Midroll Video (Input 2)
                            if (isSponsor) ...[
                              Text(
                                '2. 7-Minute Skippable Mid-roll Video (Pick Video from Device) [Required]',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInputField(
                                      '',
                                      midrollVideoUrlController,
                                      'Selected midroll video file path',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _pickDeviceMediaFile(
                                      context: context,
                                      fileType: FileType.video,
                                      targetController: midrollVideoUrlController,
                                      pickedFileNameNotifier: pickedMidrollFileName,
                                    ),
                                    icon: const Icon(
                                      Icons.video_collection_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    label: const Text('Pick Video (Device)'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.warning,
                                      foregroundColor: AppColors.bgPage,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _showChannelVideosPicker(
                                        context,
                                        controller,
                                        onSelected: (video) {
                                          midrollVideoUrlController.text =
                                              video['videoUrl'] ?? '';
                                          pickedMidrollFileName.value =
                                              video['title'] ?? '';
                                        },
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.video_library_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    label: const Text('Presets'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.bgDivider,
                                      foregroundColor: AppColors.textPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Obx(() {
                                if (pickedMidrollFileName.value.isNotEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      '📁 Selected media: ${pickedMidrollFileName.value}',
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }),
                              const SizedBox(height: 16),
                            ],

                            // Image creative link (Input 3)
                            if (!isSkippable || isSponsor) ...[
                              Text(
                                isSponsor
                                    ? '3. Sponsor Brand Banner Image (Pick Image from Device) [Required]'
                                    : isScroll
                                    ? 'Image Banner (Pick Image from Device) [Required for Scroll Ads]'
                                    : 'Image Banner (Pick Image from Device) [Optional]',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInputField(
                                      '',
                                      imageUrlController,
                                      'Selected banner image file path',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _pickDeviceMediaFile(
                                      context: context,
                                      fileType: FileType.image,
                                      targetController: imageUrlController,
                                      pickedFileNameNotifier: pickedBannerFileName,
                                    ),
                                    icon: const Icon(
                                      Icons.image_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    label: const Text('Pick Image (Device)'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.warning,
                                      foregroundColor: AppColors.bgPage,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _showImagePicker(
                                        context,
                                        onSelectedUrl: (url) {
                                          imageUrlController.text = url;
                                          pickedBannerFileName.value =
                                              'Preset Banner Sample';
                                        },
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.photo_library_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    label: const Text('Presets'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.bgDivider,
                                      foregroundColor: AppColors.textPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Obx(() {
                                if (pickedBannerFileName.value.isNotEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      '📁 Selected media: ${pickedBannerFileName.value}',
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }),
                              const SizedBox(height: 16),
                            ],

                            // Sponsor Interactive Pinned Comment
                            if (isSponsor) ...[
                              Text(
                                '4. Sponsor Interactive Pinned Comment Text (Viewers interact below video) [Required]',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.textSecondary,
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

                      // STEP 3: Budget & Launch
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Campaign Budget & Delivery Plan',
                            style: AppTextStyles.sectionHeader.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
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
                            Text(
                              'Select Fallback / Banner Theme',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textSecondary,
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
                                              ? AppColors.warning
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
                    color: Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border(
                      top: BorderSide(color: Color(0xFF2A2A2A)),
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
                          label: Text(currentStep.value > 1 ? 'Back' : 'Cancel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.bgDivider,
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        if (currentStep.value < 3)
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
                              currentStep.value++;
                            },
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            label: const Text('Next Step'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: AppColors.bgPage,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
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
                                existingCampaign: existingCampaign,
                              );
                            },
                            icon: const Icon(
                              Icons.rocket_launch_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            label: const Text('Proceed to Checkout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: AppColors.bgPage,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
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
                ? AppColors.warning.withValues(alpha: 0.15)
                : isDone
                ? const Color(0xFF222222)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? AppColors.warning
                  : isDone
                  ? AppColors.textSecondary.withValues(alpha: 0.3)
                  : const Color(0xFF333333),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isDone ? Icons.check_circle_rounded : icon,
                color: isActive
                    ? AppColors.warning
                    : isDone
                    ? Colors.white
                    : AppColors.textDisabled,
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isActive
                        ? AppColors.warning
                        : isDone
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
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
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Video Creative',
                      style: AppTextStyles.sectionHeader.copyWith(
                        fontSize: 18,
                        color: AppColors.textPrimary,
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
                const Divider(color: AppColors.bgDivider),
                const SizedBox(height: 8),
                Text(
                  'Pick from your channel videos or select a high-quality video preset.',
                  style: AppTextStyles.labelLarge.copyWith(
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
                          color: const Color(0xFF1E1E1E),
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 60,
                                height: 36,
                                color: AppColors.bgPage,
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
                                    style: AppTextStyles.labelLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
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
                                      color: AppColors.warning,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Preset',
                                      style: TextStyle(
                                        color: AppColors.bgPage,
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
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textTertiary,
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
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pick Sponsor Banner Image',
                    style: AppTextStyles.sectionHeader.copyWith(
                      fontSize: 18,
                      color: AppColors.textPrimary,
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
              const Divider(color: AppColors.bgDivider),
              const SizedBox(height: 8),
              Text(
                'Select a brand image from sample presets for the recommended videos list.',
                style: AppTextStyles.labelLarge.copyWith(
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
                      color: const Color(0xFF1E1E1E),
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
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
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

  Future<void> _pickDeviceMediaFile({
    required BuildContext context,
    required FileType fileType,
    required TextEditingController targetController,
    required RxString pickedFileNameNotifier,
    List<String>? allowedExtensions,
    double? maxDurationSeconds,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;

        // If a max duration limit is specified (e.g. 5 seconds for Sponsor Ads), validate duration
        if (maxDurationSeconds != null) {
          try {
            VideoPlayerController? tempController;
            if (pickedFile.bytes != null) {
              final ext = pickedFile.extension?.toLowerCase() ?? '';
              final isAudio = ext == 'mp3' ||
                  ext == 'wav' ||
                  ext == 'm4a' ||
                  ext == 'aac' ||
                  ext == 'ogg';
              final mime = isAudio ? 'audio/mp3' : 'video/mp4';
              final dataUri =
                  Uri.dataFromBytes(pickedFile.bytes!, mimeType: mime)
                      .toString();
              tempController =
                  VideoPlayerController.networkUrl(Uri.parse(dataUri));
            } else if (pickedFile.path != null &&
                pickedFile.path!.isNotEmpty) {
              tempController = VideoPlayerController.networkUrl(
                Uri.parse(pickedFile.path!),
              );
            }

            if (tempController != null) {
              await tempController.initialize();
              final durSec =
                  tempController.value.duration.inMilliseconds / 1000.0;
              await tempController.dispose();

              if (durSec > maxDurationSeconds) {
                AppSnackbar.show(
                  'Media Exceeds Duration Limit',
                  'Sponsor video/audio ads must be 5 seconds or less in duration. Selected file duration is ${durSec.toStringAsFixed(1)} seconds.',
                  backgroundColor: AppColors.error,
                  colorText: Colors.white,
                );
                return;
              }
            }
          } catch (durErr) {
            debugPrint(
              '[AdvertiserPortal] Duration validation notice: $durErr',
            );
          }
        }

        pickedFileNameNotifier.value = pickedFile.name;

        String? finalPath;
        if (pickedFile.bytes != null) {
          try {
            final storageService = Get.isRegistered<StorageService>()
                ? Get.find<StorageService>()
                : Get.put(StorageService());
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final storagePath =
                'ad_campaigns_media/${timestamp}_${pickedFile.name}';
            final ext = pickedFile.extension?.toLowerCase() ?? '';
            var mimeType = fileType == FileType.image
                ? 'image/jpeg'
                : fileType == FileType.video
                    ? 'video/mp4'
                    : 'application/octet-stream';
            if (ext == 'png') mimeType = 'image/png';
            if (ext == 'webp') mimeType = 'image/webp';
            if (ext == 'gif') mimeType = 'image/gif';
            if (ext == 'webm') mimeType = 'video/webm';

            finalPath = await storageService.uploadFileFromBytes(
              path: storagePath,
              bytes: pickedFile.bytes!,
              mimeType: mimeType,
            );
          } catch (uploadErr) {
            debugPrint(
              '[AdvertiserPortal] Remote storage upload skipped: $uploadErr. Using local file path.',
            );
            finalPath = (pickedFile.path != null && pickedFile.path!.isNotEmpty)
                ? pickedFile.path
                : pickedFile.name;
          }
        } else if (pickedFile.path != null && pickedFile.path!.isNotEmpty) {
          finalPath = pickedFile.path;
        } else {
          finalPath = pickedFile.name;
        }

        targetController.text = finalPath ?? pickedFile.name;

        AppSnackbar.show(
          'Media File Selected',
          'Selected ${pickedFile.name} from device.',
        );
      }
    } catch (e) {
      debugPrint('File picker error: $e');
      AppSnackbar.show(
        'File Selection Error',
        'Could not pick file from device: $e',
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
              ? const Color(0xFF1E1B4B).withValues(alpha: 0.3)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.indigoAccent : AppColors.bgDivider,
            width: 1.5,
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
              style: AppTextStyles.badge.copyWith(
                color: isSelected
                    ? AppColors.textPrimary
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
                    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'POPULAR (4-in-1)',
                  style: TextStyle(
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
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textDisabled),
            fillColor: const Color(0xFF1C1C1C),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
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
              ? const Color(0xFF1E1B4B).withValues(alpha: 0.3)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.indigoAccent : AppColors.bgDivider,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Colors.indigoAccent : AppColors.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tierName,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              cost,
              style: AppTextStyles.sectionHeader.copyWith(
                fontSize: 16,
                color: AppColors.warning,
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
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.bgDivider),
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
                          AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        progressStep.value == 1
                            ? 'Securing checkout channel...'
                            : progressStep.value == 2
                            ? 'Authorizing payment method...'
                            : 'Finalizing campaign launch...',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 64,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Campaign Created Successfully!',
                        style: AppTextStyles.sectionHeader.copyWith(
                          fontSize: 18,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your advertisement has been submitted for moderation. Once approved by Gemini, it will go live.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: Get.back,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.bgPage,
                          minimumSize: const Size(140, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Stripe Checkout',
                        style: AppTextStyles.sectionHeader.copyWith(
                          fontSize: 18,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.bgDivider, height: 20),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ad Campaign (${budgetTier.toUpperCase()})',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '₹${cost.toStringAsFixed(0)}',
                        style: AppTextStyles.sectionHeader.copyWith(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                    onPressed: () {
                      progressStep.value = 1;
                      Future.delayed(const Duration(milliseconds: 600), () {
                        progressStep.value = 2;
                        Future.delayed(const Duration(milliseconds: 600), () {
                          progressStep.value = 3;
                          Future.delayed(
                            const Duration(milliseconds: 600),
                            () async {
                              if (existingCampaign != null) {
                                final ad = existingCampaign.copyWith(
                                  advertiser: brand,
                                  title: title,
                                  description: description,
                                  imageUrl: imageUrl ?? '',
                                  ctaText: ctaText,
                                  ctaTarget: ctaTarget,
                                  gradientColors:
                                      gradient ?? existingCampaign.gradientColors,
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
                                id: 'camp_${DateTime.now().millisecondsSinceEpoch}',
                                userId: AuthService.to.uid,
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
                            },
                          );
                        });
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: AppColors.bgPage,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      existingCampaign != null
                          ? 'Save & Resubmit Campaign'
                          : 'Pay ₹${cost.toStringAsFixed(0)}',
                      style: AppTextStyles.sectionHeader.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
