import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart' as app_exceptions;

/// Mixin managing likes, dislikes, and creator hearts on comments and replies.
mixin SessionCommentInteractionsMixin on BaseController {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  static const String _videosCollection = 'videos';
  static const String _commentsSubcollection = 'comments';
  static const String _repliesSubcollection = 'replies';
  static const Duration _defaultTimeout = Duration(seconds: 10);

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
        debugPrint('UserSessionController: Comment $commentId toggled like');
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserSessionController._likeCommentInternal');
      if (kDebugMode) {
        debugPrint('Error liking comment: $e');
      }
      rethrow;
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserSessionController._dislikeCommentInternal');
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
      var creatorName = 'Creator';
      final currentUid = _auth.currentUser?.uid;
      if (currentUid != null && currentUid.isNotEmpty) {
        final userDoc = await _firestore
            .collection(FirestoreCollections.users)
            .doc(currentUid)
            .get();
        if (userDoc.exists) {
          creatorName = userDoc.data()?['name'] ?? 'Creator';
        }
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserSessionController.heartComment');
      if (kDebugMode) {
        debugPrint('Error hearting comment: $e');
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
        debugPrint('UserSessionController: Reply $replyId toggled like');
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserSessionController._likeReplyInternal');
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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserSessionController._dislikeReplyInternal');
      if (kDebugMode) {
        debugPrint('Error disliking reply: $e');
      }
      rethrow;
    }
  }
}
