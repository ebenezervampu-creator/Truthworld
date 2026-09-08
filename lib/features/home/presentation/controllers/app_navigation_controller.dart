import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart'
    as app_exceptions;

class AppNavigationController extends BaseController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId => _auth.currentUser?.uid ?? '';
  static const Duration _defaultTimeout = Duration(seconds: 10);




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
      final videoRef = _firestore.collection(FirestoreCollections.videos).doc(videoId);

      await _firestore
          .runTransaction((transaction) async {
            final snapshot = await transaction.get(videoRef);

            if (!snapshot.exists) {
              throw const app_exceptions.FirestoreException(
                message: 'Video not found',
              );
            }

            final shares = List<String>.from(
              snapshot.data()!['shares'] as List? ?? [],
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

  /// Increment view count for a video & channel (follows Unique User + Qualified View Strategy)
  Future<void> incrementViews({
    required String videoId,
    required String userId,
    required bool isQualified,
    String? channelId,
  }) async {
    if (videoId.isEmpty) return;

    try {
      final videoRef = _firestore.collection(FirestoreCollections.videos).doc(videoId);

      // If user is authenticated, enforce one view per user
      if (userId.isNotEmpty && userId != 'anonymous') {
        final viewRef = videoRef.collection('views').doc(userId);

        if (kIsWeb) {
          try {
            final viewDoc = await viewRef.get().timeout(_defaultTimeout);
            if (!viewDoc.exists) {
              await viewRef
                  .set({
                    'timestamp': FieldValue.serverTimestamp(),
                  })
                  .timeout(_defaultTimeout);

              await videoRef
                  .update({
                    'viewCount': FieldValue.increment(1),
                    if (isQualified)
                      'qualifiedViewCount': FieldValue.increment(1),
                  })
                  .timeout(_defaultTimeout);

              if (channelId != null && channelId.isNotEmpty) {
                _firestore
                    .collection(FirestoreCollections.channels)
                    .doc(channelId)
                    .set({
                      'metrics': {'totalViews': FieldValue.increment(1)},
                      'viewCount': FieldValue.increment(1),
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true))
                    .catchError((_) {});
              }
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

                  if (channelId != null && channelId.isNotEmpty) {
                    final channelRef = _firestore
                        .collection(FirestoreCollections.channels)
                        .doc(channelId);
                    transaction.set(
                      channelRef,
                      {
                        'metrics': {'totalViews': FieldValue.increment(1)},
                        'viewCount': FieldValue.increment(1),
                        'updatedAt': FieldValue.serverTimestamp(),
                      },
                      SetOptions(merge: true),
                    );
                  }
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

        if (channelId != null && channelId.isNotEmpty) {
          _firestore
              .collection(FirestoreCollections.channels)
              .doc(channelId)
              .set({
                'metrics': {'totalViews': FieldValue.increment(1)},
                'viewCount': FieldValue.increment(1),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true))
              .catchError((_) {});
        }
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
    String? channelId,
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

      final timestampMs = DateTime.now().millisecondsSinceEpoch;
      final eventId = '${sessionId}_${position}_${eventType}_$timestampMs';

      final payload = jsonEncode({
        'videoId': videoId,
        'channelId': channelId ?? '',
        'userId': userId ?? 'anonymous',
        'sessionId': sessionId,
        'eventId': eventId,
        'eventType': eventType,
        'position': position,
        'duration': duration,
        'watchTimeSecondsDelta': watchTimeSecondsDelta ?? 0,
        'isSubscriber': isSubscriber,
        'isNotSubscriber': isNotSubscriber,
        'trafficSource': trafficSource,
        // Anti-fraud / dedup fields
        'idempotencyKey': eventId,
        'viewerHash': viewerHash, // Privacy-safe anonymous identity
        'dedupKey':
            dedupKey, // Server creates qualified_views/{dedupKey} via tx
      });
      final headers = {'Content-Type': 'application/json'};

      // Try direct Cloud Run service first, with fallback to Cloud Functions endpoint
      http.Response response;
      try {
        response = await http
            .post(
              Uri.parse('https://trackwatchevent-prcqnsipmq-el.a.run.app'),
              headers: headers,
              body: payload,
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        response = await http
            .post(
              Uri.parse('${AppConfig.cloudFunctionsBaseUrl}/trackWatchEvent'),
              headers: headers,
              body: payload,
            )
            .timeout(const Duration(seconds: 10));
      }

      if (response.statusCode != 200) {
        // Retry via Cloud Functions endpoint if direct Cloud Run returned non-200
        final fallbackResponse = await http
            .post(
              Uri.parse('${AppConfig.cloudFunctionsBaseUrl}/trackWatchEvent'),
              headers: headers,
              body: payload,
            )
            .timeout(const Duration(seconds: 5));

        if (fallbackResponse.statusCode != 200) {
          if (kDebugMode) {
            debugPrint(
              'MainController: trackWatchEvent failed (${fallbackResponse.statusCode}): ${fallbackResponse.body}',
            );
          }
          return false;
        }
        return true;
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
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .update({'shareCount': FieldValue.increment(1)})
          .timeout(_defaultTimeout);
    } catch (e) {
      debugPrint('Error incrementing share count: $e');
    }
  }

}
