import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/presentation/controllers/interaction/topic_interaction_state_base.dart';
import 'package:truthworld/features/video/data/models/reply.dart';

/// Mixin handling user like and dislike reactions on topic comment replies.
mixin TopicReplyReactionsMixin on TopicInteractionStateBase {
  Future<void> toggleReplyLike(
    String topicId,
    String commentId,
    String replyId,
  ) async {
    final userId = currentUserId;
    if (userId.isEmpty) {
      AppSnackbar.warning('Please sign in to interact.');
      return;
    }

    final currentInteraction =
        userReplyInteractions[replyId] ??
        {'isLiked': false, 'isDisliked': false};
    final wasLiked = currentInteraction['isLiked'] ?? false;
    final wasDisliked = currentInteraction['isDisliked'] ?? false;

    final newLiked = !wasLiked;
    final newDisliked = !newLiked && wasDisliked;

    userReplyInteractions[replyId] = {
      'isLiked': newLiked,
      'isDisliked': newDisliked,
    };
    userReplyInteractions.refresh();

    final replies = repliesMap[commentId] ?? [];
    final index = replies.indexWhere((r) => r.id == replyId);
    Reply? oldReply;
    if (index != -1) {
      oldReply = replies[index];
      var newLikeCount = oldReply.likeCount;
      var newDislikeCount = oldReply.dislikeCount;
      if (newLiked) {
        newLikeCount++;
        if (wasDisliked) {
          newDislikeCount = (newDislikeCount - 1).clamp(0, 999999);
        }
      } else {
        newLikeCount = (newLikeCount - 1).clamp(0, 999999);
      }
      replies[index] = oldReply.copyWith(
        likeCount: newLikeCount,
        dislikeCount: newDislikeCount,
        isLikedByCurrentUser: newLiked,
        isDislikedByCurrentUser: newDisliked,
      );
      repliesMap.refresh();
    }

    try {
      final replyRef = firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId);

      final likeRef = replyRef.collection('likes').doc(userId);
      final dislikeRef = replyRef.collection('dislikes').doc(userId);

      final userInteractionRef = firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('liked_topic_replies')
          .doc(replyId);

      final likeDoc = await likeRef.get();
      final dislikeDoc = await dislikeRef.get();

      final batch = firestore.batch();

      if (likeDoc.exists) {
        batch.delete(likeRef);
        batch.delete(userInteractionRef);
        batch.update(replyRef, {
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        batch.set(likeRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.set(userInteractionRef, {
          'topicId': topicId,
          'commentId': commentId,
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
        batch.update(replyRef, updates);
      }

      await batch.commit();
    } catch (e, s) {
      userReplyInteractions[replyId] = currentInteraction;
      userReplyInteractions.refresh();
      if (index != -1 && oldReply != null) {
        replies[index] = oldReply;
        repliesMap.refresh();
      }
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TopicInteractionController.toggleReplyLike',
      );
    }
  }

  Future<void> toggleReplyDislike(
    String topicId,
    String commentId,
    String replyId,
  ) async {
    final userId = currentUserId;
    if (userId.isEmpty) {
      AppSnackbar.warning('Please sign in to interact.');
      return;
    }

    final currentInteraction =
        userReplyInteractions[replyId] ??
        {'isLiked': false, 'isDisliked': false};
    final wasLiked = currentInteraction['isLiked'] ?? false;
    final wasDisliked = currentInteraction['isDisliked'] ?? false;

    final newDisliked = !wasDisliked;
    final newLiked = !newDisliked && wasLiked;

    userReplyInteractions[replyId] = {
      'isLiked': newLiked,
      'isDisliked': newDisliked,
    };
    userReplyInteractions.refresh();

    final replies = repliesMap[commentId] ?? [];
    final index = replies.indexWhere((r) => r.id == replyId);
    Reply? oldReply;
    if (index != -1) {
      oldReply = replies[index];
      var newLikeCount = oldReply.likeCount;
      var newDislikeCount = oldReply.dislikeCount;
      if (newDisliked) {
        newDislikeCount++;
        if (wasLiked) newLikeCount = (newLikeCount - 1).clamp(0, 999999);
      } else {
        newDislikeCount = (newDislikeCount - 1).clamp(0, 999999);
      }
      replies[index] = oldReply.copyWith(
        likeCount: newLikeCount,
        dislikeCount: newDislikeCount,
        isLikedByCurrentUser: newLiked,
        isDislikedByCurrentUser: newDisliked,
      );
      repliesMap.refresh();
    }

    try {
      final replyRef = firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId);

      final likeRef = replyRef.collection('likes').doc(userId);
      final dislikeRef = replyRef.collection('dislikes').doc(userId);

      final userInteractionRef = firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('liked_topic_replies')
          .doc(replyId);

      final likeDoc = await likeRef.get();
      final dislikeDoc = await dislikeRef.get();

      final batch = firestore.batch();

      if (dislikeDoc.exists) {
        batch.delete(dislikeRef);
        batch.delete(userInteractionRef);
        batch.update(replyRef, {
          'dislikeCount': FieldValue.increment(-1),
        });
      } else {
        batch.set(dislikeRef, {
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.set(userInteractionRef, {
          'topicId': topicId,
          'commentId': commentId,
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
        batch.update(replyRef, updates);
      }

      await batch.commit();
    } catch (e, s) {
      userReplyInteractions[replyId] = currentInteraction;
      userReplyInteractions.refresh();
      if (index != -1 && oldReply != null) {
        replies[index] = oldReply;
        repliesMap.refresh();
      }
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TopicInteractionController.toggleReplyDislike',
      );
    }
  }
}
