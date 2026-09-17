import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/mentions_helper.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/notifications/data/models/user_notification.dart';
import 'package:truthworld/features/notifications/data/services/user_notification_service.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/video.dart';
/// Premium Comments Controller with GetX - handles all comment-related logic
/// 100% GetX reactive with optimized Firestore queries for low latency
import 'package:truthworld/features/video/data/repositories/firestore_comments_repository.dart';
import 'package:truthworld/features/video/data/services/comment_service.dart';
import 'package:truthworld/features/video/domain/repositories/video_comments_repository.dart';

class CommentsController extends BaseController with ContentValidationMixin {
  CommentsController({
    this.video,
    this.isOffline = false,
    VideoCommentsRepository? commentsRepository,
  }) : _commentsRepository = commentsRepository ?? FirestoreCommentsRepository();

  final VideoCommentsRepository _commentsRepository;

  Stream<List<Comment>> streamCommentsRepo(String videoId) {
    return _commentsRepository.streamComments(videoId);
  }
  final CommentService _commentService = CommentService();

  // Video data
  Video? video;
  @override
  bool isOffline;

  // Reactive state
  final comments = RxList<Comment>();
  final RxBool isLoadingComments = false.obs;
  final RxBool hasMoreComments = true.obs;
  final commentsError = Rx<String?>(null);
  final RxBool isSortNewest = false.obs;

  // Reactive targets for comment/reply deep linking
  final targetCommentId = Rx<String?>(null);
  final targetReplyId = Rx<String?>(null);
  bool hasScrolledToTarget = false;

  // For creating comments
  final RxBool isSubmittingComment = false.obs;
  final commentError = Rx<String?>(null);

  // For interactions (likes/dislikes)
  final userCommentInteractions = RxMap<String, Map<String, bool>>();
  // Structure: {commentId/replyId: {'isLiked': bool, 'isDisliked': bool}}

  // Pagination
  static const int _commentsPerPage = 20;

  // Current user info
  String get currentUserId => AuthService.to.uid;
  String get currentUserName => AuthService.to.activeDisplayName;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments != null) {
      if (Get.arguments['commentId'] != null) {
        targetCommentId.value = Get.arguments['commentId'] as String?;
      }
      if (Get.arguments['replyId'] != null) {
        targetReplyId.value = Get.arguments['replyId'] as String?;
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

  final RxBool isCounterArgumentFlipped = false.obs;

  void sortComments(bool newest) {
    isSortNewest.value = newest;
    isCounterArgumentFlipped.value = false;
    if (newest) {
      comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      comments.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    }
  }

  void toggleCounterArgumentSort() {
    isCounterArgumentFlipped.toggle();
    if (isCounterArgumentFlipped.value) {
      const contrastKeywords = [
        'however',
        'disagree',
        'perspective',
        'contrary',
        'evidence',
      ];

      // O(N) precomputation pass: memoize contrast match per comment to avoid
      // repeated string lowercasing and substring search inside O(N log N) comparator.
      final contrastMap = <String, bool>{};
      for (final comment in comments) {
        final text = comment.text.toLowerCase();
        var hasContrast = false;
        for (final kw in contrastKeywords) {
          if (text.contains(kw)) {
            hasContrast = true;
            break;
          }
        }
        contrastMap[comment.id] = hasContrast;
      }

      comments.sort((a, b) {
        final contrastA = contrastMap[a.id] ?? false;
        final contrastB = contrastMap[b.id] ?? false;

        if (contrastA && !contrastB) return -1;
        if (!contrastA && contrastB) return 1;
        return b.likeCount.compareTo(a.likeCount);
      });
    } else {
      sortComments(isSortNewest.value);
    }
  }

  Future<void> _loadUserInteractions() async {
    if (currentUserId.isEmpty || video == null) return;

    try {
      final commentInteractSnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(currentUserId)
          .collection('comment_interactions')
          .where('videoId', isEqualTo: video!.id)
          .get();

      for (final doc in commentInteractSnap.docs) {
        final data = doc.data();
        final type = data['type'];
        final commentId = doc.id;
        userCommentInteractions[commentId] = {
          'isLiked': type == 'like',
          'isDisliked': type == 'dislike',
        };
      }

      final replyInteractSnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(currentUserId)
          .collection('reply_interactions')
          .where('videoId', isEqualTo: video!.id)
          .get();

      for (final doc in replyInteractSnap.docs) {
        final data = doc.data();
        final type = data['type'];
        final replyId = doc.id;
        userCommentInteractions[replyId] = {
          'isLiked': type == 'like',
          'isDisliked': type == 'dislike',
        };
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CommentsController._loadUserInteractions',
      );
    }
  }

  void _initializeComments() {
    if (video == null) return;

    // Load user interactions in background
    _loadUserInteractions();

    // Stream comments
    trackSubscription(_commentService
        .getCommentsStream(
          videoId: video!.id,
        )
        .listen(
          (loadedComments) async {
            final targetId = targetCommentId.value;
            if (targetId != null && targetId.isNotEmpty) {
              final containsTarget = loadedComments.any(
                (c) => c.id == targetId,
              );
              if (!containsTarget) {
                try {
                  final targetComment = await _commentService.getComment(
                    video!.id,
                    targetId,
                  );
                  if (targetComment != null) {
                    loadedComments.insert(0, targetComment);
                  }
                } catch (e, stackTrace) {
                  ErrorHandler.log(
                    e,
                    stackTrace: stackTrace,
                    tag: 'CommentsController._initializeComments.deepLink',
                  );
                }
              }
            }

            comments.value = loadedComments;
            sortComments(isSortNewest.value);
            isLoadingComments.value = false;
            hasMoreComments.value = loadedComments.length >= _commentsPerPage;
            commentsError.value = null;
          },
          onError: (e, stackTrace) {
            ErrorHandler.log(
              e,
              stackTrace: stackTrace,
              tag: 'CommentsController._initializeComments',
            );
            commentsError.value = AppException.from(e, stackTrace).displayMessage;
            isLoadingComments.value = false;
          },
        ));
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
    String? userProfilePicUrl,
    double donationAmount = 0.0,
    String donationCurrency = r'$',
    bool isDonatedComment = false,
    String? donationColorHex,
  }) async {
    if (text.trim().isEmpty) {
      throw Exception('Comment cannot be empty');
    }

    if (video == null) {
      throw Exception('Video not loaded');
    }

    if (!AuthService.to.isAuthenticated.value || currentUserId.isEmpty) {
      throw Exception('User not authenticated');
    }

    final validation = await validateContent(text, fieldName: 'Comment');
    if (!validation.isValid) {
      commentError.value = validation.message;
      throw Exception(validation.message);
    }

    try {
      isSubmittingComment.value = true;
      commentError.value = null;

      final authService = AuthService.to;
      final hasChannel =
          authService.hasChannel.value && authService.userChannel != null;

      final finalUserName = authService.activeDisplayName;
      final finalUserProfilePicUrl =
          userProfilePicUrl ?? authService.activePhotoUrl;
      final finalChannelId = (channelId != null && channelId.isNotEmpty)
          ? channelId
          : (hasChannel ? authService.userChannel!.id : channelId);
      final finalChannelName = (channelName != null && channelName.isNotEmpty)
          ? channelName
          : (hasChannel
                ? (authService.userChannel?.handle.isNotEmpty == true
                      ? authService.userChannel!.handle
                      : authService.userChannel!.name)
                : authService.activeDisplayName);
      final finalChannelProfilePicUrl =
          channelProfilePicUrl ?? authService.activePhotoUrl;

      final commentId = await _commentService.addComment(
        videoId: video!.id,
        userId: currentUserId,
        userName: finalUserName,
        userProfilePicUrl: finalUserProfilePicUrl,
        channelId: finalChannelId ?? currentUserId,
        channelName: finalChannelName,
        channelProfilePicUrl: finalChannelProfilePicUrl,
        text: text.trim(),
        donationAmount: donationAmount,
        donationCurrency: donationCurrency,
        isDonatedComment: isDonatedComment,
        donationColorHex: donationColorHex,
      );

      if (donationAmount > 0 && video?.channelId.isNotEmpty == true) {
        try {
          await FirebaseFirestore.instance
              .collection(FirestoreCollections.channels)
              .doc(video!.channelId)
              .collection('donations')
              .add({
                'amount': donationAmount,
                'currency': donationCurrency,
                'donorId': currentUserId,
                'donorName': finalUserName,
                'videoId': video!.id,
                'commentId': commentId,
                'donatedAt': FieldValue.serverTimestamp(),
                'type': 'super_thanks',
              });
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'CommentsController.recordDonation',
          );
        }
      }

      try {
        await MentionsHelper.processAndNotifyMentions(
          text: text.trim(),
          videoId: video!.id,
          videoTitle: video!.title,
          videoThumbnailUrl: video!.thumbnailUrl,
          videoChannelId: video!.channelId,
          commentId: commentId,
        );
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'CommentsController.processMentionsInComment',
        );
      }

      commentError.value = null;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'CommentsController.addComment',
      );
      commentError.value =
          'Unable to post comment. Please check your connection and try again.';
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
        await _commentService.removeCommentInteraction(
          videoId: video!.id,
          commentId: commentId,
          userId: userId,
          isVideoCreator: isVideoCreator,
        );
      } else {
        _triggerLikeNotification(comment);
        await _commentService.likeComment(
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
        await _commentService.removeCommentInteraction(
          videoId: video!.id,
          commentId: commentId,
          userId: userId,
          isVideoCreator: isVideoCreator,
        );
      } else {
        await _commentService.dislikeComment(
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
      ErrorHandler.log(e, context: 'CommentsController.deleteComment');
      AppSnackbar.error('Unable to delete comment. Please try again.');
    }
  }

  // ============================================================================
  // REPLY OPERATIONS
  // ============================================================================

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

    final validation = await validateContent(text, fieldName: 'Reply');
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
      final finalChannelId = hasChannel
          ? authService.userChannel!.id
          : channelId;
      final finalChannelName = hasChannel
          ? (authService.userChannel?.handle.isNotEmpty == true
                ? authService.userChannel!.handle
                : authService.userChannel!.name)
          : authService.activeDisplayName;
      final finalChannelProfilePicUrl = authService.activePhotoUrl;

      final replyId = await _commentService.addReply(
        videoId: video!.id,
        commentId: commentId,
        userId: currentUserId,
        userName: finalUserName,
        userProfilePicUrl: finalUserProfilePicUrl,
        channelId: finalChannelId ?? currentUserId,
        channelName: finalChannelName,
        channelProfilePicUrl: finalChannelProfilePicUrl,
        text: text.trim(),
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
        await _commentService.removeReplyInteraction(
          videoId: video!.id,
          commentId: commentId,
          replyId: replyId,
          userId: userId,
        );
      } else {
        if (replyAuthorId != null &&
            replyAuthorId.isNotEmpty &&
            replyAuthorId != userId) {
          _triggerReplyLikeNotification(
            commentId,
            replyId,
            replyAuthorId,
            replyText,
          );
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
      await _commentService.deleteReply(video!.id, commentId, replyId);
    } catch (e) {
      ErrorHandler.log(e, context: 'CommentsController.deleteReply');
      AppSnackbar.error('Unable to delete reply. Please try again.');
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

  void _triggerReplyLikeNotification(
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

  @override
  void onClose() {
    comments.clear();
    userCommentInteractions.clear();
    super.onClose();
  }
}
