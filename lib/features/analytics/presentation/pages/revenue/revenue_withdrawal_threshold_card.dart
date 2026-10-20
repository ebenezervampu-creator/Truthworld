import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/widgets/revenue_withdrawal_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

  Widget buildWithdrawalThresholdCard(
    BuildContext context,
    RevenueAnalyticsController controller,
  ) {
    final available = controller.totalRevenue.value;
    final isHeld = controller.isWithdrawalHeld.value;
    final canWithdraw = controller.canWithdraw;
    final isAwaitingFirstOfMonth = controller.isThresholdMetButAwaitingFirstOfMonth;
    final isGraceDay = controller.isTodayGraceDay;
    final remaining = controller.remainingToWithdraw;
    final progress = controller.withdrawalProgress;
    final isIndian = Get.isRegistered<CurrencyLocalizationService>()
        ? CurrencyLocalizationService.to.isIndianUser
        : controller.isViewingINR;
    final minBadgeText = isIndian ? 'Min ₹100' : r'Min $10';
    final minFullText = isIndian ? '₹100 (100 Rupees)' : r'$10 (10 Dollars)';
    final nextPayoutFormatted = RevenueAnalyticsStateBase.upcomingFirstOfMonthFormatted;
    final nextPayoutShort = RevenueAnalyticsStateBase.nextPayoutShortMonth;

    Color statusColor;
    String badgeText;
    if (isHeld) {
      statusColor = const Color(0xFFF59E0B);
      badgeText = 'Hold (Surge)';
    } else if (canWithdraw) {
      statusColor = const Color(0xFF10B981);
      badgeText = isGraceDay ? 'Grace Period (Day 2)' : 'Unlocked';
    } else if (isAwaitingFirstOfMonth) {
      statusColor = const Color(0xFF3B82F6);
      badgeText = 'Opens 1st $nextPayoutShort';
    } else {
      statusColor = const Color(0xFFF59E0B);
      badgeText = minBadgeText;
    }

    String subtitleText;
    if (isHeld) {
      subtitleText = 'TruthWorld is fronting 100% of viral surge costs. Upgrade plan to release withdrawals.';
    } else if (canWithdraw) {
      if (isGraceDay) {
        subtitleText = isIndian
            ? 'Grace Period (Day 2 of 2): Available for cash withdrawal to your bank or UPI'
            : 'Grace Period (Day 2 of 2): Available for cash withdrawal to your bank or PayPal';
      } else {
        subtitleText = isIndian
            ? 'Withdrawal window open today (1st of month) to your bank or UPI'
            : 'Withdrawal window open today (1st of month) to your bank or PayPal';
      }
    } else if (isAwaitingFirstOfMonth) {
      subtitleText = 'YouTube-style cycle: Cash withdrawals open 1st of every month (Next: $nextPayoutFormatted)';
    } else {
      subtitleText = 'Withdrawals open on 1st of month ($minBadgeText threshold • Missed funds roll over)';
    }

    String progressText;
    if (canWithdraw) {
      if (isGraceDay) {
        progressText = 'Missed Day 1? 1-Day grace period is active today (Day 2)! Cash withdrawals are unlocked.';
      } else {
        progressText = 'Your channel balance has reached $minBadgeText and withdrawal window is open today (1st of the month)!';
      }
    } else if (isAwaitingFirstOfMonth) {
      progressText = '$minBadgeText threshold reached! Cash withdrawals open on the 1st day of every month (Next: $nextPayoutFormatted).';
    } else {
      progressText = isIndian
          ? '₹${remaining.toStringAsFixed(2)} more needed to reach ₹100. Withdrawals open on the 1st of every month.'
          : '\$${remaining.toStringAsFixed(2)} more needed to reach \$10. Withdrawals open on the 1st of every month.';
    }

    VoidCallback onButtonPressed;
    IconData buttonIcon;
    String buttonLabel;
    Color buttonBgColor;
    Color buttonBorderColor;

    if (isHeld) {
      buttonIcon = Icons.lock_clock_rounded;
      buttonLabel = 'Withdrawal on Hold (Upgrade Plan)';
      buttonBgColor = const Color(0xFFD97706);
      buttonBorderColor = const Color(0xFFF59E0B);
      onButtonPressed = () {
        AppSnackbar.warning(
          controller.withdrawalHoldReason.value.isNotEmpty
              ? controller.withdrawalHoldReason.value
              : 'TruthWorld has covered 100% of your viral infrastructure surge costs! Please upgrade your custom channel plan to release revenue withdrawals.',
          title: 'Withdrawal On Hold',
        );
      };
    } else if (canWithdraw) {
      buttonIcon = Icons.payments_rounded;
      buttonLabel = isGraceDay ? 'Withdraw Funds (Grace Period Day 2)' : 'Withdraw Funds';
      buttonBgColor = const Color(0xFF10B981);
      buttonBorderColor = const Color(0xFF10B981);
      onButtonPressed = () {
        RevenueWithdrawalDialog.show(context);
      };
    } else if (isAwaitingFirstOfMonth) {
      buttonIcon = Icons.calendar_month_rounded;
      buttonLabel = 'Withdraw on 1st of Month (Opens $nextPayoutShort 1st)';
      buttonBgColor = const Color(0xFF1E293B);
      buttonBorderColor = const Color(0xFF3B82F6);
      onButtonPressed = () {
        _showMonthlyPayoutScheduleDialog(context, controller);
      };
    } else {
      buttonIcon = Icons.lock_outline_rounded;
      buttonLabel = 'Withdraw Earnings (${isIndian ? 'Minimum ₹100' : 'Minimum \$10'})';
      buttonBgColor = const Color(0xFF27272A);
      buttonBorderColor = const Color(0xFF3F3F46);
      onButtonPressed = () {
        _showThresholdNoticeDialog(context, controller);
      };
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121218),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHeld
              ? const Color(0xFFF59E0B)
              : (canWithdraw
                  ? const Color(0xFF10B981)
                  : (isAwaitingFirstOfMonth ? const Color(0xFF3B82F6) : const Color(0xFF27272A))),
          width: isHeld || canWithdraw || isAwaitingFirstOfMonth ? 1.5 : 1,
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
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isHeld
                      ? Icons.lock_clock_rounded
                      : (isAwaitingFirstOfMonth ? Icons.calendar_month_rounded : Icons.payments_rounded),
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
                      subtitleText,
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
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: statusColor,
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
                isIndian
                    ? (controller.originalUsdMemberships.value > 0
                        ? 'Available: ₹${available.toStringAsFixed(2)} (≈ \$${controller.totalRevenueUSD.value.toStringAsFixed(2)} USD)'
                        : 'Available: ₹${available.toStringAsFixed(2)}')
                    : 'Available: \$${controller.totalRevenueUSD.value.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Threshold: $minFullText',
                style: const TextStyle(
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
                  canWithdraw
                      ? const Color(0xFF10B981)
                      : (isAwaitingFirstOfMonth ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            progressText,
            style: TextStyle(
              color: canWithdraw
                  ? const Color(0xFF10B981)
                  : (isAwaitingFirstOfMonth ? const Color(0xFF60A5FA) : AppColors.textSecondary),
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
              onPressed: onButtonPressed,
              icon: Icon(
                buttonIcon,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonBgColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: buttonBorderColor,
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
                    'Instant Use: You do not need to wait for the 1st of the month or ₹100 to use your earnings — your balance of ₹${available.toStringAsFixed(2)} is immediately usable for AI Subtitles and Dubbing!',
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

  void _showMonthlyPayoutScheduleDialog(
    BuildContext context,
    RevenueAnalyticsController controller,
  ) {
    final nextDate = RevenueAnalyticsStateBase.upcomingFirstOfMonthFormatted;
    final available = controller.totalRevenue.value;

    Get.defaultDialog(
      title: 'YouTube-Style Monthly Payout',
      backgroundColor: const Color(0xFF18181B),
      titleStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 17,
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'TruthWorld operates on a YouTube-standard monthly payout cycle:\n\n'
              '• Monthly Window: Cash withdrawals open on the 1st of every month.\n'
              '• 1-Day Grace Period: If you miss Day 1, you can still withdraw on Day 2.\n'
              '• Automatic Rollover: If missed, 100% of your earnings roll over automatically to next month ($nextDate) — your funds never expire or disappear!\n\n'
              'Your current accumulated earnings: ₹${available.toStringAsFixed(2)} (₹100 threshold met).\n\n'
              'Instant AI Use: 100% of your earnings can be spent immediately anytime on AI Subtitles and Dubbing without waiting!',
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
      buttonColor: const Color(0xFF3B82F6),
      onConfirm: Get.back,
    );
  }

  void _showThresholdNoticeDialog(
    BuildContext context,
    RevenueAnalyticsController controller,
  ) {
    final isIndian = controller.isViewingINR;
    final minFullText = isIndian ? '₹100 (100 Rupees)' : r'$10 (10 Dollars)';
    final currentBal = isIndian
        ? '₹${controller.totalRevenue.value.toStringAsFixed(2)}'
        : '\$${controller.totalRevenueUSD.value.toStringAsFixed(2)}';
    final remainingBal = isIndian
        ? '₹${controller.remainingToWithdraw.toStringAsFixed(2)}'
        : '\$${controller.remainingToWithdraw.toStringAsFixed(2)}';

    Get.defaultDialog(
      title: 'Withdrawal Threshold: $minFullText',
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
              'The minimum cash withdrawal threshold is $minFullText, and cash withdrawals process on the 1st day of every month (with a 1-day grace period on Day 2).'
              '\n\n'
              'Your current accumulated earnings are $currentBal. '
              'You need $remainingBal more in creator revenue to reach the threshold.'
              '\n\n'
              'Next Payout Window: ${RevenueAnalyticsStateBase.upcomingFirstOfMonthFormatted}.'
              '\n\n'
              'YouTube Rollover Guarantee: Unwithdrawn or missed earnings automatically roll over to the next month without loss, and 100% can be spent immediately anytime on AI Subtitles and Dubbing!',
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


