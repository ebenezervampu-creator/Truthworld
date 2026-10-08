import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart' as app_exceptions;
import 'package:truthworld/domain/usecases/video/toggle_like_video_usecase.dart';

/// Mixin managing video like and dislike interactions with Firestore transactions
/// and race-condition prevention guards.
mixin SessionVideoInteractionsMixin on BaseController {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  static const String _videosCollection = 'videos';

  final RxMap<String, int> videoLikes = <String, int>{}.obs;
  final RxMap<String, int> videoDislikes = <String, int>{}.obs;

  // Client-side guard for rapid tapping (race condition prevention)
  final Set<String> _pendingLikeOperations = <String>{};
  final Set<String> _pendingDislikeOperations = <String>{};

  @visibleForTesting
  Set<String> get pendingLikeOperations => _pendingLikeOperations;

  @visibleForTesting
  Set<String> get pendingDislikeOperations => _pendingDislikeOperations;

  /// Like a video
  /// Stores index in: users/{userId}/likedVideos/{videoId}
  /// Increments/decrements scalar `likeCount` on video document
  Future<void> likeVideo(String videoId, String userId) async {
    if (videoId.isEmpty || userId.isEmpty) return;

    // Security: always use server-verified UID, never trust caller-supplied userId
    final authenticatedUid = FirebaseAuth.instance.currentUser?.uid;
    if (authenticatedUid == null || authenticatedUid.isEmpty) return;
    if (authenticatedUid != userId) return;

    final operationKey = 'like:$videoId:$userId';
    if (_pendingLikeOperations.contains(operationKey)) {
      debugPrint('[Like] Operation already in progress, ignoring duplicate');
      return;
    }
    _pendingLikeOperations.add(operationKey);

    try {
      if (Get.isRegistered<ToggleLikeVideoUseCase>()) {
        final useCase = Get.find<ToggleLikeVideoUseCase>();
        final res = await useCase(ToggleLikeVideoParams(videoId: videoId, userId: userId));
        if (res.isFailure) {
          throw res.exceptionOrNull ?? Exception('Failed to update like status');
        }
        return;
      }

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
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserSessionController.likeVideo');
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

    // Security: always use server-verified UID, never trust caller-supplied userId
    final authenticatedUid = FirebaseAuth.instance.currentUser?.uid;
    if (authenticatedUid == null || authenticatedUid.isEmpty) return;
    if (authenticatedUid != userId) return;

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
          // Undislike
          transaction.delete(userDislikedRef);
          transaction.update(videoRef, {
            'dislikeCount': FieldValue.increment(-1),
          });
        } else {
          // Dislike
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
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'UserSessionController.dislikeVideo',
      );
      throw app_exceptions.FirestoreException(
        message: 'Failed to update dislike status',
        originalException: e,
      );
    } finally {
      _pendingDislikeOperations.remove(operationKey);
    }
  }
}
