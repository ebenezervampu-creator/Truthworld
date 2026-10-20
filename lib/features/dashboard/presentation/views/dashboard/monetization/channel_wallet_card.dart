import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/channel_wallet_topup_sheet.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/monetization_ai_features_modal.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/monetization_card_container.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/tw_radius.dart';

/// Interactive card presenting the channel's wallet balance, top-up actions, and live transaction stream.
class ChannelWalletCard extends StatelessWidget {
  const ChannelWalletCard({
    required this.channel,
    this.controller,
    super.key,
  });

  final Channel channel;
  final DashboardController? controller;

  @override
  Widget build(BuildContext context) {
    final walletService = ChannelWalletService();
    final showTransactions = false.obs;

    final rate = Get.isRegistered<CurrencyLocalizationService>()
        ? CurrencyLocalizationService.to.rate
        : CurrencyLocalizationService.defaultRate;

    final liveChannel = controller?.currentChannel.value ?? channel;

    // Convert dashboard INR revenues to USD before computing spendable balance
    final rawTotalRevINR = controller?.rxTotalRevenue.value ?? 0.0;
    final withdrawableRevINR = (controller?.rxMembershipsRevenue.value ?? 0.0) +
        (controller?.rxSuperchatRevenue.value ?? 0.0);
    final rawTotalRevUSD = rawTotalRevINR > 0 ? (rawTotalRevINR / rate) : 0.0;
    final withdrawableRevUSD =
        withdrawableRevINR > 0 ? (withdrawableRevINR / rate) : 0.0;

    final spendable = walletService.getSpendableBalance(
      channel: liveChannel,
      rawTotalRevenue: rawTotalRevUSD,
      withdrawableRevenue: withdrawableRevUSD,
    );

    final totalUsd = spendable.totalSpendableBalance;
    final inrEquiv = (totalUsd * rate).toStringAsFixed(2);
    final isCustom = liveChannel.channelType == ChannelType.custom;

    return MonetizationCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isCustom ? AppColors.warning : AppColors.brand,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Channel Wallet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCustom
                      ? AppColors.warning.withValues(alpha: 0.15)
                      : AppColors.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCustom
                        ? AppColors.warning.withValues(alpha: 0.4)
                        : AppColors.brand.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  isCustom ? 'CUSTOM WALLET' : 'STANDARD WALLET',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isCustom ? AppColors.warning : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Total Spendable Balance Callout
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Spendable Balance',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '\$${totalUsd.toStringAsFixed(2)}',
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
                const SizedBox(height: 12),
                const Divider(color: AppColors.bgDivider, height: 1),
                const SizedBox(height: 12),

                // Balance Breakdown
                Row(
                  children: [
                    Expanded(
                      child: _buildBreakdownItem(
                        label: 'Deposited Funds',
                        amount: '\$${spendable.fundedBalance.toStringAsFixed(2)}',
                        icon: Icons.account_balance_wallet_outlined,
                        color: Colors.white,
                      ),
                    ),
                    if (isCustom && spendable.rolloverCredit > 0) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildBreakdownItem(
                          label: 'Rollover Safe',
                          amount: '\$${spendable.rolloverCredit.toStringAsFixed(2)}',
                          icon: Icons.savings_rounded,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildBreakdownItem(
                        label: 'Earned Revenue',
                        amount: '\$${spendable.totalRevenue.toStringAsFixed(2)}',
                        icon: Icons.trending_up_rounded,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Add Money & Spend Features
          Row(
            children: [
              Expanded(
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
                    size: 18,
                  ),
                  label: const Text(
                    'Add Money',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: TWRadius.mdBorderRadius,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (controller != null) {
                      SpendRevenueBottomSheet.show(context, controller!);
                    }
                  },
                  icon: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Spend on Features',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.bgDivider),
                    backgroundColor: AppColors.bgInput,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: TWRadius.mdBorderRadius,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Collapsible Recent Transactions Header
          InkWell(
            onTap: showTransactions.toggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Wallet Activity',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Obx(() => Icon(
                        showTransactions.value
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      )),
                ],
              ),
            ),
          ),

          // Transactions Stream
          Obx(() {
            if (!showTransactions.value) return const SizedBox.shrink();

            return StreamBuilder<List<WalletTransaction>>(
              stream: walletService.streamChannelTransactions(channel.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.brand,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  );
                }

                final transactions = snapshot.data ?? [];
                if (transactions.isEmpty) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'No wallet transactions yet. Funds added or spent for AI features will appear here.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length.clamp(0, 5),
                  separatorBuilder: (_, _) =>
                      const Divider(color: AppColors.bgDivider, height: 12),
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final isTopup =
                        tx.category == WalletTransactionCategory.walletTopup;
                    final formattedDate =
                        DateFormat('MMM d, h:mm a').format(tx.timestamp);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isTopup
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : AppColors.bgSurfaceHover,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isTopup
                                  ? Icons.add_rounded
                                  : Icons.remove_rounded,
                              color: isTopup ? Colors.green : Colors.white70,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
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
                            isTopup
                                ? '+\$${tx.amount.toStringAsFixed(2)}'
                                : '-\$${tx.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isTopup ? Colors.green : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem({
    required String label,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
