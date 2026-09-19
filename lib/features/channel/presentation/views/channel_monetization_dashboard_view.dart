import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_payout_calculator.dart';
import 'package:truthworld/core/services/infrastructure_metering_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/views/channel/monetization/monetization_widgets.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/channel_wallet_card.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/channel/presentation/views/channel/monetization/monetization_widgets.dart';

/// Full monetization, revenue share, and cloud infrastructure dashboard for channels.
class ChannelMonetizationDashboardView extends StatelessWidget {
  final Channel channel;

  const ChannelMonetizationDashboardView({
    required this.channel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      ChannelMonetizationController(initialChannel: channel),
      tag: channel.id,
    );

    final typography = context.twTypography;

    return Obx(() {
      final currentChannel = controller.channel;
      final isCustom = currentChannel.channelType == ChannelType.custom;

      final totalGross = controller.adRevenue +
          controller.premiumSubRevenue +
          controller.tipsRevenue +
          controller.membershipsRevenue;

      final infraCost = InfrastructureMeteringService.calculateInfraCost(
        storageUsedBytes: controller.storageUsedBytes,
        bandwidthUsedBytes: controller.bandwidthUsedBytes,
      );

      final payoutBreakdown = ChannelPayoutCalculator.calculatePayout(
        currentChannel,
        adRevenue: controller.adRevenue,
        premiumSubRevenue: controller.premiumSubRevenue,
        tipsRevenue: controller.tipsRevenue,
        membershipsRevenue: controller.membershipsRevenue,
        grossRevenue: totalGross,
        actualInfraCost: infraCost,
      );

      final videoWithdrawalEligibility =
          ChannelPayoutCalculator.calculateVideoWithdrawalEligibility(
        channel: currentChannel,
        videoId: currentChannel.featuredVideoIds.isNotEmpty
            ? currentChannel.featuredVideoIds.first
            : currentChannel.id,
        videoRevenue: controller.singleVideoRevenue,
        videoWatchTimeMinutes: controller.singleVideoWatchTimeMinutes,
      );

      return Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: AppBar(
          backgroundColor: AppColors.bgSurface,
          title: Text(
            'Monetization & Infrastructure',
            style: typography.headline.copyWith(color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Scheduled Change Banner (If Pending)
              if (currentChannel.pendingChannelType != null) ...[
                ChannelScheduledChangeBanner(controller: controller),
                const SizedBox(height: 16),
              ],

              // $10 Free Trial Credit Welcome Banner
              ChannelFreeTrialBanner(controller: controller),
              const SizedBox(height: 16),

              // Channel Header Card (Shows Channel Type & Days Left To Switch)
              ChannelMonetizationHeaderCard(
                controller: controller,
                isCustom: isCustom,
              ),
              const SizedBox(height: 20),

              // Channel Wallet & Top-Up Card
              ChannelWalletCard(channel: currentChannel),
              const SizedBox(height: 20),

              // Day 1 Earning & 10-Hour Video Withdrawal Rule Card
              ChannelWithdrawalRulesCard(
                eligibility: videoWithdrawalEligibility,
                isCustom: isCustom,
              ),
              const SizedBox(height: 20),

              // Custom Channel Plans & Feature Breakdown ("What You Get")
              ChannelPlansBreakdownSection(
                controller: controller,
                isCustom: isCustom,
              ),
              const SizedBox(height: 20),

              // Revenue Breakdown Section
              ChannelRevenueBreakdownSection(
                controller: controller,
                breakdown: payoutBreakdown,
                isCustom: isCustom,
              ),
              const SizedBox(height: 20),

              // Custom Channel Infrastructure Section (if Custom)
              if (isCustom) ...[
                ChannelInfrastructureSection(
                  controller: controller,
                  infraCost: infraCost,
                  onStorageTopup: () => showStorageTopupSheet(context, controller),
                  onBandwidthTopup: () => showBandwidthTopupSheet(context, controller),
                ),
                const SizedBox(height: 20),
                const ChannelZeroLossSafeguardCard(),
                const SizedBox(height: 20),
              ],

              // Action / Upgrade Section
              ChannelTierUpgradeCard(
                controller: controller,
                isCustom: isCustom,
              ),
            ],
          ),
        ),
      );
    });
  }
}
