import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/distributed_counter_service.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/presentation/controllers/interaction/topic_interaction_state_base.dart';
import 'package:truthworld/features/video/data/models/comment.dart';

/// Mixin providing topic comments streaming, cursor pagination, backend ingestion, and deletion.
mixin TopicCommentsCrudMixin on TopicInteractionStateBase {
  @override
  Future<void> fetchComments(String topicId) async {
    commentsSubscription?.cancel();
    isLoadingComments.value = true;
    hasMoreComments.value = true;
    lastCommentDoc = null;

    try {
      commentsSubscription = firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .limit(TopicInteractionStateBase.commentsPerPage)
          .snapshots()
          .listen(
        (snap) {
          if (snap.docs.isNotEmpty) {
            lastCommentDoc = snap.docs.last;
          }
          final loaded = snap.docs.map((doc) {
            final comment = Comment.fromDocumentSnapshot(doc);
            final interaction = userCommentInteractions[comment.id];
            if (interaction != null) {
              return comment.copyWith(
                isLikedByCurrentUser: interaction['isLiked'] ?? false,
                isDislikedByCurrentUser: interaction['isDisliked'] ?? false,
              );
            }
            return comment;
          }).toList();

          final seenIds = <String>{};
          final deduplicated = loaded.where((c) => seenIds.add(c.id)).toList();

          // Preserve loaded paged comments if more than first page is already loaded
          if (comments.length > TopicInteractionStateBase.commentsPerPage) {
            final firstPageIds = deduplicated.map((c) => c.id).toSet();
            final tail = comments.where((c) => !firstPageIds.contains(c.id)).toList();
            comments.value = [...deduplicated, ...tail];
          } else {
            comments.value = deduplicated;
          }

          hasMoreComments.value =
              snap.docs.length >= TopicInteractionStateBase.commentsPerPage;

          if (comments.length > commentCount.value) {
            commentCount.value = comments.length;
          }
          isLoadingComments.value = false;
        },
        onError: (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'TopicInteractionController.streamComments',
          );
          isLoadingComments.value = false;
        },
      );
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TopicInteractionController.setupCommentsStream',
      );
      isLoadingComments.value = false;
    }
  }

  /// Industry standard cursor-based pagination loading the next 25 comments.
  @override
  Future<void> loadMoreComments(String topicId) async {
    if (isLoadingMoreComments.value ||
        !hasMoreComments.value ||
        lastCommentDoc == null) {
      return;
    }

    try {
      isLoadingMoreComments.value = true;
      final nextSnap = await firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastCommentDoc!)
          .limit(TopicInteractionStateBase.commentsPerPage)
          .get();

      if (nextSnap.docs.isNotEmpty) {
        lastCommentDoc = nextSnap.docs.last;
        final nextComments = nextSnap.docs.map((doc) {
          final comment = Comment.fromDocumentSnapshot(doc);
          final interaction = userCommentInteractions[comment.id];
          if (interaction != null) {
            return comment.copyWith(
              isLikedByCurrentUser: interaction['isLiked'] ?? false,
              isDislikedByCurrentUser: interaction['isDisliked'] ?? false,
            );
          }
          return comment;
        }).toList();

        final currentIds = comments.map((c) => c.id).toSet();
        for (final c in nextComments) {
          if (currentIds.add(c.id)) {
            comments.add(c);
          }
        }
        comments.refresh();
      }

      hasMoreComments.value =
          nextSnap.docs.length >= TopicInteractionStateBase.commentsPerPage;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TopicInteractionController.loadMoreComments',
      );
    } finally {
      isLoadingMoreComments.value = false;
    }
  }

  Future<void> addComment(String topicId, String text) async {
    if (text.trim().isEmpty) return;
    if (isSubmittingComment.value) return;
    if (currentUserId.isEmpty) {
      AppSnackbar.warning('Please sign in to comment.');
      return;
    }

    final validation = await validateContent(
      text,
      fieldName: 'Comment',
      maxLength: ContentValidator.defaultMaxCommentLength,
    );
    if (!validation.isValid) {
      AppSnackbar.warning(validation.message);
      return;
    }

    isSubmittingComment.value = true;
    Comment? optimisticComment;

    try {
      final commentRef = firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc();

      // Resolve channel details
      String? channelId;
      String? channelName;
      String? channelProfilePicUrl;

      if (AuthService.to.hasChannel.value &&
          AuthService.to.userChannel != null) {
        final channel = AuthService.to.userChannel!;
        channelId = channel.id;
        channelName = channel.handle.isNotEmpty ? channel.handle : channel.name;
        channelProfilePicUrl = channel.avatarUrl;
      }

      final commentObj = Comment(
        id: commentRef.id,
        videoId: topicId,
        userId: currentUserId,
        userName: currentUserName,
        userProfilePicUrl: currentUserProfilePicUrl,
        channelId: channelId ?? currentUserId,
        channelName: channelName,
        channelProfilePicUrl: channelProfilePicUrl,
        text: text.trim(),
        likeCount: 0,
        dislikeCount: 0,
        reportCount: 0,
        createdAt: Timestamp.now(),
      );
      optimisticComment = commentObj;

      // Optimistically insert into local comments list if not already present
      if (!comments.any((c) => c.id == commentObj.id)) {
        comments.insert(0, commentObj);
        comments.refresh();
      }
      commentCount.value++;

      // Backend Ingestion via Callable Cloud Function with distributed counter sharding
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
            .httpsCallable('addTopicComment');
        await callable.call({
          'topicId': topicId,
          'text': text.trim(),
          'userName': currentUserName,
          'userProfilePicUrl': currentUserProfilePicUrl,
          'channelId': channelId ?? currentUserId,
          'channelName': channelName,
          'channelProfilePicUrl': channelProfilePicUrl,
        }).timeout(const Duration(seconds: 8));
      } catch (fnError) {
        // Direct Firestore fallback + Distributed Counter sharding
        await commentRef.set(commentObj.toMap());
        if (Get.isRegistered<DistributedCounterService>()) {
          await DistributedCounterService.to.incrementTopicComments(
            topicId: topicId,
          );
        } else {
          await firestore
              .collection(FirestoreCollections.topics)
              .doc(topicId)
              .update({
                'commentCount': FieldValue.increment(1),
              });
        }
      }

      // Synchronize commentCount with loaded list if needed
      if (comments.length > commentCount.value) {
        commentCount.value = comments.length;
      }
    } catch (e) {
      // Revert optimistic updates on failure
      final failedComment = optimisticComment;
      if (failedComment != null) {
        comments.removeWhere((c) => c.id == failedComment.id);
        comments.refresh();
        commentCount.value = (commentCount.value - 1).clamp(0, 999999);
      }
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to add comment. Please try again.');
    } finally {
      isSubmittingComment.value = false;
    }
  }

  Future<void> deleteComment(String topicId, String commentId) async {
    try {
      comments.removeWhere((c) => c.id == commentId);
      comments.refresh();
      commentCount.value = (commentCount.value - 1).clamp(0, 999999);

      await firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .delete();

      if (Get.isRegistered<DistributedCounterService>()) {
        DistributedCounterService.to.incrementTopicComments(
          topicId: topicId,
          delta: -1,
        );
      } else {
        await firestore
            .collection(FirestoreCollections.topics)
            .doc(topicId)
            .update({
              'commentCount': FieldValue.increment(-1),
            });
      }

      AppSnackbar.success('Comment deleted successfully.');
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to delete comment. Please try again.');
    }
  }
}
