import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/creator_intelligence_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/intelligence/intelligence_verification_modal.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';

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
      default:
        AppSnackbar.info(action.label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.read;

    var leadingIcon = Icons.notifications_rounded;
    var badgeBg = const Color(0xFF18181B);
    var badgeBorder = const Color(0xFF27272A);

    if (notification.type.contains('verification')) {
      if (notification.priority == NotificationPriority.critical ||
          notification.severity == NotificationSeverity.warning) {
        leadingIcon = Icons.cancel_rounded;
        badgeBg = const Color(0xFF450A0A);
        badgeBorder = const Color(0xFFEF4444).withValues(alpha: 0.4);
      } else {
        leadingIcon = Icons.verified_rounded;
        badgeBg = const Color(0xFF064E3B);
        badgeBorder = const Color(0xFF10B981).withValues(alpha: 0.4);
      }
    } else if (notification.type.contains('milestone')) {
      leadingIcon = Icons.emoji_events_rounded;
      badgeBg = const Color(0xFF451A03);
      badgeBorder = const Color(0xFFF59E0B).withValues(alpha: 0.4);
    } else if (notification.type.contains('performance') ||
        notification.type.contains('retention')) {
      leadingIcon = Icons.trending_up_rounded;
      badgeBg = const Color(0xFF1E293B);
      badgeBorder = const Color(0xFF38BDF8).withValues(alpha: 0.4);
    } else if (notification.type.contains('coach')) {
      leadingIcon = Icons.auto_awesome_rounded;
      badgeBg = const Color(0xFF2E1065);
      badgeBorder = const Color(0xFF8B5CF6).withValues(alpha: 0.4);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread
              ? const Color(0xFF38BDF8).withValues(alpha: 0.5)
              : const Color(0xFF27272A),
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
                                    fontSize: 14,
                                    fontWeight: isUnread
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('h:mm a')
                                    .format(notification.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF71717A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            notification.message,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFFA1A1AA),
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
                          color: Color(0xFF38BDF8),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),

                // Action Buttons Row
                if (notification.actions.isNotEmpty ||
                    notification.verificationReportId != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFF27272A)),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
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
                            color: Colors.white,
                          ),
                          label: const Text('View Verification Audit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
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
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      for (final action in notification.actions)
                        OutlinedButton(
                          onPressed: () => _handleAction(context, action),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF3F3F46)),
                            backgroundColor: const Color(0xFF18181B),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
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
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Snapshot at creation: ${NumberFormat.compact().format(snapshot.views)} views • ${NumberFormat.compact().format(snapshot.subscribers)} subs',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFA1A1AA),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
