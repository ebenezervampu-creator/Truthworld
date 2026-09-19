import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/presentation/controllers/interaction/topic_interaction_state_base.dart';
import 'package:truthworld/features/video/data/models/comment.dart';

/// Mixin handling user like and dislike reactions on topic comments.
mixin TopicCommentReactionsMixin on TopicInteractionStateBase {
  Future<void> toggleCommentLike(String topicId, String commentId) async {
    final userId = currentUserId;
    if (userId.isEmpty) {
      AppSnackbar.warning('Please sign in to interact.');
      return;
    }

    final currentInteraction =
        userCommentInteractions[commentId] ??
        {'isLiked': false, 'isDisliked': false};
    final wasLiked = currentInteraction['isLiked'] ?? false;
    final wasDisliked = currentInteraction['isDisliked'] ?? false;

    final newLiked = !wasLiked;
    final newDisliked = !newLiked && wasDisliked;

    // Optimistic UI update
    userCommentInteractions[commentId] = {
      'isLiked': newLiked,
      'isDisliked': newDisliked,
    };
    userCommentInteractions.refresh();

    final index = comments.indexWhere((c) => c.id == commentId);
    Comment? oldComment;
    if (index != -1) {
      oldComment = comments[index];
      var newLikeCount = oldComment.likeCount;
      var newDislikeCount = oldComment.dislikeCount;
      if (newLiked) {
        newLikeCount++;
        if (wasDisliked) {
          newDislikeCount = (newDislikeCount - 1).clamp(0, 999999);
        }
      } else {
        newLikeCount = (newLikeCount - 1).clamp(0, 999999);
      }

      comments[index] = oldComment.copyWith(
        likeCount: newLikeCount,
        dislikeCount: newDislikeCount,
        isLikedByCurrentUser: newLiked,
        isDislikedByCurrentUser: newDisliked,
      );
      comments.refresh();
    }

    try {
      final commentRef = firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId);

      final likeRef = commentRef.collection('likes').doc(userId);
      final dislikeRef = commentRef.collection('dislikes').doc(userId);

      final userInteractionRef = firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('liked_topic_comments')
          .doc(commentId);

      final likeDoc = await likeRef.get();
      final dislikeDoc = await dislikeRef.get();

      final batch = firestore.batch();

      if (likeDoc.exists) {
        batch.delete(likeRef);
        batch.delete(userInteractionRef);
        batch.update(commentRef, {
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        batch.set(likeRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.set(userInteractionRef, {
          'topicId': topicId,
          'isLiked': true,
          'isDisliked': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
        final updates = <String, dynamic>{
          'likeCount': FieldValue.increment(1),
        };
        if (dislikeDoc.exists) {
          batch.delete(dislikeRef);
          updates['dislikeCount'] = FieldValue.increment(-1);
        }
        batch.update(commentRef, updates);
      }

      await batch.commit();
    } catch (e, s) {
      userCommentInteractions[commentId] = currentInteraction;
      userCommentInteractions.refresh();
      if (index != -1 && oldComment != null) {
        comments[index] = oldComment;
        comments.refresh();
      }
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TopicInteractionController.toggleCommentLike',
      );
    }
  }

  Future<void> toggleCommentDislike(String topicId, String commentId) async {
    final userId = currentUserId;
    if (userId.isEmpty) {
      AppSnackbar.warning('Please sign in to interact.');
      return;
    }

    final currentInteraction =
        userCommentInteractions[commentId] ??
        {'isLiked': false, 'isDisliked': false};
    final wasLiked = currentInteraction['isLiked'] ?? false;
    final wasDisliked = currentInteraction['isDisliked'] ?? false;

    final newDisliked = !wasDisliked;
    final newLiked = !newDisliked && wasLiked;

    // Optimistic UI update
    userCommentInteractions[commentId] = {
      'isLiked': newLiked,
      'isDisliked': newDisliked,
    };
    userCommentInteractions.refresh();

    final index = comments.indexWhere((c) => c.id == commentId);
    Comment? oldComment;
    if (index != -1) {
      oldComment = comments[index];
      var newLikeCount = oldComment.likeCount;
      var newDislikeCount = oldComment.dislikeCount;
      if (newDisliked) {
        newDislikeCount++;
        if (wasLiked) {
          newLikeCount = (newLikeCount - 1).clamp(0, 999999);
        }
      } else {
        newDislikeCount = (newDislikeCount - 1).clamp(0, 999999);
      }

      comments[index] = oldComment.copyWith(
        likeCount: newLikeCount,
        dislikeCount: newDislikeCount,
        isLikedByCurrentUser: newLiked,
        isDislikedByCurrentUser: newDisliked,
      );
      comments.refresh();
    }

    try {
      final commentRef = firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId);

      final likeRef = commentRef.collection('likes').doc(userId);
      final dislikeRef = commentRef.collection('dislikes').doc(userId);

      final userInteractionRef = firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('liked_topic_comments')
          .doc(commentId);

      final likeDoc = await likeRef.get();
      final dislikeDoc = await dislikeRef.get();

      final batch = firestore.batch();

      if (dislikeDoc.exists) {
        batch.delete(dislikeRef);
        batch.delete(userInteractionRef);
        batch.update(commentRef, {
          'dislikeCount': FieldValue.increment(-1),
        });
      } else {
        batch.set(dislikeRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.set(userInteractionRef, {
          'topicId': topicId,
          'isLiked': false,
          'isDisliked': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
        final updates = <String, dynamic>{
          'dislikeCount': FieldValue.increment(1),
        };
        if (likeDoc.exists) {
          batch.delete(likeRef);
          updates['likeCount'] = FieldValue.increment(-1);
        }
        batch.update(commentRef, updates);
      }

      await batch.commit();
    } catch (e, s) {
      userCommentInteractions[commentId] = currentInteraction;
      userCommentInteractions.refresh();
      if (index != -1 && oldComment != null) {
        comments[index] = oldComment;
        comments.refresh();
      }
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TopicInteractionController.toggleCommentDislike',
      );
    }
  }
}
