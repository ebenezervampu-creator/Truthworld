import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/notification_service.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_models.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:url_launcher/url_launcher.dart';

/// Handles deep linking, navigation, display name formatting, and timestamp parsing
/// for notifications.
class NotificationNavigationHandler {
  const NotificationNavigationHandler._();

  /// Routes to the video watch screen with video arguments.
  static void navigateToVideo(Video notification) {
    Get.toNamed(
      '/watch?v=${notification.id}',
      arguments: {'video': notification},
    );
  }

  /// Evaluates alert notification payload and directs user to the appropriate screen
  /// (Creator Studio, Perspective Flip, Video player with comments, external URLs, or Channel).
  static void navigateToAlertNotification(UserNotification alert) {
    final typeLower = alert.type.toLowerCase();
    final titleLower = alert.title.toLowerCase();
    final messageLower = alert.message.toLowerCase();

    // 1. Check if notification is a New Subscriber / Follower / Creator Studio notification
    final isSubscriberNotification = typeLower == 'new_follower' ||
        typeLower == 'subscriber' ||
        typeLower == 'new_subscriber' ||
        typeLower == 'subscription' ||
        typeLower == 'subscribers_milestone' ||
        typeLower.contains('subscriber') ||
        typeLower.contains('follower') ||
        titleLower.contains('subscriber') ||
        titleLower.contains('subscribers') ||
        messageLower.contains('subscribed to your channel') ||
        messageLower.contains('subscribed');

    final isStudioNotification = isSubscriberNotification ||
        typeLower == 'creator_intelligence' ||
        typeLower == 'coach_growth_tip' ||
        typeLower == 'coach_growth_tip_v1' ||
        typeLower == 'subscribers_milestone_v1' ||
        typeLower == 'analytics_alert' ||
        typeLower == 'monetization' ||
        (alert.actionUrl != null &&
            alert.actionUrl!.toLowerCase().contains('studio'));

    if (isStudioNotification) {
      StudioLauncher.openStudio();
      return;
    }

    // 2. Check for Perspective Flip notification
    final videoId = alert.metadata?['videoId'] as String? ??
        alert.metadata?['targetVideoId'] as String? ??
        alert.metadata?['video_id'] as String?;

    if (alert.type == 'perspective_flip' &&
        videoId != null &&
        videoId.isNotEmpty) {
      NotificationService.to.handlePerspectiveFlipNotification(
        videoId: videoId,
        commentId: alert.metadata?['commentId'] as String?,
        replyId: alert.metadata?['replyId'] as String?,
      );
      return;
    }

    // 3. Check for specific Video-related notifications (Comment, Reply, Like, Mention, Video update)
    if (videoId != null && videoId.isNotEmpty) {
      final commentId = alert.metadata?['commentId'] as String?;
      final replyId = alert.metadata?['replyId'] as String?;

      Get.toNamed(
        '/watch?v=$videoId',
        arguments: {
          'videoId': videoId,
          'commentId': ?commentId,
          'replyId': ?replyId,
        },
      );
      return;
    }

    // 4. Action URL routing (e.g. /channel/xxx, /post/xxx, /topic/xxx, /community-guidelines, etc.)
    final actionUrl = alert.actionUrl;
    if (actionUrl != null && actionUrl.isNotEmpty) {
      try {
        if (actionUrl.startsWith('/')) {
          Get.toNamed(actionUrl);
          return;
        } else if (actionUrl.startsWith('http://') ||
            actionUrl.startsWith('https://')) {
          final uri = Uri.parse(actionUrl);
          launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'NotificationNavigationHandler.actionUrl',
        );
      }
    }

    // 5. If channelId is present in metadata, navigate to channel details
    final channelId = alert.metadata?['channelId'] as String? ??
        alert.metadata?['subscriberChannelId'] as String? ??
        alert.metadata?['mentionedChannelId'] as String?;
    if (channelId != null && channelId.isNotEmpty) {
      Get.toNamed('/channel/$channelId');
      return;
    }
  }

  /// Human-friendly relative timestamp formatter.
  static String formatNotificationTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.isNegative || difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${(difference.inDays / 30).floor()}mo ago';
    }
  }

  /// Extracts display name from notification metadata or parses from common notification templates.
  static String getDisplayName(UnifiedNotificationItem item) {
    if (item.video != null) {
      return item.video!.channelName;
    }
    if (item.alert != null) {
      final meta = item.alert!.metadata;
      if (meta != null) {
        final explicitName = meta['senderName'] as String? ??
            meta['channelName'] as String? ??
            meta['userName'] as String? ??
            meta['displayName'] as String? ??
            meta['subscriberName'] as String? ??
            meta['commentAuthorName'] as String?;
        if (explicitName != null && explicitName.trim().isNotEmpty) {
          return explicitName.trim();
        }
      }
      final message = item.alert!.message;
      if (message.contains(' subscribed to your channel')) {
        return message.split(' subscribed to your channel')[0].trim();
      }
      if (message.contains(' commented:')) {
        return message.split(' commented:')[0].trim();
      }
      if (message.contains(' replied to your comment:')) {
        return message.split(' replied to your comment:')[0].trim();
      }
      if (message.contains(' liked your comment:')) {
        return message.split(' liked your comment:')[0].trim();
      }
      if (message.contains(' liked your reply:')) {
        return message.split(' liked your reply:')[0].trim();
      }
      if (message.contains(' mentioned you:')) {
        return message.split(' mentioned you:')[0].trim();
      }
      if (message.startsWith('@')) {
        final words = message.split(' ');
        if (words.isNotEmpty) return words[0].replaceAll('@', '');
      }
      if (item.alert!.title.isNotEmpty) {
        return item.alert!.title;
      }
    }
    return '';
  }

  /// Returns a deterministically chosen background color based on name hash.
  static Color getAvatarColor(String name) {
    final clean = name.trim().replaceAll('@', '');
    if (clean.isEmpty) return const Color(0xFF374151);
    const colors = [
      Color(0xFFE11D48), // Rose
      Color(0xFFD97706), // Amber
      Color(0xFF059669), // Emerald
      Color(0xFF0D9488), // Teal
      Color(0xFF0284C7), // Sky
      Color(0xFF4F46E5), // Indigo
      Color(0xFF7C3AED), // Violet
      Color(0xFFC026D3), // Fuchsia
      Color(0xFFDB2777), // Pink
      Color(0xFF2563EB), // Blue
    ];
    var hash = 0;
    for (var i = 0; i < clean.length; i++) {
      hash = clean.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }
}
