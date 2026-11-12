import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/services/infrastructure_metering_service.dart';
import 'package:truthworld/data/models/channel.dart';
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
              const SizedBox(width: 8),
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

/// Information card detailing TruthWorld's Zero-Waste Plan Rollover Policy.
/// Guarantees that if a custom channel takes a $15 plan and spends only $5,
/// the remaining $10 will roll over safe to next month and NEVER reset to $0.
class ChannelZeroWasteRolloverCard extends StatelessWidget {
  final ChannelMonetizationController controller;

  const ChannelZeroWasteRolloverCard({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final typography = context.twTypography;
    return Obx(() {
      final channel = controller.channel;
      final infra = channel.infraConfig;
      if (channel.channelType != ChannelType.custom || infra == null) {
        return const SizedBox.shrink();
      }

      final planFee = infra.flatPlatformFee > 0 ? infra.flatPlatformFee : 15.0;
      final currentSpent = InfrastructureMeteringService.calculateInfraCost(
        storageUsedBytes: controller.storageUsedBytes,
        bandwidthUsedBytes: controller.bandwidthUsedBytes,
      );
      final unspentThisMonth = (planFee - currentSpent).clamp(0.0, planFee);
      final rolloverAccumulated = infra.rolloverCreditUSD;
      final totalSafe = unspentThisMonth + rolloverAccumulated;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.savings_rounded,
                    color: Colors.white,
                    size: 22,
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
                              'Zero-Waste Rollover Guarantee',
                              style: typography.title.copyWith(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Text(
                              '0 CENTS WASTED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r'1 cent is never wasted in TruthWorld. Unspent plan funds roll over safe to next month and never expire to $0.',
                        style: typography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: AppColors.bgDivider, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStat(
                    label: 'Plan Budget',
                    value: '\$${planFee.toStringAsFixed(2)}',
                    subtext: '${infra.planTier.toUpperCase()} tier',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStat(
                    label: 'Spent This Month',
                    value: '\$${currentSpent.toStringAsFixed(2)}',
                    subtext: 'Infra consumed',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStat(
                    label: 'Safe For Next Month',
                    value: '\$${totalSafe.toStringAsFixed(2)}',
                    subtext: rolloverAccumulated > 0
                        ? 'Includes \$${rolloverAccumulated.toStringAsFixed(2)} roll'
                        : '100% Protected',
                    isHighlight: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStat({
    required String label,
    required String value,
    required String subtext,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlight
            ? const Color(0xFF0284C7).withValues(alpha: 0.2)
            : AppColors.bgInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlight
              ? const Color(0xFF38BDF8).withValues(alpha: 0.4)
              : AppColors.bgDivider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isHighlight ? const Color(0xFF38BDF8) : Colors.white,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 9,
              color: isHighlight ? const Color(0xFF7DD3FC) : AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
