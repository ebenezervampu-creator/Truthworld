import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/data/models/notification_model.dart';
import 'package:truthworld/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl extends BaseRepository
    implements NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<List<NotificationModel>>> getNotifications(
    String userId, {
    int limit = 20,
    dynamic cursor,
  }) async {
    return safeFetch(() async {
      var q = _firestore
          .collection(FirestoreCollections.userNotifications(userId))
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (cursor != null && cursor is DocumentSnapshot) {
        q = q.startAfterDocument(cursor);
      }

      final snapshot = await q.get();
      return snapshot.docs
          .map(NotificationModel.fromDocumentSnapshot)
          .toList();
    });
  }

  @override
  Future<Result<void>> markAsRead(String userId, String id) async {
    return safeUpdate(
      _firestore
          .collection(FirestoreCollections.userNotifications(userId))
          .doc(id),
      {'isRead': true},
    );
  }

  @override
  Future<Result<void>> markAllAsRead(String userId) async {
    return safeFetch(() async {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection(FirestoreCollections.userNotifications(userId))
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    });
  }

  @override
  Future<Result<void>> deleteNotification(String userId, String id) async {
    return safeDelete(
      _firestore
          .collection(FirestoreCollections.userNotifications(userId))
          .doc(id),
    );
  }
}
