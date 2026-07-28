import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
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
        : (uid.isNotEmpty ? Get.put(DashboardController(channelId: uid)) : null);

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
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Get.back<void>(),
        ),
      ),
      body: controller == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Channel Monetization',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Day 1 Creator Monetization Program',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  ),
                  const SizedBox(height: 12),
                  _buildPolicyNoticeCard(),
                  const SizedBox(height: 24),
                  _buildEligibilitySection(controller),
                  const SizedBox(height: 24),
                  _buildRevenueSummary(context, controller),
                  const SizedBox(height: 24),
                  _buildPerVideoWithdrawalSection(context, controller),
                ],
              ),
            ),
    );
  }

  Widget _buildPolicyNoticeCard() {
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
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instant Revenue from Day 1',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '• Zero subscriber requirement: Generate ad & view revenue starting immediately.\n'
                  '• Cash Payout Rule: Money generated by a video becomes withdrawable once that video crosses 10 hours of watch time.\n'
                  '• AI Tools Usability: Locked earnings can be used anytime for features like AI Subtitles and Dubbing!',
                  style: TextStyle(
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

  Widget _buildEligibilitySection(DashboardController controller) {
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
                  value: '10h / Video',
                  subtitle: 'Watch time for cash withdrawal',
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

  Widget _buildRevenueSummary(BuildContext context, DashboardController controller) {
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
                icon: const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 20),
                onPressed: () {
                  Get.defaultDialog(
                    title: 'Monetization Rules',
                    backgroundColor: AppColors.bgSurface,
                    titleStyle: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    content: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        '1. Channels start earning revenue immediately from day one.\n\n'
                        '2. Cash withdrawal for earnings from a video unlocks when that video reaches 10 hours of watch time.\n\n'
                        '3. Unwithdrawn or locked money can be spent anytime for AI subtitles, dubbing, and other platform features.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
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
            final revenueStr = controller.channelStats['revenue']?.toString() ?? r'$0.00';

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
                _buildRevenueRow('Total Estimated Revenue', revenueStr, isHighlight: true),
                const Divider(color: AppColors.bgDivider, height: 20),
                _buildRevenueRow(
                  'Available for Cash Withdrawal',
                  eligibleCount > 0 ? '\$${eligibleCount * 10}.00 (Est.)' : r'$0.00',
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
                    onPressed: () => _showUseForAiFeaturesDialog(context, controller),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Use Balance for AI Subtitles & Dubbing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: AppColors.textPrimary,
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
                    fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                    color: isHighlight ? AppColors.textPrimary : AppColors.textSecondary,
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

  Widget _buildPerVideoWithdrawalSection(BuildContext context, DashboardController controller) {
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
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: videos.length,
              separatorBuilder: (_, __) => const Divider(color: AppColors.bgDivider, height: 16),
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

  Widget _buildVideoWithdrawalRow(BuildContext context, DashboardController controller, Video video) {
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
                    ? Image.network(video.thumbnailUrl, fit: BoxFit.cover)
                    : const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 24),
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
                isEligibleForCashOut ? 'Cash-Out Ready' : 'Locked (${watchHours.toStringAsFixed(1)}h/10h)',
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
                progressColor: isEligibleForCashOut ? Colors.green : AppColors.brand,
                backgroundColor: AppColors.bgInput,
                barRadius: const Radius.circular(3),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () => _showUseForAiFeaturesDialog(context, controller, video),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
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

  void _showUseForAiFeaturesDialog(BuildContext context, DashboardController controller, [Video? targetVideo]) {
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
                      Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Spend Revenue on AI Features',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                targetVideo != null
                    ? 'Use accumulated channel revenue for: ${targetVideo.title}'
                    : 'Use accumulated channel revenue for AI tools even before 10 hours watch time!',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              _buildAiFeatureOption(
                icon: Icons.subtitles_rounded,
                title: 'AI Subtitles & Captions',
                description: 'Generate automatic synchronized closed-captions and subtitles.',
                costText: 'Included with Channel Revenue',
                onSelect: () {
                  Get.back();
                  Get.snackbar(
                    'AI Subtitles',
                    'Channel revenue balance applied for AI Subtitles!',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.brand,
                    colorText: Colors.black,
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildAiFeatureOption(
                icon: Icons.translate_rounded,
                title: 'AI Multilingual Dubbing',
                description: 'Dub video voiceover into over 30 languages automatically.',
                costText: 'Included with Channel Revenue',
                onSelect: () {
                  Get.back();
                  Get.snackbar(
                    'AI Dubbing',
                    'Channel revenue balance applied for AI Multilingual Dubbing!',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.brand,
                    colorText: Colors.black,
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildAiFeatureOption(
                icon: Icons.video_library_rounded,
                title: 'AI Chapters & Metadata',
                description: 'Auto-generate smart video chapters, tags, and summary.',
                costText: 'Included with Channel Revenue',
                onSelect: () {
                  Get.back();
                  Get.snackbar(
                    'AI Video Chapters',
                    'Channel revenue balance applied for AI Chapter creation!',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppColors.brand,
                    colorText: Colors.black,
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.15),
            shape: BoxShape.circle,
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
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
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
