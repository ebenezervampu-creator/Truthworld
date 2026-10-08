import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/features/notifications/presentation/views/notifications/widgets/notification_navigation_handler.dart';
import 'package:truthworld/features/video/data/models/video.dart';

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

    NotificationNavigationHandler.safeNavigate('flip_$videoId', () {
      unawaited(
        Get.toNamed(
          '/watch?v=$videoId',
          arguments: arguments,
          parameters: {
            'v': videoId,
            'isFlipped': 'true',
            'commentId': ?commentId,
            'replyId': ?replyId,
          },
        ),
      );
    });
  }

  /// Handle generic notification payload map using unified router
  void handleNotificationPayload(Map<String, dynamic> payload) {
    try {
      NotificationNavigationHandler.navigateFromPayload(payload);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'NotificationService.handleNotificationPayload',
      );
    }
  }
}
