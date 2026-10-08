import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/data/models/channel.dart';

/// Abstract remote data source contract for Channel Firestore operations.
abstract class ChannelRemoteDataSource {
  Future<Channel> getChannelById(String id);
  Future<Channel> getChannelByHandle(String handle);
  Future<List<Channel>> getSubscriptions(String userId, {int limit = 20, dynamic startAfter});
  Future<void> toggleSubscription(String channelId, String userId);
  Future<Channel> createChannel({
    required String name,
    required String handle,
    required String description,
    required String ownerId,
  });
}

/// Production implementation of [ChannelRemoteDataSource] powered by Cloud Firestore.
class FirestoreChannelRemoteDataSource implements ChannelRemoteDataSource {
  final FirebaseFirestore _firestore;

  FirestoreChannelRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Channel> getChannelById(String id) async {
    final doc = await _firestore
        .collection(FirestoreCollections.channels)
        .doc(id)
        .get();
    if (!doc.exists) {
      throw NotFoundException(message: 'Channel not found: $id');
    }
    return Channel.fromDocumentSnapshot(doc);
  }

  @override
  Future<Channel> getChannelByHandle(String handle) async {
    final handleLower = handle.toLowerCase();
    final snapshot = await _firestore
        .collection(FirestoreCollections.channels)
        .where('handleLowercase', isEqualTo: handleLower)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw NotFoundException(message: 'Channel not found for handle: $handle');
    }

    return Channel.fromDocumentSnapshot(snapshot.docs.first);
  }

  @override
  Future<List<Channel>> getSubscriptions(
    String userId, {
    int limit = 20,
    dynamic startAfter,
  }) async {
    var query = _firestore
        .collection(FirestoreCollections.subscriptions)
        .where('userId', isEqualTo: userId)
        .orderBy('subscribedAt', descending: true)
        .limit(limit);

    if (startAfter is DocumentSnapshot) {
      query = query.startAfterDocument(startAfter);
    }

    final subSnapshot = await query.get();
    if (subSnapshot.docs.isEmpty) return [];

    final channelIds = subSnapshot.docs
        .map((doc) => doc.data()['channelId'] as String?)
        .whereType<String>()
        .toList();

    if (channelIds.isEmpty) return [];

    final channelDocs = await Future.wait(
      channelIds.map((id) => _firestore.collection(FirestoreCollections.channels).doc(id).get()),
    );

    return channelDocs
        .where((doc) => doc.exists)
        .map(Channel.fromDocumentSnapshot)
        .toList();
  }

  @override
  Future<void> toggleSubscription(String channelId, String userId) async {
    final subRef = _firestore
        .collection(FirestoreCollections.subscriptions)
        .doc('${userId}_$channelId');
    final channelRef = _firestore
        .collection(FirestoreCollections.channels)
        .doc(channelId);

    await _firestore.runTransaction<void>((tx) async {
      final subSnap = await tx.get(subRef);
      if (subSnap.exists) {
        tx.delete(subRef);
        tx.update(channelRef, {'subscriberCount': FieldValue.increment(-1)});
      } else {
        tx.set(subRef, {
          'userId': userId,
          'channelId': channelId,
          'subscribedAt': FieldValue.serverTimestamp(),
        });
        tx.update(channelRef, {'subscriberCount': FieldValue.increment(1)});
      }
    });
  }

  @override
  Future<Channel> createChannel({
    required String name,
    required String handle,
    required String description,
    required String ownerId,
  }) async {
    final docRef = _firestore.collection(FirestoreCollections.channels).doc();
    final now = FieldValue.serverTimestamp();
    final data = {
      'id': docRef.id,
      'name': name,
      'nameLowercase': name.toLowerCase(),
      'handle': handle,
      'handleLowercase': handle.toLowerCase(),
      'description': description,
      'ownerId': ownerId,
      'avatarUrl': '',
      'bannerUrl': '',
      'subscriberCount': 0,
      'videoCount': 0,
      'isVerified': false,
      'status': 'active',
      'category': 'other',
      'categories': [],
      'visibility': 'Public',
      'createdAt': now,
      'updatedAt': now,
    };

    await docRef.set(data);
    final doc = await docRef.get();
    return Channel.fromDocumentSnapshot(doc);
  }
}
