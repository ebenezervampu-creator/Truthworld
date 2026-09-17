import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/services/infrastructure_metering_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
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
  final ChannelWalletService walletService = ChannelWalletService();

  @override
  void onInit() {
    super.onInit();
    channelRx = initialChannel.obs;
    if (initialChannel.infraConfig != null) {
      selectedPlanId.value = initialChannel.infraConfig!.planTier;
    }
  }

  SpendableBalance get spendableBalance {
    final totalRev = adRevenue + premiumSubRevenue + tipsRevenue + membershipsRevenue;
    return walletService.getSpendableBalance(
      channel: channel,
      rawTotalRevenue: totalRev,
      withdrawableRevenue: totalRev * 0.70,
      lockedRevenue: totalRev * 0.30,
    );
  }

  // Real channel revenue metrics derived from channel activity
  double get adRevenue =>
      channel.metrics.totalViews > 0 ? (channel.metrics.totalViews * 0.005) : 0.0;
  double get premiumSubRevenue => channel.metrics.totalWatchTimeMinutes > 0
      ? (channel.metrics.totalWatchTimeMinutes * 0.002)
      : 0.0;
  double get tipsRevenue =>
      Get.isRegistered<DashboardController>()
          ? Get.find<DashboardController>().rxSuperchatRevenue.value
          : 0.0;
  double get membershipsRevenue =>
      Get.isRegistered<DashboardController>()
          ? Get.find<DashboardController>().rxMembershipsRevenue.value
          : 0.0;

  // Real channel video metrics for 10-hour withdrawal rule
  int get singleVideoWatchTimeMinutes => channel.metrics.totalWatchTimeMinutes;
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
    );

    if (success) {
      final existingInfra = channel.infraConfig;
      final newTrialRemaining = existingInfra != null
          ? (existingInfra.trialCreditRemainingUSD - plan.priceUSD).clamp(0.0, 999999.0)
          : 0.0;

      final updatedInfra = CustomChannelInfraConfig(
        stripeConnectAccountId: existingInfra?.stripeConnectAccountId ?? '',
        subscriptionId: existingInfra?.subscriptionId ?? 'sub_${channel.id}',
        storageUsedBytes: existingInfra?.storageUsedBytes ?? 0,
        storageQuotaBytes: plan.storageGB * 1024 * 1024 * 1024,
        bandwidthUsedBytesThisMonth: existingInfra?.bandwidthUsedBytesThisMonth ?? 0,
        bandwidthQuotaBytesThisMonth: plan.bandwidthGB * 1024 * 1024 * 1024,
        trialCreditRemainingUSD: newTrialRemaining,
        planTier: plan.id,
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
        'Successfully subscribed to ${plan.title} plan (\$${plan.priceUSD.toStringAsFixed(0)}/mo) using account balance.',
        title: 'Plan Activated!',
      );
    }
    isUpdatingRx.value = false;
  }
}
