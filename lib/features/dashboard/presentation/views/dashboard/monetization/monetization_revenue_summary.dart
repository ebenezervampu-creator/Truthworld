import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/monetization_ai_features_modal.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/monetization_card_container.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/tw_radius.dart';

/// Card showing total estimated revenue, withdrawable balance, locked balance, and AI usable balance.
class RevenueWithdrawalSummaryCard extends StatelessWidget {
  const RevenueWithdrawalSummaryCard({
    required this.controller,
    super.key,
  });

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return MonetizationCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonetizationSectionTitle(
            title: 'Revenue & Withdrawal Summary',
            trailing: IconButton(
              icon: const Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () {
                Get.defaultDialog(
                  title: 'Monetization Rules',
                  backgroundColor: AppColors.bgSurface,
                  titleStyle: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  content: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      '1. Channels start earning revenue immediately from day one.\n\n'
                      '2. Cash withdrawal for earnings from a video unlocks when that video reaches 10 hours of watch time.\n\n'
                      '3. Unwithdrawn or locked money can be spent anytime for AI subtitles, dubbing, and other platform features.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  textConfirm: 'Got it',
                  confirmTextColor: Colors.black,
                  buttonColor: AppColors.brand,
                  onConfirm: Get.back,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final revenueStr =
                controller.channelStats['revenue']?.toString() ?? '₹0.00';

            // Calculate videos eligible vs awaiting watch time
            final videos = controller.recentVideos;
            var eligibleCount = 0;
            var pendingCount = 0;
            for (final v in videos) {
              if (controller.isVideoWithdrawalEligible(v)) {
                eligibleCount++;
              } else {
                pendingCount++;
              }
            }

            final isCustom =
                controller.currentChannel.value?.channelType ==
                ChannelType.custom;
            final directWithdrawable =
                controller.rxMembershipsRevenue.value +
                controller.rxSuperchatRevenue.value;
            final adAndWatchRev =
                controller.rxAdsRevenue.value +
                controller.rxWatchTimeRevenue.value;
            final totalVideoWatchHours = videos.fold<double>(
              0.0,
              (acc, v) => acc + controller.getVideoWatchHours(v),
            );
            final eligibleVideoWatchHours = videos
                .where(controller.isVideoWithdrawalEligible)
                .fold<double>(
                  0.0,
                  (acc, v) => acc + controller.getVideoWatchHours(v),
                );
            final watchRatio = totalVideoWatchHours > 0
                ? (eligibleVideoWatchHours / totalVideoWatchHours)
                    .clamp(0.0, 1.0)
                : (eligibleCount > 0 ? 1.0 : 0.0);

            final withdrawableAdWatch = isCustom
                ? adAndWatchRev
                : (adAndWatchRev * 0.70 * watchRatio);
            final withdrawableTotal = directWithdrawable + withdrawableAdWatch;
            final lockedTotal =
                (controller.rxTotalRevenue.value - withdrawableTotal)
                    .clamp(0.0, double.infinity);

            return Column(
              children: [
                RevenueMetricRow(
                  period: 'Total Estimated Revenue',
                  amount: revenueStr,
                  isHighlight: true,
                ),
                const Divider(color: AppColors.bgDivider, height: 20),
                RevenueMetricRow(
                  period: 'Available for Cash Withdrawal',
                  amount: '₹${withdrawableTotal.toStringAsFixed(2)}',
                  subtitle: isCustom
                      ? '100% Gross Revenue directly withdrawable'
                      : (directWithdrawable > 0 && eligibleCount == 0
                          ? 'Fan Memberships & Superchats directly withdrawable'
                          : '$eligibleCount video(s) crossed 10h watch time'),
                  badgeColor: Colors.green,
                ),
                RevenueMetricRow(
                  period: 'Locked for Cash Out (Awaiting 10h)',
                  amount: '₹${lockedTotal.toStringAsFixed(2)}',
                  subtitle: pendingCount > 0
                      ? '$pendingCount video(s) under 10h watch time'
                      : (lockedTotal > 0
                          ? 'Awaiting video watch threshold'
                          : 'No locked funds'),
                  badgeColor: Colors.orange,
                ),
                RevenueMetricRow(
                  period: 'Usable Balance for AI Features',
                  amount: revenueStr,
                  subtitle: 'Ready for AI Subtitles & Dubbing',
                  badgeColor: AppColors.brand,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        SpendRevenueBottomSheet.show(context, controller),
                    icon: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: Colors.black,
                    ),
                    label: const Text('Use Balance for AI Subtitles & Dubbing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: TWRadius.mdBorderRadius,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// Reusable row component for rendering revenue and financial breakdown items.
class RevenueMetricRow extends StatelessWidget {
  const RevenueMetricRow({
    required this.period,
    required this.amount,
    super.key,
    this.isHighlight = false,
    this.subtitle,
    this.badgeColor,
  });

  final String period;
  final String amount;
  final bool isHighlight;
  final String? subtitle;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 400;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment:
            isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period,
                  style: TextStyle(
                    fontSize: isHighlight ? 15 : 14,
                    fontWeight: isHighlight
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isHighlight
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: badgeColor ?? AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 0,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: isHighlight ? (isNarrow ? 16 : 18) : (isNarrow ? 14 : 16),
                fontWeight: FontWeight.bold,
                color: isHighlight ? AppColors.brand : AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
