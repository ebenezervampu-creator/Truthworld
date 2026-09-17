import 'package:flutter/material.dart';
import 'package:truthworld/core/services/channel_payout_calculator.dart';
import 'package:truthworld/features/channel/presentation/views/channel/monetization/channel_monetization_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Single revenue line item row displaying creator share and platform share.
class ChannelRevenueRow extends StatelessWidget {
  final String label;
  final double creatorShare;
  final double platformShare;

  const ChannelRevenueRow({
    required this.label,
    required this.creatorShare,
    required this.platformShare,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
}

/// Monthly revenue breakdown section showing gross, net, and component revenue splits.
class ChannelRevenueBreakdownSection extends StatelessWidget {
  final ChannelMonetizationController controller;
  final ChannelPayoutBreakdown breakdown;
  final bool isCustom;

  const ChannelRevenueBreakdownSection({
    required this.controller,
    required this.breakdown,
    required this.isCustom,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
          ChannelRevenueRow(
            label: 'Ad Revenue (70% Creator)',
            creatorShare: controller.adRevenue * 0.70,
            platformShare: controller.adRevenue * 0.30,
          ),
          ChannelRevenueRow(
            label: 'Premium Subs (70% Creator)',
            creatorShare: controller.premiumSubRevenue * 0.70,
            platformShare: controller.premiumSubRevenue * 0.30,
          ),
          ChannelRevenueRow(
            label: 'Tips (100% Creator)',
            creatorShare: controller.tipsRevenue,
            platformShare: 0.0,
          ),
          ChannelRevenueRow(
            label: 'Memberships (100% Creator)',
            creatorShare: controller.membershipsRevenue,
            platformShare: 0.0,
          ),
        ],
      ),
    );
  }
}
