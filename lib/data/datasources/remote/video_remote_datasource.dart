import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Abstract remote data source contract for Video data handling.
/// Isolates Firestore SDK queries from domain and repository aggregation logic.
abstract class VideoRemoteDataSource {
  Future<List<Video>> getHomeFeed({int limit = 10, dynamic startAfter});
  Future<Video> getVideoById(String id);
  Future<List<Video>> searchVideos(String query, {int limit = 20, dynamic startAfter});
  Future<List<Video>> getVideosByChannel(String channelId, {int limit = 20, dynamic startAfter});
  Future<List<Video>> getTrendingVideos({int limit = 20});
  Future<void> toggleLike(String videoId, String userId);
  Future<void> toggleDislike(String videoId, String userId);
  Future<void> deleteVideo(String videoId);
  Future<void> incrementViewCount(String videoId);
}

/// Production implementation of [VideoRemoteDataSource] powered by Cloud Firestore.
class FirestoreVideoRemoteDataSource implements VideoRemoteDataSource {
  final FirebaseFirestore _firestore;

  FirestoreVideoRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Video>> getHomeFeed({int limit = 10, dynamic startAfter}) async {
    var query = _firestore
        .collection(FirestoreCollections.videos)
        .where('status', isEqualTo: 'published')
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter is DocumentSnapshot) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map(Video.fromDocumentSnapshot).toList();
  }

  @override
  Future<Video> getVideoById(String id) async {
    final doc = await _firestore.collection(FirestoreCollections.videos).doc(id).get();
    if (!doc.exists) {
      throw NotFoundException(message: 'Video not found: $id');
    }
    final video = Video.fromDocumentSnapshot(doc);
    if (video.status == VideoStatus.rejected) {
      throw const ValidationException(
        message: 'This video has been removed for violating community guidelines.',
      );
    }
    return video;
  }

  @override
  Future<List<Video>> searchVideos(
    String query, {
    int page = 1,
    int limit = 20,
    dynamic startAfter,
  }) async {
    final queryLower = query.toLowerCase();
    var q = _firestore
        .collection(FirestoreCollections.videos)
        .where('status', isEqualTo: 'published')
        .where('titleLowercase', isGreaterThanOrEqualTo: queryLower)
        .where('titleLowercase', isLessThanOrEqualTo: '$queryLower\uf8ff')
        .where('visibility', isEqualTo: 'public')
        .limit(limit);

    if (startAfter is DocumentSnapshot) {
      q = q.startAfterDocument(startAfter);
    }

    final snapshot = await q.get();
    return snapshot.docs.map(Video.fromDocumentSnapshot).toList();
  }

  @override
  Future<List<Video>> getVideosByChannel(
    String channelId, {
    int page = 1,
    int limit = 20,
    dynamic startAfter,
  }) async {
    var q = _firestore
        .collection(FirestoreCollections.videos)
        .where('status', isEqualTo: 'published')
        .where('channelId', isEqualTo: channelId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter is DocumentSnapshot) {
      q = q.startAfterDocument(startAfter);
    }

    final snapshot = await q.get();
    return snapshot.docs.map(Video.fromDocumentSnapshot).toList();
  }

  @override
  Future<List<Video>> getTrendingVideos({int limit = 20}) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.videos)
        .where('status', isEqualTo: 'published')
        .where('visibility', isEqualTo: 'public')
        .orderBy('viewCount', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map(Video.fromDocumentSnapshot).toList();
  }

  @override
  Future<void> toggleLike(String videoId, String userId) async {
    final docRef = _firestore
        .collection(FirestoreCollections.videos)
        .doc(videoId)
        .collection('likes')
        .doc(userId);
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
      await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .update({'likeCount': FieldValue.increment(-1)});
    } else {
      await docRef.set({'likedAt': FieldValue.serverTimestamp()});
      await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .update({'likeCount': FieldValue.increment(1)});
    }
  }

  @override
  Future<void> toggleDislike(String videoId, String userId) async {
    final docRef = _firestore
        .collection(FirestoreCollections.videos)
        .doc(videoId)
        .collection('dislikes')
        .doc(userId);
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
      await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .update({'dislikeCount': FieldValue.increment(-1)});
    } else {
      await docRef.set({'dislikedAt': FieldValue.serverTimestamp()});
      await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .update({'dislikeCount': FieldValue.increment(1)});
    }
  }

  @override
  Future<void> deleteVideo(String videoId) async {
    await _firestore
        .collection(FirestoreCollections.videos)
        .doc(videoId)
        .update({
          'status': 'deleted',
          'visibility': 'private',
          'deletedAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<void> incrementViewCount(String videoId) async {
    await _firestore
        .collection(FirestoreCollections.videos)
        .doc(videoId)
        .update({'viewCount': FieldValue.increment(1)});
  }
}
