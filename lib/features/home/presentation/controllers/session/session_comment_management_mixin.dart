import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart' as app_exceptions;
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';

/// Mixin managing comment and reply creation, deletion, and real-time streams.
mixin SessionCommentManagementMixin on BaseController {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static const String _videosCollection = 'videos';
  static const String _commentsSubcollection = 'comments';
  static const String _repliesSubcollection = 'replies';
  static const Duration _defaultTimeout = Duration(seconds: 10);

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
      final userChannel = hasChannel ? authService.userChannel : null;

      final rawName = authService.userDisplayName.value ??
          authService.user?.displayName ??
          'User';
      final finalUserName =
          rawName.startsWith('@') ? rawName.substring(1) : rawName;
      final finalUserProfilePicUrl = authService.userPhotoUrl.value ??
          authService.user?.photoURL ??
          '';
      final finalChannelId = hasChannel ? userChannel!.id : '';
      final finalChannelHandle = userChannel?.handle;
      final finalChannelName = userChannel?.name;
      final finalChannelProfilePicUrl = userChannel?.avatarUrl;

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
        channelHandle: finalChannelHandle,
        channelProfilePicUrl: finalChannelProfilePicUrl,
        isChannel: hasChannel,
        likeCount: 0,
        dislikeCount: 0,
        reportCount: 0,
      );

      await docRef.set(comment.toMap()).timeout(_defaultTimeout);

      showSuccess('Comment added');

      if (kDebugMode) {
        debugPrint('UserSessionController: Comment added to video $videoId');
      }
    } on app_exceptions.TimeoutException {
      rethrow;
    } on app_exceptions.ValidationException {
      rethrow;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserSessionController._addCommentInternal');
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
      final userChannel = hasChannel ? authService.userChannel : null;

      final rawName = authService.userDisplayName.value ??
          authService.user?.displayName ??
          'User';
      final finalUserName =
          rawName.startsWith('@') ? rawName.substring(1) : rawName;
      final finalUserProfilePicUrl = authService.userPhotoUrl.value ??
          authService.user?.photoURL ??
          '';
      final finalChannelId = hasChannel ? userChannel!.id : '';
      final finalChannelHandle = userChannel?.handle;
      final finalChannelName = userChannel?.name;
      final finalChannelProfilePicUrl = userChannel?.avatarUrl;

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
        channelHandle: finalChannelHandle,
        channelProfilePicUrl: finalChannelProfilePicUrl,
        isChannel: hasChannel,
        likeCount: 0,
        dislikeCount: 0,
        reportCount: 0,
      );

      await docRef.set(reply.toMap()).timeout(_defaultTimeout);

      showSuccess('Reply added');

      if (kDebugMode) {
        debugPrint('UserSessionController: Reply added to comment $commentId');
      }
    } on app_exceptions.TimeoutException {
      rethrow;
    } on app_exceptions.ValidationException {
      rethrow;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserSessionController._addReplyInternal');
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
        debugPrint('UserSessionController: Comment $commentId deleted');
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserSessionController._deleteCommentInternal');
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
        debugPrint('UserSessionController: Reply $replyId deleted');
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserSessionController._deleteReplyInternal');
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
}
