import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/views/channel/monetization/channel_monetization_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Studio creator advisory card displayed when a custom channel experiences a viral hype spike.
/// Collects and displays 100% revenue across Ads, Premium Subs, Memberships, and Superchats,
/// shows incurred infrastructure surge costs, guides the creator to upgrade their custom plan,
/// and enables immediate 100% revenue withdrawal.
class ChannelHypeSurgeAdvisoryCard extends StatelessWidget {
  final ChannelMonetizationController controller;

  const ChannelHypeSurgeAdvisoryCard({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final typography = context.twTypography;
    final rate = Get.isRegistered<CurrencyLocalizationService>()
        ? CurrencyLocalizationService.to.rate
        : CurrencyLocalizationService.defaultRate;

    return Obx(() {
      final summary = controller.hypeSurgeSummary;
      final recommendedPlan = summary.recommendedUpgradePlan;
      final spendable = controller.spendableBalance;
      final isUpdating = controller.isUpdating;
      final grossInr = (summary.grossTotalRevenue * rate).toStringAsFixed(2);
      final netInr = (summary.netWithdrawableAfterUpgrade * rate).toStringAsFixed(2);

      // Determine surge alert badge
      String statusBadgeText;
      Color statusBadgeColor;
      if (summary.lossPreventionMode == LossPreventionMode.autoScaled) {
        statusBadgeText = 'AUTO-SCALED AT 480P (ZERO-LOSS ACTIVE)';
        statusBadgeColor = const Color(0xFF10B981);
      } else if (summary.isWithdrawalHeld) {
        statusBadgeText = 'TRUTHWORLD FRONTING 100% COSTS • WITHDRAWAL ON HOLD';
        statusBadgeColor = const Color(0xFFEF4444);
      } else if (summary.lossPreventionMode == LossPreventionMode.warning) {
        statusBadgeText = 'HIGH BANDWIDTH STRAIN (75% QUOTA)';
        statusBadgeColor = const Color(0xFFEAB308);
      } else {
        statusBadgeText = 'VIRAL HYPE SURGE ACTIVE (UNINTERRUPTED HD)';
        statusBadgeColor = const Color(0xFF8B5CF6);
      }

      final usagePercent = summary.bandwidthUsagePercent;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF16131F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Sudden Hype Surge Detected',
                              style: typography.headline.copyWith(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBadgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: statusBadgeColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          statusBadgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: statusBadgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Text(
              'Your video experienced a massive traffic spike! Under your ${summary.currentPlan.title} (\$${summary.currentPlan.priceUSD.toStringAsFixed(0)}/mo) custom plan, streaming bandwidth surged to ${summary.bandwidthUsedGB.toStringAsFixed(1)} GB. TruthWorld Zero-Loss Protection kept your channel live without overdraft debt.',
              style: typography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.bgDivider, height: 1),
            const SizedBox(height: 16),

            // Revenue Collected from all 4 streams (100% Creator Retention)
            Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF10B981),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Collected Hype Revenue (100% Creator Retention — 0% Platform Fee)',
                    style: typography.title.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 4 Revenue Stream Tiles
            Row(
              children: [
                Expanded(
                  child: _buildRevenuePill(
                    label: 'Ads Revenue',
                    amount: '\$${summary.adRevenue.toStringAsFixed(2)}',
                    subtext: '100% Creator',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildRevenuePill(
                    label: 'Premium Subs',
                    amount: '\$${summary.premiumSubRevenue.toStringAsFixed(2)}',
                    subtext: '100% Creator',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildRevenuePill(
                    label: 'Memberships',
                    amount: '\$${summary.membershipsRevenue.toStringAsFixed(2)}',
                    subtext: '100% Creator',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildRevenuePill(
                    label: 'Superchats & Tips',
                    amount: '\$${summary.tipsRevenue.toStringAsFixed(2)}',
                    subtext: '100% Creator',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Gross Revenue Callout
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Hype Revenue Collected:',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '\$${summary.grossTotalRevenue.toStringAsFixed(2)} (≈ ₹$grossInr)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Infrastructure Metering & Surge Costs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Surge Bandwidth Consumption',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${summary.bandwidthUsedGB.toStringAsFixed(1)} GB / ${summary.bandwidthQuotaGB.toStringAsFixed(0)} GB',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: usagePercent.clamp(0.0, 1.0),
                backgroundColor: AppColors.bgInput,
                valueColor: AlwaysStoppedAnimation<Color>(
                  usagePercent >= 1.0
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF8B5CF6),
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Incurred Cloud Infrastructure Cost:',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '\$${summary.currentInfraCost.toStringAsFixed(2)} USD',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Studio Creator Advisory & Cost Recovery Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF4C1D95).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFA855F7).withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.upgrade_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      Expanded(
                        child: Text(
                          summary.isWithdrawalHeld
                              ? 'Zero-Downtime Guarantee: TruthWorld is Fronting 100% of Surge Costs'
                              : 'Studio Action Required: Upgrade Plan to Cover Surge',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary.isWithdrawalHeld
                        ? 'TruthWorld pays for 100% of all cloud infrastructure and CDN egress costs exceeding your current plan — your viewers experience uninterrupted, full-quality 1080p/4K streaming without any throttling.\n\n'
                            'Because TruthWorld is fronting your delivery costs, revenue withdrawals are temporarily on hold until you upgrade to the ${recommendedPlan.title} (\$${recommendedPlan.priceUSD.toStringAsFixed(0)}/mo) tier (${recommendedPlan.bandwidthGB} GB CDN).\n\n'
                            'You can settle the upgrade directly using your \$${spendable.totalSpendableBalance.toStringAsFixed(2)} earned revenue balance. The instant you upgrade, the withdrawal hold is released and you can cash out 100% of your remaining earnings (≈ ₹$netInr) directly to your bank account!'
                        : 'To maintain your growing audience and ensure ample capacity, upgrade to the ${recommendedPlan.title} (\$${recommendedPlan.priceUSD.toStringAsFixed(0)}/mo) tier (${recommendedPlan.bandwidthGB} GB CDN).\n\n'
                            'You can settle the upgrade directly using your \$${spendable.totalSpendableBalance.toStringAsFixed(2)} earned revenue balance. Once upgraded, all surge capacity is secured, and you can withdraw 100% of your remaining earnings (≈ ₹$netInr) directly to your bank account!',
                    style: typography.caption.copyWith(
                      color: const Color(0xFFDDD6FE),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons: Upgrade Plan & Withdraw 100% Revenue
            Row(
              children: [
                // Upgrade Plan Button (White/Brand background -> strictly Black text & Black icons)
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: isUpdating
                        ? null
                        : controller.upgradePlanToCoverSurge,
                    icon: isUpdating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.black,
                            size: 16,
                          ),
                    label: Text(
                      isUpdating
                          ? 'Upgrading...'
                          : 'Upgrade to ${recommendedPlan.title} (\$${recommendedPlan.priceUSD.toStringAsFixed(0)}/mo)',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: TWRadius.mdBorderRadius,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 100% Cash Withdrawal Button
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (summary.isWithdrawalHeld) {
                        AppSnackbar.warning(
                          'TruthWorld is fronting 100% of your viral infrastructure costs! Please upgrade to ${recommendedPlan.title} (\$${recommendedPlan.priceUSD.toStringAsFixed(0)}/mo) to release your withdrawals.',
                          title: 'Withdrawal On Hold',
                        );
                      } else {
                        controller.openRevenueWithdrawalDialog(context);
                      }
                    },
                    icon: Icon(
                      summary.isWithdrawalHeld
                          ? Icons.lock_outline_rounded
                          : Icons.account_balance_wallet_outlined,
                      color: summary.isWithdrawalHeld ? const Color(0xFFFBBF24) : Colors.white,
                      size: 16,
                    ),
                    label: Text(
                      summary.isWithdrawalHeld ? 'Withdraw Held' : 'Withdraw 100%',
                      style: TextStyle(
                        color: summary.isWithdrawalHeld ? const Color(0xFFFBBF24) : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: summary.isWithdrawalHeld
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                      ),
                      backgroundColor: summary.isWithdrawalHeld
                          ? const Color(0xFF78350F).withValues(alpha: 0.4)
                          : const Color(0xFF064E3B).withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: TWRadius.mdBorderRadius,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildRevenuePill({
    required String label,
    required String amount,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtext,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF10B981),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
