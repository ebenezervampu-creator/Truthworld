import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/pages/revenue/revenue_withdrawal_threshold_card.dart';
import 'package:truthworld/features/analytics/presentation/widgets/revenue_withdrawal_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/channel_financial_history_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/channel_wallet_topup_sheet.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/monetization_ai_features_modal.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/monetization_card_container.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/tw_radius.dart';

/// Unified Channel Account & Financial Hub Card.
/// Seamlessly unifies the Channel Wallet (pre-funded deposits & AI spends) with
/// Channel Revenue (monetization earnings, watch-time thresholds, and cash payouts).
class ChannelAccountHubCard extends StatelessWidget {
  const ChannelAccountHubCard({
    required this.channel,
    this.controller,
    this.revController,
    super.key,
  });

  final Channel channel;
  final DashboardController? controller;
  final RevenueAnalyticsController? revController;

  @override
  Widget build(BuildContext context) {
    final walletService = ChannelWalletService();
    final showTransactions = true.obs;
    final selectedFilter = 'all'.obs; // 'all', 'earnings', 'spends'

    final rate = Get.isRegistered<CurrencyLocalizationService>()
        ? CurrencyLocalizationService.to.rate
        : CurrencyLocalizationService.defaultRate;

    final effectiveRevController = revController ??
        (Get.isRegistered<RevenueAnalyticsController>()
            ? RevenueAnalyticsController.to
            : null);

    return Obx(() {
      final liveChannel = controller?.currentChannel.value ?? channel;
      final isCustom = liveChannel.channelType == ChannelType.custom;

      // ── Financial Calculations ──
      final rawTotalRevINR = controller?.rxTotalRevenue.value ??
          effectiveRevController?.totalRevenue.value ??
          liveChannel.clearedBalanceINR;

      final directWithdrawableINR = (controller?.rxMembershipsRevenue.value ?? 0.0) +
          (controller?.rxSuperchatRevenue.value ?? 0.0);

      final adAndWatchRevINR = (controller?.rxAdsRevenue.value ?? 0.0) +
          (controller?.rxWatchTimeRevenue.value ?? 0.0);

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
      final prefundedAndRolloverUSD = spendable.fundedBalance + spendable.rolloverCredit;

      return MonetizationCardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header & Channel Badge ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Channel Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Unified Wallet & Monetization Hub',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
                    const SizedBox(width: 4),
                    IconButton(
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
                  const Text(
                    'Total Purchasing Power & Spendable Balance',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '\$${totalSpendableUSD.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'USD (≈ ₹$inrEquiv)',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.bgDivider, height: 1),
                  const SizedBox(height: 14),

                  // ── Three-Way Financial Breakdown ──
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 360;
                      return isNarrow
                          ? Column(
                              children: [
                                _buildSubMetricItem(
                                  label: 'Withdrawable Cash',
                                  amount: '₹${withdrawableINR.toStringAsFixed(2)}',
                                  subtitle: withdrawableINR >= 100.0
                                      ? 'Bank / UPI Ready (₹100 Met)'
                                      : 'Min ₹100 threshold • 1st of month',
                                  icon: Icons.account_balance_rounded,
                                ),
                                const SizedBox(height: 8),
                                _buildSubMetricItem(
                                  label: 'Locked Earnings',
                                  amount: '₹${lockedINR.toStringAsFixed(2)}',
                                  subtitle: 'Spend on AI or wait',
                                  icon: Icons.lock_clock_rounded,
                                ),
                                const SizedBox(height: 8),
                                _buildSubMetricItem(
                                  label: 'Pre-Funded Credits',
                                  amount: '\$${prefundedAndRolloverUSD.toStringAsFixed(2)}',
                                  subtitle: isCustom && spendable.rolloverCredit > 0
                                      ? 'Includes \$${spendable.rolloverCredit.toStringAsFixed(2)} rollover'
                                      : 'Deposited for tools',
                                  icon: Icons.savings_rounded,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _buildSubMetricItem(
                                    label: 'Withdrawable Cash',
                                    amount: '₹${withdrawableINR.toStringAsFixed(2)}',
                                    subtitle: withdrawableINR >= 100.0
                                        ? 'Bank / UPI Ready (₹100 Met)'
                                        : 'Min ₹100 threshold • 1st of month',
                                    icon: Icons.account_balance_rounded,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildSubMetricItem(
                                    label: 'Locked Earnings',
                                    amount: '₹${lockedINR.toStringAsFixed(2)}',
                                    subtitle: 'Spend on AI or wait',
                                    icon: Icons.lock_clock_rounded,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildSubMetricItem(
                                    label: 'Pre-Funded Credits',
                                    amount: '\$${prefundedAndRolloverUSD.toStringAsFixed(2)}',
                                    subtitle: isCustom && spendable.rolloverCredit > 0
                                        ? 'Includes \$${spendable.rolloverCredit.toStringAsFixed(2)} safe rollover'
                                        : 'Deposited for tools',
                                    icon: Icons.savings_rounded,
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
            Row(
              children: [
                // 1. Add Funds (White button with black text/icon)
                Expanded(
                  flex: 10,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ChannelWalletTopupSheet.show(
                        context,
                        channel: liveChannel,
                        onTopupSuccess: () {
                          controller?.refreshChannelData();
                        },
                      );
                    },
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Colors.black,
                      size: 17,
                    ),
                    label: const Text(
                      'Add Funds',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: TWRadius.mdBorderRadius,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Cash Out
                Expanded(
                  flex: 10,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleCashOutAction(context, withdrawableINR, liveChannel),
                    icon: const Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    label: const Text(
                      'Cash Out',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.bgSurfaceHover,
                      side: BorderSide(
                        color: AppColors.textPrimary.withValues(alpha: 0.2),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: TWRadius.mdBorderRadius,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Spend on AI
                Expanded(
                  flex: 11,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final DashboardController effectiveController = controller ??
                          (Get.isRegistered<DashboardController>()
                              ? Get.find<DashboardController>()
                              : Get.put(DashboardController(channelId: liveChannel.id)));
                      SpendRevenueBottomSheet.show(context, effectiveController);
                    },
                    icon: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    label: const Text(
                      'Spend on AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.bgSurfaceHover,
                      side: BorderSide(
                        color: AppColors.textPrimary.withValues(alpha: 0.2),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: TWRadius.mdBorderRadius,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Unified Financial Activity Feed ──
            InkWell(
              onTap: showTransactions.toggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Unified Activity Feed',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurfaceHover,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Live Stream',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Obx(
                      () => Icon(
                        showTransactions.value
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Activity Feed Content ──
            Obx(() {
              if (!showTransactions.value) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All Activity', 'all', selectedFilter),
                        const SizedBox(width: 8),
                        _buildFilterChip('Earnings & Payouts', 'earnings', selectedFilter),
                        const SizedBox(width: 8),
                        _buildFilterChip('Spends & Deposits', 'spends', selectedFilter),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Stream Consumer
                  StreamBuilder<List<UnifiedChannelTransaction>>(
                    stream: walletService.streamUnifiedTransactions(
                      liveChannel.id,
                      userId: liveChannel.ownerId.isNotEmpty ? liveChannel.ownerId : null,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        ErrorHandler.log(snapshot.error);
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.bgPage,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.bgDivider),
                          ),
                          child: const Text(
                            'Unable to load activity right now. Please check your connection.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        );
                      }

                      final allTransactions = snapshot.data ?? [];
                      final filtered = allTransactions.where((tx) {
                        if (selectedFilter.value == 'earnings') {
                          return tx.type == UnifiedTransactionType.payout ||
                              tx.type == UnifiedTransactionType.revenueEarned;
                        } else if (selectedFilter.value == 'spends') {
                          return tx.type == UnifiedTransactionType.topup ||
                              tx.type == UnifiedTransactionType.aiSpend ||
                              tx.type == UnifiedTransactionType.planUpgrade;
                        }
                        return true;
                      }).toList();

                      if (filtered.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.bgPage,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.bgDivider),
                          ),
                          child: Text(
                            selectedFilter.value == 'earnings'
                                ? 'No earnings or payout requests recorded yet.'
                                : (selectedFilter.value == 'spends'
                                    ? 'No tool spends or wallet deposits recorded yet.'
                                    : 'No account activity recorded yet. Deposits, AI spends, and earnings will appear here.'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length.clamp(0, 6),
                        separatorBuilder: (_, _) =>
                            const Divider(color: AppColors.bgDivider, height: 12),
                        itemBuilder: (context, index) {
                          final tx = filtered[index];
                          return _buildUnifiedTransactionRow(tx);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // ── Full History & Statement Action ──
                  InkWell(
                    onTap: () => ChannelFinancialHistoryPage.show(context, channel: liveChannel),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurfaceHover,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.history_edu_rounded, color: Colors.white, size: 15),
                          SizedBox(width: 6),
                          Text(
                            'View 8-Year Audit History & Export Statements',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
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

  // ── Filter Chip ──
  Widget _buildFilterChip(String label, String value, RxString activeFilter) {
    return Obx(() {
      final isSelected = activeFilter.value == value;
      return InkWell(
        onTap: () => activeFilter.value = value,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : AppColors.bgSurfaceHover,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.white : AppColors.bgDivider,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.black : AppColors.textSecondary,
            ),
          ),
        ),
      );
    });
  }

  // ── Unified Transaction Item Row ──
  Widget _buildUnifiedTransactionRow(UnifiedChannelTransaction tx) {
    final formattedDate = DateFormat('MMM d, h:mm a').format(tx.timestamp);

    IconData icon;
    Color iconBgColor = AppColors.bgSurfaceHover;

    switch (tx.type) {
      case UnifiedTransactionType.topup:
        icon = Icons.add_rounded;
        break;
      case UnifiedTransactionType.payout:
        icon = Icons.account_balance_rounded;
        break;
      case UnifiedTransactionType.revenueEarned:
        icon = Icons.trending_up_rounded;
        break;
      case UnifiedTransactionType.planUpgrade:
        icon = Icons.stars_rounded;
        break;
      case UnifiedTransactionType.aiSpend:
        icon = Icons.auto_awesome_rounded;
        break;
    }

    final isPayout = tx.type == UnifiedTransactionType.payout;
    final isProcessing = tx.status == 'processing' || tx.status == 'pending';
    final isRejected = tx.status == 'rejected';
    final isHeld = tx.status == 'held';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tx.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isPayout) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isRejected
                              ? Colors.red.withValues(alpha: 0.2)
                              : (isHeld
                                  ? Colors.orange.withValues(alpha: 0.2)
                                  : (isProcessing
                                      ? Colors.amber.withValues(alpha: 0.2)
                                      : Colors.green.withValues(alpha: 0.2))),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tx.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isRejected
                                ? Colors.redAccent
                                : (isHeld
                                    ? Colors.orangeAccent
                                    : (isProcessing
                                        ? Colors.amberAccent
                                        : Colors.greenAccent)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            tx.formattedAmount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: tx.isCredit ? Colors.white : Colors.white70,
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
      backgroundColor: const Color(0xFF1E1E1E),
      titleStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
      ),
      content: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          '1. Channel Monetization ON: Monetization turns ON for your channel when ANY video crosses 1,000 views and 10 hours of watch time, and creator KYC verification is completed.\n\n'
          '2. Revenue Generation: From then on, every uploaded video on your channel generates revenue.\n\n'
          '3. Cash Out Window: Money generated by a specific video becomes available for cash withdrawal once that video crosses 1,000 views and 10 hours of watch time (YouTube-style monthly cycle: 1st of month + 1-day grace, min ₹100).\n\n'
          '4. Instant AI Spend: If funds are awaiting cash-out or watch-time thresholds, you can spend them immediately on TruthWorld AI features (subtitles, voice dubbing, fact-checking) or channel plans.',
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
}
