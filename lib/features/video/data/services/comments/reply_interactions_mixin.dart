import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/video/data/services/comments/comment_service_base.dart';

/// Mixin providing like, dislike, and remove interaction operations for comment replies.
mixin ReplyInteractionsMixin on CommentServiceBase {
  /// Like reply securely via backend Callable Cloud Function,
  /// falling back to direct Firestore batch operations if unavailable.
  Future<void> likeReply({
    required String videoId,
    required String commentId,
    required String replyId,
    required String userId,
    required bool asChannel,
  }) async {
    try {
      await ensureAuthFreshness();
      final callable = functions.httpsCallable('toggleReplyInteraction');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
        'replyId': replyId,
        'interactionType': 'like',
        'asChannel': asChannel,
      });
    } catch (e) {
      logger.warning(
        'Failed to like reply via cloud function, falling back to direct Firestore: $e',
        tag: 'COMMENTS',
      );
      try {
        final replyRef = firestore
            .collection(videosCollection)
            .doc(videoId)
            .collection(commentsCollection)
            .doc(commentId)
            .collection(repliesCollection)
            .doc(replyId);

        final likeRef = replyRef.collection('likes').doc(userId);
        final dislikeRef = replyRef.collection('dislikes').doc(userId);

        final likeDoc = await likeRef.get();
        final dislikeDoc = await dislikeRef.get();

        final batch = firestore.batch();

        if (likeDoc.exists) {
          batch.delete(likeRef);
          batch.update(replyRef, {'likeCount': FieldValue.increment(-1)});
        } else {
          batch.set(likeRef, {
            'userId': userId,
            'likedAt': FieldValue.serverTimestamp(),
          });
          batch.update(replyRef, {'likeCount': FieldValue.increment(1)});

          if (dislikeDoc.exists) {
            batch.delete(dislikeRef);
            batch.update(replyRef, {'dislikeCount': FieldValue.increment(-1)});
          }
        }

        await batch.commit();
      } catch (firestoreError) {
        logger.error(
          'Direct Firestore fallback failed for likeReply: $firestoreError',
          tag: 'COMMENTS',
        );
        throw Exception('Failed to like reply: $firestoreError');
      }
    }
  }

  /// Dislike reply securely via backend Callable Cloud Function,
  /// falling back to direct Firestore batch operations if unavailable.
  Future<void> dislikeReply({
    required String videoId,
    required String commentId,
    required String replyId,
    required String userId,
    required bool asChannel,
  }) async {
    try {
      await ensureAuthFreshness();
      final callable = functions.httpsCallable('toggleReplyInteraction');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
        'replyId': replyId,
        'interactionType': 'dislike',
        'asChannel': asChannel,
      });
    } catch (e) {
      logger.warning(
        'Failed to dislike reply via cloud function, falling back to direct Firestore: $e',
        tag: 'COMMENTS',
      );
      try {
        final replyRef = firestore
            .collection(videosCollection)
            .doc(videoId)
            .collection(commentsCollection)
            .doc(commentId)
            .collection(repliesCollection)
            .doc(replyId);

        final likeRef = replyRef.collection('likes').doc(userId);
        final dislikeRef = replyRef.collection('dislikes').doc(userId);

        final likeDoc = await likeRef.get();
        final dislikeDoc = await dislikeRef.get();

        final batch = firestore.batch();

        if (dislikeDoc.exists) {
          batch.delete(dislikeRef);
          batch.update(replyRef, {'dislikeCount': FieldValue.increment(-1)});
        } else {
          batch.set(dislikeRef, {
            'userId': userId,
            'dislikedAt': FieldValue.serverTimestamp(),
          });
          batch.update(replyRef, {'dislikeCount': FieldValue.increment(1)});

          if (likeDoc.exists) {
            batch.delete(likeRef);
            batch.update(replyRef, {'likeCount': FieldValue.increment(-1)});
          }
        }

        await batch.commit();
      } catch (firestoreError) {
        logger.error(
          'Direct Firestore fallback failed for dislikeReply: $firestoreError',
          tag: 'COMMENTS',
        );
        throw Exception('Failed to dislike reply: $firestoreError');
      }
    }
  }

  /// Remove like/dislike from reply via Callable Function,
  /// falling back to direct Firestore batch operations if unavailable.
  Future<void> removeReplyInteraction({
    required String videoId,
    required String commentId,
    required String replyId,
    required String userId,
  }) async {
    try {
      await ensureAuthFreshness();
      final callable = functions.httpsCallable('toggleReplyInteraction');
      await callable.call({
        'videoId': videoId,
        'commentId': commentId,
        'replyId': replyId,
        'interactionType': 'remove',
        'asChannel': false,
      });
    } catch (e) {
      logger.warning(
        'Failed to remove reply interaction via cloud function, falling back to direct Firestore: $e',
        tag: 'COMMENTS',
      );
      try {
        final replyRef = firestore
            .collection(videosCollection)
            .doc(videoId)
            .collection(commentsCollection)
            .doc(commentId)
            .collection(repliesCollection)
            .doc(replyId);

        final likeRef = replyRef.collection('likes').doc(userId);
        final dislikeRef = replyRef.collection('dislikes').doc(userId);

        final likeDoc = await likeRef.get();
        final dislikeDoc = await dislikeRef.get();

        final batch = firestore.batch();

        if (likeDoc.exists) {
          batch.delete(likeRef);
          batch.update(replyRef, {'likeCount': FieldValue.increment(-1)});
        }
        if (dislikeDoc.exists) {
          batch.delete(dislikeRef);
          batch.update(replyRef, {'dislikeCount': FieldValue.increment(-1)});
        }

        await batch.commit();
      } catch (firestoreError) {
        logger.error(
          'Direct Firestore fallback failed for removeReplyInteraction: $firestoreError',
          tag: 'COMMENTS',
        );
        throw Exception('Failed to remove reply interaction: $firestoreError');
      }
    }
  }
}
