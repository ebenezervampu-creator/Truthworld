import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/notification_service.dart';
import 'package:truthworld/core/utils/cross_app_launcher.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_models.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:url_launcher/url_launcher.dart';

/// Represents the resolved routing target for a notification payload
class NotificationNavigationTarget {
  const NotificationNavigationTarget({
    required this.route,
    this.arguments,
    this.parameters,
    this.targetApp = AppFlavor.app,
    this.isStudio = false,
    this.isAdmin = false,
    this.isAdvertiser = false,
    this.isPerspectiveFlip = false,
    this.isExternalUrl = false,
  });

  final String route;
  final Map<String, dynamic>? arguments;
  final Map<String, String>? parameters;
  final AppFlavor targetApp;
  final bool isStudio;
  final bool isAdmin;
  final bool isAdvertiser;
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
      final videoRegex = RegExp('(?:^|/)(?:video|watch|v|shorts)/([^/?#]+)');
      final match = videoRegex.firstMatch(actionUrl);
      if (match != null) {
        videoId = match.group(1);
      } else if (actionUrl.contains('v=') || actionUrl.contains('videoId=')) {
        final normalized = actionUrl.startsWith('http') || actionUrl.startsWith('/')
            ? actionUrl
            : '/$actionUrl';
        final uri = Uri.tryParse(normalized);
        if (uri != null) {
          videoId = uri.queryParameters['v'] ?? uri.queryParameters['videoId'];
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
    final rawTarget = (data['targetApp'] as String? ?? data['app'] as String? ?? data['appFlavor'] as String? ?? '').toLowerCase().trim();
    if (rawTarget == 'studio') return true;
    if (rawTarget == 'admin' || rawTarget == 'advertiser' || rawTarget == 'ads') return false;

    final type = (data['type'] as String? ?? data['notificationType'] as String? ?? '').toLowerCase();
    final effectiveAction = (actionUrl ?? data['actionUrl'] as String? ?? '').toLowerCase();
    final titleLower = (title ?? data['title'] as String? ?? '').toLowerCase();
    final bodyLower = (body ?? data['message'] as String? ?? data['body'] as String? ?? '').toLowerCase();
    final category = (data['category'] as String? ?? '').toLowerCase();

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

    final isFactCheckOrClaim = type == 'fact_check_pending' ||
        type == 'fact_check_ready' ||
        type == 'fact_check_completed' ||
        type == 'verification_result' ||
        type == 'batch_verification_result' ||
        type == 'copyright_claim' ||
        type == 'claim_dispute' ||
        type.contains('fact_check') ||
        type.contains('verification') ||
        category == 'verification';

    final isStudioTitleOrBody = titleLower.contains('truth verification') ||
        titleLower.contains('fact-checking') ||
        titleLower.contains('fact check') ||
        titleLower.contains('video moderation') ||
        titleLower.contains('content moderation') ||
        titleLower.contains('topic moderation') ||
        titleLower.contains('thumbnail verification') ||
        titleLower.contains('video not accepted') ||
        titleLower.contains('topic not accepted') ||
        titleLower.contains('video under manual review') ||
        titleLower.contains('topic under manual review') ||
        titleLower.contains('video processing') ||
        titleLower.contains('video approved & published') ||
        titleLower.contains('topic approved & published') ||
        titleLower.contains('creator studio') ||
        titleLower.contains('channel policy') ||
        titleLower.contains('copyright claim') ||
        titleLower.contains('claim dispute') ||
        bodyLower.contains('studio notifications') ||
        bodyLower.contains('creator studio') ||
        bodyLower.contains('content moderation') ||
        bodyLower.contains('topic moderation') ||
        bodyLower.contains('fact-checking for') ||
        bodyLower.contains('held in studio');

    return isSubscriber ||
        isFactCheckOrClaim ||
        isStudioTitleOrBody ||
        type == 'channel_notifications' ||
        type == 'studio_notifications' ||
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
        type == 'view_milestone' ||
        type == 'milestone_achieved' ||
        type == 'ranking_change' ||
        type == 'trust_score_change' ||
        type == 'tier_promotion' ||
        type == 'tier_downgrade' ||
        type == 'inactivity_warning' ||
        type == 'performance_warning' ||
        type == 'weekly_digest' ||
        type == 'chapters' ||
        type.contains('chapter') ||
        type == 'drafts' ||
        type == 'trash' ||
        type.contains('studio') ||
        type.contains('monetization') ||
        type.contains('milestone') ||
        type.contains('coach') ||
        category == 'monetization' ||
        category == 'analytics' ||
        category == 'growth' ||
        category == 'education' ||
        effectiveAction.contains('studio') ||
        effectiveAction.contains('/subscribers') ||
        effectiveAction.contains('/views') ||
        effectiveAction.contains('/watchtime') ||
        effectiveAction.contains('/analytics') ||
        effectiveAction.contains('/copyright') ||
        effectiveAction.contains('/monetization') ||
        effectiveAction.contains('/revenue') ||
        effectiveAction.contains('/payout') ||
        effectiveAction.contains('/saved-community-posts');
  }

  /// Determines whether a notification payload should route to Admin & Moderation.
  static bool isAdminNotificationPayload(
    Map<String, dynamic> data, {
    String? title,
    String? body,
    String? actionUrl,
  }) {
    final type = (data['type'] as String? ?? data['notificationType'] as String? ?? '').toLowerCase();
    final effectiveAction = (actionUrl ?? data['actionUrl'] as String? ?? '').toLowerCase();
    final category = (data['category'] as String? ?? '').toLowerCase();

    return type.startsWith('admin_') ||
        type.contains('flagged') ||
        type.contains('escalation') ||
        type == 'kyc_submitted' ||
        type == 'channel_verification' ||
        type == 'security_alert' ||
        type == 'system_alert' ||
        type == 'audit_log' ||
        type == 'audit_logs' ||
        type == 'appeals' ||
        type.contains('appeal') ||
        type.contains('dispute') ||
        type == 'user_flagged' ||
        type == 'ad_flagged' ||
        type == 'ad_reported' ||
        type == 'ad_reports' ||
        type == 'admin_invite' ||
        type == 'team_member_added' ||
        type == 'user_feedback' ||
        type == 'feedback_request' ||
        category == 'security' ||
        category == 'policy_enforcement' ||
        effectiveAction.contains('/admin');
  }

  /// Determines whether a notification payload should route to Advertiser Portal.
  static bool isAdvertiserNotificationPayload(
    Map<String, dynamic> data, {
    String? title,
    String? body,
    String? actionUrl,
  }) {
    final type = (data['type'] as String? ?? data['notificationType'] as String? ?? '').toLowerCase();
    final effectiveAction = (actionUrl ?? data['actionUrl'] as String? ?? '').toLowerCase();
    final category = (data['category'] as String? ?? '').toLowerCase();

    return type.startsWith('campaign_') ||
        type == 'campaign_approved' ||
        type == 'campaign_rejected' ||
        type == 'campaign_status' ||
        type == 'campaign_budget_low' ||
        type == 'campaign_completed' ||
        type == 'campaign_performance' ||
        type == 'ad_performance' ||
        type == 'ad_report' ||
        type == 'billing_invoice' ||
        type == 'billing_low_balance' ||
        type == 'payment_success' ||
        type == 'payment_failed' ||
        type == 'ad_targeting' ||
        type == 'audience_insight' ||
        type == 'ad_sponsorship' ||
        type == 'sponsorship_request' ||
        type == 'ad_creative' ||
        type == 'asset_approved' ||
        type == 'brand_settings' ||
        type.contains('creative') ||
        type.contains('asset') ||
        type.contains('brand_setting') ||
        type.contains('brand_settings') ||
        type.contains('advertiser') ||
        category == 'sponsorship' ||
        category == 'advertisement' ||
        effectiveAction.contains('/advertiser') ||
        effectiveAction.contains('/ads') ||
        effectiveAction.contains('/advertisements');
  }

  /// Resolves which TruthWorld product flavor is targeted by the notification payload
  static AppFlavor resolveTargetFlavor(
    Map<String, dynamic> data, {
    String? title,
    String? body,
    String? actionUrl,
  }) {
    final rawTarget = (data['targetApp'] as String? ??
            data['app'] as String? ??
            data['appFlavor'] as String? ??
            '')
        .trim()
        .toLowerCase();

    if (rawTarget == 'studio') return AppFlavor.studio;
    if (rawTarget == 'admin') return AppFlavor.admin;
    if (rawTarget == 'advertiser' || rawTarget == 'ads') return AppFlavor.advertiser;
    if (rawTarget == 'app') return AppFlavor.app;
    if (rawTarget == 'all') return AppFlavor.active;

    if (isAdminNotificationPayload(data, title: title, body: body, actionUrl: actionUrl)) {
      return AppFlavor.admin;
    }
    if (isAdvertiserNotificationPayload(data, title: title, body: body, actionUrl: actionUrl)) {
      return AppFlavor.advertiser;
    }
    if (isStudioNotificationPayload(data, title: title, body: body, actionUrl: actionUrl)) {
      return AppFlavor.studio;
    }
    return AppFlavor.app;
  }

  /// Routes directly to video watch screen, dismissing miniplayer and starting playback.
  static void navigateToVideo(Video notification) {
    safeNavigate('video_${notification.id}', () {
      if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer') ||
          Get.isRegistered<MiniplayerController>()) {
        MiniplayerController.to.dismiss();
      }

      Get.toNamed(
        '/watch',
        arguments: {
          'video': notification,
          'videoId': notification.id,
          'fromNotification': true,
          'fromPush': true,
          'autoplay': true,
        },
        parameters: {
          'v': notification.id,
          'autoplay': 'true',
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

    var commentId = payload['commentId'] as String? ??
        meta?['commentId'] as String?;
    var replyId = payload['replyId'] as String? ??
        meta?['replyId'] as String?;

    if (actionUrl != null && (commentId == null || replyId == null)) {
      final normalized = actionUrl.startsWith('http') || actionUrl.startsWith('/')
          ? actionUrl
          : '/$actionUrl';
      final uri = Uri.tryParse(normalized);
      if (uri != null) {
        commentId ??= uri.queryParameters['commentId'] ?? uri.queryParameters['comment'];
        replyId ??= uri.queryParameters['replyId'] ?? uri.queryParameters['reply'];
      }
    }

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

    int? claimIndex;
    final rawClaimIndex = payload['claimIndex'] ?? meta?['claimIndex'];
    if (rawClaimIndex is int) {
      claimIndex = rawClaimIndex;
    } else if (rawClaimIndex is String) {
      claimIndex = int.tryParse(rawClaimIndex);
    }
    if (claimIndex == null && actionUrl != null) {
      final normalized = actionUrl.startsWith('http') || actionUrl.startsWith('/')
          ? actionUrl
          : '/$actionUrl';
      final uri = Uri.tryParse(normalized);
      if (uri != null && uri.queryParameters['claimIndex'] != null) {
        claimIndex = int.tryParse(uri.queryParameters['claimIndex']!);
      }
    }

    // ── Resolve Product Flavor Target ──
    final targetFlavor = resolveTargetFlavor(
      payload,
      title: effectiveTitle,
      body: effectiveBody,
      actionUrl: actionUrl,
    );

    // ── APP FLAVOR 1: Admin & Moderation (com.truthworld.admin) ──
    if (targetFlavor == AppFlavor.admin) {
      var adminTab = 'dashboard';
      if (typeLower.contains('video') ||
          typeLower == 'content_flagged' ||
          typeLower == 'moderation_escalation') {
        adminTab = 'videos';
      } else if (typeLower.contains('ad_report')) {
        adminTab = 'ad_reports';
      } else if (typeLower.contains('report')) {
        adminTab = 'reports';
      } else if (typeLower.contains('image') || typeLower.contains('thumbnail')) {
        adminTab = 'images';
      } else if (typeLower.contains('channel') || typeLower == 'kyc_submitted') {
        adminTab = 'channels';
      } else if (typeLower.contains('topic')) {
        adminTab = 'topics';
      } else if (typeLower == 'appeals' || typeLower.contains('appeal') || typeLower.contains('dispute')) {
        adminTab = 'appeals';
      } else if (typeLower.contains('user') && !typeLower.contains('user_feedback')) {
        adminTab = 'users';
      } else if (typeLower.contains('team') || typeLower.contains('admin_invite')) {
        adminTab = 'team';
      } else if (typeLower.contains('ad') || typeLower.contains('campaign')) {
        adminTab = 'ads';
      } else if (typeLower.contains('feedback')) {
        adminTab = 'feedbacks';
      } else if (typeLower.contains('log')) {
        adminTab = 'logs';
      } else if (typeLower.contains('alert') || typeLower.contains('security')) {
        adminTab = 'alerts';
      }

      return NotificationNavigationTarget(
        route: '/admin/dashboard',
        targetApp: AppFlavor.admin,
        isAdmin: true,
        arguments: {
          'tab': adminTab,
          'videoId': ?videoId,
          'channelId': ?channelId,
          'topicId': ?topicId,
          if (payload['reportId'] != null) 'reportId': payload['reportId'],
          if (payload['appealId'] != null) 'appealId': payload['appealId'],
          if (payload['userId'] != null) 'userId': payload['userId'],
          if (payload['adId'] != null) 'adId': payload['adId'],
        },
        parameters: {
          'tab': adminTab,
          'videoId': ?videoId,
        },
      );
    }

    // ── APP FLAVOR 2: Advertiser Portal (com.truthworld.advertiser) ──
    if (targetFlavor == AppFlavor.advertiser) {
      var adTabIndex = 0;
      if (typeLower == 'campaign_performance' ||
          typeLower == 'ad_performance' ||
          typeLower == 'ad_report' ||
          typeLower.contains('performance') ||
          typeLower.contains('analytics')) {
        adTabIndex = 2; // Performance Reports
      } else if (typeLower.contains('campaign')) {
        adTabIndex = 1; // My Campaigns
      } else if (typeLower.contains('subtitle')) {
        adTabIndex = 3; // AI Video Subtitles
      } else if (typeLower.contains('dub')) {
        adTabIndex = 4; // AI Audio Dubbing
      } else if (typeLower.contains('bill') ||
          typeLower.contains('invoice') ||
          typeLower.contains('payment') ||
          typeLower.contains('balance') ||
          typeLower.contains('funds')) {
        adTabIndex = 5; // Billing & Invoices
      } else if (typeLower.contains('audience') || typeLower.contains('target')) {
        adTabIndex = 6; // Audience & Targeting
      } else if (typeLower.contains('sponsor')) {
        adTabIndex = 7; // Creator Sponsorships
      } else if (typeLower.contains('creative') || typeLower.contains('asset')) {
        adTabIndex = 8; // Creative Assets
      } else if (typeLower.contains('brand') || typeLower.contains('setting')) {
        adTabIndex = 9; // Brand Settings
      } else if (typeLower.contains('report')) {
        adTabIndex = 2; // Fallback reports
      }

      return NotificationNavigationTarget(
        route: '/advertiser',
        targetApp: AppFlavor.advertiser,
        isAdvertiser: true,
        arguments: {
          'tab': adTabIndex,
          if (payload['campaignId'] != null) 'campaignId': payload['campaignId'],
        },
        parameters: {
          'tab': '$adTabIndex',
        },
      );
    }

    // ── APP FLAVOR 3: Creator Studio (com.truthworld.studio) ──
    if (targetFlavor == AppFlavor.studio) {
      // 1. Fact-check & Verification results
      if (typeLower == 'fact_check_pending' ||
          typeLower == 'fact_check_ready' ||
          typeLower == 'fact_check_completed' ||
          typeLower == 'verification_result' ||
          typeLower == 'batch_verification_result') {
        if (actionUrlLower.contains('community') || meta?['itemType'] == 'community_post') {
          return const NotificationNavigationTarget(
            route: '/saved-community-posts',
            targetApp: AppFlavor.studio,
            isStudio: true,
          );
        }
        if (actionUrlLower.contains('topic') ||
            meta?['itemType'] == 'topic' ||
            (topicId != null && topicId.isNotEmpty && !typeLower.contains('video') && videoId == null)) {
          return NotificationNavigationTarget(
            route: '/studio',
            targetApp: AppFlavor.studio,
            isStudio: true,
            arguments: {
              'tab': 14, // ContentScreen Topics tab
              'topicId': ?topicId,
            },
            parameters: {
              'tab': 'topics',
              'topicId': ?topicId,
            },
          );
        }
        return NotificationNavigationTarget(
          route: '/studio',
          targetApp: AppFlavor.studio,
          isStudio: true,
          arguments: {
            'tab': 15, // TruthVerificationDashboardPage
            'filter': 'fact_check',
            'videoId': ?videoId,
          },
          parameters: {
            'tab': 'verification',
            'videoId': ?videoId,
          },
        );
      }

      // 2. Copyright Claims
      if (typeLower == 'copyright_claim' || typeLower == 'claim_dispute') {
        return NotificationNavigationTarget(
          route: '/studio',
          targetApp: AppFlavor.studio,
          isStudio: true,
          arguments: {
            'tab': 9, // CopyrightScreen
            'videoId': ?videoId,
          },
          parameters: {
            'tab': 'copyright',
            'videoId': ?videoId,
          },
        );
      }

      // 3. Subscriber Milestones & Follower Updates
      if (actionUrlLower.contains('/subscribers') ||
          typeLower == 'subscribers_milestone' ||
          typeLower == 'subscribers_milestone_v1' ||
          typeLower == 'sub_milestone' ||
          typeLower == 'subscriber' ||
          typeLower == 'new_subscriber' ||
          typeLower == 'new_follower') {
        return NotificationNavigationTarget(
          route: '/subscribers',
          targetApp: AppFlavor.studio,
          isStudio: true,
          arguments: {
            'tab': 12, // AudiencePage
            'channelId': ?channelId,
          },
          parameters: {
            'tab': 'audience',
          },
        );
      }

      // 4. Analytics & Growth Insights
      if (actionUrlLower.contains('/views')) {
        return const NotificationNavigationTarget(
          route: '/views',
          targetApp: AppFlavor.studio,
          isStudio: true,
        );
      }
      if (actionUrlLower.contains('/watchtime')) {
        return const NotificationNavigationTarget(
          route: '/watchtime',
          targetApp: AppFlavor.studio,
          isStudio: true,
        );
      }
      if (actionUrlLower.contains('/analytics') ||
          typeLower == 'analytics_alert' ||
          typeLower == 'performance_insight' ||
          typeLower == 'retention_spike' ||
          typeLower == 'view_milestone' ||
          typeLower == 'channel_notifications' ||
          typeLower == 'studio_notifications' ||
          typeLower.contains('coach_growth_tip')) {
        return const NotificationNavigationTarget(
          route: '/analytics',
          targetApp: AppFlavor.studio,
          isStudio: true,
          arguments: {'tab': 3},
          parameters: {'tab': 'analytics'},
        );
      }

      // 5. Channel Notifications & AI Coach
      if (typeLower == 'creator_coach_insight' ||
          typeLower == 'creator_motivation') {
        return const NotificationNavigationTarget(
          route: '/studio/notifications',
          targetApp: AppFlavor.studio,
          isStudio: true,
          arguments: {'tab': 16},
          parameters: {'tab': 'notifications'},
        );
      }

      // 6. Monetization & Wallet
      if (actionUrlLower.contains('/wallet') ||
          typeLower == 'monetization' ||
          typeLower == 'monetization_revenue' ||
          typeLower == 'monetization_payout' ||
          typeLower == 'membership_milestone') {
        return const NotificationNavigationTarget(
          route: '/wallet',
          targetApp: AppFlavor.studio,
          isStudio: true,
          arguments: {'tab': 5},
          parameters: {'tab': 'monetization'},
        );
      }

      // 7. Chapters, Drafts, Trash
      if (actionUrlLower.contains('/chapters') || typeLower == 'chapters') {
        return const NotificationNavigationTarget(
          route: '/studio/chapters',
          targetApp: AppFlavor.studio,
          isStudio: true,
          arguments: {'tab': 11},
          parameters: {'tab': 'chapters'},
        );
      }
      if (actionUrlLower.contains('/drafts')) {
        return const NotificationNavigationTarget(
          route: '/studio/drafts',
          targetApp: AppFlavor.studio,
          isStudio: true,
          arguments: {'tab': 2, 'filter': 'drafts'},
          parameters: {'tab': 'drafts'},
        );
      }
      if (actionUrlLower.contains('/trash')) {
        return const NotificationNavigationTarget(
          route: '/studio/trash',
          targetApp: AppFlavor.studio,
          isStudio: true,
          arguments: {'tab': 2, 'filter': 'trash'},
          parameters: {'tab': 'trash'},
        );
      }

      return const NotificationNavigationTarget(
        route: '/studio',
        targetApp: AppFlavor.studio,
        isStudio: true,
        arguments: {'tab': 1},
        parameters: {'tab': 'overview'},
      );
    }

    // ── APP FLAVOR 4: Consumer App (com.truthworld.app) ──
    // 1. Perspective Flip
    if (typeLower == 'perspective_flip' && videoId != null && videoId.isNotEmpty) {
      return NotificationNavigationTarget(
        route: '/watch?v=$videoId',
        isPerspectiveFlip: true,
        arguments: {
          'videoId': videoId,
          'isFlipped': true,
          'autoplay': true,
          'fromNotification': true,
          'fromPush': true,
          'commentId': ?commentId,
          'replyId': ?replyId,
        },
        parameters: {
          'v': videoId,
          'isFlipped': 'true',
          'autoplay': 'true',
          'commentId': ?commentId,
          'replyId': ?replyId,
        },
      );
    }

    // 2. Video Watch Screen with Autoplay:
    // (new_video_followed, new_video_topic, comment, comment_like, comment_reply, mention, claim_note)
    if (videoId != null && videoId.isNotEmpty) {
      final isTopicOrigin = typeLower == 'new_video_topic' || topicId != null;

      // Direct deep-link to claim deliberation notes / Truth Credibility if specified
      if (claimIndex != null || typeLower.contains('claim')) {
        return NotificationNavigationTarget(
          route: '/claim-detail?videoId=$videoId&claimIndex=${claimIndex ?? 0}',
          arguments: {
            'videoId': videoId,
            'claimIndex': claimIndex ?? 0,
            'commentId': ?commentId,
            'fromNotification': true,
            'fromPush': true,
          },
          parameters: {
            'videoId': videoId,
            'claimIndex': (claimIndex ?? 0).toString(),
            'commentId': ?commentId,
          },
        );
      }

      return NotificationNavigationTarget(
        route: '/watch?v=$videoId',
        arguments: {
          'videoId': videoId,
          'autoplay': true,
          'fromNotification': true,
          'fromPush': true,
          'commentId': ?commentId,
          'replyId': ?replyId,
          'channelId': ?channelId,
          'topicId': ?topicId,
          'claimIndex': ?claimIndex,
          if (isTopicOrigin) 'fromTopic': true,
          if (payload['thumbnailUrl'] != null) 'thumbnailUrl': payload['thumbnailUrl'],
        },
        parameters: {
          'v': videoId,
          'autoplay': 'true',
          'commentId': ?commentId,
          'replyId': ?replyId,
          if (claimIndex != null) 'claimIndex': claimIndex.toString(),
        },
      );
    }

    // 3. Community Post (new_community_post, comment, comment_like, comment_reply)
    if (typeLower == 'new_community_post' || (postId != null && postId.isNotEmpty)) {
      if (postId != null && postId.isNotEmpty) {
        return NotificationNavigationTarget(
          route: '/post/$postId',
          arguments: {
            'postId': postId,
            'channelId': ?channelId,
            'commentId': ?commentId,
            'replyId': ?replyId,
            'fromNotification': true,
            'fromPush': true,
          },
          parameters: {
            'postId': postId,
            'commentId': ?commentId,
            'replyId': ?replyId,
          },
        );
      }
      if (channelId != null && channelId.isNotEmpty) {
        return NotificationNavigationTarget(
          route: '/channel/$channelId',
        );
      }
    }

    // 4. Topic Updates
    if (topicId != null && topicId.isNotEmpty) {
      return NotificationNavigationTarget(
        route: '/topic/$topicId',
        arguments: {
          'topicId': topicId,
          'commentId': ?commentId,
          'replyId': ?replyId,
          'fromNotification': true,
          'fromPush': true,
        },
        parameters: {
          'topicId': topicId,
          'commentId': ?commentId,
          'replyId': ?replyId,
        },
      );
    }

    // 5. Channel Navigation
    if (channelId != null && channelId.isNotEmpty) {
      return NotificationNavigationTarget(
        route: '/channel/$channelId',
      );
    }

    // 6. Direct Action URL (Internal or External)
    if (actionUrl != null && actionUrl.isNotEmpty) {
      if (actionUrl.startsWith('/')) {
        return NotificationNavigationTarget(
          route: actionUrl,
        );
      } else if (actionUrl.startsWith('http://') ||
          actionUrl.startsWith('https://')) {
        return NotificationNavigationTarget(
          route: actionUrl,
          isExternalUrl: true,
        );
      }
    }

    // 7. Universal Fallback to In-App Notification Center
    return const NotificationNavigationTarget(
      route: '/notifications',
    );
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

      if (target.isExternalUrl) {
        final uri = Uri.tryParse(target.route);
        if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
          unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
        }
        return;
      }

      // Check if targetApp matches current AppFlavor.active
      final currentFlavor = AppFlavor.active;
      final isCrossFlavor = (target.targetApp != currentFlavor);

      if (isCrossFlavor) {
        CrossAppLauncher.launchFlavor(
          target.targetApp,
          route: target.route,
          arguments: target.arguments,
          parameters: target.parameters,
        );
        return;
      }

      // In-app navigation for current flavor
      safeNavigate('nav_${target.route}', () {
        var effectiveRoute = target.route;
        var effectiveParams = target.parameters != null
            ? Map<String, String>.from(target.parameters!)
            : null;

        if (effectiveRoute.contains('?')) {
          final uri = Uri.parse(effectiveRoute);
          effectiveRoute = uri.path;
          effectiveParams ??= {};
          effectiveParams.addAll(uri.queryParameters);
        }

        if (effectiveRoute.startsWith('/watch')) {
          if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer') ||
              Get.isRegistered<MiniplayerController>()) {
            MiniplayerController.to.dismiss();
          }
          final videoId = target.arguments?['videoId'] as String?;
          if (videoId != null) {
            final player = TowerPlayerController.getForTagOrActive(videoId);
            if (player != null && !player.isPlaying.value) {
              player.videoPlayerController.play();
            }
          }
          if (Get.currentRoute.startsWith('/watch')) {
            unawaited(
              Get.offNamed(
                effectiveRoute,
                arguments: target.arguments,
                parameters: effectiveParams,
              ),
            );
            return;
          }
        } else if (target.targetApp == AppFlavor.studio) {
          if (AppFlavor.isStudio) {
            final tabIndex = target.arguments?['tab'] as int?;
            if (Get.isRegistered<DashboardController>()) {
              final ctrl = Get.find<DashboardController>();
              if (tabIndex != null) {
                ctrl.selectedIndex.value = tabIndex;
              }
              final videoId = target.arguments?['videoId'] as String?;
              if (videoId != null && videoId.isNotEmpty) {
                ctrl.targetVideoId.value = videoId;
                TruthVerificationDashboardPage.targetVideoId.value = videoId;
              }
              ctrl.applyRouteTargetIfPresent();
            }
            RouteStackObserver.navigateToStudio(
              arguments: target.arguments,
              parameters: effectiveParams,
            );
            return;
          }
        } else if (target.targetApp == AppFlavor.admin) {
          final tab = target.arguments?['tab'] as String?;
          if (Get.isRegistered<AdminController>()) {
            final ctrl = Get.find<AdminController>();
            ctrl.applyRouteTargetIfPresent(tab, target.arguments);
          }
        } else if (target.targetApp == AppFlavor.advertiser) {
          final tabIndex = target.arguments?['tab'] as int?;
          final campId = target.arguments?['campaignId'] as String?;
          if (Get.isRegistered<AdvertiserPortalController>()) {
            final ctrl = Get.find<AdvertiserPortalController>();
            ctrl.applyRouteTargetIfPresent(tabIndex, campId);
          }
        }

        unawaited(
          Get.toNamed(
            effectiveRoute,
            arguments: target.arguments,
            parameters: effectiveParams,
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
