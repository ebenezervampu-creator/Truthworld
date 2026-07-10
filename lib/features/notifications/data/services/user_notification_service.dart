import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/core/services/logger_service.dart';

class UserNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionPath = 'user_notifications';

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  /// Stream live real-time notifications for the given user
  Stream<List<UserNotification>> getNotificationsStream(String userId,
      {int limit = 50}) {
    if (userId.isEmpty || userId == 'guest_user') {
      return Stream.value([]);
    }

    return _firestore
        .collection(_collectionPath)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserNotification.fromDocumentSnapshot(doc))
            .toList());
  }

  /// Manually trigger fetch via Callable Cloud Function (fallback/sync support)
  Future<List<UserNotification>> fetchNotificationsViaCallable(
      {int limit = 50}) async {
    try {
      final callable = _functions.httpsCallable('getNotifications');
      final result = await callable.call({'limit': limit});
      final data = result.data as Map<String, dynamic>? ?? {};
      final list = data['notifications'] as List<dynamic>? ?? [];

      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return UserNotification.fromJson(map['id'] as String? ?? '', map);
      }).toList();
    } catch (e) {
      logger.error('Failed to fetch notifications via callable: $e',
          tag: 'NOTIFICATIONS');
      return [];
    }
  }

  /// Mark notification as read securely via backend Callable Cloud Function
  Future<bool> markAsRead(String notificationId) async {
    try {
      final callable = _functions.httpsCallable('markNotificationRead');
      await callable.call({'notificationId': notificationId});
      return true;
    } catch (e) {
      logger.error('Failed to mark notification read: $e', tag: 'NOTIFICATIONS');
      // For immediate client resilience, update the document directly as fallback
      try {
        await _firestore
            .collection(_collectionPath)
            .doc(notificationId)
            .update({'read': true});
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Mark all unread notifications as read directly in batch for UI convenience
  Future<void> markAllAsReadBatch(String userId, List<String> unreadIds) async {
    if (unreadIds.isEmpty) return;
    try {
      final batch = _firestore.batch();
      for (final id in unreadIds) {
        final ref = _firestore.collection(_collectionPath).doc(id);
        batch.update(ref, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      logger.error('Failed batch mark all read: $e', tag: 'NOTIFICATIONS');
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
  }) async {
    if (userId.isEmpty || userId == 'guest_user') return;
    try {
      final docRef = _firestore.collection(_collectionPath).doc();
      final notification = UserNotification(
        id: docRef.id,
        userId: userId,
        type: type,
        severity: severity,
        title: title,
        message: message,
        actionUrl: actionUrl,
        metadata: metadata,
        read: false,
        createdAt: DateTime.now(),
      );
      await docRef.set(notification.toJson());
    } catch (e) {
      logger.error('Failed to create notification: $e', tag: 'NOTIFICATIONS');
    }
  }
}




