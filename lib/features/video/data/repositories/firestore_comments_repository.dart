import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/domain/repositories/video_comments_repository.dart';

/// Firestore implementation of [VideoCommentsRepository].
class FirestoreCommentsRepository implements VideoCommentsRepository {
  FirestoreCommentsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<Comment>> streamComments(String videoId) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(Comment.fromDocumentSnapshot)
            .toList());
  }

  @override
  Future<Result<Comment>> postComment({
    required String videoId,
    required String text,
    required String userId,
    required String userName,
    String? userAvatar,
  }) async {
    try {
      final docRef = _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc();

      final now = Timestamp.now();
      final comment = Comment(
        id: docRef.id,
        videoId: videoId,
        userId: userId,
        userName: userName,
        userProfilePicUrl: userAvatar ?? '',
        channelId: userId,
        text: text,
        likeCount: 0,
        dislikeCount: 0,
        reportCount: 0,
        createdAt: now,
      );

      await docRef.set(comment.toMap());

      await _firestore.collection('videos').doc(videoId).update({
        'commentCount': FieldValue.increment(1),
      });

      return Result.success(comment);
    } catch (e) {
      return Result.failure(GenericAppException(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteComment(String commentId) async {
    try {
      final snap = await _firestore.collectionGroup('comments').where('id', isEqualTo: commentId).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
      return Result.success(null);
    } catch (e) {
      return Result.failure(GenericAppException(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> toggleCommentReaction({
    required String commentId,
    required String userId,
    required bool isLike,
  }) async {
    try {
      final snap = await _firestore.collectionGroup('comments').where('id', isEqualTo: commentId).get();
      if (snap.docs.isNotEmpty) {
        final docRef = snap.docs.first.reference;
        final field = isLike ? 'likeCount' : 'dislikeCount';
        await docRef.update({
          field: FieldValue.increment(1),
        });
      }
      return Result.success(null);
    } catch (e) {
      return Result.failure(GenericAppException(message: e.toString()));
    }
  }
}
