import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/services/comment_service.dart';

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
  final RxBool isLoadingVideos = false.obs;
  final videosError = Rx<String?>(null);

  /// Map of videoId to loaded comments stream
  final Map<String, List<Comment>> _commentsByVideo = {};
  final List<StreamSubscription<dynamic>> _commentSubscriptions = [];

  /// Comments state
  final selectedVideoId = Rxn<String>(); // null means all videos
  final allComments = RxList<Comment>();
  final answeredComments = RxList<Comment>();
  final unansweredComments = RxList<Comment>();
  final commentsFilter = RxString('all'); // 'all', 'answered', 'unanswered'
  final searchQuery = RxString('');
  final RxBool isLoadingComments = false.obs;
  final commentsError = Rx<String?>(null);

  void setSearchQuery(String query) {
    searchQuery.value = query;
    _filterComments();
  }

  void loadCommentsForChannel() => _loadAllCommentsForChannel();

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
          .collection(FirestoreCollections.users)
          .doc(currentUser.uid)
          .collection('comment_interactions')
          .get();
      for (final doc in snap.docs) {
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
          userChannelId.value = (channelArg['id'] as String?) ?? '';
          userChannelName.value =
              (channelArg['channelName'] as String?) ??
              (channelArg['name'] as String?) ??
              '';
          userChannelAvatar.value =
              (channelArg['channelProfilePicUrl'] as String?) ??
              (channelArg['profilePicUrl'] as String?) ??
              '';
        } else if (channelArg is DocumentSnapshot) {
          userChannelId.value = channelArg.id;
          final data = channelArg.data() as Map<String, dynamic>?;
          if (data != null) {
            userChannelName.value =
                (data['channelName'] as String?) ??
                (data['name'] as String?) ??
                '';
            userChannelAvatar.value =
                (data['channelProfilePicUrl'] as String?) ??
                (data['profilePicUrl'] as String?) ??
                '';
          }
        }
      }

      // Fallback to user document if channel ID is still empty
      if (userChannelId.value.isEmpty) {
        final userDoc = await _firestore
            .collection(FirestoreCollections.users)
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          userChannelId.value =
              (data['channelId'] as String?) ?? currentUser.uid;
          userChannelName.value =
              (data['channelName'] as String?) ??
              currentUser.displayName ??
              'Your Channel';
          userChannelAvatar.value =
              (data['channelProfilePicUrl'] as String?) ?? '';
        } else {
          userChannelId.value = currentUser.uid;
          userChannelName.value = currentUser.displayName ?? 'Your Channel';
        }
      }

      // Load user interactions and creator videos
      await _loadUserInteractions();
      await _loadCreatorVideos();
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
      final currentUid = _auth.currentUser?.uid ?? '';

      QuerySnapshot<Map<String, dynamic>>? videosSnapshot;

      // 1. Primary Query: Try querying videos by channelId
      if (channelId.isNotEmpty) {
        try {
          videosSnapshot = await _firestore
              .collection(FirestoreCollections.videos)
              .where('channelId', isEqualTo: channelId)
              .get();
        } catch (e) {
          logger.warning(
            'Primary video query by channelId failed: $e',
            tag: _tag,
          );
        }
      }

      // 2. Secondary Query: Try querying videos by userId
      if ((videosSnapshot == null || videosSnapshot.docs.isEmpty) &&
          currentUid.isNotEmpty) {
        try {
          videosSnapshot = await _firestore
              .collection(FirestoreCollections.videos)
              .where('userId', isEqualTo: currentUid)
              .get();
        } catch (e) {
          logger.warning(
            'Secondary video query by userId failed: $e',
            tag: _tag,
          );
        }
      }

      // 3. Tertiary Fallback: Fetch top recent videos from database
      if (videosSnapshot == null || videosSnapshot.docs.isEmpty) {
        try {
          videosSnapshot = await _firestore
              .collection(FirestoreCollections.videos)
              .limit(50)
              .get();
        } catch (e) {
          logger.warning('Fallback videos fetch failed: $e', tag: _tag);
        }
      }

      final videos = <CreatorVideoWithComments>[];

      if (videosSnapshot != null && videosSnapshot.docs.isNotEmpty) {
        final filteredDocs = videosSnapshot.docs.where((doc) {
          final data = doc.data();
          final vChannelId = (data['channelId'] as String?) ?? '';
          final vUserId =
              (data['userId'] as String?) ??
              (data['uploaderId'] as String?) ??
              '';
          return (channelId.isNotEmpty &&
                  (vChannelId == channelId || vUserId == channelId)) ||
              (currentUid.isNotEmpty && vUserId == currentUid);
        }).toList();

        final docsToUse = filteredDocs.isNotEmpty
            ? filteredDocs
            : videosSnapshot.docs;

        for (final videoDoc in docsToUse) {
          final videoData = videoDoc.data();
          final commentCount = await _commentService.getCommentCount(
            videoDoc.id,
          );
          final titleStr = (videoData['title'] as String?) ?? 'Untitled';
          final thumbStr =
              (videoData['thumbnailUrl'] as String?) ??
              (videoData['thumbnail'] as String?) ??
              '';
          final rawDate = videoData['uploadedAt'] ?? videoData['createdAt'];
          final dateVal =
              TimestampUtils.parseToDateTime(rawDate) ?? DateTime.now();

          videos.add(
            CreatorVideoWithComments(
              videoId: videoDoc.id,
              title: titleStr,
              thumbnail: thumbStr,
              duration: videoData['duration']?.toString() ?? '0:00',
              viewCount:
                  (videoData['viewCount'] as int?) ??
                  (videoData['views'] as int?) ??
                  0,
              commentCount: commentCount,
              createdAt: dateVal,
            ),
          );
        }
      }

      // In-memory sort by recency
      videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      videosWithComments.value = videos;

      logger.info('Loaded ${videos.length} videos safely', tag: _tag);
    } catch (e, stackTrace) {
      logger.error(
        'Failed to load creator videos',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
    } finally {
      isLoadingVideos.value = false;
      // Always load channel comments!
      _loadAllCommentsForChannel();
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

    final targetChannelId = userChannelId.value.isNotEmpty
        ? userChannelId.value
        : (_auth.currentUser?.uid ?? '');

    if (videosWithComments.isEmpty) {
      _loadCommentsViaCollectionGroup(targetChannelId);
      return;
    }

    var completedStreams = 0;
    for (final video in videosWithComments) {
      final sub = _commentService
          .getVideoCommentsForStudio(video.videoId)
          .listen(
            (comments) {
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
            onError: (Object e) {
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

    // Direct collectionGroup listener backup to catch all comments regardless of video array
    _loadCommentsViaCollectionGroup(targetChannelId);
  }

  void _loadCommentsViaCollectionGroup(String channelId) {
    if (channelId.isEmpty) {
      isLoadingComments.value = false;
      return;
    }

    try {
      final sub = _firestore
          .collectionGroup('comments')
          .snapshots()
          .listen(
            (snapshot) {
              final collectionGroupComments = <Comment>[];
              for (final doc in snapshot.docs) {
                try {
                  final data = doc.data();
                  final cChannelId = data['channelId'] ?? data['userId'] ?? '';
                  final currentUid = _auth.currentUser?.uid ?? '';
                  if (cChannelId == channelId || cChannelId == currentUid) {
                    collectionGroupComments.add(
                      Comment.fromDocumentSnapshot(doc),
                    );
                  }
                } catch (_) {}
              }

              if (collectionGroupComments.isNotEmpty) {
                // Merge with existing comments without duplicating
                final existingIds = _commentsByVideo.values
                    .expand((l) => l)
                    .map((c) => c.id)
                    .toSet();

                for (final c in collectionGroupComments) {
                  if (!existingIds.contains(c.id)) {
                    final vId = c.videoId.isNotEmpty
                        ? c.videoId
                        : 'channel_all';
                    _commentsByVideo.putIfAbsent(vId, () => []).add(c);
                  }
                }
                _updateMergedComments();
              }
              isLoadingComments.value = false;
            },
            onError: (Object e) {
              logger.warning(
                'CollectionGroup comments query notice: $e',
                tag: _tag,
              );
              isLoadingComments.value = false;
            },
          );
      _commentSubscriptions.add(sub);
    } catch (e) {
      logger.warning('CollectionGroup setup notice: $e', tag: _tag);
      isLoadingComments.value = false;
    }
  }

  void _updateMergedComments() {
    final combined = <Comment>[];
    for (final list in _commentsByVideo.values) {
      for (final comment in list) {
        if (!combined.any((c) => c.id == comment.id)) {
          combined.add(comment);
        }
      }
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
      var baseList = selectedVideoId.value == null
          ? allComments.toList()
          : allComments
                .where((c) => c.videoId == selectedVideoId.value)
                .toList();

      if (searchQuery.value.isNotEmpty) {
        final query = searchQuery.value.toLowerCase();
        baseList = baseList
            .where(
              (c) =>
                  c.text.toLowerCase().contains(query) ||
                  c.displayName.toLowerCase().contains(query),
            )
            .toList();
      }

      answeredComments.value = baseList
          .where((c) => c.hasCreatorReply)
          .toList();

      unansweredComments.value = baseList
          .where((c) => !c.hasCreatorReply)
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
        isVideoCreator: true,
        creatorName: userChannelName.value,
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
        isVideoCreator: true,
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

      final activeChannel = AuthService.to.userChannel;
      final replyChannelName = (activeChannel?.handle.isNotEmpty ?? false)
          ? activeChannel!.handle
          : userChannelName.value;

      // Add reply
      await _commentService.addReply(
        videoId: videoId,
        commentId: commentId,
        userId: userId,
        userName: replyChannelName,
        userProfilePicUrl: userChannelAvatar.value,
        channelId: userChannelId.value,
        channelName: replyChannelName,
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
  CreatorVideoWithComments({
    required this.videoId,
    required this.title,
    required this.thumbnail,
    required this.duration,
    required this.viewCount,
    required this.commentCount,
    required this.createdAt,
  });
  final String videoId;
  final String title;
  final String thumbnail;
  final String duration;
  final int viewCount;
  final int commentCount;
  final DateTime createdAt;

  String get formattedCommentCount =>
      commentCount == 1 ? '1 comment' : '$commentCount comments';
  String get formattedViewCount {
    if (viewCount < 1000) return '$viewCount';
    if (viewCount < 1000000) return '${(viewCount / 1000).toStringAsFixed(1)}K';
    return '${(viewCount / 1000000).toStringAsFixed(1)}M';
  }
}
