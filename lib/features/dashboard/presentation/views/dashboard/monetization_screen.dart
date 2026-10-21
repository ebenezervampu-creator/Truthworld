import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/pages/revenue/revenue_analytics_widgets.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/monetization_components.dart';
import 'package:truthworld/theme/app_colors.dart';

export 'package:truthworld/features/analytics/presentation/pages/revenue/revenue_analytics_widgets.dart';
export 'monetization/monetization_components.dart';

/// Unified Studio Earnings & Revenue Screen.
/// Seamlessly merges all features from the Earnings page and the Revenue Analytics page into
/// one cohesive, high-performance creator monetization hub.
class MonetizationScreen extends StatelessWidget {
  const MonetizationScreen({
    this.isDarkMode = true,
    this.initialTabIndex,
    this.pageTitle = 'Earnings & Monetization',
    super.key,
  });

  final bool isDarkMode;
  final int? initialTabIndex;
  final String pageTitle;

  /// Target watch time in hours required for cash withdrawal on standard channels.
  static const double cashOutWatchHoursThreshold = 10;

  static const List<({IconData icon, String label})> _subTabs = [
    (icon: Icons.dashboard_customize_rounded, label: 'All Features'),
    (icon: Icons.account_balance_wallet_rounded, label: 'Revenue & Payouts'),
    (icon: Icons.monetization_on_rounded, label: 'Ways You Earn'),
    (icon: Icons.video_library_rounded, label: 'Video Eligibility'),
    (icon: Icons.stars_rounded, label: 'Tier & Rules'),
  ];

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    final argChannelId = (args['channelId'] as String?) ?? '';
    final argChannelName = (args['channelName'] as String?) ?? '';
    final argRevenueChange = (args['revenueChange'] as String?) ?? '';

    final targetChannelId = argChannelId.isNotEmpty ? argChannelId : uid;

    final controller = Get.isRegistered<DashboardController>()
        ? Get.find<DashboardController>()
        : Get.put(DashboardController(channelId: targetChannelId.isNotEmpty ? targetChannelId : 'creator_default'));

    final revController = RevenueAnalyticsController.to;

    final effectiveChannelId = argChannelId.isNotEmpty
        ? argChannelId
        : (controller.channelId.isNotEmpty
            ? controller.channelId
            : (controller.currentChannel.value?.id.isNotEmpty == true
                ? controller.currentChannel.value!.id
                : uid));

    final effectiveChannelName = argChannelName.isNotEmpty
        ? argChannelName
        : (controller.currentChannel.value?.name ?? 'Channel');

    final effectiveRevChange = argRevenueChange.isNotEmpty
        ? argRevenueChange
        : (controller.channelStats['revenueChange']?.toString() ?? '+₹0.00');

    if (initialTabIndex != null) {
      revController.selectedEarningsTab.value = initialTabIndex!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (effectiveChannelId.isNotEmpty &&
          revController.channelId.value != effectiveChannelId) {
        revController.loadRevenueAnalytics(
          effectiveChannelId,
          chName: effectiveChannelName,
          change: effectiveRevChange,
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Obx(() {
          final chName = revController.channelName.value.isNotEmpty
              ? revController.channelName.value
              : (controller.currentChannel.value?.name ?? '');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pageTitle,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              if (chName.isNotEmpty)
                Text(
                  chName,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
            ],
          );
        }),
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Get.back<void>();
            } else if (Get.isRegistered<DashboardController>()) {
              Get.find<DashboardController>().setSelectedIndex(1);
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Earnings & Analytics',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () async {
              revController.refreshData();
              controller.refreshChannelData();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        if ((controller.rxIsLoading.value || revController.isLoading) &&
            controller.currentChannel.value == null) {
          return const StudioLoadingIndicator(
            message: 'Loading monetization dashboard...',
          );
        }
        final channel = controller.currentChannel.value;
              final isCustom = channel?.channelType == ChannelType.custom;
              final selectedTab = revController.selectedEarningsTab.value;

              final mediaQuery = MediaQuery.of(context);
              final isMobile = mediaQuery.size.width < 600;
              final padding = EdgeInsets.all(isMobile ? 16.0 : 20.0);

              return RefreshIndicator(
                color: Colors.white,
                backgroundColor: const Color(0xFF1E1E1E),
                onRefresh: () async {
                  await revController.refreshData();
                  controller.refreshChannelData();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonetizationHeaderSection(
                        channel: channel,
                        isMonetized: controller.isChannelMonetizationActive,
                      ),
                      const SizedBox(height: 16),
                      _buildEarningsSubTabBar(revController, isMobile),
                      const SizedBox(height: 20),
                      ..._buildTabContent(
                        context,
                        selectedTab,
                        controller,
                        revController,
                        channel,
                        isCustom,
                      ),
                    ],
                  ),
                ),
              );
            }),
    );
  }

  Widget _buildEarningsSubTabBar(
    RevenueAnalyticsController revController,
    bool isMobile,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_subTabs.length, (index) {
          final tab = _subTabs[index];
          final isSelected = revController.selectedEarningsTab.value == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                revController.selectedEarningsTab.value = index;
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : AppColors.bgDivider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 16,
                      color: isSelected ? Colors.black : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color:
                            isSelected ? Colors.black : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildTabContent(
    BuildContext context,
    int selectedTab,
    DashboardController controller,
    RevenueAnalyticsController revController,
    Channel? channel,
    bool isCustom,
  ) {
    switch (selectedTab) {
      case 1:
        // Revenue & Payouts Tab
        return [
          buildRevenueHeroMetricCard(revController),
          const SizedBox(height: 18),
          if (channel != null) ...[
            ChannelAccountHubCard(
              channel: channel,
              controller: controller,
              revController: revController,
            ),
            const SizedBox(height: 18),
          ] else ...[
            buildWithdrawalThresholdCard(context, revController),
            const SizedBox(height: 14),
            RevenueWithdrawalSummaryCard(controller: controller),
            const SizedBox(height: 18),
          ],
          buildDirectBankAccountCard(context, revController),
          const SizedBox(height: 14),
          buildCreatorKycCard(context, revController),
        ];

      case 2:
        // Ways You Earn Tab
        return [
          buildRevenueSectionHeader(
            title: 'Ways You Earned',
            badge: 'All Active Streams',
          ),
          const SizedBox(height: 14),
          buildMembershipsStreamCard(revController),
          const SizedBox(height: 14),
          buildSuperchatStreamCard(revController),
          const SizedBox(height: 14),
          buildAdRevenueStreamCard(revController),
          const SizedBox(height: 14),
          buildWatchTimeStreamCard(revController),
          const SizedBox(height: 14),
          const PremiumSubsRevenueCard(),
          const SizedBox(height: 24),
          buildRevenueDistributionCard(revController),
        ];

      case 3:
        // Video Eligibility Tab
        return [
          PerVideoWithdrawalSection(controller: controller),
        ];

      case 4:
        // Tier & Rules Tab
        return [
          ChannelTypeCard(channel: channel),
          const SizedBox(height: 24),
          PolicyNoticeCard(
            isCustom: isCustom,
            isMonetized: controller.isChannelMonetizationActive,
          ),
          const SizedBox(height: 24),
          PartnerEligibilitySection(
            isCustom: isCustom,
            isChannelMonetized: controller.isChannelMonetizationActive,
          ),
          const SizedBox(height: 24),
          buildPayoutAndUsabilityCard(revController),
        ];

      case 0:
      default:
        // All Features Combined (Seamless comprehensive Earnings page)
        return [
          // 1. Hero Revenue Metric Card
          buildRevenueHeroMetricCard(revController),
          const SizedBox(height: 18),

          // 2. Unified Channel Account Hub (Wallet + Revenue + Cash Out + Activity Feed)
          if (channel != null) ...[
            ChannelAccountHubCard(
              channel: channel,
              controller: controller,
              revController: revController,
            ),
            const SizedBox(height: 18),
          ] else ...[
            buildWithdrawalThresholdCard(context, revController),
            const SizedBox(height: 14),
            RevenueWithdrawalSummaryCard(controller: controller),
            const SizedBox(height: 18),
          ],

          // 3. Direct Bank Account Arrangement
          buildDirectBankAccountCard(context, revController),
          const SizedBox(height: 14),

          // 4. Creator KYC Verification
          buildCreatorKycCard(context, revController),
          const SizedBox(height: 24),

          // 5. Ways You Earn (Active Streams)
          buildRevenueSectionHeader(
            title: 'Ways You Earned',
            badge: 'All Active Streams',
          ),
          const SizedBox(height: 14),
          buildMembershipsStreamCard(revController),
          const SizedBox(height: 14),
          buildSuperchatStreamCard(revController),
          const SizedBox(height: 14),
          buildAdRevenueStreamCard(revController),
          const SizedBox(height: 14),
          buildWatchTimeStreamCard(revController),
          const SizedBox(height: 14),
          const PremiumSubsRevenueCard(),
          const SizedBox(height: 24),
          buildRevenueDistributionCard(revController),
          const SizedBox(height: 24),

          // 8. Per-Video Cash-Out Eligibility (1,000 Views & 10 Hours)
          PerVideoWithdrawalSection(controller: controller),
          const SizedBox(height: 24),

          // 9. Channel Infrastructure & Tier
          ChannelTypeCard(channel: channel),
          const SizedBox(height: 24),

          // 10. Platform Policy Notices & Eligibility
          PolicyNoticeCard(
            isCustom: isCustom,
            isMonetized: controller.isChannelMonetizationActive,
          ),
          const SizedBox(height: 24),
          PartnerEligibilitySection(
            isCustom: isCustom,
            isChannelMonetized: controller.isChannelMonetizationActive,
          ),
          const SizedBox(height: 24),

          // 11. Platform Payout Guarantee & AI Usability
          buildPayoutAndUsabilityCard(revController),
        ];
    }
  }

}
