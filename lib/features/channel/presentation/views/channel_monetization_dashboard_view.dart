import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/services/channel_payout_calculator.dart';
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
  late Channel _channel;
  bool _isUpdating = false;
  String _selectedPlanId = 'starter_15';

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
    _channel = widget.channel;
    if (_channel.infraConfig != null) {
      _selectedPlanId = _channel.infraConfig!.planTier;
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
    final newType = _channel.channelType == ChannelType.standard
        ? ChannelType.custom
        : ChannelType.standard;

    setState(() => _isUpdating = true);

    final success = await controller.scheduleChannelTypeChange(
      _channel.id,
      newType,
    );
    if (success) {
      final now = DateTime.now();
      final effectiveDate = DateTime(now.year, now.month + 1);
      final effectiveTimestamp = Timestamp.fromDate(effectiveDate);

      setState(() {
        _channel = Channel(
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
          updatedAt: _channel.updatedAt,
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
          infraConfig: _channel.infraConfig,
          pendingChannelType: newType,
          pendingTypeEffectiveDate: effectiveTimestamp,
          nextBillingCycleDate: effectiveTimestamp,
        );
      });

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

    setState(() => _isUpdating = false);
  }

  Future<void> _cancelScheduledChange() async {
    final controller = _channelController;

    setState(() => _isUpdating = true);

    final success = await controller.cancelScheduledChannelTypeChange(
      _channel.id,
    );
    if (success) {
      setState(() {
        _channel = Channel(
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
          updatedAt: _channel.updatedAt,
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
          infraConfig: _channel.infraConfig,
          nextBillingCycleDate: _channel.nextBillingCycleDate,
        );
      });

      Get.snackbar(
        'Request Canceled',
        'Scheduled tier switch has been canceled.',
        backgroundColor: AppColors.bgSurfaceHigh,
        colorText: Colors.white,
      );
    }

    setState(() => _isUpdating = false);
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
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.bgSurfaceHigh,
                backgroundImage: _channel.avatarUrl.isNotEmpty
                    ? NetworkImage(_channel.avatarUrl)
                    : null,
                child: _channel.avatarUrl.isEmpty
                    ? const Icon(Icons.tv, color: Colors.white, size: 30)
                    : null,
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

          // Plan Cards List
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: InfrastructureMeteringService.availablePlans.map((
                plan,
              ) {
                final isSelected = _selectedPlanId == plan.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPlanId = plan.id),
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
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
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
              const Icon(Icons.cloud_queue, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                'Infrastructure Metering',
                style: typography.headline.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Storage Meter
          _buildMeterBar(
            context,
            title: 'Video Storage',
            valueText: '${storageGB.toStringAsFixed(1)} GB / 50 GB',
            progress: (storageGB / 50.0).clamp(0.0, 1.0),
          ),
          const SizedBox(height: 12),

          // Bandwidth Meter
          _buildMeterBar(
            context,
            title: 'CDN Streaming Bandwidth',
            valueText: '${bandwidthGB.toStringAsFixed(1)} GB / 200 GB',
            progress: (bandwidthGB / 200.0).clamp(0.0, 1.0),
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
