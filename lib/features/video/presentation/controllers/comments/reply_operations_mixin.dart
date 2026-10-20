import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/mentions_helper.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/data/services/user_notification_service.dart';
import 'package:truthworld/features/video/presentation/controllers/comments/comments_state_base.dart';

/// Mixin handling thread reply submission, likes, dislikes, mentions, notifications, and deletion.
mixin ReplyOperationsMixin on CommentsStateBase {
  /// Add a reply to a comment
  Future<void> submitReply({
    required String commentId,
    required String text,
    required String userProfilePicUrl,
    String? channelId,
    String? channelName,
    String? channelProfilePicUrl,
    String? commentAuthorId,
  }) async {
    if (text.trim().isEmpty || video == null) return;
    if (!AuthService.to.isAuthenticated.value || currentUserId.isEmpty) {
      throw Exception('User not authenticated');
    }

    final validation = await validateContent(
      text,
      fieldName: 'Reply',
      maxLength: ContentValidator.defaultMaxReplyLength,
    );
    if (!validation.isValid) {
      commentError.value = validation.message;
      return;
    }

    try {
      isSubmittingComment.value = true;
      commentError.value = null;

      final authService = AuthService.to;
      final hasChannel =
          authService.hasChannel.value && authService.userChannel != null;

      final finalUserName = authService.activeDisplayName;
      final finalUserProfilePicUrl = authService.activePhotoUrl;
      final finalChannelId =
          hasChannel ? authService.userChannel!.id : channelId;
      final finalChannelName = hasChannel
          ? (authService.userChannel?.handle.isNotEmpty == true
                ? authService.userChannel!.handle
                : authService.userChannel!.name)
          : authService.activeDisplayName;
      final finalChannelProfilePicUrl = authService.activePhotoUrl;

      // Channel Membership & Loyalty Badge lookup
      var isMember = false;
      Timestamp? memberSince;
      String? memberTierName;
      final targetChannelId = video?.channelId;
      if (targetChannelId != null && targetChannelId.isNotEmpty) {
        try {
          final memDoc = await FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(currentUserId)
              .collection('channel_memberships')
              .doc(targetChannelId)
              .get();
          if (memDoc.exists && memDoc.data() != null) {
            final data = memDoc.data()!;
            final status =
                (data['status'] ?? 'active').toString().toLowerCase();
            if (status == 'active') {
              isMember = true;
              memberSince = data['joinedAt'] is Timestamp
                  ? data['joinedAt'] as Timestamp
                  : null;
              memberTierName = data['tierName'] as String?;
            }
          }
        } catch (_) {}
      }

      final replyId = await commentService.addReply(
        videoId: video!.id,
        commentId: commentId,
        userId: currentUserId,
        userName: finalUserName,
        userProfilePicUrl: finalUserProfilePicUrl,
        channelId: finalChannelId ?? currentUserId,
        channelName: finalChannelName,
        channelProfilePicUrl: finalChannelProfilePicUrl,
        text: text.trim(),
        isMember: isMember,
        memberSince: memberSince,
        memberTierName: memberTierName,
      );

      if (commentAuthorId != null &&
          commentAuthorId.isNotEmpty &&
          commentAuthorId != currentUserId) {
        final notificationService = UserNotificationService();
        final displayHandle = hasChannel
            ? authService.activeHandle
            : (currentUserName.startsWith('@')
                  ? currentUserName
                  : '@$currentUserName');

        notificationService.createNotification(
          userId: commentAuthorId,
          type: 'comment_reply',
          severity: NotificationSeverity.info,
          title: 'New Reply',
          message: '$displayHandle replied to your comment: "${text.trim()}"',
          actionUrl: '/watch?v=${video!.id}',
          metadata: {
            'videoId': video!.id,
            'commentId': commentId,
            'replyId': replyId,
            'thumbnailUrl': video!.thumbnailUrl,
            'channelId': video!.channelId,
            'userAvatar': authService.activePhotoUrl,
          },
        );
      }

      try {
        await MentionsHelper.processAndNotifyMentions(
          text: text.trim(),
          videoId: video!.id,
          videoTitle: video!.title,
          videoThumbnailUrl: video!.thumbnailUrl,
          videoChannelId: video!.channelId,
          commentId: commentId,
          replyId: replyId,
        );
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'CommentsController.processMentionsInReply',
        );
      }

      commentError.value = null;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CommentsController.addReply',
      );
      commentError.value =
          'Unable to post reply. Please check your connection and try again.';
    } finally {
      isSubmittingComment.value = false;
    }
  }

  /// Toggle like on reply
  Future<void> toggleReplyLike({
    required String commentId,
    required String replyId,
    required bool likeAsChannel,
    String? replyAuthorId,
    String? replyText,
  }) async {
    if (!AuthService.to.isAuthenticated.value || video == null) return;

    final userId = currentUserId;
    if (userId.isEmpty) return;

    final currentStatus = userCommentInteractions[replyId];
    final wasLiked = currentStatus?['isLiked'] ?? false;

    // Optimistic Update
    if (wasLiked) {
      userCommentInteractions[replyId] = {
        'isLiked': false,
        'isDisliked': false,
      };
    } else {
      userCommentInteractions[replyId] = {
        'isLiked': true,
        'isDisliked': false,
      };
    }

    try {
      if (wasLiked) {
        await commentService.removeReplyInteraction(
          videoId: video!.id,
          commentId: commentId,
          replyId: replyId,
          userId: userId,
        );
      } else {
        await commentService.likeReply(
          videoId: video!.id,
          commentId: commentId,
          replyId: replyId,
          userId: userId,
          asChannel: likeAsChannel,
        );
      }
    } catch (e) {
      ErrorHandler.log(e, context: 'CommentsController.toggleReplyLike');
      userCommentInteractions[replyId] =
          currentStatus ??
          {
            'isLiked': false,
            'isDisliked': false,
          };
      AppSnackbar.error('Unable to like reply. Please try again.');
    }
  }

  /// Toggle dislike on reply
  Future<void> toggleReplyDislike({
    required String commentId,
    required String replyId,
    required bool dislikeAsChannel,
  }) async {
    if (!AuthService.to.isAuthenticated.value || video == null) return;

    final userId = currentUserId;
    if (userId.isEmpty) return;

    final currentStatus = userCommentInteractions[replyId];
    final wasDisliked = currentStatus?['isDisliked'] ?? false;

    // Optimistic Update
    if (wasDisliked) {
      userCommentInteractions[replyId] = {
        'isLiked': false,
        'isDisliked': false,
      };
    } else {
      userCommentInteractions[replyId] = {
        'isLiked': false,
        'isDisliked': true,
      };
    }

    try {
      if (wasDisliked) {
        await commentService.removeReplyInteraction(
          videoId: video!.id,
          commentId: commentId,
          replyId: replyId,
          userId: userId,
        );
      } else {
        await commentService.dislikeReply(
          videoId: video!.id,
          commentId: commentId,
          replyId: replyId,
          userId: userId,
          asChannel: dislikeAsChannel,
        );
      }
    } catch (e) {
      ErrorHandler.log(e, context: 'CommentsController.toggleReplyDislike');
      userCommentInteractions[replyId] =
          currentStatus ??
          {
            'isLiked': false,
            'isDisliked': false,
          };
      AppSnackbar.error('Unable to dislike reply. Please try again.');
    }
  }

  bool isReplyLikedByUser(String replyId) {
    return userCommentInteractions[replyId]?['isLiked'] ?? false;
  }

  bool isReplyDislikedByUser(String replyId) {
    return userCommentInteractions[replyId]?['isDisliked'] ?? false;
  }

  /// Delete a reply
  Future<void> deleteReply(String commentId, String replyId) async {
    if (video == null) return;

    try {
      await commentService.deleteReply(video!.id, commentId, replyId);
    } catch (e) {
      ErrorHandler.log(e, context: 'CommentsController.deleteReply');
      AppSnackbar.error('Unable to delete reply. Please try again.');
    }
  }

  void triggerReplyLikeNotification(
    String commentId,
    String replyId,
    String? replyAuthorId,
    String? replyText,
  ) {
    if (video == null ||
        currentUserId.isEmpty ||
        replyAuthorId == null ||
        replyAuthorId.isEmpty ||
        currentUserId == replyAuthorId) {
      return;
    }

    final authService = AuthService.to;
    final notificationService = UserNotificationService();
    notificationService.createNotification(
      userId: replyAuthorId,
      type: 'reply_like',
      severity: NotificationSeverity.info,
      title: 'Reply Liked',
      message:
          '${authService.activeHandle} liked your reply: "${replyText ?? ''}"',
      actionUrl: '/watch?v=${video!.id}',
      metadata: {
        'videoId': video!.id,
        'commentId': commentId,
        'replyId': replyId,
        'thumbnailUrl': video!.thumbnailUrl,
        'channelId': video!.channelId,
        'userAvatar': authService.activePhotoUrl,
      },
    );
  }
}
