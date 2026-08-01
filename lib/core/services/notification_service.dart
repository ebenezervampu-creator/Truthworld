import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
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
        payload['type'] as String? ?? payload['notificationType'] as String?;
    final videoId = payload['videoId'] as String? ?? payload['id'] as String?;

    if (type == 'perspective_flip' && videoId != null && videoId.isNotEmpty) {
      handlePerspectiveFlipNotification(
        videoId: videoId,
        commentId: payload['commentId'] as String?,
        replyId: payload['replyId'] as String?,
      );
    }
  }
}
