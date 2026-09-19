import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/comment_entity.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/domain/repositories/video_comments_repository.dart';

/// Firestore implementation of [VideoCommentsRepository].
class FirestoreCommentsRepository implements VideoCommentsRepository {
  FirestoreCommentsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<CommentEntity>> streamComments(String videoId) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Comment.fromDocumentSnapshot(doc).toEntity())
            .toList());
  }

  @override
  Future<Result<CommentEntity>> postComment({
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

      return Result.success(comment.toEntity());
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, context: 'FirestoreCommentsRepository.postComment');
      return Result.failure(AppException.from(e, stackTrace));
    }
  }

  @override
  Future<Result<void>> deleteComment(String commentId) async {
    try {
      await _firestore.collection('comments').doc(commentId).delete();
      return Result.success(null);
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, context: 'FirestoreCommentsRepository.deleteComment');
      return Result.failure(AppException.from(e, stackTrace));
    }
  }

  @override
  Future<Result<void>> toggleCommentReaction({
    required String commentId,
    required String userId,
    required bool isLike,
  }) async {
    try {
      final field = isLike ? 'likes' : 'dislikes';
      final countField = isLike ? 'likeCount' : 'dislikeCount';
      final ref = _firestore.collection('comments').doc(commentId);

      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;

        final list = List<String>.from(snap.data()?[field] ?? []);
        if (list.contains(userId)) {
          list.remove(userId);
        } else {
          list.add(userId);
        }
        tx.update(ref, {field: list, countField: list.length});
      });

      return Result.success(null);
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, context: 'FirestoreCommentsRepository.toggleCommentReaction');
      return Result.failure(AppException.from(e, stackTrace));
    }
  }
}
