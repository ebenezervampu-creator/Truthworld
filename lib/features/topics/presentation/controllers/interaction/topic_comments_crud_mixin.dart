import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/presentation/controllers/interaction/topic_interaction_state_base.dart';
import 'package:truthworld/features/video/data/models/comment.dart';

/// Mixin providing topic comments streaming, addition, and deletion.
mixin TopicCommentsCrudMixin on TopicInteractionStateBase {
  @override
  Future<void> fetchComments(String topicId) async {
    commentsSubscription?.cancel();
    isLoadingComments.value = true;
    try {
      commentsSubscription = firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .listen(
        (snap) {
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

          comments.value = loaded;
          if (loaded.length > commentCount.value) {
            commentCount.value = loaded.length;
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

  Future<void> addComment(String topicId, String text) async {
    if (text.trim().isEmpty) return;
    if (currentUserId.isEmpty) {
      AppSnackbar.warning('Please sign in to comment.');
      return;
    }

    final validation = await validateContent(text, fieldName: 'Comment');
    if (!validation.isValid) {
      AppSnackbar.warning(validation.message);
      return;
    }

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

      await commentRef.set(commentObj.toMap());

      // Update commentCount in Firestore topics collection
      await firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .update({
            'commentCount': FieldValue.increment(1),
          });

      // Update local UI count and list
      commentCount.value++;
      comments.insert(0, commentObj);
      comments.refresh();
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to add comment. Please try again.');
    }
  }

  Future<void> deleteComment(String topicId, String commentId) async {
    try {
      await firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .delete();

      await firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .update({
            'commentCount': FieldValue.increment(-1),
          });

      commentCount.value = (commentCount.value - 1).clamp(0, 999999);
      comments.removeWhere((c) => c.id == commentId);
      comments.refresh();
      AppSnackbar.success('Comment deleted successfully.');
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to delete comment. Please try again.');
    }
  }
}
