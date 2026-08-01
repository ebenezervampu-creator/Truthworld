import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/video_entity.dart';
import 'package:truthworld/domain/repositories/video_repository.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class VideoRepositoryImpl extends BaseRepository implements VideoRepository {
  final FirebaseFirestore _firestore;

  // Cursors for pagination (naive implementation for stateless interface)
  DocumentSnapshot? _lastHomeDoc;
  DocumentSnapshot? _lastSearchDoc;
  DocumentSnapshot? _lastChannelDoc;

  VideoRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  VideoEntity _mapToEntity(Video model) {
    return VideoEntity(
      id: model.id,
      title: model.title,
      description: model.description,
      ownerId: model.ownerId,
      channelId: model.channelId,
      channelName: model.channelName,
      channelAvatarUrl: model.channelAvatarUrl,
      thumbnailUrl: model.thumbnailUrl,
      originalUrl: model.originalUrl,
      hlsUrl: model.hlsUrl,
      dashUrl: model.dashUrl,
      viewCount: model.viewCount,
      likeCount: model.likeCount,
      dislikeCount: model.dislikeCount,
      commentCount: model.commentCount,
      shareCount: model.shareCount,
      duration: model.durationValue,
      createdAt: model.createdAt.toDate(),
      updatedAt: model.updatedAt.toDate(),
      status: model.status.name,
      visibility: model.visibility,
      category: model.category,
      tags: model.tags,
      topics: model.topics,
      language: model.language,
      isShort: model.isShort,
      isKidFriendly: model.isKidFriendly,
      enableComments: model.enableComments,
      isMonetized: model.isMonetized,
      trustScore: model.trustScore,
    );
  }

  @override
  Future<Result<List<VideoEntity>>> getHomeFeed({
    int page = 1,
    int limit = 10,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastHomeDoc = null;

      var query = _firestore
          .collection(FirestoreCollections.videos)
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (page > 1 && _lastHomeDoc != null) {
        query = query.startAfterDocument(_lastHomeDoc!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastHomeDoc = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final video = Video.fromDocumentSnapshot(doc);
        return _mapToEntity(video);
      }).toList();
    });
  }

  @override
  Future<Result<VideoEntity>> getVideoById(String id) async {
    return safeFetch(() async {
      final doc = await _firestore
          .collection(FirestoreCollections.videos)
          .doc(id)
          .get();
      if (!doc.exists) throw Exception('Video not found');

      final video = Video.fromDocumentSnapshot(doc);
      return _mapToEntity(video);
    });
  }

  @override
  Future<Result<List<VideoEntity>>> searchVideos(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastSearchDoc = null;

      final queryLower = query.toLowerCase();
      var q = _firestore
          .collection(FirestoreCollections.videos)
          .where('titleLowercase', isGreaterThanOrEqualTo: queryLower)
          .where('titleLowercase', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .where('visibility', isEqualTo: 'public')
          .limit(limit);

      if (page > 1 && _lastSearchDoc != null) {
        q = q.startAfterDocument(_lastSearchDoc!);
      }

      final snapshot = await q.get();
      if (snapshot.docs.isNotEmpty) {
        _lastSearchDoc = snapshot.docs.last;
      }

      return snapshot.docs
          .map((doc) => _mapToEntity(Video.fromDocumentSnapshot(doc)))
          .toList();
    });
  }

  @override
  Future<Result<List<VideoEntity>>> getVideosByChannel(
    String channelId, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastChannelDoc = null;

      var q = _firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: channelId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (page > 1 && _lastChannelDoc != null) {
        q = q.startAfterDocument(_lastChannelDoc!);
      }

      final snapshot = await q.get();
      if (snapshot.docs.isNotEmpty) {
        _lastChannelDoc = snapshot.docs.last;
      }

      return snapshot.docs
          .map((doc) => _mapToEntity(Video.fromDocumentSnapshot(doc)))
          .toList();
    });
  }

  @override
  Future<Result<List<VideoEntity>>> getTrendingVideos({int limit = 20}) async {
    return safeFetch(() async {
      final snapshot = await _firestore
          .collection(FirestoreCollections.videos)
          .where('visibility', isEqualTo: 'public')
          .orderBy('viewCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => _mapToEntity(Video.fromDocumentSnapshot(doc)))
          .toList();
    });
  }

  @override
  Future<Result<void>> toggleLike(String videoId, String userId) async {
    return safeTransaction((tx) async {
      final likeRef = _firestore
          .collection(FirestoreCollections.videoLikes(videoId))
          .doc(userId);
      final videoRef = _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId);

      final likeDoc = await tx.get(likeRef);
      if (likeDoc.exists) {
        tx.delete(likeRef);
        tx.update(videoRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        tx.update(videoRef, {'likeCount': FieldValue.increment(1)});
      }
    });
  }

  @override
  Future<Result<void>> toggleDislike(String videoId, String userId) async {
    return safeTransaction((tx) async {
      final dislikeRef = _firestore
          .collection(FirestoreCollections.videoDislikes(videoId))
          .doc(userId);
      final videoRef = _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId);

      final dislikeDoc = await tx.get(dislikeRef);
      if (dislikeDoc.exists) {
        tx.delete(dislikeRef);
        tx.update(videoRef, {'dislikeCount': FieldValue.increment(-1)});
      } else {
        tx.set(dislikeRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        tx.update(videoRef, {'dislikeCount': FieldValue.increment(1)});
      }
    });
  }

  @override
  Future<Result<void>> deleteVideo(String videoId) async {
    return safeDelete(
      _firestore.collection(FirestoreCollections.videos).doc(videoId),
    );
  }

  @override
  Future<Result<void>> incrementViewCount(String videoId) async {
    return safeUpdate(
      _firestore.collection(FirestoreCollections.videos).doc(videoId),
      {'viewCount': FieldValue.increment(1)},
    );
  }
}
