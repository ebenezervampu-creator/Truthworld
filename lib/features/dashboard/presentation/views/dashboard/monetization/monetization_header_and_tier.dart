import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channel_plan_selection_screen.dart';
import 'package:truthworld/features/channel/presentation/views/channel_monetization_dashboard_view.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/monetization_card_container.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Top header section displaying channel monetization title and active status.
class MonetizationHeaderSection extends StatelessWidget {
  const MonetizationHeaderSection({
    required this.channel,
    this.isMonetized,
    super.key,
  });

  final Channel? channel;
  final bool? isMonetized;

  @override
  Widget build(BuildContext context) {
    final channelType = channel?.channelType ?? ChannelType.standard;
    final isCustom = channelType == ChannelType.custom;
    final active = isMonetized ?? true;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  const Text(
                    'Channel Monetization',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  ChannelTypeBadge(type: channelType),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isCustom
                    ? 'Custom Channel Infrastructure & Direct Earnings'
                    : 'Day 1 Creator Monetization Program',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? Colors.green.withValues(alpha: 0.5)
                  : Colors.orange.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_top_rounded,
                color: active ? Colors.green : Colors.orange,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                active ? 'ACTIVE' : 'QUALIFICATION PENDING',
                style: TextStyle(
                  color: active ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Badge indicating whether the channel is Custom or Standard.
class ChannelTypeBadge extends StatelessWidget {
  const ChannelTypeBadge({
    required this.type,
    super.key,
  });

  final ChannelType type;

  @override
  Widget build(BuildContext context) {
    final isCustom = type == ChannelType.custom;
    final badgeColor = isCustom ? AppColors.warning : AppColors.info;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCustom ? Icons.stars_rounded : Icons.layers_rounded,
            color: badgeColor,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            isCustom ? 'CUSTOM CHANNEL' : 'STANDARD CHANNEL',
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Infrastructure tier card with detailed quotas and action button.
class ChannelTypeCard extends StatelessWidget {
  const ChannelTypeCard({
    required this.channel,
    super.key,
  });

  final Channel? channel;

  @override
  Widget build(BuildContext context) {
    final channelType = channel?.channelType ?? ChannelType.standard;
    final isCustom = channelType == ChannelType.custom;
    final pendingType = channel?.pendingChannelType;

    return MonetizationCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isCustom
                            ? AppColors.warning
                            : AppColors.brand,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Channel Type & Infrastructure Tier',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ChannelTypeBadge(type: channelType),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isCustom
                ? r'Your channel operates on the Custom Channel Tier with full infrastructure control, 100% gross revenue share across all sources (0% platform cut), plans at $15, $30, $45, $100, $200/mo etc., unlimited uploads, and a 1,000 views and 10-hour watch time threshold for video cash withdrawals.'
                : 'Your channel is currently on the Standard Channel Tier with zero hosting fees, 70% net revenue share on ads and premium subscriptions (30% platform), 100% creator share on superchats and memberships (0% platform), 10 min/day video upload limit, and a 1,000 views and 10-hour watch time threshold for cash withdrawals.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ChannelTypeDetailTile(
                  icon: Icons.video_collection_outlined,
                  label: 'Upload Limit',
                  value: isCustom ? 'Unlimited Videos' : '10 Mins / Day',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChannelTypeDetailTile(
                  icon: Icons.timelapse_rounded,
                  label: 'Video Duration',
                  value: isCustom
                      ? 'Up to 24 Hours'
                      : 'Up to 10 Mins / Day',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ChannelTypeDetailTile(
                  icon: Icons.pie_chart_outline_rounded,
                  label: 'Revenue Share',
                  value: isCustom ? '100% Net (Plans)' : '70% Ads/Subs • 100% Fans',
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: ChannelTypeDetailTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Cash-Out Rule',
                  value: '1k Views & 10h Gate',
                ),
              ),
            ],
          ),

          if (pendingType != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Scheduled to switch to ${pendingType.name.toUpperCase()} CHANNEL at the next billing cycle.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final currentPlan = isCustom
                    ? ChannelPlanType.custom
                    : ChannelPlanType.standard;
                final selectedPlan = await ChannelTypeSelectorModal.show(
                  context,
                  initialPlan: currentPlan,
                );
                if (selectedPlan != null && channel != null) {
                  unawaited(
                    Get.to<void>(
                      () => ChannelMonetizationDashboardView(channel: channel!),
                    ),
                  );
                }
              },
              icon: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 16,
              ),
              label: Text(
                isCustom
                    ? 'Manage Custom Infra & Tier Settings'
                    : 'Explore / Switch Channel Type',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.brand.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Detail tile for displaying single metric / limit under channel type.
class ChannelTypeDetailTile extends StatelessWidget {
  const ChannelTypeDetailTile({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
