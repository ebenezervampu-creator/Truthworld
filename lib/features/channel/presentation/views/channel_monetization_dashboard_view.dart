import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/channel_payout_calculator.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/services/infrastructure_metering_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/theme/app_theme.dart';

class ChannelMonetizationDashboardView extends StatefulWidget {
  const ChannelMonetizationDashboardView({required this.channel, super.key});

  final Channel channel;

  @override
  State<ChannelMonetizationDashboardView> createState() =>
      _ChannelMonetizationDashboardViewState();
}

class _ChannelMonetizationDashboardViewState
    extends State<ChannelMonetizationDashboardView> {
  late final Rx<Channel> _channelRx;
  Channel get _channel => _channelRx.value;

  final RxBool _isUpdatingRx = false.obs;
  bool get _isUpdating => _isUpdatingRx.value;

  final RxString _selectedPlanId = 'starter_15'.obs;
  final ChannelWalletService _walletService = ChannelWalletService();

  SpendableBalance get _spendableBalance => _walletService.getSpendableBalance(
        channel: _channel,
        rawTotalRevenue:
            _adRevenue + _premiumSubRevenue + _tipsRevenue + _membershipsRevenue,
        withdrawableRevenue:
            (_adRevenue + _premiumSubRevenue + _tipsRevenue + _membershipsRevenue) *
                0.70,
        lockedRevenue:
            (_adRevenue + _premiumSubRevenue + _tipsRevenue + _membershipsRevenue) *
                0.30,
      );

  // Demo revenue numbers for visualization
  final double _adRevenue = 15000.0;
  final double _premiumSubRevenue = 10000.0;
  final double _tipsRevenue = 5000.0;
  final double _membershipsRevenue = 20000.0;

  // Video watch time demo simulation for 10-hour withdrawal rule
  final int _singleVideoWatchTimeMinutes =
      720; // 12 hours (crossed 10h threshold!)
  final double _singleVideoRevenue = 35000.0;

  // Custom channel infra simulation
  final int _storageUsedBytes = 25 * 1024 * 1024 * 1024; // 25 GB
  final int _bandwidthUsedBytes = 180 * 1024 * 1024 * 1024; // 180 GB

  @override
  void initState() {
    super.initState();
    _channelRx = widget.channel.obs;
    if (_channel.infraConfig != null) {
      _selectedPlanId.value = _channel.infraConfig!.planTier;
    }
  }

  int _calculateDaysLeftToSwitch() {
    final now = DateTime.now();
    final effectiveDate =
        _channel.pendingTypeEffectiveDate?.toDate() ??
        DateTime(now.year, now.month + 1);
    final difference = effectiveDate.difference(now).inDays + 1;
    return max(0, difference);
  }

  ChannelController get _channelController {
    if (Get.isRegistered<ChannelController>()) {
      return Get.find<ChannelController>();
    }
    return Get.put(ChannelController());
  }

  Future<void> _scheduleTierChange() async {
    final controller = _channelController;
    final ch = _channel;
    final newType = ch.channelType == ChannelType.standard
        ? ChannelType.custom
        : ChannelType.standard;

    _isUpdatingRx.value = true;

    final success = await controller.scheduleChannelTypeChange(
      ch.id,
      newType,
    );
    if (success) {
      final now = DateTime.now();
      final effectiveDate = DateTime(now.year, now.month + 1);
      final effectiveTimestamp = Timestamp.fromDate(effectiveDate);

      _channelRx.value = Channel(
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
        updatedAt: ch.updatedAt,
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

      final formattedDate = DateFormat('MMMM d, yyyy').format(effectiveDate);
      final daysLeft = _calculateDaysLeftToSwitch();

      Get.snackbar(
        'Request Scheduled',
        'Tier switch to ${newType.name.toUpperCase()} scheduled in $daysLeft days ($formattedDate).',
        backgroundColor: AppColors.bgSurfaceHigh,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } else {
      Get.snackbar(
        'Error',
        'Failed to schedule channel type change',
        backgroundColor: AppColors.bgSurfaceHigh,
        colorText: Colors.white,
      );
    }

    _isUpdatingRx.value = false;
  }

  Future<void> _cancelScheduledChange() async {
    final controller = _channelController;
    final ch = _channel;

    _isUpdatingRx.value = true;

    final success = await controller.cancelScheduledChannelTypeChange(
      ch.id,
    );
    if (success) {
      _channelRx.value = Channel(
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
        updatedAt: ch.updatedAt,
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

      Get.snackbar(
        'Request Canceled',
        'Scheduled tier switch has been canceled.',
        backgroundColor: AppColors.bgSurfaceHigh,
        colorText: Colors.white,
      );
    }

    _isUpdatingRx.value = false;
  }

  Future<void> _subscribePlanWithBalance(
    BuildContext context,
    CustomChannelPlanTier plan,
  ) async {
    final auth = AuthService.to;
    final userId = auth.uid.isNotEmpty ? auth.uid : _channel.ownerId;
    final spendable = _spendableBalance;

    if (!spendable.canAfford(plan.priceUSD)) {
      Get.snackbar(
        'Insufficient Balance',
        'Your spendable balance (\$${spendable.totalSpendableBalance.toStringAsFixed(2)}) is insufficient for \$${plan.priceUSD.toStringAsFixed(2)}.',
        backgroundColor: AppColors.bgSurfaceHigh,
        colorText: Colors.white,
      );
      return;
    }

    _isUpdatingRx.value = true;
    final success = await _walletService.spendForCustomPlan(
      channel: _channel,
      userId: userId,
      planTier: plan.id,
      priceUSD: plan.priceUSD,
    );

    if (success) {
      final existingInfra = _channel.infraConfig;
      final newTrialRemaining = existingInfra != null
          ? (existingInfra.trialCreditRemainingUSD - plan.priceUSD)
              .clamp(0.0, 999999.0)
          : 0.0;

      final updatedInfra = CustomChannelInfraConfig(
        stripeConnectAccountId:
            existingInfra?.stripeConnectAccountId ?? 'acct_${_channel.id}',
        subscriptionId:
            existingInfra?.subscriptionId ?? 'sub_${_channel.id}',
        storageUsedBytes: existingInfra?.storageUsedBytes ?? 0,
        storageQuotaBytes: plan.storageGB * 1024 * 1024 * 1024,
        bandwidthUsedBytesThisMonth:
            existingInfra?.bandwidthUsedBytesThisMonth ?? 0,
        bandwidthQuotaBytesThisMonth:
            plan.bandwidthGB * 1024 * 1024 * 1024,
        trialCreditRemainingUSD: newTrialRemaining,
        planTier: plan.id,
      );

      _channelRx.value = Channel(
        id: _channel.id,
        name: _channel.name,
        nameLowercase: _channel.nameLowercase,
        handle: _channel.handle,
        handleLowercase: _channel.handleLowercase,
        description: _channel.description,
        avatarUrl: _channel.avatarUrl,
        bannerUrl: _channel.bannerUrl,
        ownerId: _channel.ownerId,
        createdAt: _channel.createdAt,
        updatedAt: Timestamp.now(),
        subscriberCount: _channel.subscriberCount,
        videoCount: _channel.videoCount,
        metrics: _channel.metrics,
        status: _channel.status,
        isVerified: _channel.isVerified,
        category: _channel.category,
        categories: _channel.categories,
        language: _channel.language,
        monetizationTier: _channel.monetizationTier,
        channelType: ChannelType.custom,
        infraConfig: updatedInfra,
      );
      _selectedPlanId.value = plan.id;

      Get.snackbar(
        'Plan Activated!',
        'Successfully subscribed to ${plan.title} plan (\$${plan.priceUSD.toStringAsFixed(0)}/mo) using account balance.',
        backgroundColor: AppColors.bgSurfaceHigh,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    }
    _isUpdatingRx.value = false;
  }

  void _showStorageTopupSheet(BuildContext context) {
    final typography = context.twTypography;
    final spendable = _spendableBalance;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storage_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Buy Extra Storage with Balance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Available Spendable Balance: \$${spendable.totalSpendableBalance.toStringAsFixed(2)} (\$${spendable.trialCreditRemaining.toStringAsFixed(2)} Trial Credit + \$${spendable.totalRevenue.toStringAsFixed(2)} Revenue)',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ...ChannelWalletService.storagePacks.map((pack) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.bgSurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_upload_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  pack.title,
                                  style: typography.title.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (pack.badge.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgElevated,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      pack.badge,
                                      style: typography.caption.copyWith(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '+${pack.gigabytes} GB permanent add-on video storage',
                              style: typography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Get.back();
                          final auth = AuthService.to;
                          final uid = auth.uid.isNotEmpty
                              ? auth.uid
                              : _channel.ownerId;
                          final ok = await _walletService.spendForStorageTopup(
                            channel: _channel,
                            userId: uid,
                            pack: pack,
                          );
                          if (ok) {
                            final cur = _channel.infraConfig?.storageQuotaBytes ??
                                53687091200;
                            final updated = CustomChannelInfraConfig(
                              stripeConnectAccountId: _channel.infraConfig
                                      ?.stripeConnectAccountId ??
                                  '',
                              subscriptionId:
                                  _channel.infraConfig?.subscriptionId ?? '',
                              storageQuotaBytes: cur + pack.bytes,
                              storageUsedBytes: _channel.infraConfig?.storageUsedBytes ?? 0,
                              bandwidthQuotaBytesThisMonth: _channel.infraConfig?.bandwidthQuotaBytesThisMonth ?? 214748364800,
                              bandwidthUsedBytesThisMonth: _channel.infraConfig?.bandwidthUsedBytesThisMonth ?? 0,
                              trialCreditRemainingUSD: (_channel.infraConfig?.trialCreditRemainingUSD ?? 10.0) > pack.priceUSD
                                  ? (_channel.infraConfig!.trialCreditRemainingUSD - pack.priceUSD)
                                  : 0.0,
                              planTier: _channel.infraConfig?.planTier ?? 'starter_15',
                            );
                            _channelRx.value = Channel(
                              id: _channel.id,
                              name: _channel.name,
                              nameLowercase: _channel.nameLowercase,
                              handle: _channel.handle,
                              handleLowercase: _channel.handleLowercase,
                              description: _channel.description,
                              avatarUrl: _channel.avatarUrl,
                              bannerUrl: _channel.bannerUrl,
                              ownerId: _channel.ownerId,
                              createdAt: _channel.createdAt,
                              updatedAt: Timestamp.now(),
                              subscriberCount: _channel.subscriberCount,
                              videoCount: _channel.videoCount,
                              metrics: _channel.metrics,
                              status: _channel.status,
                              isVerified: _channel.isVerified,
                              category: _channel.category,
                              categories: _channel.categories,
                              language: _channel.language,
                              monetizationTier: _channel.monetizationTier,
                              channelType: _channel.channelType,
                              infraConfig: updated,
                            );
                            Get.snackbar(
                              'Storage Added!',
                              'Added +${pack.gigabytes} GB storage to your channel using account balance.',
                              backgroundColor: AppColors.bgSurfaceHigh,
                              colorText: Colors.white,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          '\$${pack.priceUSD.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showBandwidthTopupSheet(BuildContext context) {
    final typography = context.twTypography;
    final spendable = _spendableBalance;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.speed_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Buy Streaming Bandwidth with Balance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Available Spendable Balance: \$${spendable.totalSpendableBalance.toStringAsFixed(2)} (\$${spendable.trialCreditRemaining.toStringAsFixed(2)} Trial Credit + \$${spendable.totalRevenue.toStringAsFixed(2)} Revenue)',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ...ChannelWalletService.bandwidthPacks.map((pack) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.bgSurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.stream_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  pack.title,
                                  style: typography.title.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (pack.badge.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgElevated,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      pack.badge,
                                      style: typography.caption.copyWith(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '+${pack.gigabytes} GB CDN streaming bandwidth for high viewer traffic',
                              style: typography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Get.back();
                          final auth = AuthService.to;
                          final uid = auth.uid.isNotEmpty
                              ? auth.uid
                              : _channel.ownerId;
                          final ok = await _walletService.spendForBandwidthTopup(
                            channel: _channel,
                            userId: uid,
                            pack: pack,
                          );
                          if (ok) {
                            final cur = _channel.infraConfig?.bandwidthQuotaBytesThisMonth ??
                                214748364800;
                            final updated = CustomChannelInfraConfig(
                              stripeConnectAccountId: _channel.infraConfig
                                      ?.stripeConnectAccountId ??
                                  '',
                              subscriptionId:
                                  _channel.infraConfig?.subscriptionId ?? '',
                              storageQuotaBytes: _channel.infraConfig?.storageQuotaBytes ?? 53687091200,
                              storageUsedBytes: _channel.infraConfig?.storageUsedBytes ?? 0,
                              bandwidthQuotaBytesThisMonth: cur + pack.bytes,
                              bandwidthUsedBytesThisMonth: _channel.infraConfig?.bandwidthUsedBytesThisMonth ?? 0,
                              trialCreditRemainingUSD: (_channel.infraConfig?.trialCreditRemainingUSD ?? 10.0) > pack.priceUSD
                                  ? (_channel.infraConfig!.trialCreditRemainingUSD - pack.priceUSD)
                                  : 0.0,
                              planTier: _channel.infraConfig?.planTier ?? 'starter_15',
                            );
                            _channelRx.value = Channel(
                              id: _channel.id,
                              name: _channel.name,
                              nameLowercase: _channel.nameLowercase,
                              handle: _channel.handle,
                              handleLowercase: _channel.handleLowercase,
                              description: _channel.description,
                              avatarUrl: _channel.avatarUrl,
                              bannerUrl: _channel.bannerUrl,
                              ownerId: _channel.ownerId,
                              createdAt: _channel.createdAt,
                              updatedAt: Timestamp.now(),
                              subscriberCount: _channel.subscriberCount,
                              videoCount: _channel.videoCount,
                              metrics: _channel.metrics,
                              status: _channel.status,
                              isVerified: _channel.isVerified,
                              category: _channel.category,
                              categories: _channel.categories,
                              language: _channel.language,
                              monetizationTier: _channel.monetizationTier,
                              channelType: _channel.channelType,
                              infraConfig: updated,
                            );
                            Get.snackbar(
                              'Bandwidth Added!',
                              'Added +${pack.gigabytes} GB CDN bandwidth to your channel using account balance.',
                              backgroundColor: AppColors.bgSurfaceHigh,
                              colorText: Colors.white,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          '\$${pack.priceUSD.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = _channel.channelType == ChannelType.custom;
    final totalGross =
        _adRevenue + _premiumSubRevenue + _tipsRevenue + _membershipsRevenue;
    final infraCost = InfrastructureMeteringService.calculateInfraCost(
      storageUsedBytes: _storageUsedBytes,
      bandwidthUsedBytes: _bandwidthUsedBytes,
    );

    final payoutBreakdown = ChannelPayoutCalculator.calculatePayout(
      _channel,
      adRevenue: _adRevenue,
      premiumSubRevenue: _premiumSubRevenue,
      tipsRevenue: _tipsRevenue,
      membershipsRevenue: _membershipsRevenue,
      grossRevenue: totalGross,
      actualInfraCost: infraCost,
    );

    final videoWithdrawalEligibility =
        ChannelPayoutCalculator.calculateVideoWithdrawalEligibility(
          channel: _channel,
          videoId: 'vid_demo_001',
          videoRevenue: _singleVideoRevenue,
          videoWatchTimeMinutes: _singleVideoWatchTimeMinutes,
        );

    final typography = context.twTypography;

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
            if (_channel.pendingChannelType != null) ...[
              _buildScheduledChangeBanner(context),
              const SizedBox(height: 16),
            ],

            // $10 Free Trial Credit Welcome Banner
            _buildFreeTrialBanner(context),
            const SizedBox(height: 16),

            // Channel Header Card (Shows Channel Type & Days Left To Switch)
            _buildChannelHeaderCard(context, isCustom),
            const SizedBox(height: 20),

            // Day 1 Earning & 10-Hour Video Withdrawal Rule Card
            _buildWithdrawalRulesCard(
              context,
              videoWithdrawalEligibility,
              isCustom,
            ),
            const SizedBox(height: 20),

            // Custom Channel Plans & Feature Breakdown ("What You Get")
            _buildPlansBreakdownSection(context, isCustom),
            const SizedBox(height: 20),

            // Revenue Breakdown Section
            _buildRevenueBreakdownSection(context, payoutBreakdown, isCustom),
            const SizedBox(height: 20),

            // Custom Channel Infrastructure Section (if Custom)
            if (isCustom) ...[
              _buildInfrastructureSection(context, infraCost),
              const SizedBox(height: 20),
              _buildZeroLossSafeguardCard(context),
              const SizedBox(height: 20),
            ],

            // Action / Upgrade Section
            _buildUpgradeCard(context, isCustom),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawalRulesCard(
    BuildContext context,
    VideoWithdrawalEligibility eligibility,
    bool isCustom,
  ) {
    final typography = context.twTypography;
    final watchHours = (eligibility.watchTimeMinutes / 60).toStringAsFixed(1);
    final isUnlocked = eligibility.isUnlockedForWithdrawal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day 1 Earnings Active',
                      style: typography.title.copyWith(color: Colors.white),
                    ),
                    Text(
                      isCustom
                          ? 'Custom Channel: Instant withdrawals on all revenue (100% retention).'
                          : 'Standard Channel: 70% Ad & Premium revenue share. 100% Creator retention on Memberships & Superchats.',
                      style: typography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.bgDivider, height: 1),
          const SizedBox(height: 16),

          // Video Watch Time Progress Card for Standard Channels
          if (!isCustom) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Video #1 Watch Time Progress',
                  style: typography.title.copyWith(color: Colors.white),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Text(
                    isUnlocked ? 'Unlocked (10h+ Met)' : 'Locked (< 10h)',
                    style: typography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$watchHours / 10.0 Hours Watch Time',
                  style: typography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Withdrawable: ₹${eligibility.withdrawableAmount.toStringAsFixed(0)}',
                  style: typography.title.copyWith(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (eligibility.watchTimeMinutes / 600).clamp(0.0, 1.0),
                backgroundColor: AppColors.bgSurfaceHigh,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 8,
              ),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Custom Channel Advantage: No watch time limits for withdrawals!',
                  style: typography.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduledChangeBanner(BuildContext context) {
    final typography = context.twTypography;
    final pendingTypeStr = _channel.pendingChannelType!.name.toUpperCase();
    final effectiveDate =
        _channel.pendingTypeEffectiveDate?.toDate() ??
        DateTime(DateTime.now().year, DateTime.now().month + 1);
    final formattedDate = DateFormat('MMMM d, yyyy').format(effectiveDate);
    final daysLeft = _calculateDaysLeftToSwitch();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_top, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tier Switch to $pendingTypeStr Channel Scheduled',
                  style: typography.title.copyWith(color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Text(
                  '$daysLeft Days Left',
                  style: typography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your channel will automatically convert to $pendingTypeStr Channel in $daysLeft days on $formattedDate (Start of Next Billing Cycle).',
            style: typography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isUpdating ? null : _cancelScheduledChange,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.bgDivider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Cancel Pending Switch Request',
              style: typography.button.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeTrialBanner(BuildContext context) {
    final typography = context.twTypography;
    final remainingCredit =
        _channel.infraConfig?.trialCreditRemainingUSD ?? 10.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.bgSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_giftcard,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Truthworld Welcome Bonus: ',
                      style: typography.title.copyWith(color: Colors.white),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.bgDivider),
                      ),
                      child: Text(
                        '\$$remainingCredit FREE',
                        style: typography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  r'Start your Custom Channel with ₹0 upfront out-of-pocket cost. Your $10 free credit automatically covers your initial server fees!',
                  style: typography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelHeaderCard(BuildContext context, bool isCustom) {
    final typography = context.twTypography;
    final daysLeft = _calculateDaysLeftToSwitch();
    final nextTypeStr = isCustom ? 'Standard' : 'Custom';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                radius: 30,
                photoUrl: _channel.avatarUrl,
                displayName: _channel.name,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _channel.name,
                      style: typography.headline.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurfaceHigh,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.bgDivider),
                          ),
                          child: Text(
                            isCustom
                                ? 'Custom Channel (0% Cut)'
                                : 'Standard Channel (70/30 Split)',
                            style: typography.label.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurfaceHigh,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.bgDivider),
                          ),
                          child: Text(
                            '⏳ $daysLeft Days left to switch',
                            style: typography.label.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.bgDivider, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _channel.pendingChannelType != null
                      ? 'Scheduled to switch to ${_channel.pendingChannelType!.name.toUpperCase()} in $daysLeft days.'
                      : 'Requesting a switch to $nextTypeStr Channel today will take effect in $daysLeft days (Next Billing Cycle).',
                  style: typography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlansBreakdownSection(BuildContext context, bool isCustom) {
    final typography = context.twTypography;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.layers, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                'Custom Channel Infrastructure Plans',
                style: typography.headline.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            r'Select your hosting tier once your $10 free credit is completed. All plans feature 0% Platform Commission!',
            style: typography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          Obx(() {
            final currentSelectedPlanId = _selectedPlanId.value;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: InfrastructureMeteringService.availablePlans.map((
                  plan,
                ) {
                  final isSelected = currentSelectedPlanId == plan.id;
                  return GestureDetector(
                    onTap: () => _selectedPlanId.value = plan.id,
                    child: Container(
                      width: 220,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.bgElevated
                          : AppColors.bgSurfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : AppColors.bgDivider,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              plan.title,
                              style: typography.title.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            if (plan.isPopular)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.bgSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.bgDivider,
                                  ),
                                ),
                                child: Text(
                                  'Popular',
                                  style: typography.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          plan.priceUSD > 0
                              ? '\$${plan.priceUSD.toStringAsFixed(0)} / mo'
                              : 'Custom Quote',
                          style: typography.headline.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: AppColors.bgDivider, height: 1),
                        const SizedBox(height: 12),
                        ...plan.features.map(
                          (feature) => Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    feature,
                                    style: typography.caption.copyWith(
                                      color: Colors.white,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (plan.priceUSD > 0) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _subscribePlanWithBalance(context, plan),
                              icon: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              label: Text(
                                'Pay with Balance',
                                style: typography.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected
                                    ? AppColors.bgSurface
                                    : AppColors.bgElevated,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
          }),
        ],
      ),
    );
  }

  Widget _buildRevenueBreakdownSection(
    BuildContext context,
    ChannelPayoutBreakdown breakdown,
    bool isCustom,
  ) {
    final typography = context.twTypography;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Revenue Breakdown (Monthly)',
                style: typography.headline.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Earnings Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Creator Net Take-Home',
                      style: typography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${breakdown.creatorPayout.toStringAsFixed(2)}',
                      style: typography.display.copyWith(color: Colors.white),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Gross Channel Revenue',
                      style: typography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${breakdown.grossRevenue.toStringAsFixed(2)}',
                      style: typography.title.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Line Items
          _buildRevenueRow(
            context,
            'Ad Revenue (70% Creator)',
            _adRevenue * 0.70,
            _adRevenue * 0.30,
          ),
          _buildRevenueRow(
            context,
            'Premium Subs (70% Creator)',
            _premiumSubRevenue * 0.70,
            _premiumSubRevenue * 0.30,
          ),
          _buildRevenueRow(context, 'Tips (100% Creator)', _tipsRevenue, 0.0),
          _buildRevenueRow(
            context,
            'Memberships (100% Creator)',
            _membershipsRevenue,
            0.0,
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueRow(
    BuildContext context,
    String label,
    double creatorShare,
    double platformShare,
  ) {
    final typography = context.twTypography;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: typography.body.copyWith(color: Colors.white)),
          Row(
            children: [
              Text(
                '₹${creatorShare.toStringAsFixed(0)}',
                style: typography.body.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (platformShare > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '(Platform: ₹${platformShare.toStringAsFixed(0)})',
                  style: typography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfrastructureSection(BuildContext context, double infraCost) {
    final typography = context.twTypography;
    final storageGB = _storageUsedBytes / (1024 * 1024 * 1024);
    final bandwidthGB = _bandwidthUsedBytes / (1024 * 1024 * 1024);
    final storageQuotaGB =
        (_channel.infraConfig?.storageQuotaBytes ?? 53687091200) /
            (1024 * 1024 * 1024);
    final bandwidthQuotaGB =
        (_channel.infraConfig?.bandwidthQuotaBytesThisMonth ?? 214748364800) /
            (1024 * 1024 * 1024);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_queue, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Infrastructure Metering',
                    style: typography.headline.copyWith(color: Colors.white),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showStorageTopupSheet(context),
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    label: const Text(
                      '+ Storage',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.bgDivider),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showBandwidthTopupSheet(context),
                    icon: const Icon(
                      Icons.speed_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    label: const Text(
                      '+ Bandwidth',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.bgDivider),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Storage Meter
          _buildMeterBar(
            context,
            title: 'Video Storage',
            valueText:
                '${storageGB.toStringAsFixed(1)} GB / ${storageQuotaGB.toStringAsFixed(0)} GB',
            progress: (storageGB / storageQuotaGB).clamp(0.0, 1.0),
          ),
          const SizedBox(height: 12),

          // Bandwidth Meter
          _buildMeterBar(
            context,
            title: 'CDN Streaming Bandwidth',
            valueText:
                '${bandwidthGB.toStringAsFixed(1)} GB / ${bandwidthQuotaGB.toStringAsFixed(0)} GB',
            progress: (bandwidthGB / bandwidthQuotaGB).clamp(0.0, 1.0),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated Cloud Cost:',
                style: typography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '\$${infraCost.toStringAsFixed(2)} / mo',
                style: typography.title.copyWith(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeterBar(
    BuildContext context, {
    required String title,
    required String valueText,
    required double progress,
  }) {
    final typography = context.twTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: typography.bodySmall.copyWith(color: Colors.white),
            ),
            Text(
              valueText,
              style: typography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.bgSurfaceHigh,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildZeroLossSafeguardCard(BuildContext context) {
    final typography = context.twTypography;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zero-Loss Protection Active',
                  style: typography.title.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your channel balance is protected. If bandwidth exceeds revenue, auto-resolution scaling activates so you never incur a loss.',
                  style: typography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeCard(BuildContext context, bool isCustom) {
    final typography = context.twTypography;
    final hasPending = _channel.pendingChannelType != null;
    final targetTypeStr = isCustom ? 'Standard' : 'Custom';
    final daysLeft = _calculateDaysLeftToSwitch();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCustom
                ? 'Request Switch to Standard Channel'
                : r'Request Switch to Custom Channel ($10 Free Credit)',
            style: typography.headline.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            isCustom
                ? r'Standard channels have $0 upfront monthly cost and a 70/30 ad split. Switching will take effect at the start of your next billing cycle.'
                : 'Custom channels let you keep 100% of revenue. Requesting a switch locks your request to take effect on the 1st of next month.',
            style: typography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: (_isUpdating || hasPending) ? null : _scheduleTierChange,
            style: ElevatedButton.styleFrom(
              backgroundColor: isCustom
                  ? AppColors.bgSurfaceHigh
                  : Colors.white,
              foregroundColor: isCustom ? Colors.white : Colors.black,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isUpdating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    hasPending
                        ? 'Tier Change to $targetTypeStr Scheduled'
                        : 'Schedule Switch to $targetTypeStr (in $daysLeft Days)',
                    style: typography.button.copyWith(
                      color: isCustom ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
