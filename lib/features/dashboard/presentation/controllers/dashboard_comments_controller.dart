import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
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

  /// Comments state: 0 = Videos, 1 = Published, 2 = Held for review
  final RxInt selectedTab = 1.obs;
  final selectedVideoId = Rxn<String>(); // null means all videos
  final allComments = RxList<Comment>();
  final answeredComments = RxList<Comment>();
  final unansweredComments = RxList<Comment>();
  final commentsFilter = RxString('all'); // 'all', 'unanswered', 'answered', 'hearted'
  final searchQuery = RxString('');
  final RxBool isSearchExpanded = false.obs;
  final RxBool isLoadingComments = false.obs;
  final commentsError = Rx<String?>(null);

  /// Tracks comment IDs that have authentic creator replies (self-healing local reactive state)
  final RxSet<String> creatorAnsweredCommentIds = <String>{}.obs;

  // Cursor Pagination (Industry Standard 25 per page)
  static const int commentsPerPage = 25;
  final RxBool hasMoreComments = true.obs;
  final RxBool isLoadingMoreComments = false.obs;
  DocumentSnapshot? lastStudioCommentDoc;

  /// Search text editing controller
  final TextEditingController searchController = TextEditingController();

  /// Map of commentId to active reply text controllers
  final Map<String, TextEditingController> replyControllers = {};

  /// Reactive state for inline reply drawers visibility
  final RxMap<String, bool> activeReplyBoxes = <String, bool>{}.obs;

  /// Reactive state for reply submission in progress
  final RxMap<String, bool> isSubmittingReply = <String, bool>{}.obs;

  /// Reactive state for expandable comment replies
  final RxMap<String, bool> expandedReplies = <String, bool>{}.obs;

  /// Filter chip alias pointing to commentsFilter
  RxString get selectedFilterChip => commentsFilter;

  /// Get currently selected video model if filtering by specific video
  CreatorVideoWithComments? get selectedVideo {
    final vId = selectedVideoId.value;
    if (vId == null || vId.isEmpty) return null;
    return videosWithComments.firstWhereOrNull((v) => v.videoId == vId);
  }

  /// Determines whether the creator has responded to a comment
  bool hasCreatorResponded(Comment comment) {
    if (comment.hasCreatorReply) return true;
    if (creatorAnsweredCommentIds.contains(comment.id)) return true;
    return false;
  }

  /// Marks comment as answered in local memory, re-filters, and persists to Firestore
  void markCommentAsLocallyAnswered(String commentId, String videoId) {
    if (!creatorAnsweredCommentIds.contains(commentId)) {
      creatorAnsweredCommentIds.add(commentId);
      final idx = allComments.indexWhere((c) => c.id == commentId);
      if (idx != -1 && !allComments[idx].hasCreatorReply) {
        allComments[idx] = allComments[idx].copyWith(hasCreatorReply: true);
      }
      _filterComments();

      if (videoId.isNotEmpty && videoId != 'channel_all') {
        _commentService.markCommentAsAnswered(videoId, commentId).catchError((_) {});
      }
    }
  }

  TextEditingController getReplyController(String commentId) {
    if (!replyControllers.containsKey(commentId)) {
      replyControllers[commentId] = TextEditingController();
    }
    return replyControllers[commentId]!;
  }

  void toggleReplyBox(String commentId) {
    activeReplyBoxes[commentId] = !(activeReplyBoxes[commentId] ?? false);
  }

  void closeReplyBox(String commentId) {
    activeReplyBoxes[commentId] = false;
    replyControllers[commentId]?.clear();
  }

  bool isReplyExpanded(String commentId) => expandedReplies[commentId] ?? false;

  void toggleRepliesExpanded(String commentId) {
    expandedReplies[commentId] = !(expandedReplies[commentId] ?? false);
  }

  void toggleSearch() {
    isSearchExpanded.value = !isSearchExpanded.value;
    if (!isSearchExpanded.value) {
      searchController.clear();
      setSearchQuery('');
    }
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
    _filterComments();
  }

  void setSelectedTab(int tabIndex) {
    selectedTab.value = tabIndex;
    _filterComments();
  }

  /// Handler when a video is selected from the Videos tab
  void onVideoSelectedFromList(String? videoId) {
    selectVideo(videoId);
    setSelectedTab(1); // Switch to Published tab to view this video's comments
  }

  void loadCommentsForChannel() => _loadAllCommentsForChannel();

  /// Real-time eviction when a video is moved to trash or permanently deleted
  void removeVideo(String videoId) {
    final cleanId = videoId.trim();
    if (cleanId.isEmpty) return;

    // Evict video from reactive list
    videosWithComments.removeWhere((v) => v.videoId == cleanId);

    // Evict comments for this video
    _commentsByVideo.remove(cleanId);
    allComments.removeWhere((c) => c.videoId == cleanId);

    // If currently selected video is the deleted one, reset to All Videos
    if (selectedVideoId.value == cleanId) {
      selectedVideoId.value = null;
    }

    _filterComments();
    logger.info('Evicted video $cleanId from DashboardCommentsController', tag: _tag);
  }

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

  void clearData() {
    for (final sub in _commentSubscriptions) {
      sub.cancel();
    }
    _commentSubscriptions.clear();
    _commentsByVideo.clear();
    videosWithComments.clear();
    allComments.clear();
    answeredComments.clear();
    unansweredComments.clear();
    userCommentInteractions.clear();
    userChannelId.value = '';
    userChannelName.value = '';
    userChannelAvatar.value = '';
    selectedVideoId.value = null;
    selectedTab.value = 1;
    isSearchExpanded.value = false;
    creatorAnsweredCommentIds.clear();
  }

  @override
  void onClose() {
    for (final sub in _commentSubscriptions) {
      sub.cancel();
    }
    _commentSubscriptions.clear();
    for (final c in replyControllers.values) {
      c.dispose();
    }
    replyControllers.clear();
    searchController.dispose();
    activeReplyBoxes.clear();
    isSubmittingReply.clear();
    expandedReplies.clear();
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

      // 1. Check active channel from AuthService
      try {
        if (Get.isRegistered<AuthService>() && AuthService.to.userChannel != null) {
          final ch = AuthService.to.userChannel!;
          userChannelId.value = ch.id;
          userChannelName.value = ch.name.isNotEmpty ? ch.name : ch.handle;
          userChannelAvatar.value = ch.avatarUrl;
        }
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'DashboardCommentsController.initializeUser.channel',
        );
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null && userChannelId.value.isEmpty) {
        videosError.value = 'Not authenticated';
        logger.warning('User not authenticated', tag: _tag);
        return;
      }

      // 2. Check if channel was passed in Get.arguments
      if (userChannelId.value.isEmpty) {
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
      }

      // 3. Fallback to user document if channel ID is still empty
      if (userChannelId.value.isEmpty && currentUser != null) {
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

      // Collect documents from authenticated creator's channels and user accounts
      final foundDocsMap = <String, DocumentSnapshot<Map<String, dynamic>>>{};

      // 1. Primary Query: Videos by channelId
      if (channelId.isNotEmpty) {
        try {
          final snap = await _firestore
              .collection(FirestoreCollections.videos)
              .where('channelId', isEqualTo: channelId)
              .get();
          for (final doc in snap.docs) {
            foundDocsMap[doc.id] = doc;
          }
        } catch (e) {
          logger.warning(
            'Primary video query by channelId failed: $e',
            tag: _tag,
          );
        }
      }

      // 2. Secondary Query: Videos by userId
      if (currentUid.isNotEmpty) {
        try {
          final snap = await _firestore
              .collection(FirestoreCollections.videos)
              .where('userId', isEqualTo: currentUid)
              .get();
          for (final doc in snap.docs) {
            foundDocsMap[doc.id] = doc;
          }
        } catch (e) {
          logger.warning(
            'Secondary video query by userId failed: $e',
            tag: _tag,
          );
        }

        // 3. Query videos by ownerId
        try {
          final snap = await _firestore
              .collection(FirestoreCollections.videos)
              .where('ownerId', isEqualTo: currentUid)
              .get();
          for (final doc in snap.docs) {
            foundDocsMap[doc.id] = doc;
          }
        } catch (e) {
          logger.warning(
            'Video query by ownerId failed: $e',
            tag: _tag,
          );
        }
      }

      // Cross-check with VideoManagementController if registered and active
      final activeChannelVideoIds = <String>{};
      if (Get.isRegistered<VideoManagementController>()) {
        try {
          final vm = Get.find<VideoManagementController>();
          if (vm.channelVideos.isNotEmpty) {
            activeChannelVideoIds.addAll(vm.channelVideos.map((v) => v.id));
          }
        } catch (_) {}
      }

      final videos = <CreatorVideoWithComments>[];

      for (final videoDoc in foundDocsMap.values) {
        if (!videoDoc.exists || videoDoc.data() == null) continue;
        final videoData = videoDoc.data()!;

        // Filter out phantom documents (documents without essential video fields)
        final title = (videoData['title'] as String?)?.trim() ?? '';
        final videoUrl = (videoData['videoUrl'] as String?)?.trim() ?? '';
        if (title.isEmpty && videoUrl.isEmpty) {
          // This is a phantom/metadata-free entry in videos collection, skip
          continue;
        }

        // Strictly filter out deleted, trashed, or deletion-pending videos
        final status = (videoData['status'] as String?)?.trim().toLowerCase() ?? '';
        final isDeleted = videoData['isDeleted'] == true;
        if (isDeleted ||
            status == 'deleted' ||
            status == 'deletion_pending' ||
            status == 'trashed' ||
            status == 'trash') {
          continue;
        }

        // Check timestamp deletion markers
        if (videoData['deletedAt'] != null ||
            videoData['deletionRequestedAt'] != null ||
            videoData['deletionPendingAt'] != null) {
          continue;
        }

        // Check visibility markers
        final visibility = (videoData['visibility'] as String?)?.trim().toLowerCase() ?? '';
        if (visibility == 'trash' || visibility == 'deleted') {
          continue;
        }

        // If VideoManagementController has active channelVideos, verify video is present
        if (activeChannelVideoIds.isNotEmpty && !activeChannelVideoIds.contains(videoDoc.id)) {
          continue;
        }

        final commentCount = await _commentService.getCommentCount(
          videoDoc.id,
        );
        final titleStr = title.isNotEmpty ? title : 'Untitled';
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
    lastStudioCommentDoc = null;
    hasMoreComments.value = false;

    if (videosWithComments.isEmpty) {
      isLoadingComments.value = false;
      allComments.clear();
      answeredComments.clear();
      unansweredComments.clear();
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
  }

  /// Cursor pagination for creator studio comments (25 comments per page)
  Future<void> loadMoreStudioComments() async {
    if (isLoadingMoreComments.value ||
        !hasMoreComments.value ||
        lastStudioCommentDoc == null) {
      return;
    }

    try {
      isLoadingMoreComments.value = true;
      final videoId = selectedVideoId.value;

      QuerySnapshot<Map<String, dynamic>> nextSnap;
      if (videoId != null && videoId.isNotEmpty) {
        nextSnap = await _commentService.getVideoCommentsPageSnapshotForStudio(
          videoId: videoId,
          startAfter: lastStudioCommentDoc,
        );
      } else {
        nextSnap = await _firestore
            .collectionGroup('comments')
            .orderBy('createdAt', descending: true)
            .startAfterDocument(lastStudioCommentDoc!)
            .limit(commentsPerPage)
            .get();
      }

      if (nextSnap.docs.isNotEmpty) {
        lastStudioCommentDoc = nextSnap.docs.last;
        final creatorVideoIds =
            videosWithComments.map((v) => v.videoId).toSet();

        final newComments = <Comment>[];
        for (final doc in nextSnap.docs) {
          try {
            // Strictly enforce that this document belongs to a video subcollection
            final segments = doc.reference.path.split('/');
            if (segments.length < 4 ||
                segments[0] != FirestoreCollections.videos) {
              continue;
            }
            final parentVid = segments[1];
            if (videoId == null && !creatorVideoIds.contains(parentVid)) {
              continue;
            }
            newComments.add(Comment.fromDocumentSnapshot(doc));
          } catch (e, stackTrace) {
            ErrorHandler.log(
              e,
              stackTrace: stackTrace,
              tag: 'DashboardCommentsController.loadMore.parse',
            );
          }
        }

        final existingIds = allComments.map((c) => c.id).toSet();
        for (final c in newComments) {
          if (existingIds.add(c.id)) {
            allComments.add(c);
            final vId = c.videoId.isNotEmpty ? c.videoId : 'channel_all';
            _commentsByVideo.putIfAbsent(vId, () => []).add(c);
          }
        }
        allComments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _filterComments();
      }

      hasMoreComments.value = nextSnap.docs.length >= commentsPerPage;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'DashboardCommentsController.loadMoreStudioComments',
      );
    } finally {
      isLoadingMoreComments.value = false;
    }
  }

  void _updateMergedComments() {
    final validVideoIds = videosWithComments.map((v) => v.videoId).toSet();
    final combined = <Comment>[];
    for (final entry in _commentsByVideo.entries) {
      if (entry.key != 'channel_all' && !validVideoIds.contains(entry.key)) {
        continue;
      }
      for (final comment in entry.value) {
        if (comment.videoId.isNotEmpty &&
            comment.videoId != 'channel_all' &&
            !validVideoIds.contains(comment.videoId)) {
          continue;
        }
        if (!combined.any((c) => c.id == comment.id)) {
          combined.add(comment);
        }
      }
    }
    combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    allComments.value = combined;
    _filterComments();
    _checkUnansweredCommentsForReplies(combined);
  }

  /// Asynchronously verifies if comments without hasCreatorReply actually have creator replies
  Future<void> _checkUnansweredCommentsForReplies(List<Comment> comments) async {
    final currentChId = userChannelId.value;
    final currentUid = _auth.currentUser?.uid ?? '';
    final currentChName = userChannelName.value.trim().toLowerCase();
    if (currentChId.isEmpty && currentUid.isEmpty && currentChName.isEmpty) return;

    for (final comment in comments) {
      if (hasCreatorResponded(comment)) continue;
      if (comment.videoId.isEmpty || comment.videoId == 'channel_all') continue;

      try {
        final snap = await _firestore
            .collection(FirestoreCollections.videos)
            .doc(comment.videoId)
            .collection('comments')
            .doc(comment.id)
            .collection('replies')
            .get();

        if (snap.docs.isEmpty) continue;

        final hasReply = snap.docs.any((d) {
          final data = d.data();
          final rChId = (data['channelId'] as String?) ?? '';
          final rUid = (data['userId'] as String?) ?? '';
          final rChName =
              ((data['channelName'] as String?) ?? '').trim().toLowerCase();
          final rName =
              ((data['userName'] as String?) ?? '').trim().toLowerCase();

          return (currentChId.isNotEmpty && rChId == currentChId) ||
              (currentUid.isNotEmpty &&
                  (rUid == currentUid || rChId == currentUid)) ||
              (currentChName.isNotEmpty &&
                  (rChName == currentChName || rName == currentChName));
        });

        if (hasReply) {
          markCommentAsLocallyAnswered(comment.id, comment.videoId);
        }
      } catch (_) {
        // Non-blocking background verification
      }
    }
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
    if (['all', 'answered', 'unanswered', 'hearted'].contains(filter)) {
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

      // Filter by tab: 0 = Videos, 1 = Published, 2 = Held for review
      if (selectedTab.value == 2) {
        // Held for review: comments reported or flagged
        baseList = baseList.where((c) => c.reportCount > 0).toList();
      } else {
        // Published & Videos: regular comments (not reported)
        baseList = baseList.where((c) => c.reportCount == 0).toList();
      }

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
          .where(hasCreatorResponded)
          .toList();

      unansweredComments.value = baseList
          .where((c) => !hasCreatorResponded(c))
          .toList();

      logger.info(
        'Comments filtered: tab=${selectedTab.value}, answered=${answeredComments.length}, '
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
    var baseList = selectedVideoId.value == null
        ? allComments.toList()
        : allComments.where((c) => c.videoId == selectedVideoId.value).toList();

    // Filter by tab: 0 = Videos, 1 = Published, 2 = Held for review
    if (selectedTab.value == 2) {
      baseList = baseList.where((c) => c.reportCount > 0).toList();
    } else {
      baseList = baseList.where((c) => c.reportCount == 0).toList();
    }

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

    switch (commentsFilter.value) {
      case 'answered':
        return baseList.where(hasCreatorResponded).toList();
      case 'unanswered':
        return baseList.where((c) => !hasCreatorResponded(c)).toList();
      case 'hearted':
        return baseList.where((c) => c.isHeartedByCreator).toList();
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

      var targetVideoId = videoId.trim();
      if (targetVideoId.isEmpty || targetVideoId == 'channel_all') {
        final found = allComments.firstWhereOrNull((c) => c.id == commentId);
        if (found != null &&
            found.videoId.isNotEmpty &&
            found.videoId != 'channel_all') {
          targetVideoId = found.videoId;
        }
      }
      if (targetVideoId.isEmpty || targetVideoId == 'channel_all') {
        return;
      }

      await _commentService.likeComment(
        videoId: targetVideoId,
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

      var targetVideoId = videoId.trim();
      if (targetVideoId.isEmpty || targetVideoId == 'channel_all') {
        final found = allComments.firstWhereOrNull((c) => c.id == commentId);
        if (found != null &&
            found.videoId.isNotEmpty &&
            found.videoId != 'channel_all') {
          targetVideoId = found.videoId;
        }
      }
      if (targetVideoId.isEmpty || targetVideoId == 'channel_all') {
        return;
      }

      await _commentService.dislikeComment(
        videoId: targetVideoId,
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
      var targetVideoId = videoId.trim();
      if (targetVideoId.isEmpty || targetVideoId == 'channel_all') {
        final found = allComments.firstWhereOrNull((c) => c.id == commentId);
        if (found != null &&
            found.videoId.isNotEmpty &&
            found.videoId != 'channel_all') {
          targetVideoId = found.videoId;
        }
      }
      if (targetVideoId.isEmpty || targetVideoId == 'channel_all') {
        return;
      }

      await _commentService.heartComment(
        videoId: targetVideoId,
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
  Future<bool> replyToCommentAsChannel({
    required String videoId,
    required String commentId,
    required String replyText,
  }) async {
    try {
      final userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        logger.warning('User not authenticated for reply', tag: _tag);
        return false;
      }

      final trimmedText = replyText.trim();
      if (trimmedText.isEmpty) {
        logger.warning('Reply text is empty', tag: _tag);
        return false;
      }

      final validation = ContentValidator.validate(trimmedText, fieldName: 'Reply');
      if (!validation.isValid) {
        logger.warning('Reply contains profanity: ${validation.message}', tag: _tag);
        return false;
      }

      var targetVideoId = videoId.trim();
      if (targetVideoId.isEmpty || targetVideoId == 'channel_all') {
        final found = allComments.firstWhereOrNull((c) => c.id == commentId);
        if (found != null &&
            found.videoId.isNotEmpty &&
            found.videoId != 'channel_all') {
          targetVideoId = found.videoId;
        }
      }

      if (targetVideoId.isEmpty || targetVideoId == 'channel_all') {
        logger.warning('Cannot reply without a valid videoId', tag: _tag);
        AppSnackbar.error('Unable to determine the video for this comment.');
        return false;
      }

      // 1. Verify targetVideoId belongs to this creator and actually exists in videos collection
      final isKnownVideo =
          videosWithComments.any((v) => v.videoId == targetVideoId);
      if (!isKnownVideo) {
        final videoDoc = await _firestore
            .collection(FirestoreCollections.videos)
            .doc(targetVideoId)
            .get();
        if (!videoDoc.exists || videoDoc.data() == null) {
          logger.error(
            'Target video $targetVideoId does not exist in videos collection',
            tag: _tag,
          );
          AppSnackbar.error('The video for this comment was not found.');
          return false;
        }
        final vData = videoDoc.data()!;
        final vChannelId = (vData['channelId'] as String?) ?? '';
        final vUserId = (vData['userId'] as String?) ??
            (vData['ownerId'] as String?) ??
            (vData['uploaderId'] as String?) ??
            '';
        final currentUid = _auth.currentUser?.uid ?? '';
        final chId = userChannelId.value;
        final isOwner = (chId.isNotEmpty &&
                (vChannelId == chId || vUserId == chId)) ||
            (currentUid.isNotEmpty &&
                (vUserId == currentUid || vChannelId == currentUid));
        if (!isOwner) {
          logger.error(
            'Target video $targetVideoId does not belong to creator',
            tag: _tag,
          );
          AppSnackbar.error(
            'You do not have permission to reply as channel for this video.',
          );
          return false;
        }
      }

      // 2. Verify target comment exists under this specific video
      final commentDoc = await _firestore
          .collection(FirestoreCollections.videos)
          .doc(targetVideoId)
          .collection('comments')
          .doc(commentId)
          .get();
      if (!commentDoc.exists) {
        logger.error(
          'Target comment $commentId does not exist under video $targetVideoId',
          tag: _tag,
        );
        AppSnackbar.error('This comment no longer exists.');
        return false;
      }

      final activeChannel = AuthService.to.userChannel;
      final replyChannelName = (activeChannel?.name.isNotEmpty ?? false)
          ? activeChannel!.name
          : (userChannelName.value.isNotEmpty
              ? userChannelName.value
              : (_auth.currentUser?.displayName ?? 'Creator'));

      final replyChannelAvatar = (activeChannel?.avatarUrl.isNotEmpty ?? false)
          ? activeChannel!.avatarUrl
          : userChannelAvatar.value;

      final replyChannelId = (activeChannel?.id.isNotEmpty ?? false)
          ? activeChannel!.id
          : userChannelId.value;

      // Add reply
      await _commentService.addReply(
        videoId: targetVideoId,
        commentId: commentId,
        userId: userId,
        userName: replyChannelName,
        userProfilePicUrl: replyChannelAvatar,
        channelId: replyChannelId,
        channelName: replyChannelName,
        channelProfilePicUrl: replyChannelAvatar,
        text: trimmedText,
      );

      // Mark comment as answered
      await _commentService.markCommentAsAnswered(targetVideoId, commentId);

      // Optimistically update comment in local list
      final idx = allComments.indexWhere((c) => c.id == commentId);
      if (idx != -1) {
        allComments[idx] = allComments[idx].copyWith(
          hasCreatorReply: true,
        );
        _filterComments();
      }

      logger.info('Replied to comment $commentId as channel', tag: _tag);
      return true;
    } catch (e, stackTrace) {
      logger.error(
        'Failed to reply to comment',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return false;
    }
  }

  /// Submits a reply using active state tracking
  Future<bool> submitReply({
    required Comment comment,
    required String text,
  }) async {
    isSubmittingReply[comment.id] = true;
    try {
      final success = await replyToCommentAsChannel(
        videoId: comment.videoId,
        commentId: comment.id,
        replyText: text,
      );
      if (success) {
        closeReplyBox(comment.id);
      }
      return success;
    } finally {
      isSubmittingReply[comment.id] = false;
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
