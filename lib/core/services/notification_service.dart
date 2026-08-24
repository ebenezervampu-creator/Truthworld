import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/utils/studio_launcher.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service managing notification actions and deep-linking, including perspective flip notifications.
class NotificationService extends GetxService {
  static NotificationService get to {
    if (Get.isRegistered<NotificationService>()) {
      return Get.find<NotificationService>();
    }
    return Get.put(NotificationService());
  }

  /// Handle perspective_flip notification routing.
  /// Sets video flip state in FlipCoinService to true, tracks the interaction,
  /// and navigates to the target video with isFlipped: true.
  void handlePerspectiveFlipNotification({
    required String videoId,
    Video? video,
    String? commentId,
    String? replyId,
  }) {
    if (videoId.isEmpty) return;

    debugPrint(
      '[NotificationService] Handling perspective_flip for videoId: $videoId',
    );

    if (Get.isRegistered<FlipCoinService>()) {
      FlipCoinService.to.setVideoFlipped(videoId, true);
      FlipCoinService.to.trackFlipCoinInteraction('notification');
    }

    final arguments = <String, dynamic>{
      'videoId': videoId,
      'isFlipped': true,
      'video': ?video,
      'commentId': ?commentId,
      'replyId': ?replyId,
    };

    unawaited(
      Get.toNamed(
        '/watch?v=$videoId',
        arguments: arguments,
        parameters: {
          'v': videoId,
          'isFlipped': 'true',
        },
      ),
    );
  }

  /// Handle generic notification payload map
  void handleNotificationPayload(Map<String, dynamic> payload) {
    final type =
        (payload['type'] as String? ?? payload['notificationType'] as String?)
            ?.toLowerCase();
    final videoId =
        payload['videoId'] as String? ?? payload['targetVideoId'] as String?;
    final title = (payload['title'] as String? ?? '').toLowerCase();
    final message = (payload['message'] as String? ?? '').toLowerCase();
    final actionUrl = payload['actionUrl'] as String?;

    // 1. Perspective Flip
    if (type == 'perspective_flip' && videoId != null && videoId.isNotEmpty) {
      handlePerspectiveFlipNotification(
        videoId: videoId,
        commentId: payload['commentId'] as String?,
        replyId: payload['replyId'] as String?,
      );
      return;
    }

    // 2. Subscriber / Creator Studio Notifications
    final isSubscriber = type == 'new_follower' ||
        type == 'subscriber' ||
        type == 'new_subscriber' ||
        type == 'subscription' ||
        type == 'subscribers_milestone' ||
        (type != null && type.contains('subscriber')) ||
        (type != null && type.contains('follower')) ||
        title.contains('subscriber') ||
        message.contains('subscribed') ||
        (actionUrl != null && actionUrl.toLowerCase().contains('studio'));

    if (isSubscriber) {
      StudioLauncher.openStudio();
      return;
    }

    // 3. Video deep-link
    if (videoId != null && videoId.isNotEmpty) {
      unawaited(
        Get.toNamed(
          '/watch?v=$videoId',
          arguments: {
            'videoId': videoId,
            'commentId': payload['commentId'],
            'replyId': payload['replyId'],
          },
        ),
      );
      return;
    }

    // 4. Action URL
    if (actionUrl != null && actionUrl.isNotEmpty) {
      try {
        if (actionUrl.startsWith('/')) {
          Get.toNamed(actionUrl);
          return;
        } else if (actionUrl.startsWith('http://') ||
            actionUrl.startsWith('https://')) {
          launchUrl(Uri.parse(actionUrl), mode: LaunchMode.externalApplication);
          return;
        }
      } catch (e) {
        debugPrint('Error navigating to actionUrl $actionUrl: $e');
      }
    }
  }
}
