import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/pages/revenue/revenue_withdrawal_threshold_card.dart';
import 'package:truthworld/features/analytics/presentation/widgets/revenue_withdrawal_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/monetization_card_container.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/tw_radius.dart';

/// Unified Channel Account & Financial Hub Card.
/// Seamlessly unifies the Channel Wallet (pre-funded deposits & AI spends) with
/// Channel Revenue (monetization earnings, watch-time thresholds, and cash payouts).
class ChannelAccountHubCard extends StatelessWidget {
  const ChannelAccountHubCard({
    this.channel,
    this.controller,
    this.revController,
    super.key,
  });

  final Channel? channel;
  final DashboardController? controller;
  final RevenueAnalyticsController? revController;

  @override
  Widget build(BuildContext context) {
    final walletService = ChannelWalletService();
    final localCurrency = 'INR'.obs;

    final rate = Get.isRegistered<CurrencyLocalizationService>()
        ? CurrencyLocalizationService.to.rate
        : CurrencyLocalizationService.defaultRate;

    final effectiveRevController = revController ??
        (Get.isRegistered<RevenueAnalyticsController>()
            ? RevenueAnalyticsController.to
            : null);

    return Obx(() {
      final liveChannel = controller?.currentChannel.value ??
          channel ??
          Channel(
            id: controller?.channelId.isNotEmpty == true
                ? controller!.channelId
                : (effectiveRevController?.channelId.value.isNotEmpty == true
                    ? effectiveRevController!.channelId.value
                    : 'default_channel'),
            name: controller?.currentChannel.value?.name ??
                effectiveRevController?.channelName.value ??
                'Channel',
            nameLowercase: 'channel',
            handle: '@channel',
            handleLowercase: '@channel',
            description: '',
            avatarUrl: '',
            bannerUrl: '',
            ownerId: '',
            createdAt: Timestamp.now(),
            updatedAt: Timestamp.now(),
          );
      final isCustom = liveChannel.channelType == ChannelType.custom;

      final isViewingINR = effectiveRevController?.isViewingINR ?? (localCurrency.value == 'INR');

      // ── Financial Calculations ──
      final rawTotalRevINR = controller?.rxTotalRevenue.value ??
          effectiveRevController?.totalRevenue.value ??
          liveChannel.clearedBalanceINR;

      final directWithdrawableINR = (controller?.rxMembershipsRevenue.value ?? 0.0) +
          (controller?.rxSuperchatRevenue.value ?? 0.0);

      final adAndWatchRevINR = (controller?.rxAdsRevenue.value ?? 0.0) +
          (controller?.rxPremiumSubsRevenue.value ?? 0.0);

      // Evaluate video watch time eligibility ratio
      final videos = controller?.recentVideos ?? [];
      var eligibleCount = 0;
      for (final v in videos) {
        if (controller?.isVideoWithdrawalEligible(v) == true) {
          eligibleCount++;
        }
      }

      final totalVideoWatchHours = videos.fold<double>(
        0.0,
        (acc, v) => acc + (controller?.getVideoWatchHours(v) ?? 0.0),
      );
      final eligibleVideoWatchHours = videos
          .where((v) => controller?.isVideoWithdrawalEligible(v) == true)
          .fold<double>(
            0.0,
            (acc, v) => acc + (controller?.getVideoWatchHours(v) ?? 0.0),
          );

      final watchRatio = totalVideoWatchHours > 0
          ? (eligibleVideoWatchHours / totalVideoWatchHours).clamp(0.0, 1.0)
          : (eligibleCount > 0 ? 1.0 : 0.0);

      final withdrawableAdWatchINR = isCustom
          ? (adAndWatchRevINR * watchRatio)
          : (adAndWatchRevINR * 0.70 * watchRatio);

      final withdrawableINR = controller != null
          ? (directWithdrawableINR + withdrawableAdWatchINR)
          : (effectiveRevController?.totalRevenue.value ??
              liveChannel.availableWithdrawableINR);

      final lockedINR = (rawTotalRevINR - withdrawableINR).clamp(0.0, double.infinity);

      final rawTotalRevUSD = rawTotalRevINR > 0 ? (rawTotalRevINR / rate) : 0.0;
      final withdrawableRevUSD = withdrawableINR > 0 ? (withdrawableINR / rate) : 0.0;
      final lockedRevUSD = lockedINR > 0 ? (lockedINR / rate) : 0.0;

      final spendable = walletService.getSpendableBalance(
        channel: liveChannel,
        rawTotalRevenue: rawTotalRevUSD,
        withdrawableRevenue: withdrawableRevUSD,
        lockedRevenue: lockedRevUSD,
      );

      final totalSpendableUSD = spendable.totalSpendableBalance;
      final inrEquiv = (totalSpendableUSD * rate).toStringAsFixed(2);

      return MonetizationCardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header & Channel Badge (Overflow-Safe) ──
            LayoutBuilder(
              builder: (context, headerConstraints) {
                final isCompact = headerConstraints.maxWidth < 400;
                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.bgSurfaceHover,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.textPrimary.withValues(alpha: 0.15),
                              ),
                            ),
                            child: const Icon(
                              Icons.payments_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Channel Revenue',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: const Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            tooltip: 'Channel Account Rules',
                            onPressed: () => _showMonetizationInfoDialog(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Monetization & Payouts Hub',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.bgSurfaceHover,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.textPrimary.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Text(
                              isCustom ? 'CUSTOM ACCOUNT' : 'STANDARD ACCOUNT',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.bgSurfaceHover,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.textPrimary.withValues(alpha: 0.15),
                              ),
                            ),
                            child: const Icon(
                              Icons.payments_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Channel Revenue',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Monetization & Payouts Hub',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurfaceHover,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.textPrimary.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            isCustom ? 'CUSTOM ACCOUNT' : 'STANDARD ACCOUNT',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          tooltip: 'Channel Account Rules',
                          onPressed: () => _showMonetizationInfoDialog(context),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Hero Total Purchasing Power Box ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Text(
                        'Total Channel Revenue',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Currency View Toggle (INR vs USD)
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.bgPage,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.bgDivider),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildCurrencyChip(
                                  label: '₹ INR',
                                  isSelected: isViewingINR,
                                  onTap: () {
                                    if (effectiveRevController != null) {
                                      effectiveRevController.setCurrencyView('INR');
                                    } else {
                                      localCurrency.value = 'INR';
                                    }
                                  },
                                ),
                                _buildCurrencyChip(
                                  label: r'$ USD',
                                  isSelected: !isViewingINR,
                                  onTap: () {
                                    if (effectiveRevController != null) {
                                      effectiveRevController.setCurrencyView('USD');
                                    } else {
                                      localCurrency.value = 'USD';
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.bgSurfaceHover,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.textPrimary.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.trending_up_rounded,
                                  color: Colors.white,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    effectiveRevController?.revenueChange.value ??
                                        (controller?.channelStats['revenueChange']?.toString() ??
                                            (isViewingINR ? '+₹0.00' : r'+$0.00')),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        isViewingINR
                            ? '₹$inrEquiv'
                            : '\$${totalSpendableUSD.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isViewingINR
                              ? '(≈ \$${totalSpendableUSD.toStringAsFixed(2)} USD)'
                              : '(≈ ₹$inrEquiv INR)',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPillTag(
                        icon: Icons.verified_rounded,
                        label: '0% Platform Fee on Fan Support',
                      ),
                      _buildPillTag(
                        icon: Icons.calendar_today_rounded,
                        label: 'Last 28 days',
                      ),
                      if (effectiveRevController?.originalUsdMemberships.value != null &&
                          effectiveRevController!.originalUsdMemberships.value > 0)
                        _buildPillTag(
                          icon: Icons.currency_exchange_rounded,
                          label: 'Exchange Rate: 1 USD = ₹${rate.toStringAsFixed(2)} INR',
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.bgDivider, height: 1),
                  const SizedBox(height: 14),

                  // ── Two-Way Financial Breakdown ──
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 400;
                      final withdrawableText = isViewingINR
                          ? '₹${withdrawableINR.toStringAsFixed(2)}'
                          : '\$${withdrawableRevUSD.toStringAsFixed(2)}';
                      final lockedText = isViewingINR
                          ? '₹${lockedINR.toStringAsFixed(2)}'
                          : '\$${lockedRevUSD.toStringAsFixed(2)}';

                      return isNarrow
                          ? Column(
                              children: [
                                _buildSubMetricItem(
                                  label: 'Withdrawable Cash',
                                  amount: withdrawableText,
                                  subtitle: withdrawableINR >= 100.0
                                      ? 'Bank / UPI Ready (₹100 Met)'
                                      : 'Min ₹100 threshold • 1st of month',
                                  icon: Icons.check_circle_outline_rounded,
                                ),
                                const SizedBox(height: 8),
                                _buildSubMetricItem(
                                  label: 'Locked Earnings',
                                  amount: lockedText,
                                  subtitle: '7-Day Hold • In clearing',
                                  icon: Icons.hourglass_top_rounded,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _buildSubMetricItem(
                                    label: 'Withdrawable Cash',
                                    amount: withdrawableText,
                                    subtitle: withdrawableINR >= 100.0
                                        ? 'Bank / UPI Ready (₹100 Met)'
                                        : 'Min ₹100 threshold • 1st of month',
                                    icon: Icons.check_circle_outline_rounded,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildSubMetricItem(
                                    label: 'Locked Earnings',
                                    amount: lockedText,
                                    subtitle: '7-Day Hold • In clearing',
                                    icon: Icons.hourglass_top_rounded,
                                  ),
                                ),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Primary Action Bar ──
            LayoutBuilder(
              builder: (context, actionConstraints) {
                final cashOutBtn = ElevatedButton.icon(
                  onPressed: () => _handleCashOutAction(context, withdrawableINR, liveChannel),
                  icon: const Icon(
                    Icons.account_balance_rounded,
                    color: Colors.black,
                    size: 17,
                  ),
                  label: const Text(
                    'Cash Out',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: TWRadius.mdBorderRadius,
                    ),
                  ),
                );

                return Row(
                  children: [
                    Expanded(child: cashOutBtn),
                  ],
                );
              },
            ),
          ],
        ),
      );
    });
  }

  // ── Sub-metric Column Item ──
  Widget _buildSubMetricItem({
    required String label,
    required String amount,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cash Out Action Router ──
  void _handleCashOutAction(
    BuildContext context,
    double withdrawableINR,
    Channel liveChannel,
  ) {
    final rev = revController ?? RevenueAnalyticsController.to;
    if (rev.channelId.value != liveChannel.id) {
      rev.loadRevenueAnalytics(liveChannel.id, chName: liveChannel.name);
    }

    // 1. Minimum threshold check (₹100) -> Opens the detailed threshold popup modal
    if (withdrawableINR < 100.0 && rev.totalRevenue.value < 100.0) {
      showThresholdNoticeDialog(context, rev);
      return;
    }

    // 2. Threshold met but awaiting 1st of month payout schedule -> Opens YouTube-style monthly schedule popup
    if (!rev.canWithdraw && rev.isThresholdMetButAwaitingFirstOfMonth) {
      showMonthlyPayoutScheduleDialog(context, rev);
      return;
    }

    // 3. Payout active -> Opens Cash Withdrawal Dialog
    RevenueWithdrawalDialog.show(context);
  }

  // ── Info Rules Dialog ──
  void _showMonetizationInfoDialog(BuildContext context) {
    Get.defaultDialog(
      title: 'Channel Account Rules',
      backgroundColor: AppColors.bgSurface,
      titleStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
      ),
      content: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          '1. Channel Monetization ON: Monetization turns ON for your channel when ANY video crosses 1,000 views and 30 hours of watch time, and creator KYC verification is completed.\n\n'
          '2. Revenue Generation: From then on, every uploaded video on your channel generates revenue.\n\n'
          '3. Cash Out Window: Money generated by a specific video becomes available for cash withdrawal once that video crosses 1,000 views and 30 hours of watch time (YouTube-style monthly cycle: 1st of month + 1-day grace, min ₹100).',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ),
      textConfirm: 'Got it',
      confirmTextColor: Colors.black,
      buttonColor: Colors.white,
      onConfirm: Get.back,
    );
  }

  // ── Currency View Toggle Chip ──
  Widget _buildCurrencyChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Informative Pill Tag ──
  Widget _buildPillTag({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
