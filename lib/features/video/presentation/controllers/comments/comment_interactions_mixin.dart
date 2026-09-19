import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/data/services/user_notification_service.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/presentation/controllers/comments/comments_state_base.dart';

/// Mixin handling comment likes, dislikes, hearting, and like notifications.
mixin CommentInteractionsMixin on CommentsStateBase {
  /// Toggle like on comment with channel option
  Future<void> toggleCommentLike({
    required String commentId,
    required bool likeAsChannel,
  }) async {
    if (!AuthService.to.isAuthenticated.value || video == null) return;

    final userId = currentUserId;
    if (userId.isEmpty) return;

    // --- Optimistic UI Update ---
    final index = comments.indexWhere((c) => c.id == commentId);
    if (index == -1) return;

    final comment = comments[index];
    final currentStatus = userCommentInteractions[commentId];
    final wasLiked = currentStatus?['isLiked'] ?? false;

    // Calculate new counts
    var newLikeCount = comment.likeCount;
    var newDislikeCount = comment.dislikeCount;
    if (wasLiked) {
      newLikeCount = (newLikeCount - 1).clamp(0, double.maxFinite.toInt());
      userCommentInteractions[commentId] = {
        'isLiked': false,
        'isDisliked': false,
      };
    } else {
      newLikeCount += 1;
      if (currentStatus?['isDisliked'] ?? false) {
        newDislikeCount = (newDislikeCount - 1).clamp(
          0,
          double.maxFinite.toInt(),
        );
      }
      userCommentInteractions[commentId] = {
        'isLiked': true,
        'isDisliked': false,
      };
    }

    final isVideoCreator = video != null && currentUserId == video!.ownerId;
    final creatorName = video?.channelName.isNotEmpty ?? false
        ? video!.channelName
        : 'Creator';
    var newIsHeartedByCreator = comment.isHeartedByCreator;
    var newCreatorHeartName = comment.creatorHeartName;

    if (isVideoCreator) {
      if (wasLiked) {
        newIsHeartedByCreator = false;
        newCreatorHeartName = null;
      } else {
        newIsHeartedByCreator = true;
        newCreatorHeartName = creatorName;
      }
    }

    comments[index] = comment.copyWith(
      likeCount: newLikeCount,
      dislikeCount: newDislikeCount,
      isHeartedByCreator: newIsHeartedByCreator,
      creatorHeartName: newCreatorHeartName,
    );
    comments.refresh();

    // --- Backend API Call ---
    try {
      if (wasLiked) {
        await commentService.removeCommentInteraction(
          videoId: video!.id,
          commentId: commentId,
          userId: userId,
          isVideoCreator: isVideoCreator,
        );
      } else {
        triggerLikeNotification(comment);
        await commentService.likeComment(
          videoId: video!.id,
          commentId: commentId,
          userId: userId,
          asChannel: likeAsChannel,
          isVideoCreator: isVideoCreator,
          creatorName: creatorName,
        );
      }
    } catch (e) {
      // Revert on error
      comments[index] = comment;
      userCommentInteractions[commentId] =
          currentStatus ??
          {
            'isLiked': false,
            'isDisliked': false,
          };
      comments.refresh();
      ErrorHandler.log(e, context: 'CommentsController.toggleCommentLike');
      AppSnackbar.error('Unable to update interaction. Please try again.');
    }
  }

  /// Toggle dislike on comment
  Future<void> toggleCommentDislike({
    required String commentId,
    required bool dislikeAsChannel,
  }) async {
    if (!AuthService.to.isAuthenticated.value || video == null) return;

    final userId = currentUserId;
    if (userId.isEmpty) return;

    // --- Optimistic UI Update ---
    final index = comments.indexWhere((c) => c.id == commentId);
    if (index == -1) return;

    final comment = comments[index];
    final currentStatus = userCommentInteractions[commentId];
    final wasDisliked = currentStatus?['isDisliked'] ?? false;

    // Calculate new counts
    var newLikeCount = comment.likeCount;
    var newDislikeCount = comment.dislikeCount;
    if (wasDisliked) {
      newDislikeCount = (newDislikeCount - 1).clamp(
        0,
        double.maxFinite.toInt(),
      );
      userCommentInteractions[commentId] = {
        'isLiked': false,
        'isDisliked': false,
      };
    } else {
      newDislikeCount += 1;
      if (currentStatus?['isLiked'] ?? false) {
        newLikeCount = (newLikeCount - 1).clamp(0, double.maxFinite.toInt());
      }
      userCommentInteractions[commentId] = {
        'isLiked': false,
        'isDisliked': true,
      };
    }

    final isVideoCreator = video != null && currentUserId == video!.ownerId;
    var newIsHeartedByCreator = comment.isHeartedByCreator;
    var newCreatorHeartName = comment.creatorHeartName;

    if (isVideoCreator) {
      newIsHeartedByCreator = false;
      newCreatorHeartName = null;
    }

    comments[index] = comment.copyWith(
      likeCount: newLikeCount,
      dislikeCount: newDislikeCount,
      isHeartedByCreator: newIsHeartedByCreator,
      creatorHeartName: newCreatorHeartName,
    );
    comments.refresh();

    // --- Backend API Call ---
    try {
      if (wasDisliked) {
        await commentService.removeCommentInteraction(
          videoId: video!.id,
          commentId: commentId,
          userId: userId,
          isVideoCreator: isVideoCreator,
        );
      } else {
        await commentService.dislikeComment(
          videoId: video!.id,
          commentId: commentId,
          userId: userId,
          asChannel: dislikeAsChannel,
          isVideoCreator: isVideoCreator,
        );
      }
    } catch (e) {
      // Revert on error
      comments[index] = comment;
      userCommentInteractions[commentId] =
          currentStatus ??
          {
            'isLiked': false,
            'isDisliked': false,
          };
      comments.refresh();
      ErrorHandler.log(e, context: 'CommentsController.toggleCommentDislike');
      AppSnackbar.error('Unable to update interaction. Please try again.');
    }
  }

  /// Check if current user has liked a comment
  bool isCommentLikedByUser(Comment comment) {
    if (currentUserId.isEmpty) return false;
    return userCommentInteractions[comment.id]?['isLiked'] ?? false;
  }

  /// Check if current user has disliked a comment
  bool isCommentDislikedByUser(Comment comment) {
    if (currentUserId.isEmpty) return false;
    return userCommentInteractions[comment.id]?['isDisliked'] ?? false;
  }

  /// Get who liked the comment (formatted display)
  String getLikedByText(Comment comment) {
    final count = comment.likeCount;
    if (count == 0) return '';
    if (count == 1) return 'Liked by 1 user';
    return 'Liked by $count users';
  }

  void triggerLikeNotification(Comment comment) {
    if (video == null ||
        currentUserId.isEmpty ||
        currentUserId == comment.userId) {
      return;
    }

    final authService = AuthService.to;
    final notificationService = UserNotificationService();
    notificationService.createNotification(
      userId: comment.userId,
      type: 'comment_like',
      severity: NotificationSeverity.info,
      title: 'Comment Liked',
      message:
          '${authService.activeHandle} liked your comment: "${comment.text}"',
      actionUrl: '/watch?v=${video!.id}',
      metadata: {
        'videoId': video!.id,
        'commentId': comment.id,
        'thumbnailUrl': video!.thumbnailUrl,
        'channelId': video!.channelId,
        'userAvatar': authService.activePhotoUrl,
      },
    );
  }
}
