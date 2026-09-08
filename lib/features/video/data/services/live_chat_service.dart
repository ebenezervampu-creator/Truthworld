import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/firebase_rtdb_helper.dart';
import 'package:truthworld/features/video/data/models/live_chat_message.dart';

/// Real-time Live Chat Service backed by Firebase RTDB.
///
/// Features:
/// - Low latency WebSocket streaming (<30ms)
/// - Sliding window bounded listeners (last 100 messages)
/// - Local & server-side rate limiting (1 msg / 1.5s)
/// - Content validation / profanity screening
/// - Authoritative Superchats & Moderation actions
class LiveChatService extends GetxService with ContentValidationMixin {
  static const String _tag = 'LiveChatService';

  final FirebaseDatabase _database = getSafeFirebaseDatabase();
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  // Local cooldown tracking (UX throttle)
  DateTime? _lastMessageSentTime;
  static const Duration _rateLimitDuration = Duration(milliseconds: 1500);

  bool get canSendMessage {
    if (_lastMessageSentTime == null) return true;
    return DateTime.now().difference(_lastMessageSentTime!) >= _rateLimitDuration;
  }

  Duration get remainingCooldown {
    if (_lastMessageSentTime == null) return Duration.zero;
    final diff = DateTime.now().difference(_lastMessageSentTime!);
    if (diff >= _rateLimitDuration) return Duration.zero;
    return _rateLimitDuration - diff;
  }

  /// Listen to live chat messages for a specific video/stream (sliding window of 100 messages)
  Stream<List<LiveChatMessage>> streamMessages(String videoId, {int limit = 100}) {
    if (videoId.isEmpty) return Stream.value(<LiveChatMessage>[]);

    final query = _database
        .ref('liveChat/$videoId/messages')
        .orderByChild('timestamp')
        .limitToLast(limit);

    return query.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return <LiveChatMessage>[];

      final messages = <LiveChatMessage>[];
      data.forEach((key, raw) {
        if (raw is Map) {
          messages.add(LiveChatMessage.fromMap(key.toString(), raw));
        }
      });

      // Sort chronologically ascending
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  /// Listen to pinned Superchat / Announcement at the top of the chat
  Stream<LiveChatMessage?> streamPinnedMessage(String videoId) {
    if (videoId.isEmpty) return Stream.value(null);

    return _database.ref('liveChat/$videoId/pinned').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return null;

      final expiresAt = (data['expiresAt'] as num?)?.toInt();
      if (expiresAt != null && expiresAt < DateTime.now().millisecondsSinceEpoch) {
        return null; // Expired
      }

      return LiveChatMessage.fromMap('pinned', data);
    });
  }

  /// Send a standard live chat message
  Future<bool> sendMessage({
    required String videoId,
    required String text,
    required String userName,
    required String userProfilePicUrl,
    String? channelId,
    String? channelName,
    bool isCreator = false,
  }) async {
    if (!AuthService.to.isAuthenticated.value) {
      logger.warning('Must be logged in to send chat message', tag: _tag);
      return false;
    }
    final uid = AuthService.to.uid;
    if (uid.isEmpty) return false;

    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 500) return false;

    // 1. Client-side UX rate limit check
    if (!canSendMessage) {
      logger.info('Rate limited locally. Please wait.', tag: _tag);
      return false;
    }

    // 2. Client-side content validation
    final validation = validateContentSync(trimmed, fieldName: 'Message');
    if (!validation.isValid) {
      logger.warning('Message flagged by content filter: ${validation.message}', tag: _tag);
      throw Exception(validation.message);
    }

    try {
      // 3. Update server-side rate limit timestamp
      await _database.ref('liveChat/$videoId/userLimits/$uid').set({
        'lastMessageAt': ServerValue.timestamp,
      });

      // 4. Push message to RTDB
      final messageRef = _database.ref('liveChat/$videoId/messages').push();
      final effectiveName = userName.isNotEmpty
          ? userName
          : (AuthService.to.activeDisplayName.isNotEmpty
              ? AuthService.to.activeDisplayName
              : 'Viewer');
      final effectivePic = userProfilePicUrl.isNotEmpty
          ? userProfilePicUrl
          : AuthService.to.activePhotoUrl;
      await messageRef.set({
        'videoId': videoId,
        'userId': uid,
        'userName': effectiveName,
        'userProfilePicUrl': effectivePic,
        // ignore: use_null_aware_elements
        if (channelId != null) 'channelId': channelId,
        // ignore: use_null_aware_elements
        if (channelName != null) 'channelName': channelName,
        'text': trimmed,
        if (isCreator) 'isCreator': true,
        'timestamp': ServerValue.timestamp,
      });

      _lastMessageSentTime = DateTime.now();
      return true;
    } catch (e) {
      logger.error('Failed to send live chat message: $e', tag: _tag);
      rethrow;
    }
  }

  /// Authoritative Moderation Action (Timeout, Ban, Delete Message)
  Future<void> sendModerationAction({
    required String videoId,
    required String targetUserId,
    required String action, // 'timeout', 'ban', 'unban'
    int durationSeconds = 300,
    String? deleteMessageId,
    String? reason,
  }) async {
    try {
      final callable = _functions.httpsCallable('moderateLiveChatUser');
      await callable.call({
        'videoId': videoId,
        'targetUserId': targetUserId,
        'action': action,
        'durationSeconds': durationSeconds,
        'deleteMessageId': deleteMessageId,
        'reason': reason ?? 'Violated chat rules',
      });
      logger.info('Moderation action $action applied to $targetUserId', tag: _tag);
    } catch (e) {
      logger.error('Moderation action failed: $e', tag: _tag);
      rethrow;
    }
  }

  /// Send Superchat (Processes payment authoritatively through Cloud Function)
  Future<bool> sendSuperchat({
    required String videoId,
    required String channelId,
    required String text,
    required double amount,
    String currency = 'USD',
  }) async {
    try {
      final callable = _functions.httpsCallable('processSuperchat');
      final result = await callable.call({
        'videoId': videoId,
        'channelId': channelId,
        'text': text,
        'amount': amount,
        'currency': currency,
      });
      return result.data['success'] == true;
    } catch (e) {
      logger.error('Superchat submission failed: $e', tag: _tag);
      rethrow;
    }
  }
}
