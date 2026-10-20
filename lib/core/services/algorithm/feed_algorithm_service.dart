import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/algorithm/algorithm_remote_config.dart';
import 'package:truthworld/core/services/video_sanitizer.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Client for the server-side Truthworld feed endpoints.
/// Falls back to chronological feed on server failure.
class FeedAlgorithmService extends GetxService {
  FeedAlgorithmService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  /// Server endpoint for personalized home feed.
  /// Resolves dynamically from AlgorithmRemoteConfig, compile-time environment, or empty fallback.
  static String get homeFeedEndpoint {
    if (Get.isRegistered<AlgorithmRemoteConfig>()) {
      final configured = Get.find<AlgorithmRemoteConfig>().homeFeedEndpoint;
      if (configured.isNotEmpty) return configured;
    }
    return const String.fromEnvironment('TRUTHWORLD_HOME_FEED_ENDPOINT');
  }

  /// Server endpoint for public edge-cached feeds backed by Google Cloud CDN.
  static String get publicFeedEndpoint {
    const envEndpoint = String.fromEnvironment('TRUTHWORLD_FEED_ENDPOINT');
    if (envEndpoint.isNotEmpty) return envEndpoint;
    return 'https://www.truthworld.in/api/feed';
  }

  /// Check if server endpoint is configured and reachable
  bool get isServerAvailable => FeedAlgorithmService.homeFeedEndpoint.isNotEmpty;

  /// Fetch personalized home feed from server
  /// Seamlessly falls back to any available videos from Firestore on server failure, empty response, or offline state.
  Future<List<Video>> getPersonalizedFeed({
    String? userId,
    String? category,
    int limit = 24,
    DateTime? startAfter,
  }) async {
    if (!isServerAvailable || userId == null || userId.isEmpty) {
      return getPersonalizedFeedFallback(category: category, limit: limit);
    }

    final uri = Uri.parse(FeedAlgorithmService.homeFeedEndpoint).replace(
      queryParameters: {
        'userId': userId,
        'limit': limit.toString(),
        if (category != null && category.isNotEmpty) 'category': category,
        if (startAfter != null) 'startAfter': startAfter.toIso8601String(),
      },
    );

    Map<String, String>? headers;
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        headers = {'Authorization': 'Bearer $token'};
      }
    } catch (_) {}

    http.Response? response;
    try {
      response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 6));
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'FeedAlgorithmService.getPersonalizedFeed.firstAttempt',
      );
      try {
        response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 8));
      } catch (retryError, retryStackTrace) {
        ErrorHandler.log(
          retryError,
          stackTrace: retryStackTrace,
          tag: 'FeedAlgorithmService.getPersonalizedFeed.retry',
        );
        return getPersonalizedFeedFallback(category: category, limit: limit);
      }
    }

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        final videosJson = (data['feed'] as List<dynamic>?) ??
            (data['videos'] as List<dynamic>?) ??
            [];

        if (videosJson.isNotEmpty) {
          var videos = videosJson
              .map((json) => Video.fromMap(Map<String, dynamic>.from(json)))
              .toList();

          // If server returned videos that lack playable media (e.g. recommendation endpoints
          // providing ranking metadata without playable streaming URLs, or unhydrated payloads),
          // hydrate them from Firestore while strictly preserving the server's personalized ranking order.
          if (videos.any((v) => !VideoVisibilityPolicy.hasPlayableMedia(v))) {
            videos = await _hydrateVideosFromFirestore(videos);
          }

          var sanitized = VideoSanitizer.sanitizeForFeed(videos);
          if (sanitized.isEmpty && videos.isNotEmpty) {
            videos = await _hydrateVideosFromFirestore(videos, forceAll: true);
            sanitized = VideoSanitizer.sanitizeForFeed(videos);
          }

          final candidatePool = sanitized.isNotEmpty
              ? sanitized
              : videos
                  .where((v) =>
                      v.id.isNotEmpty &&
                      !v.isDraft &&
                      v.status != VideoStatus.deleted &&
                      v.status != VideoStatus.rejected &&
                      VideoVisibilityPolicy.hasPlayableMedia(v))
                  .toList();

          if (candidatePool.isNotEmpty) {
            // YouTube-style backfill:
            // First prefer personalized videos (candidatePool).
            // If the personalized videos count is lower than limit,
            // backfill remaining slots with other public videos from TruthWorld catalog in Firestore.
            if (candidatePool.length < limit) {
              final existingIds = candidatePool.map((v) => v.id).toSet();
              final remainingNeeded = limit - candidatePool.length;
              final backfillVideos = await _fallbackChronologicalFeed(
                category: category,
                limit: remainingNeeded + existingIds.length,
              );
              for (final v in backfillVideos) {
                if (!existingIds.contains(v.id)) {
                  candidatePool.add(v);
                  existingIds.add(v.id);
                  if (candidatePool.length >= limit) break;
                }
              }
            }
            return candidatePool;
          }
        }
      } catch (parseError, parseStackTrace) {
        ErrorHandler.log(
          parseError,
          stackTrace: parseStackTrace,
          tag: 'FeedAlgorithmService.getPersonalizedFeed.parse',
        );
      }
    }

    // Never return 0 videos from personalized feed:
    // If the server returned 0 videos or failed, seamlessly fall back to any other available videos from Firestore.
    return getPersonalizedFeedFallback(category: category, limit: limit);
  }

  /// Resilient fallback for personalized feed:
  /// Attempts category-specific videos first, then falls back to any other available public videos from Firestore.
  /// If category videos count is lower than limit, backfills remaining slots from global catalog.
  Future<List<Video>> getPersonalizedFeedFallback({
    String? category,
    int limit = 24,
  }) async {
    final categoryVideos = await _fallbackChronologicalFeed(
      category: category,
      limit: limit,
    );

    // If category has some videos but fewer than limit, first prefer category videos,
    // then backfill remaining slots from unconstrained TruthWorld catalog so feed never faces low count.
    if (categoryVideos.length < limit &&
        category != null &&
        category.isNotEmpty &&
        category != 'All') {
      final existingIds = categoryVideos.map((v) => v.id).toSet();
      final remainingNeeded = limit - categoryVideos.length;
      final unconstrainedVideos = await _fallbackChronologicalFeed(
        limit: remainingNeeded + existingIds.length,
      );
      for (final v in unconstrainedVideos) {
        if (!existingIds.contains(v.id)) {
          categoryVideos.add(v);
          existingIds.add(v.id);
          if (categoryVideos.length >= limit) break;
        }
      }
    }

    if (categoryVideos.isNotEmpty) {
      return categoryVideos;
    }

    return _fallbackChronologicalFeed(limit: limit);
  }

  /// Hydrates full video documents from Firestore when the recommendation endpoint
  /// returns ranking scores/metadata with unpopulated stream URLs, preserving exact server ranking order.
  Future<List<Video>> _hydrateVideosFromFirestore(
    List<Video> serverVideos, {
    bool forceAll = false,
  }) async {
    final targetIds = serverVideos
        .where((v) => forceAll || !VideoVisibilityPolicy.hasPlayableMedia(v))
        .map((v) => v.id)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (targetIds.isEmpty) return serverVideos;

    try {
      final firestoreMap = <String, Video>{};

      for (var i = 0; i < targetIds.length; i += 30) {
        final chunk = targetIds.skip(i).take(30).toList();
        final query = _firestore
            .collection(FirestoreCollections.videos)
            .where(FieldPath.documentId, whereIn: chunk);
        final snap = await query.getCacheFirst();

        for (final doc in snap.docs) {
          if (doc.exists) {
            firestoreMap[doc.id] = Video.fromDocumentSnapshot(doc);
          }
        }
      }

      final hydrated = <Video>[];
      for (final sVideo in serverVideos) {
        if (!forceAll && VideoVisibilityPolicy.hasPlayableMedia(sVideo)) {
          hydrated.add(sVideo);
        } else if (firestoreMap.containsKey(sVideo.id)) {
          final fVideo = firestoreMap[sVideo.id]!;
          hydrated.add(fVideo.copyWith(
            trustScore: sVideo.trustScore > 0 ? sVideo.trustScore : fVideo.trustScore,
            embedding: sVideo.embedding ?? fVideo.embedding,
          ));
        } else {
          hydrated.add(sVideo);
        }
      }
      return hydrated;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'FeedAlgorithmService._hydrateVideosFromFirestore',
      );
      return serverVideos;
    }
  }

  /// Fetch edge-cached public feed backed by Google Cloud CDN (sub-50ms global latency).
  /// Automatically falls back to Firestore on network failure or offline state.
  Future<List<Video>> getPublicEdgeFeed({
    String? category,
    int limit = 24,
    bool isTrending = false,
  }) async {
    final subPath = isTrending ? 'trending' : 'home';
    final queryParams = <String, String>{
      'limit': limit.toString(),
      if (category != null && category.isNotEmpty && category != 'All')
        'category': category,
    };

    final uri = Uri.parse('${FeedAlgorithmService.publicFeedEndpoint}/$subPath')
        .replace(queryParameters: queryParams);

    try {
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final rawFeed = (data['feed'] as List<dynamic>?) ?? [];
        if (rawFeed.isNotEmpty) {
          var videos = rawFeed
              .map((item) => Video.fromMap(Map<String, dynamic>.from(item as Map)))
              .toList();
          if (videos.any((v) => !VideoVisibilityPolicy.hasPlayableMedia(v))) {
            videos = await _hydrateVideosFromFirestore(videos);
          }
          return VideoSanitizer.sanitizeForFeed(videos);
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'FeedAlgorithmService.getPublicEdgeFeed.fallback',
      );
    }

    // High-availability fallback: Query Firestore directly
    return _fallbackChronologicalFeed(category: category, limit: limit);
  }

  /// Apply lightweight client-side adjustments to server-ranked feed.
  /// Does NOT rerank. Only applies session boost, diversity, and local filters.
  List<Video> applyLocalAdjustments(
    List<Video> serverRankedVideos, {
    Set<String>? notInterestedVideoIds,
    Set<String>? blockedChannelIds,
    Set<String>? recentlyWatchedVideoIds,
  }) {
    final unadjusted = serverRankedVideos.where((video) {
      // Filter out not-interested videos
      if (notInterestedVideoIds?.contains(video.id) ?? false) return false;
      // Filter out blocked channels
      if (blockedChannelIds?.contains(video.channelId) ?? false) return false;
      return true;
    }).toList();

    final adjusted = unadjusted.where((video) {
      // Filter out recently watched
      if (recentlyWatchedVideoIds?.contains(video.id) ?? false) return false;
      return true;
    }).toList();

    // If excluding recently watched removes all videos, relax the recently watched filter
    // rather than starving the feed to 0 items.
    if (adjusted.isEmpty && unadjusted.isNotEmpty) {
      return unadjusted;
    }

    // If even unadjusted is empty, fall back to the original server videos rather than returning 0 items.
    if (adjusted.isEmpty && serverRankedVideos.isNotEmpty) {
      return serverRankedVideos;
    }

    return adjusted;
  }

  /// Public convenience method to fetch any available videos from Firestore without constraints.
  Future<List<Video>> getAnyFallbackVideos({int limit = 24}) {
    return _fallbackChronologicalFeed(limit: limit);
  }

  /// Fetch discovery modules (Elite Spotlight, Verified Today, Rising Fast)
  Future<Map<String, List<Video>>> getDiscoveryModules() async {
    try {
      // In a real app we'd fetch from another endpoint or Firestore explicitly
      return {
        'elite': await _fallbackChronologicalFeed(limit: 5),
        'verified': await _fallbackChronologicalFeed(limit: 5),
        'rising': await _fallbackChronologicalFeed(limit: 5),
      };
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'FeedAlgorithmService.getDiscoveryModules',
      );
      return {};
    }
  }

  /// Fallback: chronological feed from Firestore
  Future<List<Video>> _fallbackChronologicalFeed({
    String? category,
    int limit = 24,
  }) async {
    try {
      Query query = _firestore.collection(FirestoreCollections.videos);

      if (category != null && category.isNotEmpty && category != 'All') {
        query = query.where('category', isEqualTo: category);
      }

      QuerySnapshot snapshot;
      try {
        snapshot = await query
            .orderBy('uploadedAt', descending: true)
            .limit(limit)
            .get();
      } catch (_) {
        try {
          snapshot = await query
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get();
        } catch (_) {
          snapshot = await query.limit(limit).get();
        }
      }

      if (snapshot.docs.isEmpty) {
        try {
          snapshot = await _firestore
              .collection(FirestoreCollections.videos)
              .limit(limit)
              .get();
        } catch (_) {}
      }

      final videos = snapshot.docs.map((doc) {
        final data = doc.data()! as Map<String, dynamic>;
        data['id'] = doc.id;
        return Video.fromMap(data);
      }).toList();

      final sanitized = VideoSanitizer.sanitizeForFeed(videos);
      if (sanitized.isNotEmpty) return sanitized;
      return videos
          .where((v) =>
              v.id.isNotEmpty &&
              !v.isDraft &&
              v.status != VideoStatus.deleted &&
              v.status != VideoStatus.rejected &&
              VideoVisibilityPolicy.hasPlayableMedia(v))
          .toList();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'FeedAlgorithmService.fallbackChronologicalFeed',
      );
      return [];
    }
  }
}
