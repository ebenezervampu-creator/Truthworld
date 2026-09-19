import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/following_topics_controller.dart';
import 'package:truthworld/features/topics/presentation/controllers/interaction/topic_interaction_state_base.dart';

/// Mixin handling topic initialization, like toggling, user interaction checks, and topic reporting.
mixin TopicLikeMixin on TopicInteractionStateBase {
  @override
  void initializeTopic(Topic topic) {
    if (initializedTopicId == topic.id && this.topic != null) {
      if (topic.commentCount != commentCount.value && comments.isEmpty) {
        commentCount.value = topic.commentCount;
      }
      return;
    }
    initializedTopicId = topic.id;
    this.topic = topic;

    // Set initial values
    initialDbLikeCount.value = topic.likeCount;
    commentCount.value = topic.commentCount;
    dbIsLiked.value = false;
    hasCheckedInteraction.value = false;
    isLiked.value = false;

    updateLikeCount();

    checkUserInteraction(topic.id);
    fetchUserCommentInteractions(topic.id);
    fetchComments(topic.id);
  }

  Future<void> checkUserInteraction(String topicId) async {
    if (currentUserId.isEmpty) return;
    try {
      // Try nested user's likedTopics subcollection first
      final likedTopicsDoc = await firestore
          .collection(FirestoreCollections.users)
          .doc(currentUserId)
          .collection('likedTopics')
          .doc(topicId)
          .get();

      if (likedTopicsDoc.exists) {
        isLiked.value = true;
        dbIsLiked.value = true;
      }
      hasCheckedInteraction.value = true;
      updateLikeCount();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TopicInteractionController.checkUserInteraction',
      );
    }
  }

  Future<void> fetchUserCommentInteractions(String topicId) async {
    final userId = currentUserId;
    if (userId.isEmpty) return;
    try {
      userCommentInteractions.clear();
      userReplyInteractions.clear();

      // Fetch comment interactions
      final commentsSnap = await firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('liked_topic_comments')
          .where('topicId', isEqualTo: topicId)
          .get()
          .timeout(const Duration(seconds: 10));

      for (final doc in commentsSnap.docs) {
        final data = doc.data();
        userCommentInteractions[doc.id] = {
          'isLiked': data['isLiked'] ?? false,
          'isDisliked': data['isDisliked'] ?? false,
        };
      }
      userCommentInteractions.refresh();

      // Fetch reply interactions
      final repliesSnap = await firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('liked_topic_replies')
          .where('topicId', isEqualTo: topicId)
          .get()
          .timeout(const Duration(seconds: 10));

      for (final doc in repliesSnap.docs) {
        final data = doc.data();
        userReplyInteractions[doc.id] = {
          'isLiked': data['isLiked'] ?? false,
          'isDisliked': data['isDisliked'] ?? false,
        };
      }
      userReplyInteractions.refresh();

      if (comments.isNotEmpty) {
        comments.value = comments.map((c) {
          final interaction = userCommentInteractions[c.id];
          if (interaction != null) {
            return c.copyWith(
              isLikedByCurrentUser: interaction['isLiked'] ?? false,
              isDislikedByCurrentUser: interaction['isDisliked'] ?? false,
            );
          }
          return c;
        }).toList();
        comments.refresh();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TopicInteractionController.fetchUserCommentInteractions',
      );
    }
  }

  Future<void> toggleLike(String topicId) async {
    if (currentUserId.isEmpty) {
      AppSnackbar.warning('Please sign in to like this topic.');
      return;
    }

    final wasLiked = isLiked.value;

    // Optimistic UI updates
    isLiked.value = !wasLiked;
    updateLikeCount();

    try {
      final batch = firestore.batch();
      final topicRef = firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId);
      final topicLikeRef = topicRef.collection('likes').doc(currentUserId);
      final userLikedRef = firestore
          .collection(FirestoreCollections.users)
          .doc(currentUserId)
          .collection('likedTopics')
          .doc(topicId);

      if (isLiked.value) {
        // Nested subcollections only (YouTube-standard, no legacy writes)
        batch.set(topicLikeRef, {
          'userId': currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        batch.set(userLikedRef, {
          'topicId': topicId,
          'timestamp': FieldValue.serverTimestamp(),
        });

        batch.update(topicRef, {
          'likeCount': FieldValue.increment(1),
        });
      } else {
        // Nested subcollections only
        batch.delete(topicLikeRef);
        batch.delete(userLikedRef);
        batch.update(topicRef, {'likeCount': FieldValue.increment(-1)});
      }

      await batch.commit();

      // Update dbIsLiked to match the newly committed state
      dbIsLiked.value = isLiked.value;
      updateLikeCount();

      if (Get.isRegistered<FollowingTopicsController>()) {
        final ctrl = Get.find<FollowingTopicsController>();
        if (isLiked.value && topic != null) {
          if (!ctrl.favoriteTopics.any((t) => t.id == topicId)) {
            ctrl.favoriteTopics.add(topic!);
          }
          if (!ctrl.followedTopics.any((t) => t.id == topicId)) {
            ctrl.followedTopics.add(topic!);
            ctrl.followingStates[topicId] = true;
          }
        } else if (!isLiked.value) {
          ctrl.favoriteTopics.removeWhere((t) => t.id == topicId);
        }
      }
    } catch (e, s) {
      // Revert on error
      isLiked.value = wasLiked;
      updateLikeCount();
      checkUserInteraction(topicId); // refresh count
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TopicInteractionController.toggleLike',
      );
    }
  }

  Future<void> reportTopic(
    String topicId,
    String reason,
    String details,
  ) async {
    if (currentUserId.isEmpty) {
      AppSnackbar.warning('Please sign in to report.');
      return;
    }

    try {
      await firestore.collection('topic_reports').add({
        'topicId': topicId,
        'userId': currentUserId,
        'userName': currentUserName,
        'reason': reason,
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
      });
      AppSnackbar.success(
        'Thank you for reporting. Our moderators will review it shortly.',
      );
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to submit report. Please try again.');
    }
  }
}
