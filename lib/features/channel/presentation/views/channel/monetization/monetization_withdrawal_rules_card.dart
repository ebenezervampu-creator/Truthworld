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

    final viewsRatio = (eligibility.viewCount / 1000).clamp(0.0, 1.0);
    final hoursRatio = (eligibility.watchTimeMinutes / 600).clamp(0.0, 1.0);
    final combinedProgress = ((viewsRatio + hoursRatio) / 2.0).clamp(0.0, 1.0);

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
                          ? 'Custom Channel: 100% gross revenue retention. Video cash withdrawals unlock at 1,000 views and 10 hours watch time.'
                          : 'Standard Channel: 70% Ad & Premium revenue share. Video cash withdrawals unlock at 1,000 views and 10 hours watch time.',
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

          // Video Progress Card for All Channels (Standard & Custom)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Video #1 Cash-Out Progress',
                  style: typography.title.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
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
                  isUnlocked ? 'Unlocked (1k Views & 10h Met)' : 'Locked',
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
                '${eligibility.viewCount} / 1,000 Views • $watchHours / 10.0 Hours',
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
              value: combinedProgress,
              backgroundColor: AppColors.bgSurfaceHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          if (isCustom) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Custom Channel: 100% Creator revenue retained upon reaching 1,000 views and 10 hours watch time.',
                    style: typography.caption.copyWith(
                      color: AppColors.textSecondary,
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
