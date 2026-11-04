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
import 'package:truthworld/features/video/data/models/reply.dart';

/// Mixin providing topic comment replies fetching, addition, and deletion.
mixin TopicRepliesCrudMixin on TopicInteractionStateBase {
  Future<void> fetchReplies(String topicId, String commentId) async {
    try {
      final snap = await firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .orderBy('createdAt', descending: false)
          .get();

      repliesMap[commentId] = snap.docs.map((doc) {
        return Reply.fromDocumentSnapshot(doc);
      }).toList();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TopicInteractionController.fetchReplies',
      );
    }
  }

  Future<void> addReply(String topicId, String commentId, String text) async {
    if (text.trim().isEmpty) return;
    if (isSubmittingReply.value) return;
    if (currentUserId.isEmpty) {
      AppSnackbar.warning('Please sign in to reply.');
      return;
    }

    final validation = await validateContent(text, fieldName: 'Reply');
    if (!validation.isValid) {
      AppSnackbar.warning(validation.message);
      return;
    }

    isSubmittingReply.value = true;
    try {
      final replyRef = firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc();

      final authService = AuthService.to;
      final hasChannel =
          authService.hasChannel.value && authService.userChannel != null;
      final userChannel = hasChannel ? authService.userChannel : null;

      final rawName = authService.userDisplayName.value ??
          authService.user?.displayName ??
          'User';
      final cleanUserName =
          rawName.startsWith('@') ? rawName.substring(1) : rawName;
      final cleanUserProfilePicUrl = authService.userPhotoUrl.value ??
          authService.user?.photoURL ??
          '';

      final replyObj = Reply(
        id: replyRef.id,
        commentId: commentId,
        videoId: topicId,
        userId: currentUserId,
        userName: cleanUserName,
        userProfilePicUrl: cleanUserProfilePicUrl,
        channelId: hasChannel ? userChannel!.id : '',
        channelHandle: userChannel?.handle,
        channelName: userChannel?.name,
        channelProfilePicUrl: userChannel?.avatarUrl,
        isChannel: hasChannel,
        text: ContentValidator.cleanProfanity(text.trim()),
        likeCount: 0,
        dislikeCount: 0,
        reportCount: 0,
        createdAt: Timestamp.now(),
      );

      // Backend Ingestion via Callable Cloud Function with distributed counter sharding
      try {
        final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
            .httpsCallable('addTopicReply');
        await callable.call({
          'topicId': topicId,
          'commentId': commentId,
          'text': ContentValidator.cleanProfanity(text.trim()),
          'userName': cleanUserName,
          'userProfilePicUrl': cleanUserProfilePicUrl,
          'channelId': hasChannel ? userChannel!.id : '',
          'channelHandle': userChannel?.handle,
          'channelName': userChannel?.name,
          'channelProfilePicUrl': userChannel?.avatarUrl,
          'isChannel': hasChannel,
        }).timeout(const Duration(seconds: 8));
      } catch (fnError) {
        // Fallback to direct Firestore write + Distributed Counter
        await replyRef.set(replyObj.toMap());
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

      // Update local UI count and list
      commentCount.value++;
      if (repliesMap[commentId] == null) {
        repliesMap[commentId] = [];
      }
      if (!repliesMap[commentId]!.any((r) => r.id == replyObj.id)) {
        repliesMap[commentId]!.add(replyObj);
      }
      repliesMap.refresh();
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to add reply. Please try again.');
    } finally {
      isSubmittingReply.value = false;
    }
  }

  Future<void> deleteReply(
    String topicId,
    String commentId,
    String replyId,
  ) async {
    try {
      await firestore
          .collection(FirestoreCollections.topics)
          .doc(topicId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId)
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

      commentCount.value = (commentCount.value - 1).clamp(0, 999999);
      if (repliesMap[commentId] != null) {
        repliesMap[commentId]!.removeWhere((r) => r.id == replyId);
      }
      repliesMap.refresh();
      AppSnackbar.success('Reply deleted successfully.');
    } catch (e) {
      ErrorHandler.log(e);
      AppSnackbar.error('Unable to delete reply. Please try again.');
    }
  }
}
