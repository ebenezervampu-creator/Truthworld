import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channel_plan_selection_screen.dart';
import 'package:truthworld/features/channel/presentation/views/channel_monetization_dashboard_view.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_colors.dart';

class MonetizationScreen extends StatelessWidget {
  const MonetizationScreen({required this.isDarkMode, super.key});
  final bool isDarkMode;

  static const double cashOutWatchHoursThreshold = 10;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final controller = Get.isRegistered<DashboardController>()
        ? Get.find<DashboardController>()
        : (uid.isNotEmpty
              ? Get.put(DashboardController(channelId: uid))
              : null);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text(
          'Earnings & Monetization',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Get.back<void>(),
        ),
      ),
      body: controller == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            )
          : Obx(() {
              final channel = controller.currentChannel.value;
              final isCustom = channel?.channelType == ChannelType.custom;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderSection(channel),
                    const SizedBox(height: 20),
                    _buildChannelTypeCard(context, channel),
                    const SizedBox(height: 24),
                    _buildPolicyNoticeCard(isCustom),
                    const SizedBox(height: 24),
                    _buildEligibilitySection(controller, isCustom),
                    const SizedBox(height: 24),
                    _buildRevenueSummary(context, controller),
                    const SizedBox(height: 24),
                    _buildPerVideoWithdrawalSection(context, controller),
                  ],
                ),
              );
            }),
    );
  }

  Widget _buildHeaderSection(Channel? channel) {
    final channelType = channel?.channelType ?? ChannelType.standard;
    final isCustom = channelType == ChannelType.custom;

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
                  _buildChannelTypeBadge(channelType),
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
            color: Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
              SizedBox(width: 6),
              Text(
                'ACTIVE',
                style: TextStyle(
                  color: Colors.green,
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

  Widget _buildChannelTypeBadge(ChannelType type) {
    final isCustom = type == ChannelType.custom;
    final badgeColor = isCustom
        ? const Color(0xFFF59E0B)
        : const Color(0xFF3B82F6);

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
            color: Colors.white,
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

  Widget _buildChannelTypeCard(BuildContext context, Channel? channel) {
    final channelType = channel?.channelType ?? ChannelType.standard;
    final isCustom = channelType == ChannelType.custom;
    final pendingType = channel?.pendingChannelType;

    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isCustom
                          ? const Color(0xFFF59E0B)
                          : AppColors.brand,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Channel Type & Infrastructure Tier',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              _buildChannelTypeBadge(channelType),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isCustom
                ? 'Your channel operates on the Custom Channel Tier with full infrastructure control, 100% gross revenue share (minus infrastructure usage), unlimited uploads, and instant cash withdrawals.'
                : 'Your channel is currently on the Standard Channel Tier with zero hosting fees, 70% net revenue share, 20 min/day video upload limit, and a 10-hour watch time threshold for cash withdrawals.',
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
                child: _buildChannelTypeDetailTile(
                  icon: Icons.video_collection_outlined,
                  label: 'Upload Limit',
                  value: isCustom ? 'Unlimited Videos' : '20 Mins / Day',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChannelTypeDetailTile(
                  icon: Icons.timelapse_rounded,
                  label: 'Video Duration',
                  value: isCustom
                      ? 'Up to 24 Hours'
                      : 'Up to 20 Mins / Day',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildChannelTypeDetailTile(
                  icon: Icons.pie_chart_outline_rounded,
                  label: 'Revenue Share',
                  value: isCustom ? '100% Gross - Infra' : '55% Net Creator',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChannelTypeDetailTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Cash-Out Rule',
                  value: isCustom
                      ? 'Instant Withdrawal'
                      : '10h Watch Time Gate',
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
                      () => ChannelMonetizationDashboardView(channel: channel),
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

  Widget _buildChannelTypeDetailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
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

  Widget _buildPolicyNoticeCard(bool isCustom) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Instant Revenue from Day 1',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Zero subscriber requirement: Generate ad & view revenue starting immediately.\n'
                  '${isCustom ? '• Cash Payout Rule: Direct & instant cash out on all generated revenue.' : '• Cash Payout Rule: Money generated by a video becomes withdrawable once that video crosses 10 hours of watch time.'}\n'
                  '• AI Tools Usability: Locked earnings can be used anytime for features like AI Subtitles and Dubbing!',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEligibilitySection(
    DashboardController controller,
    bool isCustom,
  ) {
    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Partner Eligibility Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildEligibilityStatusTile(
                  icon: Icons.people_outline_rounded,
                  title: 'Subscriber Gate',
                  value: '0 Required',
                  subtitle: 'Monetized from Day 1',
                  isUnlocked: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEligibilityStatusTile(
                  icon: Icons.timer_outlined,
                  title: 'Cash Out Gate',
                  value: isCustom ? 'Instant' : '10h / Video',
                  subtitle: isCustom
                      ? 'No watch time restriction'
                      : 'Watch time for cash withdrawal',
                  isUnlocked: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEligibilityStatusTile(
                  icon: Icons.auto_awesome_rounded,
                  title: 'AI Features',
                  value: 'Instant Use',
                  subtitle: 'Subtitles & Dubbing',
                  isUnlocked: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEligibilityStatusTile({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required bool isUnlocked,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const Spacer(),
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueSummary(
    BuildContext context,
    DashboardController controller,
  ) {
    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Revenue & Withdrawal Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.textSecondary,
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
            ],
          ),
          const SizedBox(height: 16),
          Obx(() {
            final revenueStr =
                controller.channelStats['revenue']?.toString() ?? r'$0.00';

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

            return Column(
              children: [
                _buildRevenueRow(
                  'Total Estimated Revenue',
                  revenueStr,
                  isHighlight: true,
                ),
                const Divider(color: AppColors.bgDivider, height: 20),
                _buildRevenueRow(
                  'Available for Cash Withdrawal',
                  eligibleCount > 0
                      ? '\$${eligibleCount * 10}.00 (Est.)'
                      : r'$0.00',
                  subtitle: '$eligibleCount video(s) crossed 10h watch time',
                  badgeColor: Colors.green,
                ),
                _buildRevenueRow(
                  'Locked for Cash Out (Awaiting 10h)',
                  pendingCount > 0 ? 'Accumulating' : r'$0.00',
                  subtitle: '$pendingCount video(s) under 10h watch time',
                  badgeColor: Colors.orange,
                ),
                _buildRevenueRow(
                  'Usable Balance for AI Features',
                  revenueStr,
                  subtitle: 'Ready for AI Subtitles & Dubbing',
                  badgeColor: AppColors.brand,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _showUseForAiFeaturesDialog(context, controller),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Use Balance for AI Subtitles & Dubbing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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

  Widget _buildRevenueRow(
    String period,
    String amount, {
    bool isHighlight = false,
    String? subtitle,
    Color? badgeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: badgeColor ?? AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isHighlight ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: isHighlight ? AppColors.brand : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerVideoWithdrawalSection(
    BuildContext context,
    DashboardController controller,
  ) {
    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Video Cash-Out Eligibility (10 Hours Target)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Track watch hours per video. Money generated becomes withdrawable once that video reaches 10 hours of watch time.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final videos = controller.recentVideos;
            if (videos.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: const Text(
                  'No uploaded videos found yet.\nUpload videos to start generating revenue from Day 1!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: videos.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: AppColors.bgDivider, height: 16),
              itemBuilder: (context, index) {
                final video = videos[index];
                return _buildVideoWithdrawalRow(context, controller, video);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVideoWithdrawalRow(
    BuildContext context,
    DashboardController controller,
    Video video,
  ) {
    final watchHours = controller.getVideoWatchHours(video);
    final isEligibleForCashOut = controller.isVideoWithdrawalEligible(video);
    final progress = (watchHours / cashOutWatchHoursThreshold).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 50,
                height: 35,
                color: AppColors.bgInput,
                child: video.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        fit: BoxFit.cover,
                        width: 50,
                        height: 35,
                        placeholder: (context, url) => const ColoredBox(color: AppColors.bgInput),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      )
                    : const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title.isNotEmpty ? video.title : 'Untitled Video',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${NumberFormat.compact().format(video.viewCount)} views • ${watchHours.toStringAsFixed(1)} / 10.0 hrs watch time',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isEligibleForCashOut
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEligibleForCashOut
                      ? Colors.green.withValues(alpha: 0.4)
                      : Colors.orange.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                isEligibleForCashOut
                    ? 'Cash-Out Ready'
                    : 'Locked (${watchHours.toStringAsFixed(1)}h/10h)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isEligibleForCashOut ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: LinearPercentIndicator(
                lineHeight: 6,
                percent: progress,
                progressColor: isEligibleForCashOut
                    ? Colors.green
                    : AppColors.brand,
                backgroundColor: AppColors.bgInput,
                barRadius: const Radius.circular(3),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () =>
                  _showUseForAiFeaturesDialog(context, controller, video),
              child: const Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Use for AI Tools',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showUseForAiFeaturesDialog(
    BuildContext context,
    DashboardController controller, [
    Video? targetVideo,
  ]) {
    final walletService = ChannelWalletService();
    final ch = controller.currentChannel.value ??
        Channel(
          id: controller.channelId,
          name: 'My Channel',
          nameLowercase: 'my channel',
          handle: '@channel',
          handleLowercase: '@channel',
          description: '',
          avatarUrl: '',
          bannerUrl: '',
          ownerId: controller.channelId,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        );

    final spendable = walletService.getSpendableBalance(
      channel: ch,
      rawTotalRevenue: 35.0,
      withdrawableRevenue: 20.0,
      lockedRevenue: 15.0,
    );

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Spend Revenue & Balances',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Available Spendable: \$${spendable.totalSpendableBalance.toStringAsFixed(2)} (\$${spendable.trialCreditRemaining.toStringAsFixed(2)} Free Credit + \$${spendable.totalRevenue.toStringAsFixed(2)} Unwithdrawn Revenue)',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Section 1: AI Content Intelligence & Localization
              const Text(
                'AI Video Features',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              _buildAiFeatureOption(
                icon: Icons.fact_check_rounded,
                title: 'Fact-Checking & Credibility Report',
                description:
                    'AI claim verification, source citation & Truth Score badge.',
                costText: r'$2.00 • Instant from balance',
                onSelect: () async {
                  Get.back();
                  final uid = AuthService.to.uid.isNotEmpty
                      ? AuthService.to.uid
                      : ch.ownerId;
                  final videoId = targetVideo?.id ?? 'demo_video_001';
                  final videoTitle = targetVideo?.title ?? 'Latest Upload';

                  await walletService.spendForVideoAIFeatures(
                    channel: ch,
                    userId: uid,
                    videoId: videoId,
                    videoTitle: videoTitle,
                    features: {'factcheck'},
                    targetLanguages: ['en'],
                  );

                  AppSnackbar.success(
                    'Channel balance applied for Fact-Checking & Credibility verification on "$videoTitle"!',
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildAiFeatureOption(
                icon: Icons.subtitles_rounded,
                title: 'AI Subtitles & Closed Captions',
                description:
                    'Generate automatic synchronized closed-captions and subtitles.',
                costText: r'$0.50 • Instant from balance',
                onSelect: () async {
                  Get.back();
                  final uid = AuthService.to.uid.isNotEmpty
                      ? AuthService.to.uid
                      : ch.ownerId;
                  final videoId = targetVideo?.id ?? 'demo_video_001';
                  final videoTitle = targetVideo?.title ?? 'Latest Upload';

                  await walletService.spendForVideoAIFeatures(
                    channel: ch,
                    userId: uid,
                    videoId: videoId,
                    videoTitle: videoTitle,
                    features: {'subtitles'},
                    targetLanguages: ['te', 'hi', 'en'],
                  );

                  AppSnackbar.success(
                    'Channel balance applied for AI Subtitles on "$videoTitle"!',
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildAiFeatureOption(
                icon: Icons.translate_rounded,
                title: 'AI Multilingual Dubbing',
                description:
                    'Dub video voiceover into over 30 languages with voice match.',
                costText: r'$1.50 • Instant from balance',
                onSelect: () async {
                  Get.back();
                  final uid = AuthService.to.uid.isNotEmpty
                      ? AuthService.to.uid
                      : ch.ownerId;
                  final videoId = targetVideo?.id ?? 'demo_video_001';
                  final videoTitle = targetVideo?.title ?? 'Latest Upload';

                  await walletService.spendForVideoAIFeatures(
                    channel: ch,
                    userId: uid,
                    videoId: videoId,
                    videoTitle: videoTitle,
                    features: {'dubbing'},
                    targetLanguages: ['te', 'hi', 'en'],
                  );

                  AppSnackbar.success(
                    'Channel balance applied for AI Multilingual Dubbing on "$videoTitle"!',
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildAiFeatureOption(
                icon: Icons.video_library_rounded,
                title: 'AI Chapters & Key Takeaways',
                description:
                    'Auto-generate smart video chapters, tags, and summary.',
                costText: r'$0.50 • Instant from balance',
                onSelect: () async {
                  Get.back();
                  final uid = AuthService.to.uid.isNotEmpty
                      ? AuthService.to.uid
                      : ch.ownerId;
                  final videoId = targetVideo?.id ?? 'demo_video_001';
                  final videoTitle = targetVideo?.title ?? 'Latest Upload';

                  await walletService.spendForVideoAIFeatures(
                    channel: ch,
                    userId: uid,
                    videoId: videoId,
                    videoTitle: videoTitle,
                    features: {'summary', 'chapters'},
                    targetLanguages: ['en'],
                  );

                  AppSnackbar.success(
                    'Channel balance applied for AI Chapters & Summary!',
                  );
                },
              ),

              const SizedBox(height: 20),

              // Section 2: Custom Channel Infrastructure & Top-Ups
              const Text(
                'Custom Channel Hosting & Quotas',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              _buildAiFeatureOption(
                icon: Icons.cloud_upload_rounded,
                title: '+50 GB Storage Top-Up',
                description:
                    'Expand permanent storage for unlimited high-definition uploads.',
                costText: r'$5.00 • Instant from balance',
                onSelect: () async {
                  Get.back();
                  final uid = AuthService.to.uid.isNotEmpty
                      ? AuthService.to.uid
                      : ch.ownerId;
                  final pack = ChannelWalletService.storagePacks[1]; // 50GB
                  await walletService.spendForStorageTopup(
                    channel: ch,
                    userId: uid,
                    pack: pack,
                  );

                  AppSnackbar.success(
                    '+50 GB storage added to your channel from balance!',
                  );
                },
              ),
              const SizedBox(height: 10),

              _buildAiFeatureOption(
                icon: Icons.speed_rounded,
                title: '+250 GB Bandwidth Top-Up',
                description:
                    'High-capacity streaming CDN bandwidth for trending traffic.',
                costText: r'$7.00 • Instant from balance',
                onSelect: () async {
                  Get.back();
                  final uid = AuthService.to.uid.isNotEmpty
                      ? AuthService.to.uid
                      : ch.ownerId;
                  final pack = ChannelWalletService.bandwidthPacks[1]; // 250GB
                  await walletService.spendForBandwidthTopup(
                    channel: ch,
                    userId: uid,
                    pack: pack,
                  );

                  AppSnackbar.success(
                    '+250 GB streaming bandwidth added to your channel from balance!',
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiFeatureOption({
    required IconData icon,
    required String title,
    required String description,
    required String costText,
    required VoidCallback onSelect,
  }) {
    return Material(
      color: AppColors.bgInput,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.bgSurfaceHigh,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              costText,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: Colors.white,
        ),
        onTap: onSelect,
      ),
    );
  }

  Widget _buildInfoCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
