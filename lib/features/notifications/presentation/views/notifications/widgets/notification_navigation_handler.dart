import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/notification_service.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_models.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:url_launcher/url_launcher.dart';

/// Represents the resolved routing target for a notification payload
class NotificationNavigationTarget {
  const NotificationNavigationTarget({
    required this.route,
    this.arguments,
    this.parameters,
    this.isStudio = false,
    this.isPerspectiveFlip = false,
    this.isExternalUrl = false,
  });

  final String route;
  final Map<String, dynamic>? arguments;
  final Map<String, String>? parameters;
  final bool isStudio;
  final bool isPerspectiveFlip;
  final bool isExternalUrl;
}

/// Handles deep linking, navigation, display name formatting, and timestamp parsing
/// for notifications.
class NotificationNavigationHandler {
  const NotificationNavigationHandler._();

  /// Safe navigation runner with cold-start queueing, navigator mounting check,
  /// and double-tap debouncing.
  static DateTime? _lastNavigationTime;
  static String? _lastNavigationKey;

  static void safeNavigate(String navigationKey, VoidCallback navigationAction) {
    final now = DateTime.now();
    if (_lastNavigationKey == navigationKey &&
        _lastNavigationTime != null &&
        now.difference(_lastNavigationTime!) < const Duration(milliseconds: 600)) {
      return; // Debounce rapid double-clicks
    }
    _lastNavigationTime = now;
    _lastNavigationKey = navigationKey;

    final isNavigatorReady =
        (Get.key.currentState != null && Get.context != null) || Get.testMode;
    if (!isNavigatorReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (Get.key.currentState != null || Get.testMode) {
            navigationAction();
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(milliseconds: 250), navigationAction);
            });
          }
        });
      });
    } else {
      navigationAction();
    }
  }

  /// Extracts video ID from payload data, metadata, or actionUrl regex patterns.
  static String? extractVideoId(
    Map<String, dynamic> payload, {
    String? actionUrl,
    Map<String, dynamic>? metadata,
  }) {
    var videoId = payload['videoId'] as String? ??
        metadata?['videoId'] as String? ??
        payload['targetVideoId'] as String? ??
        metadata?['targetVideoId'] as String? ??
        payload['video_id'] as String? ??
        metadata?['video_id'] as String?;

    if ((videoId == null || videoId.isEmpty) && actionUrl != null && actionUrl.isNotEmpty) {
      final videoRegex = RegExp('/(?:video|watch|v|shorts)/([^/?#]+)');
      final match = videoRegex.firstMatch(actionUrl);
      if (match != null) {
        videoId = match.group(1);
      } else if (actionUrl.contains('v=')) {
        final uri = Uri.tryParse(actionUrl);
        if (uri != null && uri.queryParameters.containsKey('v')) {
          videoId = uri.queryParameters['v'];
        }
      }
    }
    return (videoId != null && videoId.trim().isNotEmpty) ? videoId.trim() : null;
  }

  /// Determines whether a notification payload should route to Creator Studio or creator analytics.
  static bool isStudioNotificationPayload(
    Map<String, dynamic> data, {
    String? title,
    String? body,
    String? actionUrl,
  }) {
    final type = (data['type'] as String? ?? data['notificationType'] as String? ?? '').toLowerCase();
    final effectiveAction = (actionUrl ?? data['actionUrl'] as String? ?? '').toLowerCase();
    final titleLower = (title ?? data['title'] as String? ?? '').toLowerCase();
    final bodyLower = (body ?? data['message'] as String? ?? data['body'] as String? ?? '').toLowerCase();

    final isSubscriber = type == 'new_follower' ||
        type == 'subscriber' ||
        type == 'new_subscriber' ||
        type == 'subscription' ||
        type == 'subscribers_milestone' ||
        type == 'subscribers_milestone_v1' ||
        type == 'sub_milestone' ||
        type.contains('subscriber') ||
        type.contains('follower') ||
        titleLower.contains('subscriber') ||
        titleLower.contains('subscribers') ||
        bodyLower.contains('subscribed to your channel') ||
        bodyLower.contains('subscribed');

    return isSubscriber ||
        type == 'creator_intelligence' ||
        type == 'coach_growth_tip' ||
        type == 'coach_growth_tip_v1' ||
        type == 'creator_coach_insight' ||
        type == 'creator_motivation' ||
        type == 'analytics_alert' ||
        type == 'performance_insight' ||
        type == 'retention_spike' ||
        type == 'monetization' ||
        type == 'monetization_revenue' ||
        type == 'monetization_payout' ||
        type == 'membership_milestone' ||
        type == 'ranking_change' ||
        effectiveAction.contains('studio');
  }

  /// Routes directly to video watch screen, dismissing miniplayer and starting playback.
  static void navigateToVideo(Video notification) {
    safeNavigate('video_${notification.id}', () {
      if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer') ||
          Get.isRegistered<MiniplayerController>()) {
        MiniplayerController.to.dismiss();
      }

      Get.toNamed(
        '/watch?v=${notification.id}',
        arguments: {
          'video': notification,
          'videoId': notification.id,
          'fromNotification': true,
        },
        parameters: {
          'v': notification.id,
        },
      );
    });
  }

  /// Evaluates alert notification model and directs user to the appropriate screen.
  static void navigateToAlertNotification(UserNotification alert) {
    navigateFromPayload(
      alert.toJson(),
      title: alert.title,
      message: alert.message,
    );
  }

  /// Evaluates incoming FCM RemoteMessage and directs user to the appropriate screen.
  static void navigateToRemoteMessage(RemoteMessage message) {
    navigateFromPayload(
      message.data,
      title: message.notification?.title,
      message: message.notification?.body,
    );
  }

  /// Universal notification payload resolver.
  /// Resolves the intended route, arguments, parameters, and flags deterministically.
  static NotificationNavigationTarget resolveTarget(
    Map<String, dynamic> payload, {
    String? title,
    String? message,
  }) {
    final type = (payload['type'] as String? ??
            payload['notificationType'] as String? ??
            '')
        .trim();
    final typeLower = type.toLowerCase();

    // Parse metadata safely (nested map or JSON string)
    Map<String, dynamic>? meta;
    if (payload['metadata'] is Map) {
      meta = Map<String, dynamic>.from(payload['metadata'] as Map);
    } else if (payload['metadata'] is String) {
      try {
        final decoded = jsonDecode(payload['metadata'] as String);
        if (decoded is Map) {
          meta = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    final effectiveTitle = (title ??
            payload['title'] as String? ??
            meta?['title'] as String? ??
            '')
        .trim();
    final effectiveBody = (message ??
            payload['message'] as String? ??
            payload['body'] as String? ??
            meta?['message'] as String? ??
            meta?['body'] as String? ??
            '')
        .trim();

    final rawActionUrl = (payload['actionUrl'] as String? ??
            meta?['actionUrl'] as String? ??
            '')
        .trim();
    final actionUrl = rawActionUrl.isNotEmpty ? rawActionUrl : null;
    final actionUrlLower = (actionUrl ?? '').toLowerCase();

    // 1. Resolve videoId across all possible keys and actionUrl patterns
    final videoId = extractVideoId(
      payload,
      actionUrl: actionUrl,
      metadata: meta,
    );

    final commentId = payload['commentId'] as String? ??
        meta?['commentId'] as String?;
    final replyId = payload['replyId'] as String? ??
        meta?['replyId'] as String?;

    var channelId = payload['channelId'] as String? ??
        meta?['channelId'] as String? ??
        payload['targetChannelId'] as String? ??
        meta?['targetChannelId'] as String? ??
        payload['subscriberChannelId'] as String? ??
        meta?['subscriberChannelId'] as String? ??
        payload['mentionedChannelId'] as String? ??
        meta?['mentionedChannelId'] as String?;

    if ((channelId == null || channelId.isEmpty) && actionUrl != null) {
      final channelRegex = RegExp('/(?:channel|@)/?([^/?#]+)');
      final match = channelRegex.firstMatch(actionUrl);
      if (match != null) {
        channelId = match.group(1);
      }
    }

    var topicId = payload['topicId'] as String? ??
        meta?['topicId'] as String? ??
        payload['topicSlug'] as String? ??
        meta?['topicSlug'] as String? ??
        payload['slug'] as String? ??
        meta?['slug'] as String?;

    if ((topicId == null || topicId.isEmpty) && actionUrl != null) {
      final topicRegex = RegExp('/(?:topic|topics|t|T)/([^/?#]+)');
      final match = topicRegex.firstMatch(actionUrl);
      if (match != null) {
        topicId = match.group(1);
      }
    }

    var postId = payload['postId'] as String? ??
        meta?['postId'] as String? ??
        payload['communityPostId'] as String? ??
        meta?['communityPostId'] as String?;

    if ((postId == null || postId.isEmpty) && actionUrl != null) {
      final postRegex = RegExp('/(?:post|community)/([^/?#]+)');
      final match = postRegex.firstMatch(actionUrl);
      if (match != null) {
        postId = match.group(1);
      }
    }

    // ── ROUTE 1: Perspective Flip ──
    if (typeLower == 'perspective_flip' && videoId != null && videoId.isNotEmpty) {
      return NotificationNavigationTarget(
        route: '/watch?v=$videoId',
        isPerspectiveFlip: true,
        arguments: {
          'videoId': videoId,
          'isFlipped': true,
          'commentId': ?commentId,
          'replyId': ?replyId,
        },
        parameters: {
          'v': videoId,
          'isFlipped': 'true',
          'commentId': ?commentId,
          'replyId': ?replyId,
        },
      );
    }

    // ── ROUTE 2: Creator Studio & Subscriber Milestones ──
    final isStudio = isStudioNotificationPayload(
      payload,
      title: effectiveTitle,
      body: effectiveBody,
      actionUrl: actionUrl,
    );

    if (isStudio) {
      if (actionUrlLower.contains('/subscribers') ||
          typeLower == 'subscribers_milestone' ||
          typeLower == 'subscribers_milestone_v1') {
        return const NotificationNavigationTarget(route: '/subscribers');
      }
      if (actionUrlLower.contains('/analytics') ||
          typeLower == 'creator_intelligence' ||
          typeLower.contains('coach_growth_tip')) {
        return const NotificationNavigationTarget(route: '/analytics');
      }
      if (actionUrlLower.contains('/views')) {
        return const NotificationNavigationTarget(route: '/views');
      }
      if (actionUrlLower.contains('/watchtime')) {
        return const NotificationNavigationTarget(route: '/watchtime');
      }
      if (actionUrlLower.contains('/wallet')) {
        return const NotificationNavigationTarget(route: '/wallet');
      }

      return const NotificationNavigationTarget(route: '/studio', isStudio: true);
    }

    // ── ROUTE 3: Video Watch Screen (new_video_followed, new_video_topic, comments, likes, replies, mentions) ──
    if (videoId != null && videoId.isNotEmpty) {
      final isTopicOrigin = typeLower == 'new_video_topic' || topicId != null;

      return NotificationNavigationTarget(
        route: '/watch?v=$videoId',
        arguments: {
          'videoId': videoId,
          'commentId': ?commentId,
          'replyId': ?replyId,
          'channelId': ?channelId,
          'topicId': ?topicId,
          if (isTopicOrigin) 'fromTopic': true,
          'fromPush': true,
        },
        parameters: {
          'v': videoId,
          'commentId': ?commentId,
          'replyId': ?replyId,
        },
      );
    }

    // ── ROUTE 4: Community Post (new_community_post) ──
    if (typeLower == 'new_community_post' || (postId != null && postId.isNotEmpty)) {
      if (postId != null && postId.isNotEmpty) {
        return NotificationNavigationTarget(
          route: '/post/$postId',
          arguments: {
            'postId': postId,
            'channelId': ?channelId,
          },
        );
      }
      if (channelId != null && channelId.isNotEmpty) {
        return NotificationNavigationTarget(route: '/channel/$channelId');
      }
    }

    // ── ROUTE 5: Topic Updates ──
    if (topicId != null && topicId.isNotEmpty) {
      return NotificationNavigationTarget(route: '/topic/$topicId');
    }

    // ── ROUTE 6: Channel Navigation ──
    if (channelId != null && channelId.isNotEmpty) {
      return NotificationNavigationTarget(route: '/channel/$channelId');
    }

    // ── ROUTE 7: Verification & Moderation Actions ──
    if (typeLower == 'verification_result' ||
        typeLower == 'batch_verification_result') {
      if (actionUrlLower.contains('community') ||
          meta?['itemType'] == 'community_post') {
        return const NotificationNavigationTarget(
          route: '/saved-community-posts',
        );
      }
      return const NotificationNavigationTarget(route: '/studio', isStudio: true);
    }

    // ── ROUTE 8: Direct Action URL (Internal or External) ──
    if (actionUrl != null && actionUrl.isNotEmpty) {
      if (actionUrl.startsWith('/')) {
        return NotificationNavigationTarget(route: actionUrl);
      } else if (actionUrl.startsWith('http://') ||
          actionUrl.startsWith('https://')) {
        return NotificationNavigationTarget(
          route: actionUrl,
          isExternalUrl: true,
        );
      }
    }

    // ── ROUTE 9: Universal Fallback to In-App Notification Center ──
    return const NotificationNavigationTarget(route: '/notifications');
  }

  /// Universal notification payload deep-link routing engine.
  /// Handles all notification types across TruthWorld according to industry standards.
  static void navigateFromPayload(
    Map<String, dynamic> payload, {
    String? title,
    String? message,
  }) {
    try {
      final target = resolveTarget(payload, title: title, message: message);

      if (target.isPerspectiveFlip) {
        final videoId = target.arguments?['videoId'] as String? ?? '';
        NotificationService.to.handlePerspectiveFlipNotification(
          videoId: videoId,
          commentId: target.arguments?['commentId'] as String?,
          replyId: target.arguments?['replyId'] as String?,
        );
        return;
      }

      if (target.isStudio) {
        StudioLauncher.openStudio();
        return;
      }

      if (target.isExternalUrl) {
        final uri = Uri.tryParse(target.route);
        if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
          unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
        }
        return;
      }

      safeNavigate('nav_${target.route}', () {
        if (target.route.startsWith('/watch')) {
          if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer') ||
              Get.isRegistered<MiniplayerController>()) {
            MiniplayerController.to.dismiss();
          }
        }

        unawaited(
          Get.toNamed(
            target.route,
            arguments: target.arguments,
            parameters: target.parameters,
          ),
        );
      });
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'NotificationNavigationHandler.navigateFromPayload',
      );
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
