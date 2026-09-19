import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart' as app_exceptions;

/// Mixin managing video reporting and user watch later library operations.
mixin SessionModerationLibraryMixin on BaseController {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  static const String _usersCollection = 'users';
  static const String _reportsCollection = 'reports';
  static const Duration _defaultTimeout = Duration(seconds: 10);

  final RxBool isReporting = false.obs;
  final Set<String> _pendingReportVideoIds = <String>{};

  @visibleForTesting
  Set<String> get pendingReportVideoIds => _pendingReportVideoIds;

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
        debugPrint('UserSessionController: Report submitted for video $videoId');
      }
    } on app_exceptions.TimeoutException {
      rethrow;
    } on app_exceptions.ValidationException {
      rethrow;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'UserSessionController.reportVideo');
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
        debugPrint('UserSessionController: Video $videoId added to watch later');
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'UserSessionController._addToWatchLaterInternal',
      );
      throw app_exceptions.FirestoreException(
        message: 'Failed to add video to Watch Later',
        originalException: e,
      );
    }
  }
}
