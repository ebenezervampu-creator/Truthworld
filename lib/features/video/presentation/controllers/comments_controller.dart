import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/comment_service.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/data/services/user_notification_service.dart';
import 'package:truthworld/core/utils/mentions_helper.dart';

/// Premium Comments Controller with GetX - handles all comment-related logic
/// 100% GetX reactive with optimized Firestore queries for low latency
class CommentsController extends BaseController {
  final CommentService _commentService = CommentService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Video data
  Video? video;
  bool isOffline;

  // Reactive state
  final comments = RxList<Comment>();
  final isLoadingComments = false.obs;
  final hasMoreComments = true.obs;
  final commentsError = Rx<String?>(null);
  final isSortNewest = false.obs;

  // Reactive targets for comment/reply deep linking
  final targetCommentId = Rx<String?>(null);
  final targetReplyId = Rx<String?>(null);
  bool hasScrolledToTarget = false;

  // For creating comments
  final isSubmittingComment = false.obs;
  final commentError = Rx<String?>(null);

  // For interactions (likes/dislikes)
  final userCommentInteractions = RxMap<String, Map<String, bool>>();
  // Structure: {commentId/replyId: {'isLiked': bool, 'isDisliked': bool}}

  // Pagination
  static const int _commentsPerPage = 20;

  // Current user info
  String get currentUserId => _auth.currentUser?.uid ?? '';
  String get currentUserName =>
      _auth.currentUser?.displayName ?? 'Anonymous User';

  CommentsController({this.video, this.isOffline = false});

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments != null) {
      if (Get.arguments["commentId"] != null) {
        targetCommentId.value = Get.arguments["commentId"] as String?;
      }
      if (Get.arguments["replyId"] != null) {
        targetReplyId.value = Get.arguments["replyId"] as String?;
      }
    }
    if (video != null && !isOffline) {
      _initializeComments();
    }
  }

  void enableOnlineMode() {
    if (isOffline && video != null) {
      isOffline = false;
      _initializeComments();
    }
  }

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  void sortComments(bool newest) {
    isSortNewest.value = newest;
    if (newest) {
      comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      comments.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    }
  }

  Future<void> _loadUserInteractions() async {
    if (currentUserId.isEmpty || video == null) return;

    try {
      final commentInteractSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('comment_interactions')
          .where('videoId', isEqualTo: video!.id)
          .get();

      for (var doc in commentInteractSnap.docs) {
        final data = doc.data();
        final type = data['type'];
        final commentId = doc.id;
        userCommentInteractions[commentId] = {
          'isLiked': type == 'like',
          'isDisliked': type == 'dislike',
        };
      }

      final replyInteractSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('reply_interactions')
          .where('videoId', isEqualTo: video!.id)
          .get();

      for (var doc in replyInteractSnap.docs) {
        final data = doc.data();
        final type = data['type'];
        final replyId = doc.id;
        userCommentInteractions[replyId] = {
          'isLiked': type == 'like',
          'isDisliked': type == 'dislike',
        };
      }
    } catch (e) {
      debugPrint('[CommentsController] Error loading user interactions: $e');
    }
  }

  void _initializeComments() {
    if (video == null) return;

    // Load user interactions in background
    _loadUserInteractions();

    // Stream comments
    _commentService
        .getCommentsStream(
      videoId: video!.id,
      limit: _commentsPerPage,
    )
        .listen(
      (loadedComments) async {
        final targetId = targetCommentId.value;
        if (targetId != null && targetId.isNotEmpty) {
          final containsTarget = loadedComments.any((c) => c.id == targetId);
          if (!containsTarget) {
            try {
              final targetComment = await _commentService.getComment(video!.id, targetId);
              if (targetComment != null) {
                loadedComments.insert(0, targetComment);
              }
            } catch (e) {
              debugPrint('⚠️ Error fetching deep-linked comment: $e');
            }
          }
        }

        comments.value = loadedComments;
        sortComments(isSortNewest.value);
        isLoadingComments.value = false;
        hasMoreComments.value = loadedComments.length >= _commentsPerPage;
        commentsError.value = null;
      },
      onError: (e) {
        commentsError.value = e.toString();
        isLoadingComments.value = false;
      },
    );
  }

  // ============================================================================
  // CREATE COMMENTS
  // ============================================================================

  /// Submit a new comment
  Future<void> submitComment({
    required String text,
    String? channelId,
    String? channelName,
    String? channelProfilePicUrl,
    required String userProfilePicUrl,
  }) async {
    if (text.trim().isEmpty) {
      throw Exception('Comment cannot be empty');
    }

    if (video == null) {
      throw Exception('Video not loaded');
    }

    if (currentUserId.isEmpty) {
      throw Exception('User not authenticated');
    }

    try {
      isSubmittingComment.value = true;
      commentError.value = null;

      final commentId = await _commentService.addComment(
        videoId: video!.id,
        userId: currentUserId,
        userName: currentUserName,
        userProfilePicUrl: userProfilePicUrl,
        channelId: channelId ?? currentUserId,
        channelName: channelName,
        channelProfilePicUrl: channelProfilePicUrl,
        text: text.trim(),
      );

      try {
        await MentionsHelper.processAndNotifyMentions(
          text: text.trim(),
          videoId: video!.id,
          videoTitle: video!.title,
          videoThumbnailUrl: video!.thumbnailUrl,
          videoChannelId: video!.channelId,
          commentId: commentId,
        );
      } catch (e) {
        debugPrint('⚠️ Error processing mentions in comment: $e');
      }

      commentError.value = null;
    } catch (e) {
      commentError.value = e.toString();
      rethrow; // Re-throw so the UI can handle it
    } finally {
      isSubmittingComment.value = false;
    }
  }

  // ============================================================================
  // COMMENT INTERACTIONS - Likes/Dislikes
  // ============================================================================

  /// Toggle like on comment with channel option
  Future<void> toggleCommentLike({
    required String commentId,
    required bool likeAsChannel,
  }) async {
    if (video == null) return;

    final userId = currentUserId;
    if (userId.isEmpty) return;

    // --- Optimistic UI Update ---
    final index = comments.indexWhere((c) => c.id == commentId);
    if (index == -1) return;

    final comment = comments[index];
    final currentStatus = userCommentInteractions[commentId];
    final wasLiked = currentStatus?['isLiked'] ?? false;

    // Calculate new counts
    int newLikeCount = comment.likeCount;
    int newDislikeCount = comment.dislikeCount;
    if (wasLiked) {
      newLikeCount = (newLikeCount - 1).clamp(0, double.maxFinite.toInt());
      userCommentInteractions[commentId] = {
        'isLiked': false,
        'isDisliked': false,
      };
    } else {
      newLikeCount += 1;
      if (currentStatus?['isDisliked'] == true) {
        newDislikeCount = (newDislikeCount - 1).clamp(0, double.maxFinite.toInt());
      }
      userCommentInteractions[commentId] = {
        'isLiked': true,
        'isDisliked': false,
      };
    }

    comments[index] = comment.copyWith(
      likeCount: newLikeCount,
      dislikeCount: newDislikeCount,
    );
    comments.refresh();

    // --- Backend API Call ---
    try {
      if (wasLiked) {
        await _commentService.removeCommentInteraction(
          videoId: video!.id,
          commentId: commentId,
          userId: userId,
        );
      } else {
        _triggerLikeNotification(comment);
        await _commentService.likeComment(
          videoId: video!.id,
          commentId: commentId,
          userId: userId,
          asChannel: likeAsChannel,
        );
      }
    } catch (e) {
      // Revert on error
      comments[index] = comment;
      userCommentInteractions[commentId] = currentStatus ?? {
        'isLiked': false,
        'isDisliked': false,
      };
      comments.refresh();
      Get.snackbar('Error', 'Failed to update interaction');
    }
  }

  /// Toggle dislike on comment
  Future<void> toggleCommentDislike({
    required String commentId,
    required bool dislikeAsChannel,
  }) async {
    if (video == null) return;

    final userId = currentUserId;
    if (userId.isEmpty) return;

    // --- Optimistic UI Update ---
    final index = comments.indexWhere((c) => c.id == commentId);
    if (index == -1) return;

    final comment = comments[index];
    final currentStatus = userCommentInteractions[commentId];
    final wasDisliked = currentStatus?['isDisliked'] ?? false;

    // Calculate new counts
    int newLikeCount = comment.likeCount;
    int newDislikeCount = comment.dislikeCount;
    if (wasDisliked) {
      newDislikeCount = (newDislikeCount - 1).clamp(0, double.maxFinite.toInt());
      userCommentInteractions[commentId] = {
        'isLiked': false,
        'isDisliked': false,
      };
    } else {
      newDislikeCount += 1;
      if (currentStatus?['isLiked'] == true) {
        newLikeCount = (newLikeCount - 1).clamp(0, double.maxFinite.toInt());
      }
      userCommentInteractions[commentId] = {
        'isLiked': false,
        'isDisliked': true,
      };
    }

    comments[index] = comment.copyWith(
      likeCount: newLikeCount,
      dislikeCount: newDislikeCount,
    );
    comments.refresh();

    // --- Backend API Call ---
    try {
      if (wasDisliked) {
        await _commentService.removeCommentInteraction(
          videoId: video!.id,
          commentId: commentId,
          userId: userId,
        );
      } else {
        await _commentService.dislikeComment(
          videoId: video!.id,
          commentId: commentId,
          userId: userId,
          asChannel: dislikeAsChannel,
        );
      }
    } catch (e) {
      // Revert on error
      comments[index] = comment;
      userCommentInteractions[commentId] = currentStatus ?? {
        'isLiked': false,
        'isDisliked': false,
      };
      comments.refresh();
      Get.snackbar('Error', 'Failed to update interaction');
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

  // ============================================================================
  // PAGINATION
  // ============================================================================

  Future<void> loadMoreComments() async {
    if (video == null || !hasMoreComments.value) return;

    try {
      // This would be implemented with pagination logic
      // For now, Firestore real-time updates handle this
    } catch (e) {
      commentsError.value = e.toString();
    }
  }

  // ============================================================================
  // DELETE COMMENTS
  // ============================================================================

  Future<void> deleteComment(String commentId) async {
    if (video == null) return;

    try {
      await _commentService.deleteComment(video!.id, commentId);
      comments.removeWhere((c) => c.id == commentId);
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete comment: $e');
    }
  }

  // ============================================================================
  // REPLY OPERATIONS
  // ============================================================================

  /// Add a reply to a comment
  Future<void> submitReply({
    required String commentId,
    required String text,
    String? channelId,
    String? channelName,
    String? channelProfilePicUrl,
    required String userProfilePicUrl,
    String? commentAuthorId,
  }) async {
    if (text.trim().isEmpty || video == null) return;

    try {
      isSubmittingComment.value = true;
      commentError.value = null;

      final replyId = await _commentService.addReply(
        videoId: video!.id,
        commentId: commentId,
        userId: currentUserId,
        userName: currentUserName,
        userProfilePicUrl: userProfilePicUrl,
        channelId: channelId ?? currentUserId,
        channelName: channelName,
        channelProfilePicUrl: channelProfilePicUrl,
        text: text.trim(),
      );

      if (commentAuthorId != null && commentAuthorId.isNotEmpty && commentAuthorId != currentUserId) {
        final notificationService = UserNotificationService();
        notificationService.createNotification(
          userId: commentAuthorId,
          type: 'comment_reply',
          severity: NotificationSeverity.info,
          title: 'New Reply',
          message: '@$currentUserName replied to your comment: "${text.trim()}"',
          actionUrl: '/watch?v=${video!.id}',
          metadata: {
            'videoId': video!.id,
            'commentId': commentId,
            'replyId': replyId,
            'thumbnailUrl': video!.thumbnailUrl,
            'channelId': video!.channelId,
            'userAvatar': _auth.currentUser?.photoURL ?? '',
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
      } catch (e) {
        debugPrint('⚠️ Error processing mentions in reply: $e');
      }

      commentError.value = null;
    } catch (e) {
      commentError.value = e.toString();
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
    if (video == null) return;

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
        await _commentService.removeReplyInteraction(
          videoId: video!.id,
          commentId: commentId,
          replyId: replyId,
          userId: userId,
        );
      } else {
        if (replyAuthorId != null && replyAuthorId.isNotEmpty && replyAuthorId != userId) {
          _triggerReplyLikeNotification(commentId, replyId, replyAuthorId, replyText);
        }
        await _commentService.likeReply(
          videoId: video!.id,
          commentId: commentId,
          replyId: replyId,
          userId: userId,
          asChannel: likeAsChannel,
        );
      }
    } catch (e) {
      userCommentInteractions[replyId] = currentStatus ?? {
        'isLiked': false,
        'isDisliked': false,
      };
      Get.snackbar('Error', 'Failed to like reply');
    }
  }

  /// Toggle dislike on reply
  Future<void> toggleReplyDislike({
    required String commentId,
    required String replyId,
    required bool dislikeAsChannel,
  }) async {
    if (video == null) return;

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
        await _commentService.removeReplyInteraction(
          videoId: video!.id,
          commentId: commentId,
          replyId: replyId,
          userId: userId,
        );
      } else {
        await _commentService.dislikeReply(
          videoId: video!.id,
          commentId: commentId,
          replyId: replyId,
          userId: userId,
          asChannel: dislikeAsChannel,
        );
      }
    } catch (e) {
      userCommentInteractions[replyId] = currentStatus ?? {
        'isLiked': false,
        'isDisliked': false,
      };
      Get.snackbar('Error', 'Failed to dislike reply');
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
      await _commentService.deleteReply(video!.id, commentId, replyId);
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete reply: $e');
    }
  }

  // ============================================================================
  // UTILITIES
  // ============================================================================

  /// Get who liked the comment (formatted display)
  String getLikedByText(Comment comment) {
    final count = comment.likeCount;
    if (count == 0) return '';
    if (count == 1) return 'Liked by 1 user';
    return 'Liked by $count users';
  }

  void _triggerLikeNotification(Comment comment) {
    if (video == null || currentUserId.isEmpty || currentUserId == comment.userId) return;
    
    final notificationService = UserNotificationService();
    notificationService.createNotification(
      userId: comment.userId,
      type: 'comment_like',
      severity: NotificationSeverity.info,
      title: 'Comment Liked',
      message: '@$currentUserName liked your comment: "${comment.text}"',
      actionUrl: '/watch?v=${video!.id}',
      metadata: {
        'videoId': video!.id,
        'commentId': comment.id,
        'thumbnailUrl': video!.thumbnailUrl,
        'channelId': video!.channelId,
        'userAvatar': _auth.currentUser?.photoURL ?? '',
      },
    );
  }

  void _triggerReplyLikeNotification(String commentId, String replyId, String? replyAuthorId, String? replyText) {
    if (video == null || currentUserId.isEmpty || replyAuthorId == null || replyAuthorId.isEmpty || currentUserId == replyAuthorId) return;
    
    final notificationService = UserNotificationService();
    notificationService.createNotification(
      userId: replyAuthorId,
      type: 'reply_like',
      severity: NotificationSeverity.info,
      title: 'Reply Liked',
      message: '@$currentUserName liked your reply: "${replyText ?? ''}"',
      actionUrl: '/watch?v=${video!.id}',
      metadata: {
        'videoId': video!.id,
        'commentId': commentId,
        'replyId': replyId,
        'thumbnailUrl': video!.thumbnailUrl,
        'channelId': video!.channelId,
        'userAvatar': _auth.currentUser?.photoURL ?? '',
      },
    );
  }

  @override
  void onClose() {
    comments.clear();
    userCommentInteractions.clear();
    super.onClose();
  }
}
