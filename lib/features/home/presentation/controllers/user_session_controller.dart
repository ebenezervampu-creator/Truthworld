import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/share_bottom_sheet.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart'
    as app_exceptions;
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/features/home/presentation/controllers/app_navigation_controller.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';

// ========================================================================
// EXTENSION: Stream Retry Logic
// ========================================================================

// ========================================================================
// MAIN CONTROLLER
// ========================================================================

/// Main controller managing video operations, comments, interactions, and content discovery

class UserSessionController extends BaseController {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterVideoInfo videoInfo = FlutterVideoInfo();


  static const String _videosCollection = 'videos';
  static const String _commentsSubcollection = 'comments';
  static const String _repliesSubcollection = 'replies';
  static const String _usersCollection = 'users';
  static const String _reportsCollection = 'reports';

  String get userId => _auth.currentUser?.uid ?? '';
  static const Duration _defaultTimeout = Duration(seconds: 10);
  

  final RxMap<String, int> videoLikes = <String, int>{}.obs;
  final RxMap<String, int> videoDislikes = <String, int>{}.obs;
  final RxBool isReporting = false.obs;

  // Client-side guard for rapid tapping (race condition prevention)
  final _pendingLikeOperations = <String>{};
  final _pendingDislikeOperations = <String>{};
  final _pendingReportVideoIds = <String>{};

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

  /// Like a video
  /// Stores index in: users/{userId}/likedVideos/{videoId}
  /// Increments/decrements scalar `likeCount` on video document
  Future<void> likeVideo(String videoId, String userId) async {
    if (videoId.isEmpty || userId.isEmpty) return;

    final operationKey = 'like:$videoId:$userId';
    if (_pendingLikeOperations.contains(operationKey)) {
      debugPrint('[Like] Operation already in progress, ignoring duplicate');
      return;
    }
    _pendingLikeOperations.add(operationKey);

    try {
      final videoRef = _firestore.collection(_videosCollection).doc(videoId);
      final userLikedRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('likedVideos')
          .doc(videoId);
      final userDislikedRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('dislikedVideos')
          .doc(videoId);

      await _firestore.runTransaction((transaction) async {
        final likedDoc = await transaction.get(userLikedRef);
        final dislikedDoc = await transaction.get(userDislikedRef);

        if (likedDoc.exists) {
          // Unlike
          transaction.delete(userLikedRef);
          transaction.update(videoRef, {'likeCount': FieldValue.increment(-1)});
        } else {
          // Like
          transaction.set(userLikedRef, {
            'videoId': videoId,
            'timestamp': FieldValue.serverTimestamp(),
          });
          transaction.update(videoRef, {'likeCount': FieldValue.increment(1)});

          // Remove dislike if exists
          if (dislikedDoc.exists) {
            transaction.delete(userDislikedRef);
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
      _pendingLikeOperations.remove(operationKey);
    }
  }

  /// Dislike a video
  /// Stores index in: users/{userId}/dislikedVideos/{videoId}
  /// Increments/decrements scalar `dislikeCount` on video document
  Future<void> dislikeVideo(String videoId, String userId) async {
    if (videoId.isEmpty || userId.isEmpty) return;

    final operationKey = 'dislike:$videoId:$userId';
    if (_pendingDislikeOperations.contains(operationKey)) {
      debugPrint('[Dislike] Operation already in progress, ignoring duplicate');
      return;
    }
    _pendingDislikeOperations.add(operationKey);

    try {
      final videoRef = _firestore.collection(_videosCollection).doc(videoId);
      final userLikedRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('likedVideos')
          .doc(videoId);
      final userDislikedRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection('dislikedVideos')
          .doc(videoId);

      await _firestore.runTransaction((transaction) async {
        final likedDoc = await transaction.get(userLikedRef);
        final dislikedDoc = await transaction.get(userDislikedRef);

        if (dislikedDoc.exists) {
          // Remove dislike
          transaction.delete(userDislikedRef);
          transaction.update(videoRef, {
            'dislikeCount': FieldValue.increment(-1),
          });
        } else {
          // Add dislike
          transaction.set(userDislikedRef, {
            'videoId': videoId,
            'timestamp': FieldValue.serverTimestamp(),
          });
          transaction.update(videoRef, {
            'dislikeCount': FieldValue.increment(1),
          });

          // Remove like if exists
          if (likedDoc.exists) {
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
      Get.find<AppNavigationController>().incrementShareCount(videoId);

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
      final userDoc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .get();
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
      final hasChannel =
          authService.hasChannel.value && authService.userChannel != null;

      final finalUserName = authService.activeDisplayName;
      final finalUserProfilePicUrl = authService.activePhotoUrl;
      final finalChannelId = hasChannel ? authService.userChannel!.id : userId;
      final finalChannelName = hasChannel
          ? (authService.userChannel?.handle.isNotEmpty == true
                ? authService.userChannel!.handle
                : authService.userChannel!.name)
          : authService.activeDisplayName;
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
      final hasChannel =
          authService.hasChannel.value && authService.userChannel != null;

      final finalUserName = authService.activeDisplayName;
      final finalUserProfilePicUrl = authService.activePhotoUrl;
      final finalChannelId = hasChannel ? authService.userChannel!.id : userId;
      final finalChannelName = hasChannel
          ? (authService.userChannel?.handle.isNotEmpty == true
                ? authService.userChannel!.handle
                : authService.userChannel!.name)
          : authService.activeDisplayName;
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
          (snapshot) =>
              snapshot.docs.map(Comment.fromDocumentSnapshot).toList(),
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
          (snapshot) => snapshot.docs.map(Reply.fromDocumentSnapshot).toList(),
        );
  }


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

    final requestKey = '${_auth.currentUser!.uid}_$videoId';
    if (_pendingReportVideoIds.contains(requestKey)) {
      return; // Already submitting a report for this video
    }
    _pendingReportVideoIds.add(requestKey);

    try {
      await safeExecute(
        () => _reportVideoInternal(
          videoId: videoId,
          channelId: channelId,
          reason: reason,
          comment: comment,
        ),
        loadingMessage: 'Submitting report...',
      );
    } finally {
      _pendingReportVideoIds.remove(requestKey);
    }
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
        'reportedBy': user.uid,
        'reporterId': user.uid,
        'userEmail': user.email ?? 'unknown',
        'reason': {
          'id': reason.toLowerCase().replaceAll(' ', '_'),
          'label': reason,
        },
        'comment': comment.trim(),
        'status': 'pending',
        'type': 'video',
        'createdAt': FieldValue.serverTimestamp(),
        'reportedAt': FieldValue.serverTimestamp(),
      };

      final docId = '${user.uid}_$videoId';
      await _firestore
          .collection(_reportsCollection)
          .doc(docId)
          .set(reportData, SetOptions(merge: true))
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


  /// Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get filtered video count

  /// Get total video count

  /// Check if image is picked

  /// Check if video is picked
}
