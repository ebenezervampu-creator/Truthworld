import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/creator_intelligence_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/intelligence/intelligence_verification_modal.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Notification card rendering milestone, performance, or policy insight with action handlers.
class IntelligenceNotificationCard extends StatelessWidget {
  const IntelligenceNotificationCard({
    required this.controller,
    required this.notification,
    required this.channelId,
    this.isCriticalStyle = false,
    super.key,
  });

  final CreatorIntelligenceController controller;
  final UserNotification notification;
  final String channelId;
  final bool isCriticalStyle;

  bool get _isFactCheckNotification =>
      notification.type.contains('fact_check') ||
      notification.type.contains('factcheck') ||
      notification.metadata?['factCheckReviewMode'] != null ||
      (notification.metadata?['videoId'] != null &&
          (notification.title.toLowerCase().contains('fact') ||
              notification.title.toLowerCase().contains('truth') ||
              notification.title.toLowerCase().contains('verification')));

  bool get _isReviewFirst =>
      notification.metadata?['factCheckReviewMode'] == 'first_to_creator';

  bool get _isApproved =>
      notification.metadata?['approved'] == true ||
      notification.metadata?['isFactCheckApproved'] == true;

  String get _videoId =>
      (notification.metadata?['videoId'] as String?) ?? '';

  void _handleAction(BuildContext context, NotificationActionItem action) {
    switch (action.type) {
      case 'OPEN_ANALYTICS':
        AppSnackbar.info('Opening Channel Analytics...');
      case 'APPEAL_VERIFICATION':
        Get.to<void>(
          () => TruthVerificationDashboardPage(
            channelId: channelId,
            isDarkMode: true,
          ),
        );
      case 'APPROVE_FACT_CHECK':
        final vid = (action.payload?['videoId'] as String?) ?? _videoId;
        if (vid.isNotEmpty) {
          controller.approveFactCheck(vid, notificationId: notification.id);
        } else {
          AppSnackbar.error('Video ID not found.');
        }
      case 'VIEW_FACT_CHECK':
        final vid = (action.payload?['videoId'] as String?) ?? _videoId;
        if (vid.isNotEmpty) {
          Get.toNamed('/video/$vid');
        } else {
          AppSnackbar.error('Video ID not found.');
        }
      default:
        AppSnackbar.info(action.label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.read;

    var leadingIcon = Icons.notifications_rounded;
    var badgeBg = AppColors.bgSurfaceHover;
    var badgeBorder = AppColors.bgDivider;

    if (notification.type.contains('fact_check') ||
        notification.type.contains('factcheck') ||
        notification.type.contains('verification')) {
      if (notification.priority == NotificationPriority.critical ||
          notification.severity == NotificationSeverity.warning) {
        leadingIcon = Icons.cancel_rounded;
        badgeBg = AppColors.errorContainer;
        badgeBorder = AppColors.error.withValues(alpha: 0.4);
      } else {
        leadingIcon = Icons.verified_rounded;
        badgeBg = AppColors.successContainer;
        badgeBorder = AppColors.success.withValues(alpha: 0.4);
      }
    } else if (notification.type.contains('milestone')) {
      leadingIcon = Icons.emoji_events_rounded;
      badgeBg = AppColors.warningContainer;
      badgeBorder = AppColors.warning.withValues(alpha: 0.4);
    } else if (notification.type.contains('performance') ||
        notification.type.contains('retention')) {
      leadingIcon = Icons.trending_up_rounded;
      badgeBg = AppColors.infoContainer;
      badgeBorder = AppColors.info.withValues(alpha: 0.4);
    } else if (notification.type.contains('coach')) {
      leadingIcon = Icons.auto_awesome_rounded;
      badgeBg = AppColors.infoContainer;
      badgeBorder = AppColors.info.withValues(alpha: 0.4);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread
              ? AppColors.info.withValues(alpha: 0.5)
              : AppColors.bgDivider,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            controller.markAsRead(notification.id);
            if (notification.verificationReportId != null &&
                notification.verificationReportId!.isNotEmpty) {
              IntelligenceVerificationReportModal.show(
                context,
                controller,
                notification.verificationReportId!,
                channelId,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Badge
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Icon(leadingIcon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),

                    // Main Text Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    fontFamilyFallback: TWTypography.fallbackFamilies,
                                    fontSize: 14,
                                    fontWeight: isUnread
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('h:mm a')
                                    .format(notification.createdAt),
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontFamilyFallback: TWTypography.fallbackFamilies,
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            notification.message,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontFamilyFallback: TWTypography.fallbackFamilies,
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),

                          // Analytics Snapshot pill
                          if (notification.analyticsSnapshot != null) ...[
                            const SizedBox(height: 10),
                            IntelligenceAnalyticsSnapshotPill(
                              snapshot: notification.analyticsSnapshot!,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Unread Indicator Dot
                    if (isUnread)
                      Container(
                        margin: const EdgeInsets.only(left: 8, top: 4),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.info,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),

                // Action Buttons Row
                if (notification.actions.isNotEmpty ||
                    notification.verificationReportId != null ||
                    _isFactCheckNotification) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.bgDivider),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_isFactCheckNotification && _videoId.isNotEmpty) ...[
                        if (_isReviewFirst && !_isApproved)
                          ElevatedButton.icon(
                            onPressed: () => controller.approveFactCheck(
                              _videoId,
                              notificationId: notification.id,
                            ),
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            label: const Text('Approve & Publish Results'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontFamilyFallback:
                                    TWTypography.fallbackFamilies,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (_isReviewFirst && _isApproved)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF34D399)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  size: 14,
                                  color: Color(0xFF34D399),
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Approved for Viewers',
                                  style: TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: () {
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
                            color: Colors.black,
                          ),
                          label: const Text('Review in Fact-Checks Tab'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.black,
                            backgroundColor: AppColors.brandVariant,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontFamilyFallback:
                                  TWTypography.fallbackFamilies,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (notification.verificationReportId != null)
                        ElevatedButton.icon(
                          onPressed: () =>
                              IntelligenceVerificationReportModal.show(
                            context,
                            controller,
                            notification.verificationReportId!,
                            channelId,
                          ),
                          icon: const Icon(
                            Icons.assessment_rounded,
                            size: 15,
                            color: Colors.black,
                          ),
                          label: const Text('View Verification Audit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontFamilyFallback: TWTypography.fallbackFamilies,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      for (final action in notification.actions)
                        OutlinedButton(
                          onPressed: () => _handleAction(context, action),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.bgDivider),
                            backgroundColor: AppColors.bgSurfaceHover,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontFamilyFallback: TWTypography.fallbackFamilies,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          child: Text(action.label),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Metrics pill showing subscriber and view counts captured at notification creation time.
class IntelligenceAnalyticsSnapshotPill extends StatelessWidget {
  const IntelligenceAnalyticsSnapshotPill({
    required this.snapshot,
    super.key,
  });

  final AnalyticsSnapshotData snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_rounded, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Snapshot at creation: ${NumberFormat.compact().format(snapshot.views)} views • ${NumberFormat.compact().format(snapshot.subscribers)} subs',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
