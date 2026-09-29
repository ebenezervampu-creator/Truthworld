import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/subscription_repository.dart';

class SubscriptionRepositoryImpl extends BaseRepository implements SubscriptionRepository {
  final FirebaseFirestore _firestore;

  SubscriptionRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<List<Map<String, dynamic>>>> getSubscriptions(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeFetch(() async {
      final snapshot = await _firestore
          .collection(FirestoreCollections.userSubscriptions(userId))
          .orderBy('subscribedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {'channelId': doc.id, ...doc.data()}).toList();
    });
  }

  @override
  Future<Result<void>> subscribe(String userId, String channelId) async {
    return safeTransaction((tx) async {
      final subRef = _firestore
          .collection(FirestoreCollections.userSubscriptions(userId))
          .doc(channelId);
      final channelRef = _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId);

      tx.set(subRef, {
        'channelId': channelId,
        'notificationPreference': 'personalized',
        'notificationOption': 'personalized',
        'notificationsEnabled': true,
        'subscribedAt': FieldValue.serverTimestamp(),
      });

      tx.update(channelRef, {
        'subscriberCount': FieldValue.increment(1),
      });
    });
  }

  @override
  Future<Result<void>> unsubscribe(String userId, String channelId) async {
    return safeTransaction((tx) async {
      final subRef = _firestore
          .collection(FirestoreCollections.userSubscriptions(userId))
          .doc(channelId);
      final channelRef = _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId);

      tx.delete(subRef);
      tx.update(channelRef, {
        'subscriberCount': FieldValue.increment(-1),
      });
    });
  }

  @override
  Future<Result<bool>> isSubscribed(String userId, String channelId) async {
    return safeFetch(() async {
      final doc = await _firestore
          .collection(FirestoreCollections.userSubscriptions(userId))
          .doc(channelId)
          .get();
      return doc.exists;
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getSubscriptionFeed(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeFetch(() async {
      final subsSnapshot = await _firestore
          .collection(FirestoreCollections.userSubscriptions(userId))
          .get();

      if (subsSnapshot.docs.isEmpty) {
        return <Map<String, dynamic>>[];
      }

      final channelIds = subsSnapshot.docs.map((doc) => doc.id).toList();
      // Batch in groups of 10 for Firestore 'whereIn' limitation
      final chunkedChannelIds = channelIds.take(10).toList();

      final feedSnapshot = await _firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', whereIn: chunkedChannelIds)
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return feedSnapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  @override
  Future<Result<void>> updateNotificationPreference(
    String userId,
    String channelId, {
    required String preference,
  }) async {
    return safeUpdate(
      _firestore
          .collection(FirestoreCollections.userSubscriptions(userId))
          .doc(channelId),
      {'notificationPreference': preference, 'updatedAt': FieldValue.serverTimestamp()},
    );
  }
}
