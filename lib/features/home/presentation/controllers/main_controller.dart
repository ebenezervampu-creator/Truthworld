import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:idb_shim/idb_browser.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart'
    as app_exceptions;
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/data/models/video.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:universal_html/html.dart' as html;

// ========================================================================
// EXTENSION: Stream Retry Logic
// ========================================================================

// ========================================================================
// MAIN CONTROLLER
// ========================================================================

/// Main controller managing video operations, comments, interactions, and content discovery
class MainController extends BaseController {
  // ========================================================================
  // FIREBASE SERVICES
  // ========================================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterVideoInfo videoInfo = FlutterVideoInfo();

  // ========================================================================
  // FILE PICKING STATE
  // ========================================================================

  final pickedImage = Rx<PlatformFile?>(null);
  final pickedVideo = Rx<PlatformFile?>(null);

  // ========================================================================
  // VIDEO STATE
  // ========================================================================

  final videos = <Video>[].obs;
  final filteredVideos = <Video>[].obs;
  final searchQuery = ''.obs;

  StreamSubscription<List<Video>>? _videoSubscription;

  // ========================================================================
  // INTERACTION STATE
  // ========================================================================

  final videoLikes = <String, int>{}.obs;
  final videoDislikes = <String, int>{}.obs;
  final isReporting = false.obs;

  // Client-side guard for rapid tapping (race condition prevention)
  final _pendingLikeOperations = <String>{};
  final _pendingDislikeOperations = <String>{};

  // ========================================================================
  // CONSTANTS
  // ========================================================================

  static const String _videosCollection = 'videos';
  static const String _commentsSubcollection = 'comments';
  static const String _repliesSubcollection = 'replies';
  static const String _usersCollection = 'users';
  static const String _reportsCollection = 'reports';

  String get userId => _auth.currentUser?.uid ?? '';
  static const Duration _defaultTimeout = Duration(seconds: 10);
  static const Duration _filePickerTimeout = Duration(seconds: 30);

  // ========================================================================
  // LIFECYCLE
  // ========================================================================

  @override
  void onInit() {
    super.onInit();
    _initializeVideoStream();
  }

  @override
  void onClose() {
    _videoSubscription?.cancel();
    super.onClose();
  }

  // ========================================================================
  // VIDEO STREAM MANAGEMENT
  // ========================================================================

  /// Initialize video stream with retry logic
  void _initializeVideoStream() {
    _videoSubscription?.cancel();

    _videoSubscription = streamVideos().listen(
      _handleVideoSnapshot,
      onError: _handleVideoStreamError,
    );
  }

  /// Handle incoming video snapshot
  void _handleVideoSnapshot(List<Video> videoList) {
    videos.assignAll(videoList);
    filteredVideos.assignAll(videoList);
    clearError();

    if (kDebugMode) {
      debugPrint('MainController: Loaded ${videoList.length} videos');
    }
  }

  /// Handle video stream errors
  void _handleVideoStreamError(dynamic error) {
    if (kDebugMode) {
      debugPrint('MainController video stream error: $error');
    }

    handleError(
      app_exceptions.FirestoreException(
        message: 'Failed to load videos. Please check your connection.',
        originalException: error,
      ),
    );
  }

  /// Stream of videos from Firestore with error handling
  Stream<List<Video>> streamVideos() {
    return _firestore
        .collection(_videosCollection)
        .orderBy('uploadedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs
                .map(Video.fromDocumentSnapshot)
                .toList();
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error mapping videos: $e');
            }
            return <Video>[];
          }
        })
        .handleError((error) {
          if (kDebugMode) {
            debugPrint('Error in video stream: $error');
          }
          return <Video>[];
        });
  }

  /// Restart video stream (useful for manual refresh)
  Future<void> restartVideoStream() async {
    try {
      await _videoSubscription?.cancel();
      _initializeVideoStream();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error restarting video stream: $e');
      }
    }
  }

  // ========================================================================
  // FILE PICKING
  // ========================================================================

  /// Pick image file from device
  Future<void> pickImage() async {
    await safeExecute(_pickImageInternal, showLoading: false);
  }

  /// Internal image picking implementation
  Future<void> _pickImageInternal() async {
    try {
      final result =
          await FilePicker.pickFiles(
            type: FileType.image,
            withData: true,
          ).timeout(
            _filePickerTimeout,
            onTimeout: () => throw const app_exceptions.TimeoutException(
              message: 'Image picker timeout',
            ),
          );

      if (result != null && result.files.isNotEmpty) {
        pickedImage.value = result.files.first;
        showSuccess('Image selected successfully');

        if (kDebugMode) {
          debugPrint(
            'MainController: Image picked - ${result.files.first.name}',
          );
        }
      } else {
        showWarning('No image selected');
      }
    } on app_exceptions.TimeoutException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error picking image: $e');
      }

      throw app_exceptions.ValidationException(
        message: 'Failed to pick image',
        originalException: e,
      );
    }
  }

  /// Pick video file from device
  Future<void> pickVideo() async {
    await safeExecute(_pickVideoInternal, showLoading: false);
  }

  /// Internal video picking implementation
  Future<void> _pickVideoInternal() async {
    try {
      final result =
          await FilePicker.pickFiles(
            type: FileType.video,
            withData: true,
          ).timeout(
            _filePickerTimeout,
            onTimeout: () => throw const app_exceptions.TimeoutException(
              message: 'Video picker timeout',
            ),
          );

      if (result != null && result.files.isNotEmpty) {
        pickedVideo.value = result.files.first;

        if (result.files.first.bytes != null) {
          showSuccess('Video selected successfully');

          if (kDebugMode) {
            debugPrint(
              'MainController: Video picked - ${result.files.first.name}',
            );
          }
        } else {
          throw const app_exceptions.ValidationException(
            message: 'Failed to load video bytes',
          );
        }
      } else {
        showWarning('No video selected');
      }
    } on app_exceptions.TimeoutException {
      rethrow;
    } on app_exceptions.ValidationException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error picking video: $e');
      }

      throw app_exceptions.ValidationException(
        message: 'Failed to pick video',
        originalException: e,
      );
    }
  }

  // ========================================================================
  // VIDEO INTERACTIONS - LIKES/DISLIKES
  // ========================================================================
  //
  // REQUIRED FIRESTORE INDEXES:
  // Collection: users/{userId}/likedVideos
  //   - timestamp (descending) - for sorted liked videos query
  //
  // SECURITY RULES:
  // - likes/{userId}: only owner can write
  // - likedVideos/{videoId}: only owner can write
  // - video likeCount/dislikeCount: server-side only (via transactions)
  //

  // Deleted former internal implementations to use unified scalable methods

  /// Like a video (Scalable subcollection pattern with reverse index)
  /// Stores like in: videos/{videoId}/likes/{userId}
  /// Stores reverse index in: users/{userId}/likedVideos/{videoId}
  Future<void> likeVideo(String videoId, String userId) async {
    if (videoId.isEmpty || userId.isEmpty) return;

    // Client-side guard: prevent rapid tapping / race conditions
    final operationKey = 'like:$videoId:$userId';
    if (_pendingLikeOperations.contains(operationKey)) {
      debugPrint('[Like] Operation already in progress, ignoring duplicate');
      return;
    }
    _pendingLikeOperations.add(operationKey);

    try {
      final videoRef = _firestore.collection(_videosCollection).doc(videoId);
      final likeRef = videoRef.collection('likes').doc(userId);
      final dislikeRef = videoRef.collection('dislikes').doc(userId);
      // Reverse index for efficient "get user's liked videos" queries
      final userLikedRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('likedVideos')
          .doc(videoId);

      await _firestore.runTransaction((transaction) async {
        final likeDoc = await transaction.get(likeRef);
        final dislikeDoc = await transaction.get(dislikeRef);

        // Idempotency: check if operation already done by another concurrent request
        // This is handled naturally by Firestore transactions, but we add explicit checks
        if (likeDoc.exists) {
          // Unlike - remove from both collections
          transaction.delete(likeRef);
          transaction.delete(userLikedRef);
          transaction.update(videoRef, {'likeCount': FieldValue.increment(-1)});
        } else {
          // Like - add to both collections
          transaction.set(likeRef, {'timestamp': FieldValue.serverTimestamp()});
          transaction.set(userLikedRef, {
            'timestamp': FieldValue.serverTimestamp(),
          });
          transaction.update(videoRef, {'likeCount': FieldValue.increment(1)});

          // Remove dislike if exists
          if (dislikeDoc.exists) {
            transaction.delete(dislikeRef);
            transaction.update(videoRef, {
              'dislikeCount': FieldValue.increment(-1),
            });
          }
        }
      });

      if (kDebugMode) {
        debugPrint('[Like] Video $videoId toggled successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Like] Error: $e');
      }
      throw app_exceptions.FirestoreException(
        message: 'Failed to update like status',
        originalException: e,
      );
    } finally {
      // Always remove guard, even on error (allow retry)
      _pendingLikeOperations.remove(operationKey);
    }
  }

  /// Dislike a video (Scalable subcollection pattern)
  /// Also removes from user's likedVideos collection if present
  Future<void> dislikeVideo(String videoId, String userId) async {
    if (videoId.isEmpty || userId.isEmpty) return;

    // Client-side guard: prevent rapid tapping / race conditions
    final operationKey = 'dislike:$videoId:$userId';
    if (_pendingDislikeOperations.contains(operationKey)) {
      debugPrint('[Dislike] Operation already in progress, ignoring duplicate');
      return;
    }
    _pendingDislikeOperations.add(operationKey);

    try {
      final videoRef = _firestore.collection(_videosCollection).doc(videoId);
      final likeRef = videoRef.collection('likes').doc(userId);
      final dislikeRef = videoRef.collection('dislikes').doc(userId);
      final userLikedRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('likedVideos')
          .doc(videoId);

      await _firestore.runTransaction((transaction) async {
        final likeDoc = await transaction.get(likeRef);
        final dislikeDoc = await transaction.get(dislikeRef);

        if (dislikeDoc.exists) {
          // Remove dislike
          transaction.delete(dislikeRef);
          transaction.update(videoRef, {
            'dislikeCount': FieldValue.increment(-1),
          });
        } else {
          // Add dislike
          transaction.set(dislikeRef, {
            'timestamp': FieldValue.serverTimestamp(),
          });
          transaction.update(videoRef, {
            'dislikeCount': FieldValue.increment(1),
          });

          // Remove like if exists (from both collections)
          if (likeDoc.exists) {
            transaction.delete(likeRef);
            transaction.delete(userLikedRef);
            transaction.update(videoRef, {
              'likeCount': FieldValue.increment(-1),
            });
          }
        }
      });

      if (kDebugMode) {
        debugPrint('[Dislike] Video $videoId toggled successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Dislike] Error: $e');
      }
      throw app_exceptions.FirestoreException(
        message: 'Failed to update dislike status',
        originalException: e,
      );
    } finally {
      // Always remove guard, even on error (allow retry)
      _pendingDislikeOperations.remove(operationKey);
    }
  }

  /// Like a comment
  /// Like a comment on a video
  Future<void> likeComment({
    required String videoId,
    required String commentId,
    required String userId,
  }) async {
    await safeExecute(
      () => _likeCommentInternal(
        videoId: videoId,
        commentId: commentId,
        userId: userId,
      ),
      showLoading: false,
    );
  }

  /// Dislike a comment on a video
  Future<void> dislikeComment({
    required String videoId,
    required String commentId,
    required String userId,
  }) async {
    await safeExecute(
      () => _dislikeCommentInternal(
        videoId: videoId,
        commentId: commentId,
        userId: userId,
      ),
      showLoading: false,
    );
  }

  /// Share video functionality
  Future<void> shareVideo(
    String videoId,
    String videoTitle, {
    String? thumbnailUrl,
    String? channelName,
    int? durationMs,
    Duration? currentPosition,
    String? subtitle,
  }) async {
    try {
      final videoUrl = DeepLinkService.videoUrl(videoId);

      ShareBottomSheet.show(
        title: videoTitle,
        url: videoUrl,
        thumbnailUrl: thumbnailUrl,
        channelName: channelName,
        durationMs: durationMs,
        currentPosition: currentPosition,
        subtitle: subtitle,
        type: 'video',
      );

      // Increment share count in background
      incrementShareCount(videoId);

      if (kDebugMode) {
        debugPrint('MainController: Video $videoId share sheet opened');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sharing video: $e');
      }
      showWarning('Failed to open share options');
    }
  }

  /// Share channel functionality
  Future<void> shareChannel(
    String channelId,
    String channelName, {
    String? avatarUrl,
    String? handle,
    int? subscriberCount,
    int? videoCount,
    String? subtitle,
  }) async {
    try {
      final url = DeepLinkService.channelUrl(channelId);

      ShareBottomSheet.show(
        title: channelName,
        url: url,
        thumbnailUrl: avatarUrl,
        handle: handle,
        subscriberCount: subscriberCount,
        videoCount: videoCount,
        subtitle: subtitle,
        type: 'channel',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sharing channel: $e');
      }
      showWarning('Failed to share channel');
    }
  }

  /// Share playlist functionality
  Future<void> sharePlaylist(
    String playlistId,
    String playlistName, {
    String? thumbnailUrl,
    String? channelName,
    int? videoCount,
    String? subtitle,
  }) async {
    try {
      final url = DeepLinkService.playlistUrl(playlistId);

      ShareBottomSheet.show(
        title: playlistName,
        url: url,
        thumbnailUrl: thumbnailUrl,
        channelName: channelName,
        videoCount: videoCount,
        subtitle: subtitle,
        type: 'playlist',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sharing playlist: $e');
      }
      showWarning('Failed to share playlist');
    }
  }

  /// Share topic functionality
  Future<void> shareTopic(
    String slugOrHandle,
    String topicTitle, {
    String? thumbnailUrl,
    int? videoCount,
    int? followerCount,
    String? subtitle,
  }) async {
    try {
      final url = DeepLinkService.topicUrl(slugOrHandle);

      ShareBottomSheet.show(
        title: topicTitle,
        url: url,
        thumbnailUrl: thumbnailUrl,
        followerCount: followerCount,
        videoCount: videoCount,
        handle: slugOrHandle,
        subtitle: subtitle,
        type: 'topic',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sharing topic: $e');
      }
      showWarning('Failed to share topic');
    }
  }

  /// Internal dislike implementation
  Future<void> _dislikeCommentInternal({
    required String videoId,
    required String commentId,
    required String userId,
  }) async {
    try {
      final commentRef = _firestore
          .collection(_videosCollection)
          .doc(videoId)
          .collection(_commentsSubcollection)
          .doc(commentId);

      final likeRef = commentRef.collection('likes').doc(userId);
      final dislikeRef = commentRef.collection('dislikes').doc(userId);

      final likeDoc = await likeRef.get();
      final dislikeDoc = await dislikeRef.get();

      if (dislikeDoc.exists) {
        // Remove dislike
        await dislikeRef.delete().timeout(_defaultTimeout);
      } else {
        // Remove like if exists, then add dislike
        if (likeDoc.exists) {
          await likeRef.delete().timeout(_defaultTimeout);
        }
        await dislikeRef
            .set({'timestamp': FieldValue.serverTimestamp()})
            .timeout(_defaultTimeout);
      }

      if (kDebugMode) {
        debugPrint('Comment dislike toggled successfully');
      }
    } on app_exceptions.TimeoutException {
      showWarning('Operation took too long');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error disliking comment: $e');
      }
      rethrow;
    }
  }

  /// Heart a comment as creator
  Future<void> heartComment({
    required String videoId,
    required String commentId,
    required bool isHearted,
  }) async {
    try {
      // Get creator name (could be optimized by caching channel name)
      var creatorName = 'Creator';
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        creatorName = userDoc.data()?['name'] ?? 'Creator';
      }

      await _firestore
          .collection(_videosCollection)
          .doc(videoId)
          .collection(_commentsSubcollection)
          .doc(commentId)
          .update({
            'isHeartedByCreator': isHearted,
            'creatorHeartName': isHearted ? creatorName : null,
          });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error hearting comment: $e');
      }
      rethrow;
    }
  }

  /// Internal comment like implementation
  Future<void> _likeCommentInternal({
    required String videoId,
    required String commentId,
    required String userId,
  }) async {
    try {
      final commentRef = _firestore
          .collection(_videosCollection)
          .doc(videoId)
          .collection(_commentsSubcollection)
          .doc(commentId);

      final likeRef = commentRef.collection('likes').doc(userId);
      final dislikeRef = commentRef.collection('dislikes').doc(userId);

      final likeDoc = await likeRef.get();
      final dislikeDoc = await dislikeRef.get();

      if (likeDoc.exists) {
        // Remove like
        await likeRef.delete().timeout(_defaultTimeout);
        await commentRef
            .update({'likeCount': FieldValue.increment(-1)})
            .timeout(_defaultTimeout);
      } else {
        // Add like
        await likeRef
            .set({'userId': userId, 'likedAt': FieldValue.serverTimestamp()})
            .timeout(_defaultTimeout);
        await commentRef
            .update({'likeCount': FieldValue.increment(1)})
            .timeout(_defaultTimeout);

        // Remove dislike if exists
        if (dislikeDoc.exists) {
          await dislikeRef.delete().timeout(_defaultTimeout);
          await commentRef
              .update({'dislikeCount': FieldValue.increment(-1)})
              .timeout(_defaultTimeout);
        }
      }

      if (kDebugMode) {
        debugPrint('MainController: Comment $commentId toggled like');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error liking comment: $e');
      }
      rethrow;
    }
  }

  /// Like a reply
  Future<void> likeReply({
    required String videoId,
    required String commentId,
    required String replyId,
    required String userId,
  }) async {
    await safeExecute(
      () => _likeReplyInternal(
        videoId: videoId,
        commentId: commentId,
        replyId: replyId,
        userId: userId,
      ),
      showLoading: false,
    );
  }

  /// Internal reply like implementation
  Future<void> _likeReplyInternal({
    required String videoId,
    required String commentId,
    required String replyId,
    required String userId,
  }) async {
    try {
      final replyRef = _firestore
          .collection(_videosCollection)
          .doc(videoId)
          .collection(_commentsSubcollection)
          .doc(commentId)
          .collection(_repliesSubcollection)
          .doc(replyId);

      final likeRef = replyRef.collection('likes').doc(userId);
      final dislikeRef = replyRef.collection('dislikes').doc(userId);

      final likeDoc = await likeRef.get();
      final dislikeDoc = await dislikeRef.get();

      if (likeDoc.exists) {
        await likeRef.delete().timeout(_defaultTimeout);
        await replyRef
            .update({'likes': FieldValue.increment(-1)})
            .timeout(_defaultTimeout);
      } else {
        await likeRef
            .set({'userId': userId, 'likedAt': FieldValue.serverTimestamp()})
            .timeout(_defaultTimeout);
        await replyRef
            .update({'likes': FieldValue.increment(1)})
            .timeout(_defaultTimeout);

        if (dislikeDoc.exists) {
          await dislikeRef.delete().timeout(_defaultTimeout);
          await replyRef
              .update({'dislike': FieldValue.increment(-1)})
              .timeout(_defaultTimeout);
        }
      }

      if (kDebugMode) {
        debugPrint('MainController: Reply $replyId toggled like');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error liking reply: $e');
      }
      rethrow;
    }
  }

  /// Dislike a reply
  Future<void> dislikeReply({
    required String videoId,
    required String commentId,
    required String replyId,
    required String userId,
  }) async {
    await safeExecute(
      () => _dislikeReplyInternal(
        videoId: videoId,
        commentId: commentId,
        replyId: replyId,
        userId: userId,
      ),
      showLoading: false,
    );
  }

  /// Internal reply dislike implementation
  Future<void> _dislikeReplyInternal({
    required String videoId,
    required String commentId,
    required String replyId,
    required String userId,
  }) async {
    try {
      final replyRef = _firestore
          .collection(_videosCollection)
          .doc(videoId)
          .collection(_commentsSubcollection)
          .doc(commentId)
          .collection(_repliesSubcollection)
          .doc(replyId);

      final likeRef = replyRef.collection('likes').doc(userId);
      final dislikeRef = replyRef.collection('dislikes').doc(userId);

      final likeDoc = await likeRef.get();
      final dislikeDoc = await dislikeRef.get();

      if (dislikeDoc.exists) {
        await dislikeRef.delete().timeout(_defaultTimeout);
        await replyRef
            .update({'dislike': FieldValue.increment(-1)})
            .timeout(_defaultTimeout);
      } else {
        await dislikeRef
            .set({'userId': userId, 'dislikedAt': FieldValue.serverTimestamp()})
            .timeout(_defaultTimeout);
        await replyRef
            .update({'dislike': FieldValue.increment(1)})
            .timeout(_defaultTimeout);

        if (likeDoc.exists) {
          await likeRef.delete().timeout(_defaultTimeout);
          await replyRef
              .update({'likes': FieldValue.increment(-1)})
              .timeout(_defaultTimeout);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error disliking reply: $e');
      }
      rethrow;
    }
  }

  // ========================================================================
  // COMMENTS & REPLIES
  // ========================================================================

  /// Add a comment to a video
  Future<void> addComment({
    required String videoId,
    required String userId,
    required String userName,
    required String userProfilePicUrl,
    required String text,
  }) async {
    await safeExecute(
      () => _addCommentInternal(
        videoId: videoId,
        userId: userId,
        userName: userName,
        userProfilePicUrl: userProfilePicUrl,
        text: text,
      ),
      showLoading: false,
    );
  }

  /// Internal add comment implementation
  Future<void> _addCommentInternal({
    required String videoId,
    required String userId,
    required String userName,
    required String userProfilePicUrl,
    required String text,
  }) async {
    try {
      if (text.trim().isEmpty) {
        throw const app_exceptions.ValidationException(
          message: 'Comment cannot be empty',
        );
      }

      final docRef = _firestore
          .collection(_videosCollection)
          .doc(videoId)
          .collection(_commentsSubcollection)
          .doc();

      final authService = AuthService.to;
      final hasChannel = authService.hasChannel.value && authService.userChannel != null;

      final finalUserName = authService.activeDisplayName;
      final finalUserProfilePicUrl = authService.activePhotoUrl;
      final finalChannelId = hasChannel ? authService.userChannel!.id : userId;
      final finalChannelName = authService.activeDisplayName;
      final finalChannelProfilePicUrl = authService.activePhotoUrl;

      final comment = Comment(
        id: docRef.id,
        videoId: videoId,
        userId: userId,
        userName: finalUserName,
        text: text.trim(),
        userProfilePicUrl: finalUserProfilePicUrl,
        createdAt: Timestamp.now(),
        channelId: finalChannelId,
        channelName: finalChannelName,
        channelProfilePicUrl: finalChannelProfilePicUrl,
        likeCount: 0,
        dislikeCount: 0,
        reportCount: 0,
      );

      await docRef.set(comment.toMap()).timeout(_defaultTimeout);

      showSuccess('Comment added');

      if (kDebugMode) {
        debugPrint('MainController: Comment added to video $videoId');
      }
    } on app_exceptions.TimeoutException {
      rethrow;
    } on app_exceptions.ValidationException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding comment: $e');
      }

      throw app_exceptions.FirestoreException(
        message: 'Failed to add comment',
        originalException: e,
      );
    }
  }

  /// Add a reply to a comment
  Future<void> addReply({
    required String videoId,
    required String commentId,
    required String userId,
    required String userName,
    required String userProfilePicUrl,
    required String text,
  }) async {
    await safeExecute(
      () => _addReplyInternal(
        videoId: videoId,
        commentId: commentId,
        userId: userId,
        userName: userName,
        userProfilePicUrl: userProfilePicUrl,
        text: text,
      ),
      showLoading: false,
    );
  }

  /// Internal add reply implementation
  Future<void> _addReplyInternal({
    required String videoId,
    required String commentId,
    required String userId,
    required String userName,
    required String userProfilePicUrl,
    required String text,
  }) async {
    try {
      if (text.trim().isEmpty) {
        throw const app_exceptions.ValidationException(
          message: 'Reply cannot be empty',
        );
      }

      final docRef = _firestore
          .collection(_videosCollection)
          .doc(videoId)
          .collection(_commentsSubcollection)
          .doc(commentId)
          .collection(_repliesSubcollection)
          .doc();

      final authService = AuthService.to;
      final hasChannel = authService.hasChannel.value && authService.userChannel != null;

      final finalUserName = authService.activeDisplayName;
      final finalUserProfilePicUrl = authService.activePhotoUrl;
      final finalChannelId = hasChannel ? authService.userChannel!.id : userId;
      final finalChannelName = authService.activeDisplayName;
      final finalChannelProfilePicUrl = authService.activePhotoUrl;

      final reply = Reply(
        id: docRef.id,
        videoId: videoId,
        userId: userId,
        commentId: commentId,
        userName: finalUserName,
        text: text.trim(),
        createdAt: Timestamp.now(),
        userProfilePicUrl: finalUserProfilePicUrl,
        channelId: finalChannelId,
        channelName: finalChannelName,
        channelProfilePicUrl: finalChannelProfilePicUrl,
        likeCount: 0,
        dislikeCount: 0,
        reportCount: 0,
      );

      await docRef.set(reply.toMap()).timeout(_defaultTimeout);

      showSuccess('Reply added');

      if (kDebugMode) {
        debugPrint('MainController: Reply added to comment $commentId');
      }
    } on app_exceptions.TimeoutException {
      rethrow;
    } on app_exceptions.ValidationException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding reply: $e');
      }

      throw app_exceptions.FirestoreException(
        message: 'Failed to add reply',
        originalException: e,
      );
    }
  }

  /// Delete a comment
  Future<void> deleteComment(String videoId, String commentId) async {
    await safeExecute(
      () => _deleteCommentInternal(videoId, commentId),
      loadingMessage: 'Deleting comment...',
    );
  }

  /// Internal delete comment implementation
  Future<void> _deleteCommentInternal(String videoId, String commentId) async {
    try {
      // Delete all replies first
      final repliesSnapshot = await _firestore
          .collection(_videosCollection)
          .doc(videoId)
          .collection(_commentsSubcollection)
          .doc(commentId)
          .collection(_repliesSubcollection)
          .get()
          .timeout(_defaultTimeout);

      final batch = _firestore.batch();

      for (final doc in repliesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete comment
      final commentRef = _firestore
          .collection(_videosCollection)
          .doc(videoId)
          .collection(_commentsSubcollection)
          .doc(commentId);

      batch.delete(commentRef);
      await batch.commit().timeout(_defaultTimeout);

      showSuccess('Comment deleted');

      if (kDebugMode) {
        debugPrint('MainController: Comment $commentId deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting comment: $e');
      }
      rethrow;
    }
  }

  /// Delete a reply
  Future<void> deleteReply({
    required String videoId,
    required String commentId,
    required String replyId,
  }) async {
    await safeExecute(
      () => _deleteReplyInternal(
        videoId: videoId,
        commentId: commentId,
        replyId: replyId,
      ),
      loadingMessage: 'Deleting reply...',
    );
  }

  /// Internal delete reply implementation
  Future<void> _deleteReplyInternal({
    required String videoId,
    required String commentId,
    required String replyId,
  }) async {
    try {
      await _firestore
          .collection(_videosCollection)
          .doc(videoId)
          .collection(_commentsSubcollection)
          .doc(commentId)
          .collection(_repliesSubcollection)
          .doc(replyId)
          .delete()
          .timeout(_defaultTimeout);

      showSuccess('Reply deleted');

      if (kDebugMode) {
        debugPrint('MainController: Reply $replyId deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting reply: $e');
      }
      rethrow;
    }
  }

  /// Get comments stream for a video
  Stream<List<Comment>> getCommentsStream(String videoId) {
    return _firestore
        .collection(_videosCollection)
        .doc(videoId)
        .collection(_commentsSubcollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Comment.fromDocumentSnapshot)
              .toList(),
        );
  }

  /// Get replies stream for a comment
  Stream<List<Reply>> getRepliesStream(String videoId, String commentId) {
    return _firestore
        .collection(_videosCollection)
        .doc(videoId)
        .collection(_commentsSubcollection)
        .doc(commentId)
        .collection(_repliesSubcollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Reply.fromDocumentSnapshot)
              .toList(),
        );
  }

  // ========================================================================
  // VIDEO METADATA UPDATES
  // ========================================================================

  /// Add share record for a video
  Future<void> addShare(String videoId, String share) async {
    await safeExecute(
      () => _addShareInternal(videoId, share),
      showLoading: false,
    );
  }

  /// Internal add share implementation
  Future<void> _addShareInternal(String videoId, String share) async {
    try {
      final videoRef = _firestore.collection(_videosCollection).doc(videoId);

      await _firestore
          .runTransaction((transaction) async {
            final snapshot = await transaction.get(videoRef);

            if (!snapshot.exists) {
              throw const app_exceptions.FirestoreException(
                message: 'Video not found',
              );
            }

            final shares = List<String>.from(
              snapshot.data()!['shares'] as List? ??
                  [],
            );
            shares.add(share);

            transaction.update(videoRef, {'shares': shares});
          })
          .timeout(_defaultTimeout);

      showSuccess('Video shared');

      if (kDebugMode) {
        debugPrint('MainController: Video $videoId shared');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sharing video: $e');
      }
      rethrow;
    }
  }

  /// Increment view count for a video (follows Unique User + Qualified View Strategy)
  Future<void> incrementViews({
    required String videoId,
    required String userId,
    required bool isQualified,
  }) async {
    if (videoId.isEmpty) return;

    try {
      final videoRef = _firestore.collection(_videosCollection).doc(videoId);

      // If user is authenticated, enforce one view per user
      if (userId.isNotEmpty && userId != 'anonymous') {
        final viewRef = videoRef.collection('views').doc(userId);

        if (kIsWeb) {
          try {
            final viewDoc = await viewRef.get().timeout(_defaultTimeout);
            if (!viewDoc.exists) {
              await viewRef.set({
                'timestamp': FieldValue.serverTimestamp(),
              }).timeout(_defaultTimeout);

              await videoRef.update({
                'viewCount': FieldValue.increment(1),
                if (isQualified)
                  'qualifiedViewCount': FieldValue.increment(1),
              }).timeout(_defaultTimeout);
            }
          } catch (e) {
            debugPrint('Error updating views on Web: $e');
          }
        } else {
          await _firestore
              .runTransaction((transaction) async {
                final viewDoc = await transaction.get(viewRef);

                if (!viewDoc.exists) {
                  transaction.set(viewRef, {
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  transaction.update(videoRef, {
                    'viewCount': FieldValue.increment(1),
                    if (isQualified)
                      'qualifiedViewCount': FieldValue.increment(1),
                  });
                }
              })
              .timeout(_defaultTimeout);
        }
      } else {
        // Anonymous view (simple increment)
        await videoRef
            .update({
              'viewCount': FieldValue.increment(1),
              if (isQualified) 'qualifiedViewCount': FieldValue.increment(1),
            })
            .timeout(_defaultTimeout);
      }

      if (kDebugMode) {
        debugPrint(
          'MainController: View counted for video $videoId (Qualified: $isQualified, User: $userId)',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating views: $e');
      }
    }
  }

  /// Track a watch event via Cloud Function (Industry Standard).
  /// Events: video_start, qualified_view, milestone_25/50/75/100, video_exit
  ///
  /// Includes:
  ///   - idempotencyKey: prevents duplicate writes on function retries
  ///   - viewerHash: privacy-safe anonymous identity for server dedup
  ///   - dedupKey: explicit dedup doc ID for qualified_view enforcement
  Future<bool> trackWatchEvent({
    required String videoId,
    required String eventType,
    required int position,
    required int duration,
    int? watchTimeSecondsDelta,
    bool isSubscriber = false,
    bool isNotSubscriber = false,
    String trafficSource = 'direct',
    String? viewerHash,
    String? dedupKey,
  }) async {
    if (videoId.isEmpty) return false;

    try {
      final userId = _auth.currentUser?.uid;
      final sessionId = "session_${videoId}_${userId ?? 'anon'}";

      // Idempotency key: unique per event emission.
      // If Cloud Function retries, it checks this key and skips duplicates.
      // Format: {videoId}_{userId}_{eventType}_{positionBucket}_{timestamp}
      final positionBucket =
          (position ~/ 5) * 5; // 5s buckets for dedup tolerance
      final idempotencyKey =
          '${videoId}_${userId ?? viewerHash ?? 'anon'}_${eventType}_${positionBucket}_${DateTime.now().millisecondsSinceEpoch ~/ 1000}';

      // URL for Gen 2 (Asia South 1): https://<service-name>-<hash>-<region-code>.a.run.app
      final response = await http
          .post(
            Uri.parse('https://trackwatchevent-prcqnsipmq-el.a.run.app'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'videoId': videoId,
              'userId': userId ?? 'anonymous',
              'sessionId': sessionId,
              'eventType': eventType,
              'position': position,
              'duration': duration,
              'watchTimeSecondsDelta': watchTimeSecondsDelta ?? 0,
              'isSubscriber': isSubscriber,
              'isNotSubscriber': isNotSubscriber,
              'trafficSource': trafficSource,
              // Anti-fraud / dedup fields
              'idempotencyKey': idempotencyKey,
              'viewerHash': viewerHash, // Privacy-safe anonymous identity
              'dedupKey':
                  dedupKey, // Server creates qualified_views/{dedupKey} via tx
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            'MainController: trackWatchEvent failed (${response.statusCode}): ${response.body}',
          );
        }
        return false;
      }
      return true;
    } on http.ClientException catch (e) {
      // Caught client exception usually indicates CORS preflight blocking or missing network connection
      if (kDebugMode) {
        debugPrint(
          'MainController: Analytics endpoint unreachable or blocked by CORS preflight ($e). Failing silently to prevent UI disruption.',
        );
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MainController: Error calling trackWatchEvent: $e');
      }
      return false;
    }
  }

  /// Record a detailed watch session for analytics
  /// Record a detailed watch session for analytics (DEPRECATED: Now handled server-side)
  Future<void> recordWatchSession(Map<String, dynamic> sessionData) async {
    // Detailed sessions are now reconstructed server-side from event streams
    return;
  }

  /// Increment share count for a video
  Future<void> incrementShareCount(String videoId) async {
    if (videoId.isEmpty) return;
    try {
      await _firestore
          .collection(_videosCollection)
          .doc(videoId)
          .update({'shareCount': FieldValue.increment(1)})
          .timeout(_defaultTimeout);
    } catch (e) {
      debugPrint('Error incrementing share count: $e');
    }
  }

  // ========================================================================
  // SEARCH & FILTERING
  // ========================================================================

  /// Filter videos by search query
  void filterVideos(String query) {
    searchQuery.value = query;

    if (query.isEmpty) {
      filteredVideos.assignAll(videos);
    } else {
      final lowerQuery = query.toLowerCase();
      filteredVideos.assignAll(
        videos.where((video) {
          return video.title.toLowerCase().contains(lowerQuery) ||
              video.description.toLowerCase().contains(lowerQuery) ||
              video.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
        }).toList(),
      );
    }

    if (kDebugMode) {
      debugPrint(
        'MainController: Filtered to ${filteredVideos.length} videos for query "$query"',
      );
    }
  }

  // ========================================================================
  // OFFLINE & DOWNLOAD
  // ========================================================================

  /// Download video to device
  Future<void> downloadVideoToDevice(Uint8List bytes, String fileName) async {
    try {
      final blob = html.Blob([bytes], 'video/mp4');
      final url = html.Url.createObjectUrlFromBlob(blob);

      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();

      html.Url.revokeObjectUrl(url);

      showSuccess('Download started');

      if (kDebugMode) {
        debugPrint('MainController: Download started for $fileName');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error downloading video: $e');
      }

      throw app_exceptions.ValidationException(
        message: 'Failed to download video',
        originalException: e,
      );
    }
  }

  /// Save video for offline viewing
  Future<void> saveOfflineVideo(OfflineVideo video, String videoUrl) async {
    try {
      final response = await http
          .get(Uri.parse(videoUrl))
          .timeout(_defaultTimeout);

      if (response.statusCode != 200) {
        throw app_exceptions.ValidationException(
          message: 'Failed to download video (HTTP ${response.statusCode})',
        );
      }

      final dbFactory = getIdbFactory();
      if (dbFactory == null) return;
      final db = await dbFactory.open(
        'video_db',
        version: 1,
        onUpgradeNeeded: (e) {
          final db = e.database;
          if (!db.objectStoreNames.contains('videos')) {
            db.createObjectStore('videos');
          }
        },
      );

      final txn = db.transaction('videos', 'readwrite');
      final store = txn.objectStore('videos');

      final data = {'meta': video.toJson(), 'bytes': response.bodyBytes};

      await store.put(data, video.id);
      await txn.completed;

      showSuccess('Video saved for offline viewing');

      if (kDebugMode) {
        debugPrint('MainController: Saved offline video ${video.title}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving offline video: $e');
      }

      throw app_exceptions.ValidationException(
        message: 'Failed to save video offline',
        originalException: e,
      );
    }
  }

  // ========================================================================
  // REPORTING
  // ========================================================================

  /// Report a video with reason and optional details
  Future<void> reportVideo({
    required BuildContext context,
    required String videoId,
    required String channelId,
    required String reason,
    required String comment,
  }) async {
    if (_auth.currentUser == null) {
      showWarning('You must be signed in to report');
      return;
    }

    await safeExecute(
      () => _reportVideoInternal(
        videoId: videoId,
        channelId: channelId,
        reason: reason,
        comment: comment,
      ),
      loadingMessage: 'Submitting report...',
    );
  }

  /// Internal report video implementation
  Future<void> _reportVideoInternal({
    required String videoId,
    required String channelId,
    required String reason,
    required String comment,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const app_exceptions.AuthException(
          message: 'User not authenticated',
        );
      }

      if (reason.isEmpty) {
        throw const app_exceptions.ValidationException(
          message: 'Please select a report reason',
        );
      }

      final reportData = {
        'videoId': videoId,
        'channelId': channelId,
        'userId': user.uid,
        'userEmail': user.email ?? 'unknown',
        'reason': {
          'id': reason.toLowerCase().replaceAll(' ', '_'),
          'label': reason,
        },
        'comment': comment.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(_reportsCollection)
          .add(reportData)
          .timeout(_defaultTimeout);

      showSuccess(
        'Report submitted successfully. Thank you for your feedback.',
      );

      if (kDebugMode) {
        debugPrint('MainController: Report submitted for video $videoId');
      }
    } on app_exceptions.TimeoutException {
      rethrow;
    } on app_exceptions.ValidationException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error reporting video: $e');
      }

      throw app_exceptions.FirestoreException(
        message: 'Failed to submit report',
        originalException: e,
      );
    }
  }

  /// Add video to watch later
  Future<void> addToWatchLater(String videoId) async {
    if (_auth.currentUser == null) {
      showWarning('Please sign in to use Watch Later');
      return;
    }

    await safeExecute(
      () => _addToWatchLaterInternal(videoId),
      showLoading: false,
    );
  }

  /// Internal add to watch later implementation
  Future<void> _addToWatchLaterInternal(String videoId) async {
    try {
      final watchLaterRef = _firestore
          .collection(_usersCollection)
          .doc(_auth.currentUser!.uid)
          .collection('watch_later')
          .doc(videoId);

      await watchLaterRef
          .set({
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(_defaultTimeout);

      showSuccess('Video added to Watch Later');

      if (kDebugMode) {
        debugPrint('MainController: Video $videoId added to watch later');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding to watch later: $e');
      }

      throw app_exceptions.FirestoreException(
        message: 'Failed to add video to Watch Later',
        originalException: e,
      );
    }
  }

  // ========================================================================
  // GETTERS
  // ========================================================================

  /// Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get filtered video count
  int get filteredVideoCount => filteredVideos.length;

  /// Get total video count
  int get totalVideoCount => videos.length;

  /// Check if image is picked
  bool get isImagePicked => pickedImage.value != null;

  /// Check if video is picked
  bool get isVideoPicked => pickedVideo.value != null;
}
