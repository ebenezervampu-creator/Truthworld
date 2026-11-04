import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';

class UserNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionPath = 'user_notifications';

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  /// Stream live real-time notifications for the given user, combining both
  /// user_notifications and users/{userId}/notifications_active for 100% backend coverage.
  Stream<List<UserNotification>> getNotificationsStream(
    String userId, {
    int limit = 100,
    String? channelId,
  }) {
    if (userId.isEmpty || userId == 'guest_user') {
      return Stream.value([]);
    }

    final streamController = StreamController<List<UserNotification>>.broadcast();
    final legacyMap = <String, UserNotification>{};
    final activeMap = <String, UserNotification>{};
    final channelMap = <String, UserNotification>{};

    void emitMerged() {
      if (streamController.isClosed) return;
      final merged = <String, UserNotification>{};
      merged.addAll(legacyMap);
      merged.addAll(activeMap);
      merged.addAll(channelMap);

      final list = merged.values.toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      streamController.add(list.take(limit).toList());
    }

    StreamSubscription? subLegacy;
    StreamSubscription? subActive;
    StreamSubscription? subChannel;

    streamController.onListen = () {
      // 1. user_notifications query by userId
      subLegacy = _firestore
          .collection(_collectionPath)
          .where('userId', isEqualTo: userId)
          .limit(limit)
          .snapshots()
          .listen(
            (snapshot) {
              legacyMap.clear();
              for (final doc in snapshot.docs) {
                legacyMap[doc.id] = UserNotification.fromDocumentSnapshot(doc);
              }
              emitMerged();
            },
            onError: (e) {
              logger.error('user_notifications stream error: $e', tag: 'NOTIFICATIONS');
            },
          );

      // 2. users/{userId}/notifications_active query
      subActive = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('notifications_active')
          .limit(limit)
          .snapshots()
          .listen(
            (snapshot) {
              activeMap.clear();
              for (final doc in snapshot.docs) {
                activeMap[doc.id] = UserNotification.fromDocumentSnapshot(doc);
              }
              emitMerged();
            },
            onError: (e) {
              logger.error('notifications_active stream error: $e', tag: 'NOTIFICATIONS');
            },
          );

      // 3. channelId query in user_notifications
      if (channelId != null && channelId.isNotEmpty) {
        subChannel = _firestore
            .collection(_collectionPath)
            .where('channelId', isEqualTo: channelId)
            .limit(limit)
            .snapshots()
            .listen(
              (snapshot) {
                channelMap.clear();
                for (final doc in snapshot.docs) {
                  channelMap[doc.id] = UserNotification.fromDocumentSnapshot(doc);
                }
                emitMerged();
              },
              onError: (e) {
                logger.error('channel user_notifications stream error: $e', tag: 'NOTIFICATIONS');
              },
            );
      }
    };

    streamController.onCancel = () {
      subLegacy?.cancel();
      subActive?.cancel();
      subChannel?.cancel();
    };

    return streamController.stream;
  }

  /// Manually trigger fetch via Callable Cloud Function (fallback/sync support)
  Future<List<UserNotification>> fetchNotificationsViaCallable({
    int limit = 50,
  }) async {
    try {
      final callable = _functions.httpsCallable('getNotifications');
      final result = await callable.call({
        'limit': limit,
        'targetApp': AppFlavor.isStudio ? 'studio' : 'app',
      });
      final data = result.data as Map<String, dynamic>? ?? {};
      final list = data['notifications'] as List<dynamic>? ?? [];

      return list
          .map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            return UserNotification.fromJson(map['id'] as String? ?? '', map);
          })
          .toList();
    } catch (e) {
      logger.error(
        'Failed to fetch notifications via callable: $e',
        tag: 'NOTIFICATIONS',
      );
      return [];
    }
  }

  /// Mark notification as read securely via backend Callable Cloud Function and Firestore
  Future<bool> markAsRead(String notificationId, {String? userId}) async {
    try {
      final callable = _functions.httpsCallable('markNotificationRead');
      await callable.call({'notificationId': notificationId});
    } catch (e) {
      logger.error(
        'Failed to mark notification read via callable: $e',
        tag: 'NOTIFICATIONS',
      );
    }

    // Direct Firestore updates across collections for immediate UI responsiveness
    try {
      await _firestore.collection(_collectionPath).doc(notificationId).update(
        {'read': true, 'status': 'read'},
      );
    } catch (_) {}

    if (userId != null && userId.isNotEmpty && userId != 'guest_user') {
      try {
        await _firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection('notifications_active')
            .doc(notificationId)
            .update({'read': true, 'status': 'read'});
      } catch (_) {}
    }

    return true;
  }

  /// Mark all unread notifications as read directly in batch for UI convenience
  Future<void> markAllAsReadBatch(String userId, List<String> unreadIds) async {
    if (unreadIds.isEmpty) return;
    try {
      final batch = _firestore.batch();
      for (final id in unreadIds) {
        final ref = _firestore.collection(_collectionPath).doc(id);
        batch.update(ref, {'read': true, 'status': 'read'});
        if (userId.isNotEmpty && userId != 'guest_user') {
          final activeRef = _firestore
              .collection(FirestoreCollections.users)
              .doc(userId)
              .collection('notifications_active')
              .doc(id);
          batch.update(activeRef, {'read': true, 'status': 'read'});
        }
      }
      await batch.commit();
    } catch (e) {
      logger.error('Failed batch mark all read: $e', tag: 'NOTIFICATIONS');
    }
  }

  /// Delete notification across user_notifications and notifications_active
  Future<void> deleteNotification(String notificationId, {String? userId}) async {
    try {
      await _firestore.collection(_collectionPath).doc(notificationId).delete();
    } catch (_) {}

    if (userId != null && userId.isNotEmpty && userId != 'guest_user') {
      try {
        await _firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection('notifications_active')
            .doc(notificationId)
            .delete();
      } catch (_) {}
    }
  }

  /// Create a new notification alert in Firestore for the target user
  Future<void> createNotification({
    required String userId,
    required String type,
    required NotificationSeverity severity,
    required String title,
    required String message,
    String? actionUrl,
    Map<String, dynamic>? metadata,
    String? targetApp,
    String? category,
  }) async {
    if (userId.isEmpty || userId == 'guest_user') return;
    try {
      final docRef = _firestore.collection(_collectionPath).doc();
      final effectiveAction = (actionUrl ?? '').toLowerCase();
      final tLower = type.toLowerCase();
      final isStudio = (targetApp?.toLowerCase().trim() == 'studio') ||
          effectiveAction.contains('studio') ||
          tLower.contains('studio') ||
          tLower.contains('fact_check') ||
          tLower.contains('verification') ||
          tLower.contains('copyright') ||
          tLower.contains('monetization');
      final resolvedTarget = targetApp ?? (isStudio ? 'studio' : 'app');

      final notification = UserNotification(
        id: docRef.id,
        userId: userId,
        type: type,
        severity: severity,
        title: title,
        message: message,
        actionUrl: actionUrl,
        category: category ?? (resolvedTarget == 'studio' ? 'verification' : 'system'),
        metadata: metadata,
        read: false,
        createdAt: DateTime.now(),
        targetApp: resolvedTarget,
      );
      await docRef.set(notification.toJson());
    } catch (e) {
      logger.error('Failed to create notification: $e', tag: 'NOTIFICATIONS');
    }
  }
}
