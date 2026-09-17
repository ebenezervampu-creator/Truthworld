import 'package:flutter/material.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/features/channel/presentation/views/channel/monetization/channel_monetization_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Top profile card displaying channel identity, monetization tier, and switch status.
class ChannelMonetizationHeaderCard extends StatelessWidget {
  final ChannelMonetizationController controller;
  final bool isCustom;

  const ChannelMonetizationHeaderCard({
    required this.controller,
    required this.isCustom,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final channel = controller.channel;
    final typography = context.twTypography;
    final daysLeft = controller.calculateDaysLeftToSwitch();
    final nextTypeStr = isCustom ? 'Standard' : 'Custom';

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
              UserAvatar(
                radius: 30,
                photoUrl: channel.avatarUrl,
                displayName: channel.name,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: typography.headline.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurfaceHigh,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.bgDivider),
                          ),
                          child: Text(
                            isCustom
                                ? 'Custom Channel (0% Cut)'
                                : 'Standard Channel (70/30 Split)',
                            style: typography.label.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurfaceHigh,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.bgDivider),
                          ),
                          child: Text(
                            '⏳ $daysLeft Days left to switch',
                            style: typography.label.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.bgDivider, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  channel.pendingChannelType != null
                      ? 'Scheduled to switch to ${channel.pendingChannelType!.name.toUpperCase()} in $daysLeft days.'
                      : 'Requesting a switch to $nextTypeStr Channel today will take effect in $daysLeft days (Next Billing Cycle).',
                  style: typography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
