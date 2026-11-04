import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/datasources/remote/channel_remote_datasource.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/domain/entities/channel_entity.dart';
import 'package:truthworld/domain/repositories/channel_repository.dart';

class ChannelRepositoryImpl extends BaseRepository
    implements ChannelRepository {
  final FirebaseFirestore? _customFirestore;
  final ChannelRemoteDataSource? _customRemoteDataSource;
  final AuthService? _authService;
  final void Function(Channel)? _onChannelCreated;

  DocumentSnapshot? _lastSubDoc;

  ChannelRepositoryImpl({
    FirebaseFirestore? firestore,
    ChannelRemoteDataSource? remoteDataSource,
    AuthService? authService,
    void Function(Channel)? onChannelCreated,
    super.isTestMode,
  })  : _customFirestore = firestore,
        _customRemoteDataSource = remoteDataSource,
        _authService = authService,
        _onChannelCreated = onChannelCreated;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  ChannelRemoteDataSource get _remoteDataSource =>
      _customRemoteDataSource ??
      FirestoreChannelRemoteDataSource(firestore: _customFirestore);

  ChannelEntity _mapToEntity(Channel model) {
    return model.toEntity();
  }

  @override
  Future<Result<ChannelEntity>> getChannelById(String id) async {
    return safeFetch(() async {
      final channel = await _remoteDataSource.getChannelById(id);
      return _mapToEntity(channel);
    });
  }

  @override
  Future<Result<ChannelEntity>> getChannelByHandle(String handle) async {
    return safeFetch(() async {
      final channel = await _remoteDataSource.getChannelByHandle(handle);
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
      final legacySubRef = _firestore
          .collection(FirestoreCollections.subscriptions)
          .doc('${channelId}_$userId');
      final channelRef = _firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId);

      final subDoc = await tx.get(subRef);
      if (subDoc.exists) {
        tx.delete(subRef);
        tx.delete(userSubRef);
        tx.delete(legacySubRef);
        tx.update(channelRef, {'subscriberCount': FieldValue.increment(-1)});
      } else {
        final now = FieldValue.serverTimestamp();
        final payload = {
          'userId': userId,
          'channelId': channelId,
          'timestamp': now,
          'subscribedAt': now,
          'notificationsEnabled': true,
          'notificationOption': 'personalized',
          'notificationPreference': 'personalized',
        };
        tx.set(subRef, payload);
        tx.set(userSubRef, payload);
        tx.set(legacySubRef, payload);
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
      // 0. Strict 1 Channel Per User Account check
      final existingQuery = await _firestore
          .collection(FirestoreCollections.channels)
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        final status = existingQuery.docs.first.data()['status'];
        if (status != 'deleted') {
          throw Exception(
            'Only one channel per Google account is allowed in Truthworld.',
          );
        }
      }

      final ref = _firestore.collection(FirestoreCollections.channels).doc();
      final now = FieldValue.serverTimestamp();

      final cleanHandle = handle.startsWith('@') ? handle.substring(1).trim() : handle.trim();
      final handleLower = cleanHandle.toLowerCase();

      final data = {
        'id': ref.id,
        'name': name.trim(),
        'nameLowercase': name.trim().toLowerCase(),
        'channelName': name.trim(),
        'channelNameLowercase': name.trim().toLowerCase(),
        'handle': cleanHandle,
        'handleLowercase': handleLower,
        'customUrl': cleanHandle,
        'customUrlLowercase': handleLower,
        'description': description?.trim() ?? '',
        'ownerId': ownerId,
        'userId': ownerId,
        'createdAt': now,
        'updatedAt': now,
        'status': ChannelStatus.active.name,
        'subscriberCount': 0,
        'videoCount': 0,
        'isVerified': false,
        'avatarUrl': '',
        'bannerUrl': '',
        'metrics': {
          'totalViews': 0,
          'totalWatchTimeMinutes': 0,
          'averageRetention': 0.0,
        },
      };

      await ref.set(data);

      // Claim handle in channel_handles collection
      try {
        await _firestore
            .collection('channel_handles')
            .doc(handleLower)
            .set({
              'channelId': ref.id,
              'ownerId': ownerId,
              'claimedAt': now,
            });
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'ChannelRepositoryImpl.createChannel.claimHandle',
        );
      }

      // Update user doc with hasChannel flag and channelId
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(ownerId)
          .set({
            'channelId': ref.id,
            'hasChannel': true,
            'channelsCount': 1,
            'updatedAt': now,
          }, SetOptions(merge: true));

      // Fetch immediately to get parsed dates properly
      final doc = await ref.get();
      final createdChannel = Channel.fromDocumentSnapshot(doc);

      // Update AuthService in-memory state if injected or notify callback
      if (_authService != null) {
        _authService.setUserChannel(createdChannel);
      } else if (_onChannelCreated != null) {
        _onChannelCreated(createdChannel);
      }

      return _mapToEntity(createdChannel);
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
