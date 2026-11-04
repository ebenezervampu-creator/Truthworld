import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/services/infrastructure_metering_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/widgets/revenue_withdrawal_dialog.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';

/// GetX controller managing channel monetization state, balances, and tier transitions.
class ChannelMonetizationController extends GetxController {
  final Channel initialChannel;

  ChannelMonetizationController({required this.initialChannel});

  late final Rx<Channel> channelRx;
  Channel get channel => channelRx.value;

  final RxBool isUpdatingRx = false.obs;
  bool get isUpdating => isUpdatingRx.value;

  final RxString selectedPlanId = 'starter_15'.obs;
  final RxBool autoPayEnabled = true.obs;
  final ChannelWalletService walletService = ChannelWalletService();

  void toggleAutoPay([bool? value]) {
    autoPayEnabled.value = value ?? !autoPayEnabled.value;
  }

  @override
  void onInit() {
    super.onInit();
    channelRx = initialChannel.obs;
    if (initialChannel.infraConfig != null) {
      selectedPlanId.value = initialChannel.infraConfig!.planTier;
    }
  }

  SpendableBalance get spendableBalance {
    final isCustom = channel.channelType == ChannelType.custom;
    final membershipPlatformCutRate = (!isCustom && channel.noAdsForMembers)
        ? 0.30
        : (!isCustom ? 0.10 : 0.0);
    final membershipPlatformCut = membershipsRevenue * membershipPlatformCutRate;
    final creatorMemberships = membershipsRevenue * (1.0 - membershipPlatformCutRate);
    final creatorTips = isCustom ? tipsRevenue : (tipsRevenue * 0.90);
    final platformTips = isCustom ? 0.0 : (tipsRevenue * 0.10);

    final totalCreatorRevenue =
        adRevenue + premiumSubRevenue + creatorTips + creatorMemberships;
    final platformCut = isCustom
        ? 0.0
        : (((adRevenue > 0 ? adRevenue / 0.70 : 0.0) * 0.30) +
            ((premiumSubRevenue > 0 ? premiumSubRevenue / 0.70 : 0.0) * 0.30) +
            platformTips +
            membershipPlatformCut);
    final grossTotal = totalCreatorRevenue + platformCut;
    return walletService.getSpendableBalance(
      channel: channel,
      rawTotalRevenue: grossTotal,
      withdrawableRevenue: totalCreatorRevenue,
      lockedRevenue: platformCut,
    );
  }

  // Authentic Firestore channel revenue totals with zero mock amounts
  double get adRevenue => channel.adsRevenueTotal;
  double get premiumSubRevenue => channel.premiumSubsRevenueTotal;
  double get tipsRevenue => channel.superchatRevenueTotal > 0
      ? channel.superchatRevenueTotal
      : (Get.isRegistered<DashboardController>()
          ? Get.find<DashboardController>().rxSuperchatRevenue.value
          : 0.0);
  double get membershipsRevenue => channel.membershipRevenueTotal > 0
      ? channel.membershipRevenueTotal
      : (Get.isRegistered<DashboardController>()
          ? Get.find<DashboardController>().rxMembershipsRevenue.value
          : 0.0);

  // Real channel video metrics for 1,000 views & 10-hour withdrawal rule
  int get singleVideoWatchTimeMinutes => channel.metrics.totalWatchTimeMinutes;
  int get singleVideoViews => channel.metrics.totalViews;
  double get singleVideoRevenue => adRevenue + premiumSubRevenue;

  // Authentic custom channel infra consumption from infraConfig
  int get storageUsedBytes => channel.infraConfig?.storageUsedBytes ?? 0;
  int get bandwidthUsedBytes => channel.infraConfig?.bandwidthUsedBytesThisMonth ?? 0;

  int calculateDaysLeftToSwitch() {
    final now = DateTime.now();
    final effectiveDate = channel.pendingTypeEffectiveDate?.toDate() ??
        DateTime(now.year, now.month + 1);
    final difference = effectiveDate.difference(now).inDays + 1;
    return max(0, difference);
  }

  ChannelController get channelController {
    if (Get.isRegistered<ChannelController>()) {
      return Get.find<ChannelController>();
    }
    return Get.put(ChannelController());
  }

  Future<void> scheduleTierChange() async {
    final controller = channelController;
    final ch = channel;
    final newType = ch.channelType == ChannelType.standard
        ? ChannelType.custom
        : ChannelType.standard;

    isUpdatingRx.value = true;

    final success = await controller.scheduleChannelTypeChange(
      ch.id,
      newType,
    );
    if (success) {
      final now = DateTime.now();
      final effectiveDate = DateTime(now.year, now.month + 1);
      final effectiveTimestamp = Timestamp.fromDate(effectiveDate);

      channelRx.value = Channel(
        id: ch.id,
        name: ch.name,
        nameLowercase: ch.nameLowercase,
        handle: ch.handle,
        handleLowercase: ch.handleLowercase,
        description: ch.description,
        avatarUrl: ch.avatarUrl,
        bannerUrl: ch.bannerUrl,
        ownerId: ch.ownerId,
        createdAt: ch.createdAt,
        updatedAt: Timestamp.now(),
        subscriberCount: ch.subscriberCount,
        videoCount: ch.videoCount,
        metrics: ch.metrics,
        status: ch.status,
        isVerified: ch.isVerified,
        category: ch.category,
        categories: ch.categories,
        language: ch.language,
        monetizationTier: ch.monetizationTier,
        channelType: ch.channelType,
        infraConfig: ch.infraConfig,
        pendingChannelType: newType,
        pendingTypeEffectiveDate: effectiveTimestamp,
        nextBillingCycleDate: effectiveTimestamp,
      );

      AppSnackbar.success(
        'Tier change to ${newType.name.toUpperCase()} channel scheduled for ${effectiveDate.day}/${effectiveDate.month}/${effectiveDate.year}.',
        title: 'Switch Scheduled',
      );
    }
    isUpdatingRx.value = false;
  }

  Future<void> cancelScheduledChange() async {
    final controller = channelController;
    final ch = channel;

    isUpdatingRx.value = true;

    final success = await controller.cancelScheduledChannelTypeChange(ch.id);
    if (success) {
      channelRx.value = Channel(
        id: ch.id,
        name: ch.name,
        nameLowercase: ch.nameLowercase,
        handle: ch.handle,
        handleLowercase: ch.handleLowercase,
        description: ch.description,
        avatarUrl: ch.avatarUrl,
        bannerUrl: ch.bannerUrl,
        ownerId: ch.ownerId,
        createdAt: ch.createdAt,
        updatedAt: Timestamp.now(),
        subscriberCount: ch.subscriberCount,
        videoCount: ch.videoCount,
        metrics: ch.metrics,
        status: ch.status,
        isVerified: ch.isVerified,
        category: ch.category,
        categories: ch.categories,
        language: ch.language,
        monetizationTier: ch.monetizationTier,
        channelType: ch.channelType,
        infraConfig: ch.infraConfig,
        nextBillingCycleDate: ch.nextBillingCycleDate,
      );

      AppSnackbar.info(
        'Scheduled tier switch has been canceled.',
        title: 'Request Canceled',
      );
    }

    isUpdatingRx.value = false;
  }

  Future<void> subscribePlanWithBalance(
    BuildContext context,
    CustomChannelPlanTier plan,
  ) async {
    final auth = AuthService.to;
    final userId = auth.uid.isNotEmpty ? auth.uid : channel.ownerId;
    final spendable = spendableBalance;

    if (!spendable.canAfford(plan.priceUSD)) {
      AppSnackbar.warning(
        'Your spendable balance (\$${spendable.totalSpendableBalance.toStringAsFixed(2)}) is insufficient for \$${plan.priceUSD.toStringAsFixed(2)}.',
        title: 'Insufficient Balance',
      );
      return;
    }

    isUpdatingRx.value = true;
    final success = await walletService.spendForCustomPlan(
      channel: channel,
      userId: userId,
      planTier: plan.id,
      priceUSD: plan.priceUSD,
      autoPay: autoPayEnabled.value,
    );

    if (success) {
      final existingInfra = channel.infraConfig;
      final updatedInfra = CustomChannelInfraConfig(
        stripeConnectAccountId: existingInfra?.stripeConnectAccountId ?? '',
        subscriptionId: existingInfra?.subscriptionId ?? 'sub_${channel.id}',
        storageUsedBytes: existingInfra?.storageUsedBytes ?? 0,
        storageQuotaBytes: plan.storageGB * 1024 * 1024 * 1024,
        bandwidthUsedBytesThisMonth: existingInfra?.bandwidthUsedBytesThisMonth ?? 0,
        bandwidthQuotaBytesThisMonth: plan.bandwidthGB * 1024 * 1024 * 1024,
        planTier: plan.id,
        autoPay: autoPayEnabled.value,
      );

      channelRx.value = Channel(
        id: channel.id,
        name: channel.name,
        nameLowercase: channel.nameLowercase,
        handle: channel.handle,
        handleLowercase: channel.handleLowercase,
        description: channel.description,
        avatarUrl: channel.avatarUrl,
        bannerUrl: channel.bannerUrl,
        ownerId: channel.ownerId,
        createdAt: channel.createdAt,
        updatedAt: Timestamp.now(),
        subscriberCount: channel.subscriberCount,
        videoCount: channel.videoCount,
        metrics: channel.metrics,
        status: channel.status,
        isVerified: channel.isVerified,
        category: channel.category,
        categories: channel.categories,
        language: channel.language,
        monetizationTier: channel.monetizationTier,
        channelType: ChannelType.custom,
        infraConfig: updatedInfra,
      );
      selectedPlanId.value = plan.id;

      final autoPayNote = autoPayEnabled.value ? ' Auto Pay is active.' : '';
      AppSnackbar.success(
        'Successfully subscribed to ${plan.title} plan (\$${plan.priceUSD.toStringAsFixed(0)}/mo) using account balance.$autoPayNote',
        title: 'Plan Activated!',
      );
    }
    isUpdatingRx.value = false;
  }

  /// Subscribes to Custom Channel Plan using Spendable Balance if available, or Cashfree PG directly
  Future<void> subscribePlan(
    BuildContext context,
    CustomChannelPlanTier plan,
  ) async {
    selectedPlanId.value = plan.id;
    final spendable = spendableBalance;
    if (spendable.canAfford(plan.priceUSD)) {
      await subscribePlanWithBalance(context, plan);
      return;
    }

    // Direct Cashfree payment with Auto Pay option
    isUpdatingRx.value = true;
    try {
      final success = await walletService.buyCustomPlanWithCashfree(
        channel: channel,
        plan: plan,
        autoPay: autoPayEnabled.value,
      );

      if (success) {
        final existingInfra = channel.infraConfig;
        final updatedInfra = CustomChannelInfraConfig(
          stripeConnectAccountId: existingInfra?.stripeConnectAccountId ?? '',
          subscriptionId: existingInfra?.subscriptionId ?? 'sub_${channel.id}',
          storageUsedBytes: existingInfra?.storageUsedBytes ?? 0,
          storageQuotaBytes: plan.storageGB * 1024 * 1024 * 1024,
          bandwidthUsedBytesThisMonth: existingInfra?.bandwidthUsedBytesThisMonth ?? 0,
          bandwidthQuotaBytesThisMonth: plan.bandwidthGB * 1024 * 1024 * 1024,
          planTier: plan.id,
          autoPay: autoPayEnabled.value,
        );

        channelRx.value = Channel(
          id: channel.id,
          name: channel.name,
          nameLowercase: channel.nameLowercase,
          handle: channel.handle,
          handleLowercase: channel.handleLowercase,
          description: channel.description,
          avatarUrl: channel.avatarUrl,
          bannerUrl: channel.bannerUrl,
          ownerId: channel.ownerId,
          createdAt: channel.createdAt,
          updatedAt: Timestamp.now(),
          subscriberCount: channel.subscriberCount,
          videoCount: channel.videoCount,
          metrics: channel.metrics,
          status: channel.status,
          isVerified: channel.isVerified,
          category: channel.category,
          categories: channel.categories,
          language: channel.language,
          monetizationTier: channel.monetizationTier,
          channelType: ChannelType.custom,
          infraConfig: updatedInfra,
        );
        selectedPlanId.value = plan.id;

        final autoPayNote = autoPayEnabled.value
            ? ' Auto Pay is active for monthly renewals.'
            : ' Valid for 1 month.';
        AppSnackbar.success(
          'Successfully subscribed to ${plan.title} plan (\$${plan.priceUSD.toStringAsFixed(0)}/mo)!$autoPayNote',
          title: 'Plan Activated!',
        );
      }
    } finally {
      isUpdatingRx.value = false;
    }
  }

  /// Evaluates and compiles real-time hype surge metrics across all 4 revenue streams
  HypeSurgeSummary get hypeSurgeSummary {
    return InfrastructureMeteringService.computeHypeSurgeSummary(
      channel: channel,
      adRevenue: adRevenue,
      premiumSubRevenue: premiumSubRevenue,
      membershipsRevenue: membershipsRevenue,
      tipsRevenue: tipsRevenue,
    );
  }

  /// Whether the custom channel is currently undergoing a traffic hype spike or bandwidth strain
  bool get isHypeSurgeActive => hypeSurgeSummary.isHypeSurgeActive;

  /// 1-Click action to upgrade the custom channel plan using collected hype revenue,
  /// settling surge infrastructure costs and restoring unconstrained 4K/1080p playback.
  Future<bool> upgradePlanToCoverSurge([CustomChannelPlanTier? targetPlan]) async {
    final summary = hypeSurgeSummary;
    final plan = targetPlan ?? summary.recommendedUpgradePlan;
    final auth = AuthService.to;
    final userId = auth.uid.isNotEmpty ? auth.uid : channel.ownerId;
    final spendable = spendableBalance;

    if (!spendable.canAfford(plan.priceUSD)) {
      AppSnackbar.warning(
        'Your spendable revenue balance (\$${spendable.totalSpendableBalance.toStringAsFixed(2)}) is insufficient for \$${plan.priceUSD.toStringAsFixed(2)}.',
        title: 'Insufficient Balance',
      );
      return false;
    }

    isUpdatingRx.value = true;
    final success = await walletService.spendForCustomPlan(
      channel: channel,
      userId: userId,
      planTier: plan.id,
      priceUSD: plan.priceUSD,
    );

    if (success) {
      final existingInfra = channel.infraConfig;
      final updatedInfra = CustomChannelInfraConfig(
        stripeConnectAccountId: existingInfra?.stripeConnectAccountId ?? '',
        subscriptionId: existingInfra?.subscriptionId ?? 'sub_${channel.id}',
        storageUsedBytes: existingInfra?.storageUsedBytes ?? 0,
        storageQuotaBytes: plan.storageGB * 1024 * 1024 * 1024,
        bandwidthUsedBytesThisMonth: existingInfra?.bandwidthUsedBytesThisMonth ?? 0,
        bandwidthQuotaBytesThisMonth: plan.bandwidthGB * 1024 * 1024 * 1024,
        flatPlatformFee: plan.priceUSD,
        planTier: plan.id,
        autoPay: autoPayEnabled.value,
      );

      channelRx.value = Channel(
        id: channel.id,
        name: channel.name,
        nameLowercase: channel.nameLowercase,
        handle: channel.handle,
        handleLowercase: channel.handleLowercase,
        description: channel.description,
        avatarUrl: channel.avatarUrl,
        bannerUrl: channel.bannerUrl,
        ownerId: channel.ownerId,
        createdAt: channel.createdAt,
        updatedAt: Timestamp.now(),
        subscriberCount: channel.subscriberCount,
        videoCount: channel.videoCount,
        metrics: channel.metrics,
        status: channel.status,
        isVerified: channel.isVerified,
        category: channel.category,
        categories: channel.categories,
        language: channel.language,
        monetizationTier: channel.monetizationTier,
        channelType: ChannelType.custom,
        infraConfig: updatedInfra,
      );
      selectedPlanId.value = plan.id;

      AppSnackbar.success(
        'Upgraded to ${plan.title} (\$${plan.priceUSD.toStringAsFixed(0)}/mo). Surge capacity expanded to ${plan.bandwidthGB} GB CDN and revenue withdrawals are unlocked!',
        title: 'Withdrawals Unlocked!',
      );
      isUpdatingRx.value = false;
      return true;
    }
    isUpdatingRx.value = false;
    return false;
  }

  /// Opens the bank withdrawal dialog to cash out 100% of accumulated revenue
  void openRevenueWithdrawalDialog(BuildContext context) {
    if (!Get.isRegistered<RevenueAnalyticsController>()) {
      Get.put(RevenueAnalyticsController());
    }
    RevenueWithdrawalDialog.show(context);
  }
}
