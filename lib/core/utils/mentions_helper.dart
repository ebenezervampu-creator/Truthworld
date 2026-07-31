import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/data/services/user_notification_service.dart';

class MentionsHelper {
  static final RegExp _mentionRegExp = RegExp('@([a-zA-Z0-9_-]+)');

  /// Extracts unique lowercase handles from text without the @ prefix.
  static List<String> extractHandles(String text) {
    if (text.isEmpty) return [];
    final matches = _mentionRegExp.allMatches(text);
    return matches.map((m) => m.group(1)!.toLowerCase()).toSet().toList();
  }

  /// Processes text for mentions, queries Firestore to find channel owners,
  /// and sends notifications to them.
  static Future<void> processAndNotifyMentions({
    required String text,
    required String videoId,
    required String videoTitle,
    required String videoThumbnailUrl,
    required String videoChannelId,
    String? commentId,
    String? replyId,
  }) async {
    final handles = extractHandles(text);
    if (handles.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? '';
    final rawName = AuthService.to.activeDisplayName.isNotEmpty
        ? AuthService.to.activeDisplayName
        : 'Someone';
    final currentUserName = rawName.startsWith('@')
        ? rawName.substring(1)
        : rawName;
    final currentUserAvatar = AuthService.to.activePhotoUrl;

    final notificationService = UserNotificationService();

    for (final handle in handles) {
      try {
        final querySnap = await FirebaseFirestore.instance
            .collection('channels')
            .where('handleLowercase', isEqualTo: handle)
            .limit(1)
            .get();

        if (querySnap.docs.isNotEmpty) {
          final channelDoc = querySnap.docs.first;
          final ownerId = channelDoc.data()['ownerId'] as String?;

          // Don't notify the user themselves
          if (ownerId != null &&
              ownerId.isNotEmpty &&
              ownerId != currentUserId) {
            var title = '';
            var message = '';

            if (commentId != null) {
              if (replyId != null) {
                title = 'Mentioned in a reply';
                message = '@$currentUserName mentioned you in a reply: "$text"';
              } else {
                title = 'Mentioned in a comment';
                message =
                    '@$currentUserName mentioned you in a comment: "$text"';
              }
            } else {
              title = 'Mentioned in a video';
              message =
                  '@$currentUserName mentioned you in the video: "$videoTitle"';
            }

            await notificationService.createNotification(
              userId: ownerId,
              type: 'mention',
              severity: NotificationSeverity.info,
              title: title,
              message: message,
              actionUrl: '/watch?v=$videoId',
              metadata: {
                'videoId': videoId,
                'commentId': commentId,
                'replyId': replyId,
                'thumbnailUrl': videoThumbnailUrl,
                'channelId': videoChannelId,
                'userAvatar': currentUserAvatar,
              },
            );
            debugPrint(
              '[MentionsHelper] Mentions notification sent successfully to ownerId: $ownerId',
            );
          }
        }
      } catch (e) {
        debugPrint('[MentionsHelper] Error notifying handle @$handle: $e');
      }
    }
  }
}
