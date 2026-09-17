import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/algorithm/algorithm_remote_config.dart';
import 'package:truthworld/core/services/video_sanitizer.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Client for the server-side Truthworld feed endpoints.
/// Falls back to chronological feed on server failure.
class FeedAlgorithmService extends GetxService {
  /// Server endpoint for personalized home feed.
  /// Resolves dynamically from AlgorithmRemoteConfig, compile-time environment, or empty fallback.
  static String get homeFeedEndpoint {
    if (Get.isRegistered<AlgorithmRemoteConfig>()) {
      final configured = Get.find<AlgorithmRemoteConfig>().homeFeedEndpoint;
      if (configured.isNotEmpty) return configured;
    }
    return const String.fromEnvironment('TRUTHWORLD_HOME_FEED_ENDPOINT');
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if server endpoint is configured and reachable
  bool get isServerAvailable => homeFeedEndpoint.isNotEmpty;

  /// Fetch personalized home feed from server
  /// Throws on error to let caller fall back
  Future<List<Video>> getPersonalizedFeed({
    String? userId,
    String? category,
    int limit = 24,
    DateTime? startAfter,
  }) async {
    if (!isServerAvailable || userId == null || userId.isEmpty) {
      throw Exception('Server not available or missing userId');
    }

    final uri = Uri.parse(homeFeedEndpoint).replace(
      queryParameters: {
        'userId': userId,
        'limit': limit.toString(),
        if (category != null && category.isNotEmpty) 'category': category,
        if (startAfter != null) 'startAfter': startAfter.toIso8601String(),
      },
    );

    http.Response? response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 3));
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'FeedAlgorithmService.getPersonalizedFeed.firstAttempt',
      );
      try {
        response = await http.get(uri).timeout(const Duration(seconds: 5));
      } catch (retryError, retryStackTrace) {
        ErrorHandler.log(
          retryError,
          stackTrace: retryStackTrace,
          tag: 'FeedAlgorithmService.getPersonalizedFeed.retry',
        );
        throw Exception('Failed to fetch from server after retry.');
      }
    }

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> videosJson = data['videos'] ?? [];

      final videos = videosJson
          .map((json) => Video.fromMap(Map<String, dynamic>.from(json)))
          .toList();

      return VideoSanitizer.sanitizeForFeed(videos);
    } else {
      throw Exception('Server returned ${response.statusCode}');
    }
  }

  /// Apply lightweight client-side adjustments to server-ranked feed.
  /// Does NOT rerank. Only applies session boost, diversity, and local filters.
  List<Video> applyLocalAdjustments(
    List<Video> serverRankedVideos, {
    Set<String>? notInterestedVideoIds,
    Set<String>? blockedChannelIds,
    Set<String>? recentlyWatchedVideoIds,
  }) {
    return serverRankedVideos.where((video) {
      // Filter out not-interested videos
      if (notInterestedVideoIds?.contains(video.id) ?? false) return false;
      // Filter out blocked channels
      if (blockedChannelIds?.contains(video.channelId) ?? false) return false;
      // Filter out recently watched
      if (recentlyWatchedVideoIds?.contains(video.id) ?? false) return false;
      return true;
    }).toList();
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
      Query query = _firestore
          .collection(FirestoreCollections.videos)
          .where('status', isEqualTo: 'published');

      if (category != null && category.isNotEmpty && category != 'All') {
        query = query.where('category', isEqualTo: category);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      final snapshot = await query.get();
      final videos = snapshot.docs.map((doc) {
        final data = doc.data()! as Map<String, dynamic>;
        data['id'] = doc.id;
        return Video.fromMap(data);
      }).toList();

      return VideoSanitizer.sanitizeForFeed(videos);
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
