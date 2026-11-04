import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channel_plan_selection_screen.dart';
import 'package:truthworld/features/channel/presentation/views/channel_monetization_dashboard_view.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/monetization_card_container.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Top header section displaying channel monetization title and active status.
/// Styled with exact Library theme and channel avatar profile styling.
class MonetizationHeaderSection extends StatelessWidget {
  const MonetizationHeaderSection({
    required this.channel,
    this.isMonetized,
    this.onJoinTap,
    super.key,
  });

  final Channel? channel;
  final bool? isMonetized;
  final VoidCallback? onJoinTap;

  @override
  Widget build(BuildContext context) {
    final channelType = channel?.channelType ?? ChannelType.standard;
    final isCustom = channelType == ChannelType.custom;
    final active = isMonetized ?? (channel?.isMonetizationActive ?? false);
    final isUnderReview = channel?.isMonetizationUnderReview ?? false;
    final channelName = channel?.name.isNotEmpty == true ? channel!.name : 'Channel Monetization';
    final handle = channel?.handle.isNotEmpty == true
        ? (channel!.handle.startsWith('@') ? channel!.handle : '@${channel!.handle}')
        : '';

    return Row(
      children: [
        UserAvatar(
          radius: 28,
          photoUrl: channel?.avatarUrl ?? '',
          displayName: channelName,
          backgroundColor: AppColors.bgSurfaceHover,
          textColor: AppColors.textPrimary,
          fontSize: 22,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    channelName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  ChannelTypeBadge(type: channelType),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                handle.isNotEmpty
                    ? '$handle • ${isCustom ? 'Pro Infra & Direct Earnings' : (active ? 'Day 1 Monetization Program' : 'Creator Monetization Program')}'
                    : (isCustom
                        ? 'Pro Channel Infrastructure & Direct Earnings'
                        : (active ? 'Day 1 Creator Monetization Program' : 'Creator Monetization Program')),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (active)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceHover,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                SizedBox(width: 6),
                Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          )
        else if (isUnderReview)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceHover,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                SizedBox(width: 6),
                Text(
                  'UNDER REVIEW',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          )
        else
          ElevatedButton.icon(
            key: const Key('join_monetization_button'),
            onPressed: onJoinTap ?? () {},
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              size: 14,
              color: Colors.black,
            ),
            label: const Text(
              'Join',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
      ],
    );
  }
}

/// Badge indicating whether the channel is Custom or Standard in clean monochrome.
class ChannelTypeBadge extends StatelessWidget {
  const ChannelTypeBadge({
    required this.type,
    super.key,
  });

  final ChannelType type;

  @override
  Widget build(BuildContext context) {
    final isCustom = type == ChannelType.custom;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCustom ? Icons.stars_rounded : Icons.layers_rounded,
            color: Colors.white,
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            isCustom ? 'PRO CHANNEL' : 'STANDARD CHANNEL',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Infrastructure tier card with detailed quotas and action button in clean monochrome.
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

    final maxDailySeconds = channel?.maxDailyVideoDurationSeconds ?? 600;
    final maxVideoSeconds = channel?.maxVideoDurationSeconds ?? 600;
    final isQuotaIncreased = !isCustom && (channel?.hasCustomQuota == true || maxDailySeconds > 600);
    final dailyMins = (maxDailySeconds / 60).round();
    final maxVideoMins = (maxVideoSeconds / 60).round();

    return MonetizationCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
              const SizedBox(width: 8),
              ChannelTypeBadge(type: channelType),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isCustom
                ? r'Your channel operates on the Pro Channel Tier with full infrastructure control, 100% gross revenue share across all sources (0% platform cut), plans at $15, $25, $50, $100, $200/mo etc., unlimited uploads, and a 1,000 views and 10-hour watch time threshold for video cash withdrawals.'
                : isQuotaIncreased
                    ? 'Your channel is currently on the Standard Channel Tier with an Admin-Increased daily upload quota of $dailyMins min/day, zero hosting fees, 70% net revenue share on ads and premium subscriptions (30% platform), 90% creator share on superchats and memberships (10% platform fee), and a 1,000 views and 10-hour watch time threshold for cash withdrawals.'
                    : 'Your channel is currently on the Standard Channel Tier with zero hosting fees, 70% net revenue share on ads and premium subscriptions (30% platform), 90% creator share on superchats and memberships (10% platform fee), 10 min/day video upload limit, and a 1,000 views and 10-hour watch time threshold for cash withdrawals.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          if (isQuotaIncreased) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: AppColors.textLink,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚡ Admin-Increased Upload Limit Active: $dailyMins Mins / Day',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textLink,
                          ),
                        ),
                        if (channel?.quotaIncreaseReason != null &&
                            channel!.quotaIncreaseReason!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            channel!.quotaIncreaseReason!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ChannelTypeDetailTile(
                  icon: Icons.video_collection_outlined,
                  label: 'Upload Limit',
                  value: isCustom ? 'Unlimited Videos' : '$dailyMins Mins / Day',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChannelTypeDetailTile(
                  icon: Icons.timelapse_rounded,
                  label: 'Video Duration',
                  value: isCustom
                      ? 'Up to 24 Hours'
                      : 'Up to $maxVideoMins Mins / Day',
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
                  value: isCustom ? '100% Net (Plans)' : '70% Ads/Subs • 90% Fans',
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: ChannelTypeDetailTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Cash-Out Rule',
                  value: '1k Views & 30h Gate',
                ),
              ),
            ],
          ),

          if (pendingType != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceHover,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.15)),
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
                      'Scheduled to switch to ${pendingType == ChannelType.custom ? 'PRO' : pendingType.name.toUpperCase()} CHANNEL at the next billing cycle.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!isCustom) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.35),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.stars_rounded,
                    color: Color(0xFFA78BFA),
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Keep 100% of Your Revenue',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Upgrade to Pro Channel for 0% platform fee, unlimited uploads, 24h video duration, and dedicated cloud infrastructure.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: isCustom
                ? OutlinedButton.icon(
                    onPressed: () async {
                      const currentPlan = ChannelPlanType.custom;
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
                    label: const Text(
                      'Manage Pro Infra & Tier Settings',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.bgSurfaceHover,
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () async {
                      final selectedPlan = await ChannelTypeSelectorModal.show(
                        context,

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
                      Icons.rocket_launch_rounded,
                      color: Colors.black,
                      size: 16,
                    ),
                    label: const Text(
                      'Upgrade to Pro Channel (100% Rev-Share)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
        color: AppColors.bgPage,
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
