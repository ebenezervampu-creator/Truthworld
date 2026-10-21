import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/channel_notifications_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/notifications/notifications_detail_modal.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/notifications/notifications_verification_modal.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_navigation_handler.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Notification card rendering social creator activity, performance insights, truth audits,
/// and channel policies with high-contrast, modern, simple, and effective studio styling.
class ChannelNotificationsNotificationCard extends StatelessWidget {
  const ChannelNotificationsNotificationCard({
    required this.controller,
    required this.notification,
    required this.channelId,
    this.isCriticalStyle = false,
    super.key,
  });

  final ChannelNotificationsController controller;
  final UserNotification notification;
  final String channelId;
  final bool isCriticalStyle;

  bool get _isCommentOrSocial =>
      notification.type.contains('comment') ||
      notification.type.contains('mention') ||
      notification.category == 'comment' ||
      notification.category == 'community' ||
      notification.title.toLowerCase().contains('comment') ||
      notification.title.toLowerCase().contains('mention') ||
      notification.message.toLowerCase().contains('commented:');

  bool get _isSubscriber =>
      notification.type.contains('subscriber') ||
      notification.type.contains('follower') ||
      notification.type.contains('subscription') ||
      notification.category == 'growth' ||
      notification.category == 'subscribers' ||
      notification.title.toLowerCase().contains('subscriber') ||
      notification.message.toLowerCase().contains('subscribed to your channel');

  bool get _isMilestone =>
      !_isSubscriber &&
      (notification.type.contains('milestone') ||
          notification.category == 'milestone');

  bool get _isPolicyAlert =>
      _videoStatus == 'rejected' ||
      _videoStatus == 'manual_review' ||
      _videoStatus == 'failed' ||
      notification.priority == NotificationPriority.critical ||
      notification.severity == NotificationSeverity.warning ||
      notification.type.contains('reject') ||
      notification.type.contains('flag') ||
      notification.type.contains('policy') ||
      notification.type.contains('claim') ||
      notification.type.contains('copyright');

  bool get _isFactCheckNotification =>
      _videoStatus != 'rejected' &&
      _videoStatus != 'manual_review' &&
      _videoStatus != 'processing' &&
      _videoStatus != 'failed' &&
      (notification.type.contains('fact_check') ||
          notification.type.contains('factcheck') ||
          notification.metadata?['factCheckReviewMode'] != null ||
          (notification.metadata?['videoId'] != null &&
              (notification.title.toLowerCase().contains('fact') ||
                  notification.title.toLowerCase().contains('truth'))));

  bool get _isReviewFirst =>
      notification.metadata?['factCheckReviewMode'] == 'first_to_creator';

  bool get _isApproved =>
      notification.metadata?['approved'] == true ||
      notification.metadata?['isFactCheckApproved'] == true;

  String get _videoId =>
      (notification.metadata?['videoId'] as String?) ?? '';

  String get _videoTitle =>
      (notification.metadata?['videoTitle'] as String?) ??
      (notification.metadata?['title'] as String?) ??
      '';

  bool get _isVideoNotification =>
      notification.metadata?['itemType'] == 'video' || _videoId.isNotEmpty;

  String get _videoStatus =>
      ((notification.metadata?['status'] as String?) ?? '').toLowerCase();

  String get _avatarUrl =>
      (notification.metadata?['avatarUrl'] as String?) ??
      (notification.metadata?['userAvatar'] as String?) ??
      (notification.metadata?['channelAvatarUrl'] as String?) ??
      (notification.metadata?['photoURL'] as String?) ??
      (notification.thumbnailUrl ?? '');

  String get _commentAuthor {
    final name = (notification.metadata?['commenterName'] as String?) ??
        (notification.metadata?['authorName'] as String?) ??
        (notification.metadata?['userName'] as String?) ??
        '';
    if (name.isNotEmpty) return name;
    final match = RegExp(r'^([^:]+)\s+(?:commented|replied|mentioned)').firstMatch(notification.message);
    if (match != null) {
      return match.group(1)!.trim();
    }
    return '';
  }

  String get _commentQuote {
    final quoteMatch = RegExp(r'["“](.+?)["”]$').firstMatch(notification.message);
    if (quoteMatch != null) {
      return quoteMatch.group(1)!.trim();
    }
    final colonIdx = notification.message.indexOf(':');
    if (colonIdx != -1 && colonIdx < notification.message.length - 1) {
      final text = notification.message.substring(colonIdx + 1).trim();
      return text.replaceAll(RegExp(r'^["“]|["”]$'), '');
    }
    return notification.message;
  }

  String _formatSmartTimestamp(DateTime time) {
    final now = DateTime.now();
    final timeStr = DateFormat('h:mm a').format(time);
    if (time.year == now.year && time.month == now.month && time.day == now.day) {
      return 'Today • $timeStr';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (time.year == yesterday.year &&
        time.month == yesterday.month &&
        time.day == yesterday.day) {
      return 'Yesterday • $timeStr';
    }
    if (time.year == now.year) {
      return '${DateFormat('MMM d').format(time)} • $timeStr';
    }
    return '${DateFormat('MMM d, yyyy').format(time)} • $timeStr';
  }

  String _getCategoryTag() {
    if (_isCommentOrSocial) {
      if (notification.type.contains('mention') || notification.title.toLowerCase().contains('mention')) {
        return 'MENTION';
      }
      if (notification.type.contains('reply') || notification.title.toLowerCase().contains('reply')) {
        return 'REPLY';
      }
      return 'COMMENT';
    }
    if (_isSubscriber) return 'SUBSCRIBER';
    if (_isFactCheckNotification) return 'FACT VERIFICATION';
    if (_videoStatus == 'rejected' ||
        notification.priority == NotificationPriority.critical) {
      return 'POLICY ALERT';
    }
    if (_videoStatus == 'manual_review') return 'CONTENT REVIEW';
    if (_videoStatus == 'processing') return 'VIDEO PIPELINE';
    if (_isMilestone) return 'CHANNEL MILESTONE';
    if (notification.type.contains('performance') ||
        notification.analyticsSnapshot != null) {
      return 'PERFORMANCE INSIGHT';
    }
    if (notification.type.contains('coach')) return 'AI CREATOR COACH';
    return 'UPDATE';
  }

  String? _getStatusTag() {
    if (_isCommentOrSocial || _isSubscriber) {
      return null;
    }
    if (_isFactCheckNotification) {
      if (_isReviewFirst && !_isApproved) return 'Awaiting Approval';
      if (_isApproved) return 'Published';
      return 'Verified';
    }
    if (_videoStatus == 'rejected') return 'Action Required';
    if (_videoStatus == 'manual_review') return 'Under Review';
    if (_videoStatus == 'processing') return 'Transcoding';
    if (_isMilestone) return 'Milestone Achieved';
    if (notification.type.contains('performance') ||
        notification.analyticsSnapshot != null) {
      return 'Audience Surge';
    }
    if (notification.type.contains('coach')) return 'Growth Tip';
    return null;
  }

  Color _getStatusColor() {
    if (_videoStatus == 'rejected' ||
        notification.priority == NotificationPriority.critical) {
      return const Color(0xFFF87171);
    }
    if (_videoStatus == 'manual_review' ||
        (_isFactCheckNotification && _isReviewFirst && !_isApproved)) {
      return const Color(0xFFFBBF24);
    }
    if (_isFactCheckNotification && _isApproved) {
      return const Color(0xFF34D399);
    }
    if (_isMilestone) {
      return const Color(0xFFFBBF24);
    }
    return AppColors.textSecondary;
  }

  String? _getInlineClarityMessage() {
    if (_isCommentOrSocial || _isSubscriber) {
      return null;
    }

    if (_isFactCheckNotification) {
      if (_isReviewFirst && !_isApproved) {
        return '🔒 Private to You (Review First): Fact-checks are ready for your review before becoming visible to viewers.';
      }
      if (_isReviewFirst && _isApproved) {
        return '✅ Approved & Live: Fact-check truth badges are active on your video.';
      }
      return 'Claims in this video have been fact-checked. Citations are accessible in the Fact-Checks tab.';
    }

    if (_videoStatus == 'rejected') {
      if (notification.title.toLowerCase().contains('language') ||
          notification.message.toLowerCase().contains('language')) {
        return "🗣️ Quick Language Fix: The speaking language in this video doesn't match the language selected. You can easily fix it in Video Manager!";
      }
      return '⚠️ Quick Fix Needed: This video is hidden until adjusted to meet policies. Tap to review.';
    }

    if (_videoStatus == 'manual_review') {
      return '👀 In Review: Our Trust & Safety team is double-checking this upload. It will go live once approved.';
    }

    if (_videoStatus == 'processing') {
      return '⏳ Getting Your Video Ready: Video is transcoding across resolutions. It will go live automatically once finished.';
    }

    if (_isMilestone) {
      return '🎉 Milestone Reached: High five! You reached a new audience milestone. More people are subscribing to your channel!';
    }

    if (notification.type.contains('performance') ||
        notification.analyticsSnapshot != null) {
      return '🔥 Engagement surge detected! Lots of people are watching your video right now. Replying to comments will help even more people see it!';
    }

    if (notification.type.contains('coach')) {
      return '💡 Creator Tip: A friendly tip based on what your viewers love most to help you grow.';
    }

    return null;
  }

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
          Get.toNamed('/watch?v=$vid');
        } else {
          AppSnackbar.error('Video ID not found.');
        }
      default:
        AppSnackbar.info(action.label);
    }
  }

  void _navigateToVideo(BuildContext context, String vid) {
    if (vid.isEmpty) return;
    NotificationNavigationHandler.safeNavigate('video_$vid', () {
      Get.toNamed('/watch?v=$vid');
    });
  }

  void _navigateToChannelOrProfile(BuildContext context) {
    final subId = (notification.metadata?['subscriberId'] as String?) ??
        (notification.metadata?['userId'] as String?) ??
        '';
    if (subId.isNotEmpty) {
      Get.toNamed('/channel/$subId');
    } else {
      Get.toNamed('/studio');
    }
  }

  Widget _buildLeadingIconOrAvatar() {
    if (_isCommentOrSocial) {
      if (_avatarUrl.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: CachedNetworkImage(
            imageUrl: _avatarUrl,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 36,
              height: 36,
              color: AppColors.bgSurfaceHover,
              child: const Icon(
                Icons.chat_bubble_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.bgSurfaceHover,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bgDivider),
              ),
              alignment: Alignment.center,
              child: Text(
                _commentAuthor.isNotEmpty ? _commentAuthor[0].toUpperCase() : 'C',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      }
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceHover,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.bgDivider),
        ),
        alignment: Alignment.center,
        child: Text(
          _commentAuthor.isNotEmpty ? _commentAuthor[0].toUpperCase() : 'C',
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontFamilyFallback: TWTypography.fallbackFamilies,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      );
    }

    if (_isSubscriber) {
      if (_avatarUrl.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: CachedNetworkImage(
            imageUrl: _avatarUrl,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 36,
              height: 36,
              color: AppColors.bgSurfaceHover,
              child: const Icon(
                Icons.person_add_rounded,
                size: 16,
                color: Color(0xFF34D399),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF34D399).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF34D399).withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.person_add_rounded,
                size: 18,
                color: Color(0xFF34D399),
              ),
            ),
          ),
        );
      }
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF34D399).withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF34D399).withValues(alpha: 0.3),
          ),
        ),
        child: const Icon(
          Icons.person_add_rounded,
          size: 18,
          color: Color(0xFF34D399),
        ),
      );
    }

    var leadingIcon = Icons.notifications_rounded;
    var iconColor = AppColors.textSecondary;

    if (_videoStatus == 'rejected' ||
        notification.priority == NotificationPriority.critical) {
      leadingIcon = notification.title.toLowerCase().contains('language')
          ? Icons.translate_rounded
          : Icons.cancel_rounded;
      iconColor = const Color(0xFFF87171);
    } else if (_videoStatus == 'manual_review' ||
        _videoStatus == 'failed' ||
        notification.severity == NotificationSeverity.warning) {
      leadingIcon = Icons.policy_rounded;
      iconColor = const Color(0xFFFBBF24);
    } else if (_videoStatus == 'processing') {
      leadingIcon = Icons.hourglass_top_rounded;
      iconColor = AppColors.textSecondary;
    } else if (notification.type.contains('fact_check') ||
        notification.type.contains('factcheck') ||
        notification.type.contains('verification')) {
      leadingIcon = Icons.verified_rounded;
      iconColor = const Color(0xFF34D399);
    } else if (_isMilestone) {
      leadingIcon = Icons.emoji_events_rounded;
      iconColor = const Color(0xFFFBBF24);
    } else if (notification.type.contains('performance') ||
        notification.type.contains('retention')) {
      leadingIcon = Icons.trending_up_rounded;
      iconColor = AppColors.textSecondary;
    } else if (notification.type.contains('coach')) {
      leadingIcon = Icons.auto_awesome_rounded;
      iconColor = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Icon(leadingIcon, color: iconColor, size: 18),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context) {
    final buttons = <Widget>[];

    if (_isCommentOrSocial) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () {
            controller.markAsRead(notification.id);
            NotificationNavigationHandler.navigateToAlertNotification(notification);
          },
          icon: const Icon(Icons.reply_rounded, size: 14, color: Colors.black),
          label: const Text('Reply'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      );

      if (_videoId.isNotEmpty) {
        buttons.add(
          OutlinedButton.icon(
            onPressed: () {
              controller.markAsRead(notification.id);
              _navigateToVideo(context, _videoId);
            },
            icon: const Icon(
              Icons.play_circle_outline_rounded,
              size: 14,
              color: AppColors.textPrimary,
            ),
            label: const Text('View Video'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              backgroundColor: AppColors.bgSurfaceHover,
              side: const BorderSide(color: AppColors.bgDivider),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
      return buttons;
    }

    if (_isSubscriber) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () {
            controller.markAsRead(notification.id);
            _navigateToChannelOrProfile(context);
          },
          icon: const Icon(
            Icons.person_outline_rounded,
            size: 14,
            color: AppColors.textPrimary,
          ),
          label: const Text('View Profile'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            backgroundColor: AppColors.bgSurfaceHover,
            side: const BorderSide(color: AppColors.bgDivider),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      return buttons;
    }

    // Notice detail helper button for policy/system/insight items
    if (_isPolicyAlert ||
        notification.type.contains('performance') ||
        notification.type.contains('coach') ||
        _isMilestone) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () => ChannelNotificationsDetailModal.show(
            context,
            controller,
            notification,
            channelId,
          ),
          icon: const Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: AppColors.textPrimary,
          ),
          label: const Text('Understand Notice'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            backgroundColor: AppColors.bgSurfaceHover,
            side: const BorderSide(color: AppColors.bgDivider),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    if (_isVideoNotification && _isPolicyAlert) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () {
            controller.markAsRead(notification.id);
            if (Get.isRegistered<DashboardController>()) {
              Get.find<DashboardController>().setSelectedIndex(2);
            } else {
              Get.toNamed('/studio');
            }
          },
          icon: const Icon(
            Icons.video_library_rounded,
            size: 14,
            color: AppColors.textPrimary,
          ),
          label: const Text('Manage in Videos'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.bgDivider),
            backgroundColor: AppColors.bgSurfaceHover,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (_isFactCheckNotification && _videoId.isNotEmpty) {
      if (_isReviewFirst && !_isApproved) {
        buttons.add(
          ElevatedButton.icon(
            onPressed: () => controller.approveFactCheck(
              _videoId,
              notificationId: notification.id,
            ),
            icon: const Icon(
              Icons.check_circle_outline_rounded,
              size: 15,
              color: Colors.black,
            ),
            label: const Text('Approve & Publish Results'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        );
      }
      if (_isReviewFirst && _isApproved) {
        buttons.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceHover,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bgDivider),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      buttons.add(
        OutlinedButton.icon(
          onPressed: () {
            TruthVerificationDashboardPage.targetVideoId.value = _videoId;
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
          label: const Text('Review in Fact-Checks Tab'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            backgroundColor: AppColors.bgSurfaceHover,
            side: const BorderSide(color: AppColors.bgDivider),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (notification.verificationReportId != null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => ChannelNotificationsVerificationModal.show(
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
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
      );
    }

    for (final action in notification.actions) {
      buttons.add(
        OutlinedButton(
          onPressed: () => _handleAction(context, action),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.bgDivider),
            backgroundColor: AppColors.bgSurfaceHover,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: Text(action.label),
        ),
      );
    }

    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.read;
    final statusColor = _getStatusColor();
    final statusTag = _getStatusTag();
    final categoryTag = _getCategoryTag();
    final clarityMsg = _getInlineClarityMessage();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isUnread ? AppColors.bgSurfaceHover : AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCriticalStyle
              ? AppColors.error.withValues(alpha: 0.35)
              : (isUnread
                  ? Colors.white.withValues(alpha: 0.16)
                  : AppColors.bgDivider),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            controller.markAsRead(notification.id);
            if (_isCommentOrSocial) {
              NotificationNavigationHandler.navigateToAlertNotification(notification);
            } else if (_isSubscriber) {
              _navigateToChannelOrProfile(context);
            } else if (_isFactCheckNotification) {
              TruthVerificationDashboardPage.targetVideoId.value = _videoId;
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
            } else {
              ChannelNotificationsDetailModal.show(
                context,
                controller,
                notification,
                channelId,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Category & Status Header ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Text(
                        categoryTag,
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (statusTag != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusTag,
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      _formatSmartTimestamp(notification.createdAt),
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    if (isUnread)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Main Content Row ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic Avatar or Leading Icon
                    _buildLeadingIconOrAvatar(),
                    const SizedBox(width: 12),

                    // Main Text Content
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isCommentOrSocial && _commentAuthor.isNotEmpty) ...[
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  _commentAuthor,
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    fontFamilyFallback: TWTypography.fallbackFamilies,
                                    fontSize: 14,
                                    fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'commented on your video',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    fontFamilyFallback: TWTypography.fallbackFamilies,
                                    fontSize: 13,
                                    fontWeight: FontWeight.normal,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            // Clean comment quote container
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Text(
                                '"$_commentQuote"',
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontFamilyFallback: TWTypography.fallbackFamilies,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ] else ...[
                            Text(
                              notification.title,
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontFamilyFallback: TWTypography.fallbackFamilies,
                                fontSize: 14,
                                fontWeight: isUnread
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
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
                          ],

                          // Attached Video title chip (NEVER raw UUIDs!)
                          if (_videoId.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _navigateToVideo(context, _videoId),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.bgSurface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.bgDivider),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.play_circle_outline_rounded,
                                      size: 13,
                                      color: AppColors.textTertiary,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Obx(() {
                                        final vTitle = controller.getVideoTitle(
                                          _videoId,
                                          initialTitle: _videoTitle,
                                        );
                                        return Text(
                                          vTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: TWTypography.uiFamily,
                                            fontFamilyFallback:
                                                TWTypography.fallbackFamilies,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textSecondary,
                                          ),
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Analytics Snapshot pill
                          if (notification.analyticsSnapshot != null) ...[
                            const SizedBox(height: 8),
                            ChannelNotificationsAnalyticsSnapshotPill(
                              snapshot: notification.analyticsSnapshot!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Concise Context Box (Only when actionable guidance exists) ──
                if (clarityMsg != null) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            clarityMsg,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontFamilyFallback: TWTypography.fallbackFamilies,
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Action Buttons Row ──
                Builder(
                  builder: (context) {
                    final actionWidgets = _buildActionButtons(context);
                    if (actionWidgets.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.bgDivider),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: actionWidgets,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Metrics pill showing subscriber and view counts captured at notification creation time.
class ChannelNotificationsAnalyticsSnapshotPill extends StatelessWidget {
  const ChannelNotificationsAnalyticsSnapshotPill({
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
