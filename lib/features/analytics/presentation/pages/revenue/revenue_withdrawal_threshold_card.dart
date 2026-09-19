import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/widgets/revenue_withdrawal_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

  Widget buildWithdrawalThresholdCard(
    BuildContext context,
    RevenueAnalyticsController controller,
  ) {
    final available = controller.totalRevenue.value;
    final canWithdraw = controller.canWithdraw;
    final remaining = controller.remainingToWithdraw;
    final progress = controller.withdrawalProgress;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121218),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canWithdraw ? const Color(0xFF10B981) : const Color(0xFF27272A),
          width: canWithdraw ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (canWithdraw ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cash Payout & Withdrawal',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      canWithdraw
                          ? 'Available for cash withdrawal to your bank or UPI'
                          : 'Minimum cash withdrawal threshold is ₹100 (100 Rupees)',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (canWithdraw ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (canWithdraw ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  canWithdraw ? 'Unlocked' : 'Min ₹100',
                  style: TextStyle(
                    color: canWithdraw ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Progress Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                controller.originalUsdMemberships.value > 0
                    ? 'Available: ₹${available.toStringAsFixed(2)} (≈ \$${controller.totalRevenueUSD.value.toStringAsFixed(2)} USD)'
                    : 'Available: ₹${available.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Threshold: ₹100 (100 Rupees)',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF27272A),
                valueColor: AlwaysStoppedAnimation(
                  canWithdraw ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            canWithdraw
                ? 'Your channel balance has reached ₹100! Cash withdrawals are unlocked.'
                : '₹${remaining.toStringAsFixed(2)} more needed to reach the ₹100 (100 Rupees) cash withdrawal threshold.',
            style: TextStyle(
              color: canWithdraw ? const Color(0xFF10B981) : AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          if (controller.originalUsdMemberships.value > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.currency_exchange_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Global Fan Payments: Earnings received in US Dollars (\$) are automatically converted to Indian Rupees (₹) at ₹${RevenueAnalyticsController.usdToInrRate.toStringAsFixed(2)}/USD (real-time market rate) for direct NEFT/IMPS payout to your Indian bank account.',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (canWithdraw) {
                  RevenueWithdrawalDialog.show(context);
                } else {
                  _showThresholdNoticeDialog(context, controller);
                }
              },
              icon: Icon(
                canWithdraw ? Icons.payments_rounded : Icons.lock_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                canWithdraw ? 'Withdraw Funds' : 'Withdraw Earnings (Minimum ₹100)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canWithdraw ? const Color(0xFF10B981) : const Color(0xFF27272A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: canWithdraw ? const Color(0xFF10B981) : const Color(0xFF3F3F46),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Instant AI Tool note
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Instant Use: You do not need to wait for ₹100 to use your earnings — your balance of ₹${available.toStringAsFixed(2)} is immediately usable for AI Subtitles and Dubbing!',
                    style: const TextStyle(
                      color: Color(0xFFC7D2FE),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showThresholdNoticeDialog(
    BuildContext context,
    RevenueAnalyticsController controller,
  ) {
    Get.defaultDialog(
      title: 'Withdrawal Threshold: ₹100 (100 Rupees)',
      backgroundColor: const Color(0xFF18181B),
      titleStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'The minimum cash withdrawal threshold is ₹100 (100 Rupees).'
              '\n\n'
              'Your current accumulated earnings are ₹${controller.totalRevenue.value.toStringAsFixed(2)}. '
              'You need ₹${controller.remainingToWithdraw.toStringAsFixed(2)} more in creator revenue to unlock direct cash withdrawals.'
              '\n\n'
              'Platform Advantage: 100% of your earnings can be spent immediately anytime on platform AI features (Subtitles, Dubbing, and Highlights) without meeting the ₹100 payout gate!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
      textConfirm: 'Got it',
      confirmTextColor: Colors.black,
      buttonColor: const Color(0xFFF59E0B),
      onConfirm: Get.back,
    );
  }


