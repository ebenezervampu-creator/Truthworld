import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/video/data/services/comments/comment_service_base.dart';

/// Mixin providing like, dislike, remove interaction, and creator heart operations for comments.
mixin CommentInteractionsMixin on CommentServiceBase {
  /// Like comment securely via backend Callable Cloud Function,
  /// falling back to direct Firestore batch operations if unavailable.
  Future<void> likeComment({
    required String videoId,
    required String commentId,
    required String userId,
    required bool asChannel,
    bool isVideoCreator = false,
    String? creatorName,
  }) async {
    try {
      final callable = functions.httpsCallable('toggleCommentInteraction');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
        'interactionType': 'like',
        'asChannel': asChannel,
      });
    } catch (e) {
      logger.warning(
        'Failed to like comment via cloud function, falling back to direct Firestore: $e',
        tag: 'COMMENTS',
      );
      try {
        final commentRef = firestore
            .collection(videosCollection)
            .doc(videoId)
            .collection(commentsCollection)
            .doc(commentId);

        final likeRef = commentRef.collection('likes').doc(userId);
        final dislikeRef = commentRef.collection('dislikes').doc(userId);

        final likeDoc = await likeRef.get();
        final dislikeDoc = await dislikeRef.get();

        final batch = firestore.batch();

        if (likeDoc.exists) {
          batch.delete(likeRef);
          batch.update(commentRef, {
            'likeCount': FieldValue.increment(-1),
            if (isVideoCreator) ...{
              'isHeartedByCreator': false,
              'creatorHeartName': FieldValue.delete(),
            },
          });
        } else {
          batch.set(likeRef, {
            'userId': userId,
            'likedAt': FieldValue.serverTimestamp(),
          });
          batch.update(commentRef, {
            'likeCount': FieldValue.increment(1),
            if (isVideoCreator) ...{
              'isHeartedByCreator': true,
              'creatorHeartName': creatorName,
            },
          });

          if (dislikeDoc.exists) {
            batch.delete(dislikeRef);
            batch.update(commentRef, {
              'dislikeCount': FieldValue.increment(-1),
            });
          }
        }

        await batch.commit();
      } catch (firestoreError) {
        logger.error(
          'Direct Firestore fallback failed for likeComment: $firestoreError',
          tag: 'COMMENTS',
        );
        throw Exception('Failed to like comment: $firestoreError');
      }
    }
  }

  /// Dislike comment securely via backend Callable Cloud Function,
  /// falling back to direct Firestore batch operations if unavailable.
  Future<void> dislikeComment({
    required String videoId,
    required String commentId,
    required String userId,
    required bool asChannel,
    bool isVideoCreator = false,
  }) async {
    try {
      final callable = functions.httpsCallable('toggleCommentInteraction');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
        'interactionType': 'dislike',
        'asChannel': asChannel,
      });
    } catch (e) {
      logger.warning(
        'Failed to dislike comment via cloud function, falling back to direct Firestore: $e',
        tag: 'COMMENTS',
      );
      try {
        final commentRef = firestore
            .collection(videosCollection)
            .doc(videoId)
            .collection(commentsCollection)
            .doc(commentId);

        final likeRef = commentRef.collection('likes').doc(userId);
        final dislikeRef = commentRef.collection('dislikes').doc(userId);

        final likeDoc = await likeRef.get();
        final dislikeDoc = await dislikeRef.get();

        final batch = firestore.batch();

        if (dislikeDoc.exists) {
          batch.delete(dislikeRef);
          batch.update(commentRef, {'dislikeCount': FieldValue.increment(-1)});
        } else {
          batch.set(dislikeRef, {
            'userId': userId,
            'dislikedAt': FieldValue.serverTimestamp(),
          });
          batch.update(commentRef, {
            'dislikeCount': FieldValue.increment(1),
            if (isVideoCreator) ...{
              'isHeartedByCreator': false,
              'creatorHeartName': FieldValue.delete(),
            },
          });

          if (likeDoc.exists) {
            batch.delete(likeRef);
            batch.update(commentRef, {
              'likeCount': FieldValue.increment(-1),
              if (isVideoCreator) ...{
                'isHeartedByCreator': false,
                'creatorHeartName': FieldValue.delete(),
              },
            });
          }
        }

        await batch.commit();
      } catch (firestoreError) {
        logger.error(
          'Direct Firestore fallback failed for dislikeComment: $firestoreError',
          tag: 'COMMENTS',
        );
        throw Exception('Failed to dislike comment: $firestoreError');
      }
    }
  }

  /// Remove like/dislike from comment securely via backend Callable Cloud Function,
  /// falling back to direct Firestore batch operations if unavailable.
  Future<void> removeCommentInteraction({
    required String videoId,
    required String commentId,
    required String userId,
    bool isVideoCreator = false,
  }) async {
    try {
      final callable = functions.httpsCallable('toggleCommentInteraction');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
        'interactionType': 'remove',
        'asChannel': false,
      });
    } catch (e) {
      logger.warning(
        'Failed to remove comment interaction via cloud function, falling back to direct Firestore: $e',
        tag: 'COMMENTS',
      );
      try {
        final commentRef = firestore
            .collection(videosCollection)
            .doc(videoId)
            .collection(commentsCollection)
            .doc(commentId);

        final likeRef = commentRef.collection('likes').doc(userId);
        final dislikeRef = commentRef.collection('dislikes').doc(userId);

        final likeDoc = await likeRef.get();
        final dislikeDoc = await dislikeRef.get();

        final batch = firestore.batch();

        if (likeDoc.exists) {
          batch.delete(likeRef);
          batch.update(commentRef, {
            'likeCount': FieldValue.increment(-1),
            if (isVideoCreator) ...{
              'isHeartedByCreator': false,
              'creatorHeartName': FieldValue.delete(),
            },
          });
        }
        if (dislikeDoc.exists) {
          batch.delete(dislikeRef);
          batch.update(commentRef, {'dislikeCount': FieldValue.increment(-1)});
        }

        await batch.commit();
      } catch (firestoreError) {
        logger.error(
          'Direct Firestore fallback failed for removeCommentInteraction: $firestoreError',
          tag: 'COMMENTS',
        );
        throw Exception('Failed to remove interaction: $firestoreError');
      }
    }
  }

  /// Toggle Creator Heart on a comment (Studio only)
  Future<void> heartComment({
    required String videoId,
    required String commentId,
    required bool isHearted,
    String? creatorName,
  }) async {
    try {
      await firestore
          .collection(videosCollection)
          .doc(videoId)
          .collection(commentsCollection)
          .doc(commentId)
          .update({
            'isHeartedByCreator': isHearted,
            'creatorHeartName': isHearted ? creatorName : null,
          });
    } catch (e) {
      logger.error('Failed to heart comment: $e', tag: 'COMMENTS');
      throw Exception('Failed to heart comment: $e');
    }
  }
}
