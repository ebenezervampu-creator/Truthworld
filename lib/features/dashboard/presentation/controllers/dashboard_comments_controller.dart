import 'dart:async';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/services/comment_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/base/base_controller.dart';

/// Professional Dashboard Comments Controller (Industry Standard)
///
/// Handles creator's comment management across all their videos.
/// Features:
/// - Display videos with comment counts
/// - Fetch comments for every video from the channel by default
/// - Filter comments by answered/unanswered or specific video
/// - Sort by recency
/// - Reply to comments as channel
/// - Exception handling & logging
class DashboardCommentsController extends BaseController {
  final CommentService _commentService = CommentService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _tag = 'DashboardComments';

  // ═══════════════════════════════════════════════════════════════════════════
  // REACTIVE STATE
  // ═══════════════════════════════════════════════════════════════════════════

  /// List of creator's videos with comment counts
  final videosWithComments = RxList<CreatorVideoWithComments>();
  final isLoadingVideos = false.obs;
  final videosError = Rx<String?>(null);

  /// Map of videoId to loaded comments stream
  final Map<String, List<Comment>> _commentsByVideo = {};
  final List<StreamSubscription> _commentSubscriptions = [];

  /// Comments state
  final selectedVideoId = Rxn<String>(); // null means all videos
  final allComments = RxList<Comment>();
  final answeredComments = RxList<Comment>();
  final unansweredComments = RxList<Comment>();
  final commentsFilter = RxString('all'); // 'all', 'answered', 'unanswered'
  final isLoadingComments = false.obs;
  final commentsError = Rx<String?>(null);

  /// User comment interactions state
  final userCommentInteractions = RxMap<String, Map<String, bool>>();

  /// User info
  final userChannelId = RxString('');
  final userChannelName = RxString('');
  final userChannelAvatar = RxString('');

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void onInit() {
    super.onInit();
    _initializeUser();
  }

  @override
  void onClose() {
    for (final sub in _commentSubscriptions) {
      sub.cancel();
    }
    _commentSubscriptions.clear();
    userCommentInteractions.clear();
    super.onClose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // USER INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadUserInteractions() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('comment_interactions')
          .get();
      for (var doc in snap.docs) {
        final data = doc.data();
        final type = data['type'];
        userCommentInteractions[doc.id] = {
          'isLiked': type == 'like',
          'isDisliked': type == 'dislike',
        };
      }
    } catch (e) {
      logger.warning('Failed to load user comment interactions: $e', tag: _tag);
    }
  }

  Future<void> _initializeUser() async {
    try {
      isLoadingVideos.value = true;

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        videosError.value = 'Not authenticated';
        logger.warning('User not authenticated', tag: _tag);
        return;
      }

      // Check if channel was passed in Get.arguments
      final channelArg = Get.arguments?['channel'];
      if (channelArg != null) {
        if (channelArg is Map) {
          userChannelId.value = channelArg['id'] ?? '';
          userChannelName.value =
              channelArg['channelName'] ?? channelArg['name'] ?? '';
          userChannelAvatar.value =
              channelArg['channelProfilePicUrl'] ??
              channelArg['profilePicUrl'] ??
              '';
        } else if (channelArg is DocumentSnapshot) {
          userChannelId.value = channelArg.id;
          final data = channelArg.data() as Map<String, dynamic>?;
          if (data != null) {
            userChannelName.value = data['channelName'] ?? data['name'] ?? '';
            userChannelAvatar.value =
                data['channelProfilePicUrl'] ?? data['profilePicUrl'] ?? '';
          }
        }
      }

      // Fallback to user document if channel ID is still empty
      if (userChannelId.value.isEmpty) {
        final userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          userChannelId.value = data['channelId'] ?? currentUser.uid;
          userChannelName.value =
              data['channelName'] ?? currentUser.displayName ?? 'Your Channel';
          userChannelAvatar.value = data['channelProfilePicUrl'] ?? '';
        } else {
          userChannelId.value = currentUser.uid;
          userChannelName.value = currentUser.displayName ?? 'Your Channel';
        }
      }

      // Load user interactions and creator videos
      await _loadUserInteractions();
      _loadCreatorVideos();
    } catch (e, stackTrace) {
      logger.error(
        'Failed to initialize user',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      videosError.value = 'Failed to load user info';
    } finally {
      isLoadingVideos.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOAD VIDEOS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadCreatorVideos() async {
    try {
      isLoadingVideos.value = true;
      videosError.value = null;

      final channelId = userChannelId.value;
      if (channelId.isEmpty) {
        videosError.value = 'Channel ID not found';
        return;
      }

      // Get videos from Firestore
      final videosSnapshot = await _firestore
          .collection('videos')
          .where('channelId', isEqualTo: channelId)
          .orderBy('uploadedAt', descending: true)
          .get();

      final videos = <CreatorVideoWithComments>[];

      // Get comment counts for each video
      for (final videoDoc in videosSnapshot.docs) {
        final videoData = videoDoc.data();
        final commentCount = await _commentService.getCommentCount(videoDoc.id);

        videos.add(
          CreatorVideoWithComments(
            videoId: videoDoc.id,
            title: videoData['title'] ?? 'Untitled',
            thumbnail: videoData['thumbnailUrl'] ?? '',
            duration: videoData['duration'] ?? '0:00',
            viewCount: videoData['viewCount'] ?? 0,
            commentCount: commentCount,
            createdAt:
                (videoData['uploadedAt'] as Timestamp?)?.toDate() ??
                DateTime.now(),
          ),
        );
      }

      videosWithComments.value = videos;
      logger.info(
        'Loaded ${videos.length} videos with comment counts',
        tag: _tag,
      );

      // Automatically load comments for every video from the channel
      _loadAllCommentsForChannel();
    } catch (e, stackTrace) {
      logger.error(
        'Failed to load creator videos',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      videosError.value = 'Failed to load your videos';
    } finally {
      isLoadingVideos.value = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOAD ALL COMMENTS FOR CHANNEL
  // ═══════════════════════════════════════════════════════════════════════════

  void _loadAllCommentsForChannel() {
    for (final sub in _commentSubscriptions) {
      sub.cancel();
    }
    _commentSubscriptions.clear();
    _commentsByVideo.clear();
    selectedVideoId.value = null;
    isLoadingComments.value = true;
    commentsError.value = null;

    if (videosWithComments.isEmpty) {
      allComments.clear();
      _filterComments();
      isLoadingComments.value = false;
      return;
    }

    int completedStreams = 0;
    for (final video in videosWithComments) {
      final sub = _commentService
          .getVideoCommentsForStudio(video.videoId)
          .listen(
            (comments) {
              // Ensure each comment has its videoId populated robustly
              final populatedComments = comments
                  .map(
                    (c) => c.videoId.isEmpty
                        ? c.copyWith(videoId: video.videoId)
                        : c,
                  )
                  .toList();
              _commentsByVideo[video.videoId] = populatedComments;
              _updateMergedComments();

              completedStreams++;
              if (completedStreams >= videosWithComments.length) {
                isLoadingComments.value = false;
              }
            },
            onError: (e) {
              logger.error(
                'Failed to load comments for ${video.videoId}: $e',
                tag: _tag,
              );
              completedStreams++;
              if (completedStreams >= videosWithComments.length) {
                isLoadingComments.value = false;
              }
            },
          );
      _commentSubscriptions.add(sub);
    }
  }

  void _updateMergedComments() {
    final combined = <Comment>[];
    for (final list in _commentsByVideo.values) {
      combined.addAll(list);
    }
    combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    allComments.value = combined;
    _filterComments();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SELECT VIDEO
  // ═══════════════════════════════════════════════════════════════════════════

  void selectVideo(String? videoId) {
    selectedVideoId.value = videoId;
    _filterComments();
    logger.info(
      'Selected video switched to: ${videoId ?? "All Videos"}',
      tag: _tag,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILTER & SORT COMMENTS
  // ═══════════════════════════════════════════════════════════════════════════

  void setCommentFilter(String filter) {
    if (['all', 'answered', 'unanswered'].contains(filter)) {
      commentsFilter.value = filter;
      _filterComments();
      logger.info('Filter changed to: $filter', tag: _tag);
    }
  }

  void _filterComments() {
    try {
      final baseList = selectedVideoId.value == null
          ? allComments
          : allComments
                .where((c) => c.videoId == selectedVideoId.value)
                .toList();

      answeredComments.value = baseList
          .where((c) => c.hasCreatorReply == true)
          .toList();

      unansweredComments.value = baseList
          .where((c) => c.hasCreatorReply == false)
          .toList();

      logger.info(
        'Comments filtered: answered=${answeredComments.length}, '
        'unanswered=${unansweredComments.length}',
        tag: _tag,
      );
    } catch (e, stackTrace) {
      logger.error(
        'Failed to filter comments',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }
  }

  List<Comment> getFilteredComments() {
    final baseList = selectedVideoId.value == null
        ? allComments
        : allComments.where((c) => c.videoId == selectedVideoId.value).toList();

    switch (commentsFilter.value) {
      case 'answered':
        return answeredComments;
      case 'unanswered':
        return unansweredComments;
      default:
        return baseList;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CREATOR INTERACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Like a comment as channel
  Future<void> likeCommentAsChannel({
    required String videoId,
    required String commentId,
    required bool asChannel,
  }) async {
    try {
      final userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        logger.warning('User not authenticated for like', tag: _tag);
        return;
      }

      await _commentService.likeComment(
        videoId: videoId,
        commentId: commentId,
        userId: userId,
        asChannel: asChannel,
      );

      logger.info(
        'Liked comment $commentId as ${asChannel ? 'channel' : 'user'}',
        tag: _tag,
      );
    } catch (e, stackTrace) {
      logger.error(
        'Failed to like comment',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }
  }

  /// Dislike a comment as channel
  Future<void> dislikeCommentAsChannel({
    required String videoId,
    required String commentId,
    required bool asChannel,
  }) async {
    try {
      final userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        logger.warning('User not authenticated for dislike', tag: _tag);
        return;
      }

      await _commentService.dislikeComment(
        videoId: videoId,
        commentId: commentId,
        userId: userId,
        asChannel: asChannel,
      );

      logger.info(
        'Disliked comment $commentId as ${asChannel ? 'channel' : 'user'}',
        tag: _tag,
      );
    } catch (e, stackTrace) {
      logger.error(
        'Failed to dislike comment',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }
  }

  /// Heart a comment as creator
  Future<void> heartComment({
    required String videoId,
    required String commentId,
    required bool isHearted,
  }) async {
    try {
      await _commentService.heartComment(
        videoId: videoId,
        commentId: commentId,
        isHearted: isHearted,
        creatorName: userChannelName.value,
      );

      logger.info(
        '${isHearted ? 'Hearted' : 'Unhearted'} comment $commentId as creator',
        tag: _tag,
      );
    } catch (e, stackTrace) {
      logger.error(
        'Failed to heart comment',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }
  }

  /// Reply to a comment as channel
  Future<void> replyToCommentAsChannel({
    required String videoId,
    required String commentId,
    required String replyText,
  }) async {
    try {
      final userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        logger.warning('User not authenticated for reply', tag: _tag);
        return;
      }

      if (replyText.trim().isEmpty) {
        logger.warning('Reply text is empty', tag: _tag);
        return;
      }

      // Add reply
      await _commentService.addReply(
        videoId: videoId,
        commentId: commentId,
        userId: userId,
        userName: userChannelName.value,
        userProfilePicUrl: userChannelAvatar.value,
        channelId: userChannelId.value,
        channelName: userChannelName.value,
        channelProfilePicUrl: userChannelAvatar.value,
        text: replyText,
      );

      // Mark comment as answered
      await _commentService.markCommentAsAnswered(videoId, commentId);

      logger.info('Replied to comment $commentId as channel', tag: _tag);
    } catch (e, stackTrace) {
      logger.error(
        'Failed to reply to comment',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 30) return '${difference.inDays}d ago';

    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }

  String formatViewCount(int count) {
    if (count < 1000) return '$count';
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  /// Check if current user (creator) liked a comment
  bool isCommentLikedByCreator(Comment comment) {
    return userCommentInteractions[comment.id]?['isLiked'] ?? false;
  }

  /// Check if current user (creator) disliked a comment
  bool isCommentDislikedByCreator(Comment comment) {
    return userCommentInteractions[comment.id]?['isDisliked'] ?? false;
  }
}

/// Model for displaying creator videos with comment counts
class CreatorVideoWithComments {
  final String videoId;
  final String title;
  final String thumbnail;
  final String duration;
  final int viewCount;
  final int commentCount;
  final DateTime createdAt;

  CreatorVideoWithComments({
    required this.videoId,
    required this.title,
    required this.thumbnail,
    required this.duration,
    required this.viewCount,
    required this.commentCount,
    required this.createdAt,
  });

  String get formattedCommentCount =>
      commentCount == 1 ? '1 comment' : '$commentCount comments';
  String get formattedViewCount {
    if (viewCount < 1000) return '$viewCount';
    if (viewCount < 1000000) return '${(viewCount / 1000).toStringAsFixed(1)}K';
    return '${(viewCount / 1000000).toStringAsFixed(1)}M';
  }
}




