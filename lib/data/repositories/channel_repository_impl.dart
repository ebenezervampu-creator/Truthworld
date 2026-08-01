import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/channel_entity.dart';
import 'package:truthworld/domain/repositories/channel_repository.dart';
import 'package:truthworld/data/models/channel.dart';

class ChannelRepositoryImpl extends BaseRepository
    implements ChannelRepository {
  final FirebaseFirestore _firestore;

  DocumentSnapshot? _lastSubDoc;

  ChannelRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  ChannelEntity _mapToEntity(Channel model) {
    return ChannelEntity(
      id: model.id,
      name: model.name,
      handle: model.handle,
      ownerId: model.ownerId,
      createdAt: model.createdAt.toDate(),
      updatedAt: model.updatedAt.toDate(),
      description: model.description,
      avatarUrl: model.avatarUrl,
      bannerUrl: model.bannerUrl,
      subscriberCount: model.subscriberCount,
      videoCount: model.videoCount,
      totalViews: model.viewCount,
      isVerified: model.isVerified,
      status: model.status.name,
      category: model.category,
      categories: model.categories,
    );
  }

  @override
  Future<Result<ChannelEntity>> getChannelById(String id) async {
    return safeFetch(() async {
      final doc = await _firestore
          .collection(FirestoreCollections.channels)
          .doc(id)
          .get();
      if (!doc.exists) throw Exception('Channel not found');

      final channel = Channel.fromDocumentSnapshot(doc);
      return _mapToEntity(channel);
    });
  }

  @override
  Future<Result<ChannelEntity>> getChannelByHandle(String handle) async {
    return safeFetch(() async {
      final handleLower = handle.toLowerCase();
      final snapshot = await _firestore
          .collection(FirestoreCollections.channels)
          .where('handleLowercase', isEqualTo: handleLower)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) throw Exception('Channel not found');

      final channel = Channel.fromDocumentSnapshot(snapshot.docs.first);
      return _mapToEntity(channel);
    });
  }

  @override
  Future<Result<void>> toggleSubscription(
    String channelId,
    String userId,
  ) async {
    return safeTransaction((tx) async {
      final subRef = _firestore
          .collection(FirestoreCollections.channelSubscribers(channelId))
          .doc(userId);
      final userSubRef = _firestore
          .collection(FirestoreCollections.userSubscriptions(userId))
          .doc(channelId);
      final channelRef = _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId);

      final subDoc = await tx.get(subRef);
      if (subDoc.exists) {
        tx.delete(subRef);
        tx.delete(userSubRef);
        tx.update(channelRef, {'subscriberCount': FieldValue.increment(-1)});
      } else {
        tx.set(subRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        tx.set(userSubRef, {
          'channelId': channelId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        tx.update(channelRef, {'subscriberCount': FieldValue.increment(1)});
      }
    });
  }

  @override
  Future<Result<bool>> isSubscribed(String channelId, String userId) async {
    return safeFetch(() async {
      final doc = await _firestore
          .collection(FirestoreCollections.channelSubscribers(channelId))
          .doc(userId)
          .get();
      return doc.exists;
    });
  }

  @override
  Future<Result<List<ChannelEntity>>> getSubscriptions(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastSubDoc = null;

      var q = _firestore
          .collection(FirestoreCollections.userSubscriptions(userId))
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (page > 1 && _lastSubDoc != null) {
        q = q.startAfterDocument(_lastSubDoc!);
      }

      final snapshot = await q.get();
      if (snapshot.docs.isNotEmpty) {
        _lastSubDoc = snapshot.docs.last;
      }

      final channelIds = snapshot.docs
          .map((doc) => doc.data()['channelId'] as String)
          .toList();
      if (channelIds.isEmpty) return [];

      // Fetch actual channel docs
      final channelsSnapshot = await _firestore
          .collection(FirestoreCollections.channels)
          .where(FieldPath.documentId, whereIn: channelIds)
          .get();

      return channelsSnapshot.docs
          .map((doc) => _mapToEntity(Channel.fromDocumentSnapshot(doc)))
          .toList();
    });
  }

  @override
  Future<Result<ChannelEntity>> createChannel({
    required String name,
    required String handle,
    required String ownerId,
    String? description,
  }) async {
    return safeFetch(() async {
      final ref = _firestore.collection(FirestoreCollections.channels).doc();
      final now = FieldValue.serverTimestamp();

      final data = {
        'id': ref.id,
        'name': name,
        'nameLowercase': name.toLowerCase(),
        'handle': handle,
        'handleLowercase': handle.toLowerCase(),
        'description': description ?? '',
        'ownerId': ownerId,
        'createdAt': now,
        'updatedAt': now,
        'status': ChannelStatus.active.name,
      };

      await ref.set(data);

      // Fetch immediately to get parsed dates properly
      final doc = await ref.get();
      return _mapToEntity(Channel.fromDocumentSnapshot(doc));
    });
  }

  @override
  Future<Result<void>> updateChannel(
    String channelId,
    Map<String, dynamic> updates,
  ) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    return safeUpdate(
      _firestore.collection(FirestoreCollections.channels).doc(channelId),
      updates,
    );
  }
}
