import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/channel/presentation/views/channel/monetization/channel_monetization_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Banner displaying upcoming scheduled channel tier switch status and days remaining.
class ChannelScheduledChangeBanner extends StatelessWidget {
  final ChannelMonetizationController controller;

  const ChannelScheduledChangeBanner({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final channel = controller.channel;
    final typography = context.twTypography;
    final pendingTypeStr = channel.pendingChannelType!.name.toUpperCase();
    final effectiveDate = channel.pendingTypeEffectiveDate?.toDate() ??
        DateTime(DateTime.now().year, DateTime.now().month + 1);
    final formattedDate = DateFormat('MMMM d, yyyy').format(effectiveDate);
    final daysLeft = controller.calculateDaysLeftToSwitch();

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
            onPressed: controller.isUpdating ? null : controller.cancelScheduledChange,
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
}

/// Banner highlighting Truthworld's welcome bonus trial credit for custom channels.
class ChannelFreeTrialBanner extends StatelessWidget {
  final ChannelMonetizationController controller;

  const ChannelFreeTrialBanner({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final channel = controller.channel;
    final typography = context.twTypography;
    final remainingCredit = channel.infraConfig?.trialCreditRemainingUSD ?? 10.0;

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
}

/// Information card detailing Truthworld's zero-loss infrastructure protection policy.
class ChannelZeroLossSafeguardCard extends StatelessWidget {
  const ChannelZeroLossSafeguardCard({super.key});

  @override
  Widget build(BuildContext context) {
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
}
