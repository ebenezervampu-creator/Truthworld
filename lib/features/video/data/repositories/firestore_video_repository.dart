import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/domain/repositories/video_repository.dart';

/// Firestore implementation of [VideoRepository].
class FirestoreVideoRepository implements VideoRepository {
  FirestoreVideoRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<Result<Video>> getVideoById(String id) async {
    try {
      final doc = await _firestore.collection('videos').doc(id).get();
      if (!doc.exists || doc.data() == null) {
        return Result.failure(NotFoundException(message: 'Video not found with ID: $id'));
      }
      final data = doc.data()!;
      data['id'] = doc.id;
      return Result.success(Video.fromMap(data));
    } catch (e) {
      return Result.failure(GenericAppException(message: e.toString()));
    }
  }

  @override
  Future<Result<List<Video>>> getFeedVideos({int limit = 10}) async {
    try {
      final snap = await _firestore
          .collection('videos')
          .where('status', isEqualTo: 'published')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final videos = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Video.fromMap(data);
      }).toList();

      return Result.success(videos);
    } catch (e) {
      return Result.failure(GenericAppException(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> recordView(String videoId) async {
    try {
      await _firestore.collection('videos').doc(videoId).update({
        'views': FieldValue.increment(1),
      });
      return Result.success(null);
    } catch (e) {
      return Result.failure(GenericAppException(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> toggleLike({
    required String videoId,
    required String userId,
  }) async {
    try {
      final ref = _firestore.collection('videos').doc(videoId);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;

        final likes = List<String>.from(snap.data()?['likes'] ?? []);
        if (likes.contains(userId)) {
          likes.remove(userId);
        } else {
          likes.add(userId);
        }
        tx.update(ref, {'likes': likes, 'likesCount': likes.length});
      });
      return Result.success(null);
    } catch (e) {
      return Result.failure(GenericAppException(message: e.toString()));
    }
  }

  @override
  Future<Result<List<Video>>> getVideosByChannel(String channelId) async {
    try {
      final snap = await _firestore
          .collection('videos')
          .where('channelId', isEqualTo: channelId)
          .get();

      final videos = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Video.fromMap(data);
      }).toList();

      return Result.success(videos);
    } catch (e) {
      return Result.failure(GenericAppException(message: e.toString()));
    }
  }
}
