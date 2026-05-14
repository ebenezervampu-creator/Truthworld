import 'package:get/get.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:truthworld/features/video/data/models/comment.dart';

import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/comment_service.dart';
import 'package:truthworld/core/base/base_controller.dart';

/// Premium Comments Controller with GetX - handles all comment-related logic
/// 100% GetX reactive with optimized Firestore queries for low latency
class CommentsControllerV2 extends BaseController {
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

  // For creating comments
  final isSubmittingComment = false.obs;
  final commentError = Rx<String?>(null);

  // For interactions (likes/dislikes)
  final userCommentInteractions = RxMap<String, Map<String, bool>>();
  // Structure: {commentId: {'isLiked': bool, 'isDisliked': bool, 'asChannel': bool}}

  // Pagination

  static const int _commentsPerPage = 20;

  // Current user info
  String get currentUserId => _auth.currentUser?.uid ?? '';
  String get currentUserName =>
      _auth.currentUser?.displayName ?? 'Anonymous User';

  CommentsControllerV2({this.video, this.isOffline = false});

  @override
  void onInit() {
    super.onInit();
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

  void _initializeComments() {
    if (video == null) return;

    // Stream comments
    _commentService
        .getCommentsStream(
      videoId: video!.id,
      limit: _commentsPerPage,
    )
        .listen(
      (loadedComments) {
        comments.value = loadedComments;
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

      await _commentService.addComment(
        videoId: video!.id,
        userId: currentUserId,
        userName: currentUserName,
        userProfilePicUrl: userProfilePicUrl,
        channelId: channelId ?? currentUserId,
        channelName: channelName,
        channelProfilePicUrl: channelProfilePicUrl,
        text: text.trim(),
      );

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
    final key = likeAsChannel ? '${userId}_channel' : '${userId}_user';
    final wasLiked = comment.likedBy.containsKey(key);

    final updatedLikedBy = Map<String, bool>.from(comment.likedBy);
    final updatedDislikedBy = Map<String, bool>.from(comment.dislikedBy);

    if (wasLiked) {
      updatedLikedBy.remove(key);
    } else {
      updatedLikedBy[key] = true;
      updatedDislikedBy.remove(key);
    }

    comments[index] = comment.copyWith(
      likedBy: updatedLikedBy,
      dislikedBy: updatedDislikedBy,
      likeCount: updatedLikedBy.length,
      dislikeCount: updatedDislikedBy.length,
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
    final key = dislikeAsChannel ? '${userId}_channel' : '${userId}_user';
    final wasDisliked = comment.dislikedBy.containsKey(key);

    final updatedLikedBy = Map<String, bool>.from(comment.likedBy);
    final updatedDislikedBy = Map<String, bool>.from(comment.dislikedBy);

    if (wasDisliked) {
      updatedDislikedBy.remove(key);
    } else {
      updatedDislikedBy[key] = true;
      updatedLikedBy.remove(key);
    }

    comments[index] = comment.copyWith(
      likedBy: updatedLikedBy,
      dislikedBy: updatedDislikedBy,
      likeCount: updatedLikedBy.length,
      dislikeCount: updatedDislikedBy.length,
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
      comments.refresh();
      Get.snackbar('Error', 'Failed to update interaction');
    }
  }

  /// Check if current user has liked a comment
  bool isCommentLikedByUser(Comment comment) {
    if (currentUserId.isEmpty) return false;
    return comment.likedBy.containsKey('${currentUserId}_user') || 
           comment.likedBy.containsKey('${currentUserId}_channel');
  }

  /// Check if current user has disliked a comment
  bool isCommentDislikedByUser(Comment comment) {
    if (currentUserId.isEmpty) return false;
    return comment.dislikedBy.containsKey('${currentUserId}_user') || 
           comment.dislikedBy.containsKey('${currentUserId}_channel');
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
  }) async {
    if (text.trim().isEmpty || video == null) return;

    try {
      isSubmittingComment.value = true;
      commentError.value = null;

      await _commentService.addReply(
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
  }) async {
    if (video == null) return;
    
    final userId = currentUserId;
    if (userId.isEmpty) return;

    // --- Backend API Call (Not strictly optimistic yet as replies list isn't locally managed in controller) ---
    // Note: Re-fetching/streaming handles the UI update. 
    // For true optimistic here, we'd need a replies map.
    try {
      await _commentService.likeReply(
        videoId: video!.id,
        commentId: commentId,
        replyId: replyId,
        userId: userId,
        asChannel: likeAsChannel,
      );
    } catch (e) {
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

    try {
      final key = '${commentId}_$replyId';
      final currentState = userCommentInteractions[key];
      final isCurrentlyDisliked = currentState?['isDisliked'] ?? false;

      if (isCurrentlyDisliked && currentState?['asChannel'] == dislikeAsChannel) {
        // Remove dislike
        await _commentService.removeReplyInteraction(
          videoId: video!.id,
          commentId: commentId,
          replyId: replyId,
          userId: currentUserId,
        );
        userCommentInteractions[key] = {
          'isLiked': false,
          'isDisliked': false,
          'asChannel': false,
        };
      } else {
        // Add/update dislike
        await _commentService.dislikeReply(
          videoId: video!.id,
          commentId: commentId,
          replyId: replyId,
          userId: currentUserId,
          asChannel: dislikeAsChannel,
        );
        userCommentInteractions[key] = {
          'isLiked': false,
          'isDisliked': true,
          'asChannel': dislikeAsChannel,
        };
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to dislike reply: $e',
          snackPosition: SnackPosition.BOTTOM);
    }
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
    if (comment.likedBy.isEmpty) return '';

    final channelLikes =
        comment.likedBy.keys.where((k) => k.contains('_channel')).length;
    final userLikes =
        comment.likedBy.keys.where((k) => k.contains('_user')).length;

    if (channelLikes > 0 && userLikes > 0) {
      return 'Liked by channel and $userLikes other(s)';
    } else if (channelLikes > 0) {
      return 'Liked by channel';
    } else if (userLikes == 1) {
      return 'Liked by 1 user';
    } else {
      return 'Liked by $userLikes users';
    }
  }

  @override
  void onClose() {
    comments.clear();
    userCommentInteractions.clear();
    super.onClose();
  }
}





