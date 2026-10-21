import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/channel_notifications_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/notifications/notifications_verification_modal.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheet giving creators a clean, direct, professional understanding
/// of why this notification occurred, its impact on channel standing, and exact next steps.
class ChannelNotificationsDetailModal extends StatelessWidget {
  const ChannelNotificationsDetailModal({
    required this.controller,
    required this.notification,
    required this.channelId,
    super.key,
  });

  final ChannelNotificationsController controller;
  final UserNotification notification;
  final String channelId;

  static void show(
    BuildContext context,
    ChannelNotificationsController controller,
    UserNotification notification,
    String channelId,
  ) {
    controller.markAsRead(notification.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChannelNotificationsDetailModal(
        controller: controller,
        notification: notification,
        channelId: channelId,
      ),
    );
  }

  String get _videoId =>
      (notification.metadata?['videoId'] as String?) ?? '';

  String get _videoTitle =>
      (notification.metadata?['videoTitle'] as String?) ??
      (notification.metadata?['title'] as String?) ??
      '';

  String get _videoStatus =>
      ((notification.metadata?['status'] as String?) ?? '').toLowerCase();

  bool get _isFactCheck =>
      _videoStatus != 'rejected' &&
      _videoStatus != 'manual_review' &&
      _videoStatus != 'processing' &&
      _videoStatus != 'failed' &&
      (notification.type.contains('fact_check') ||
          notification.type.contains('factcheck') ||
          notification.metadata?['factCheckReviewMode'] != null ||
          (_videoId.isNotEmpty &&
              (notification.title.toLowerCase().contains('fact') ||
                  notification.title.toLowerCase().contains('truth'))));

  bool get _isReviewFirst =>
      notification.metadata?['factCheckReviewMode'] == 'first_to_creator';

  bool get _isApproved =>
      notification.metadata?['approved'] == true ||
      notification.metadata?['isFactCheckApproved'] == true;

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final timeStr = DateFormat('h:mm a').format(time);
    if (time.year == now.year && time.month == now.month && time.day == now.day) {
      return 'Today at $timeStr';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (time.year == yesterday.year &&
        time.month == yesterday.month &&
        time.day == yesterday.day) {
      return 'Yesterday at $timeStr';
    }
    if (time.year == now.year) {
      return '${DateFormat('MMMM d').format(time)} at $timeStr';
    }
    return '${DateFormat('MMMM d, yyyy').format(time)} at $timeStr';
  }

  String _getCategoryLabel() {
    if (_isFactCheck) return 'FACT VERIFICATION';
    if (_videoStatus == 'rejected' ||
        notification.priority == NotificationPriority.critical) {
      return 'POLICY & ACTION REQUIRED';
    }
    if (_videoStatus == 'manual_review') return 'CONTENT REVIEW';
    if (_videoStatus == 'processing') return 'VIDEO PIPELINE';
    if (notification.type.contains('milestone')) return 'CHANNEL MILESTONE';
    if (notification.type.contains('performance') ||
        notification.analyticsSnapshot != null) {
      return 'PERFORMANCE INSIGHT';
    }
    if (notification.type.contains('coach')) return 'AI CREATOR COACH';
    return 'CHANNEL NOTICE';
  }

  String _getPlainEnglishExplanation() {
    if (_isFactCheck) {
      if (_isReviewFirst && !_isApproved) {
        return 'TruthWorld verified the claims in your video. Under Creator Review First, all findings remain completely private to you. Viewers cannot see any labels until you review and approve them.';
      }
      if (_isReviewFirst && _isApproved) {
        return 'You have reviewed and approved the truth verification report for this video. Community truth badges and annotations are now visible on the video player.';
      }
      return 'Automated and community fact-checking verified the factual statements and claims in this video.';
    }

    if (_videoStatus == 'rejected') {
      if (notification.title.toLowerCase().contains('language') ||
          notification.message.toLowerCase().contains('language')) {
        return 'The detected audio language in this video did not match the channel or video language settings. Updating language in Video Manager will resolve this immediately.';
      }
      return 'This video needs an adjustment to meet community guidelines. It is temporarily hidden until resolved or appealed.';
    }

    if (_videoStatus == 'manual_review') {
      return 'This upload triggered a standard Trust & Safety check and is in queue for human review. Zero strikes or penalties have been applied to your channel.';
    }

    if (_videoStatus == 'processing') {
      return 'Your video is currently transcoding across multiple resolutions, generating thumbnails, and extracting speech transcripts. It will publish automatically once finished.';
    }

    if (notification.type.contains('milestone')) {
      return 'Congratulations! Your channel crossed a new subscriber or view threshold. This milestone reflects authentic engagement from your viewers.';
    }

    if (notification.type.contains('performance') ||
        notification.analyticsSnapshot != null) {
      return 'Your video is experiencing higher organic traffic and viewer retention than usual. Replying to comments will help sustain this momentum.';
    }

    if (notification.type.contains('coach')) {
      return 'TruthWorld AI Creator Coach analyzed your channel trajectory and generated tailored recommendations to boost audience retention and factual credibility.';
    }

    return notification.message.isNotEmpty
        ? notification.message
        : 'Notification from TruthWorld Creator Studio.';
  }

  String _getChannelStandingImpact() {
    if (_videoStatus == 'rejected') {
      return 'Channel Standing: In Good Standing (0 Strikes) • Video Hidden Pending Correction';
    }
    if (_videoStatus == 'manual_review') {
      return 'Channel Standing: In Good Standing (0 Strikes) • 100% Safe';
    }
    if (_isFactCheck) {
      return 'Channel Standing: In Good Standing (0 Strikes) • Verified';
    }
    return 'Channel Standing: In Good Standing (0 Strikes)';
  }

  List<String> _getRecommendedSteps() {
    if (_isFactCheck) {
      if (_isReviewFirst && !_isApproved) {
        return [
          'Look over the fact notes and source citations.',
          'If everything looks good to you, tap "Approve & Publish Results".',
          'If you disagree with anything, tap "Open Fact-Checks Tab" to appeal.',
        ];
      }
      return [
        'No further action required. Truth badges are active.',
        'You can inspect detailed citations in the Fact-Checks tab anytime.',
      ];
    }

    if (_videoStatus == 'rejected') {
      return [
        'Tap "Manage Video" below to open Video Manager.',
        'Review the rejection reason (e.g. language tag or metadata) and fix it.',
        'Save changes or submit an appeal so our team can re-check it.',
      ];
    }

    if (_videoStatus == 'manual_review') {
      return [
        'No action needed from you right now.',
        'Our Trust & Safety team reviews uploads within 2-4 hours.',
        'You will receive an instant notification as soon as it is approved.',
      ];
    }

    if (_videoStatus == 'processing') {
      return [
        'Our servers are preparing your video in the background.',
        'Your video will go live automatically once finished—no action needed.',
      ];
    }

    if (notification.type.contains('milestone') ||
        notification.type.contains('performance')) {
      return [
        'Say hello to the people commenting on your video.',
        'Visit Channel Analytics to see how your audience is growing!',
      ];
    }

    return [
      'Review the notice details above.',
      'Take any necessary actions indicated, or dismiss this notice.',
    ];
  }

  Widget _buildSectionContainer({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
              ],
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryLabel = _getCategoryLabel();
    final plainExplanation = _getPlainEnglishExplanation();
    final standingImpact = _getChannelStandingImpact();
    final steps = _getRecommendedSteps();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppColors.bgDivider),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Grab Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.bgDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      categoryLabel,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.bgDivider),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Notification Title & Timestamp
                  Text(
                    notification.title,
                    style: const TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTimestamp(notification.createdAt),
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Target Video Asset (Clean Title, NEVER raw UUIDs!)
                  if (_videoId.isNotEmpty)
                    _buildSectionContainer(
                      title: 'Target Video',
                      icon: Icons.video_library_rounded,
                      child: Obx(() {
                        final vTitle = controller.getVideoTitle(
                          _videoId,
                          initialTitle: _videoTitle,
                        );
                        return Row(
                          children: [
                            const Icon(
                              Icons.play_circle_outline_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                vTitle,
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontFamilyFallback:
                                      TWTypography.fallbackFamilies,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),

                  // Why You Received This Notice
                  _buildSectionContainer(
                    title: 'Why You Received This Notice',
                    icon: Icons.info_outline_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plainExplanation,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (notification.message.isNotEmpty &&
                            notification.message != plainExplanation) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.bgDivider),
                            ),
                            child: Text(
                              notification.message,
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontFamilyFallback:
                                    TWTypography.fallbackFamilies,
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Channel Standing & Safety
                  _buildSectionContainer(
                    title: 'Channel Standing & Safety',
                    icon: Icons.shield_outlined,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          size: 18,
                          color: Color(0xFF34D399),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                standingImpact,
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontFamilyFallback:
                                      TWTypography.fallbackFamilies,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'TruthWorld guarantees zero arbitrary strikes. All evaluations are transparent and appealable.',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontFamilyFallback:
                                      TWTypography.fallbackFamilies,
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Recommended Next Steps
                  _buildSectionContainer(
                    title: 'Recommended Next Steps',
                    icon: Icons.checklist_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < steps.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.bgSurface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.bgDivider,
                                    ),
                                  ),
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      fontFamilyFallback:
                                          TWTypography.fallbackFamilies,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    steps[i],
                                    style: const TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      fontFamilyFallback:
                                          TWTypography.fallbackFamilies,
                                      fontSize: 12,
                                      height: 1.4,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Analytics Snapshot Grid (if present)
                  if (notification.analyticsSnapshot != null)
                    _buildSectionContainer(
                      title: 'Performance Snapshot',
                      icon: Icons.insights_rounded,
                      child: _buildAnalyticsGrid(notification.analyticsSnapshot!),
                    ),
                ],
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.bgSurface,
                border: Border(
                  top: BorderSide(color: AppColors.bgDivider),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.bgDivider),
                      backgroundColor: AppColors.bgSurfaceHover,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                  if (_isFactCheck &&
                      _videoId.isNotEmpty &&
                      _isReviewFirst &&
                      !_isApproved)
                    ElevatedButton.icon(
                      onPressed: () {
                        controller.approveFactCheck(
                          _videoId,
                          notificationId: notification.id,
                        );
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: Colors.black,
                      ),
                      label: const Text('Approve & Publish Results'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  if (_isFactCheck && _videoId.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        TruthVerificationDashboardPage.targetVideoId.value =
                            _videoId;
                        if (Get.isRegistered<DashboardController>()) {
                          Get.find<DashboardController>().setSelectedIndex(15);
                        } else {
                          Get.to<void>(
                            () => TruthVerificationDashboardPage(
                              channelId: channelId,
                              isDarkMode: true,
                              initialVideoId: _videoId,
                            ),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.fact_check_rounded,
                        size: 15,
                        color: AppColors.textPrimary,
                      ),
                      label: const Text('Open Fact-Checks Tab'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.bgDivider),
                        backgroundColor: AppColors.bgSurfaceHover,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  if (_videoId.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (Get.isRegistered<DashboardController>()) {
                          Get.find<DashboardController>().setSelectedIndex(2);
                        } else {
                          Get.toNamed('/studio');
                        }
                      },
                      icon: const Icon(
                        Icons.video_library_rounded,
                        size: 15,
                        color: AppColors.textPrimary,
                      ),
                      label: const Text('Manage Video'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.bgDivider),
                        backgroundColor: AppColors.bgSurfaceHover,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  if (notification.verificationReportId != null &&
                      notification.verificationReportId!.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ChannelNotificationsVerificationModal.show(
                          context,
                          controller,
                          notification.verificationReportId!,
                          channelId,
                        );
                      },
                      icon: const Icon(
                        Icons.assessment_rounded,
                        size: 16,
                        color: Colors.black,
                      ),
                      label: const Text('View Full Audit Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsGrid(AnalyticsSnapshotData snapshot) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                'Views',
                NumberFormat.compact().format(snapshot.views),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                'Subscribers',
                NumberFormat.compact().format(snapshot.subscribers),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                'Watch Hours',
                snapshot.watchHours.toStringAsFixed(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                'Likes',
                NumberFormat.compact().format(snapshot.likes),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
