import 'package:flutter/material.dart';
import 'package:truthworld/core/services/channel_payout_calculator.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Card displaying the 10-hour withdrawal eligibility rule or Custom Channel unlimited withdrawal status.
class ChannelWithdrawalRulesCard extends StatelessWidget {
  final VideoWithdrawalEligibility eligibility;
  final bool isCustom;

  const ChannelWithdrawalRulesCard({
    required this.eligibility,
    required this.isCustom,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
                Expanded(
                  child: Text(
                    'Custom Channel Advantage: No watch time limits for withdrawals!',
                    style: typography.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
