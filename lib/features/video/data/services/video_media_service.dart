// ==========================================================================
// VIDEO MEDIA SERVICE — Reads/Writes to video media subcollections
// ==========================================================================
//
// Handles lazy-loading of heavy video data from subcollections:
//   videos/{videoId}/media/localization
//   videos/{videoId}/media/credibility
//   videos/{videoId}/media/streaming
//
// This service is used by VideoController to fetch additional data
// only when needed (e.g., credibility report when user opens it,
// subtitles when player starts, etc.)
// ==========================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';

class VideoMediaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache to avoid re-fetching within the same session
  static final Map<String, VideoMediaLocalization> localizationCache = {};
  static final Map<String, VideoMediaCredibility> credibilityCache = {};
  static final Map<String, VideoMediaStreaming> streamingCache = {};

  /// Fetch localization data (subtitles, dubbing, audio tracks)
  /// Called when player starts or when user switches language
  Future<VideoMediaLocalization> getLocalization(String videoId) async {
    if (localizationCache.containsKey(videoId) &&
        !localizationCache[videoId]!.isEmpty) {
      return localizationCache[videoId]!;
    }

    try {
      final doc = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('media')
          .doc('localization')
          .getCacheFirst();

      if (doc.exists && doc.data() != null) {
        final result = VideoMediaLocalization.fromMap(doc.data()!);
        localizationCache[videoId] = result;
        return result;
      }

      // Fallback: try reading from legacy fields on main video doc
      return await _fallbackLocalization(videoId);
    } catch (e) {
      debugPrint('[VideoMediaService] Error fetching localization: $e');
      return const VideoMediaLocalization();
    }
  }

  /// Fetch credibility data (full epistemic report)
  /// Called when user opens the credibility report panel
  Future<VideoMediaCredibility> getCredibility(String videoId) async {
    if (credibilityCache.containsKey(videoId)) {
      return credibilityCache[videoId]!;
    }

    try {
      final doc = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('media')
          .doc('credibility')
          .getCacheFirst();

      if (doc.exists && doc.data() != null) {
        final result = VideoMediaCredibility.fromMap(doc.data()!);
        credibilityCache[videoId] = result;
        return result;
      }

      // Fallback: try reading from legacy fields on main video doc
      return await _fallbackCredibility(videoId);
    } catch (e) {
      debugPrint('[VideoMediaService] Error fetching credibility: $e');
      return const VideoMediaCredibility();
    }
  }

  /// Fetch streaming data (resolutions, chapters, full description)
  /// Called when player initializes
  Future<VideoMediaStreaming> getStreaming(String videoId) async {
    if (streamingCache.containsKey(videoId)) {
      return streamingCache[videoId]!;
    }

    try {
      final doc = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('media')
          .doc('streaming')
          .getCacheFirst();

      if (doc.exists && doc.data() != null) {
        final result = VideoMediaStreaming.fromMap(doc.data()!);
        streamingCache[videoId] = result;
        return result;
      }

      // No streaming subcollection yet — return empty
      return const VideoMediaStreaming();
    } catch (e) {
      debugPrint('[VideoMediaService] Error fetching streaming: $e');
      return const VideoMediaStreaming();
    }
  }

  /// Stream credibility data for real-time updates during pipeline processing
  Stream<VideoMediaCredibility> streamCredibility(String videoId) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .collection('media')
        .doc('credibility')
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            final result = VideoMediaCredibility.fromMap(doc.data()!);
            credibilityCache[videoId] = result;
            return result;
          }
          return const VideoMediaCredibility();
        });
  }

  /// Stream localization data for real-time updates as subtitles/dubbing complete
  Stream<VideoMediaLocalization> streamLocalization(String videoId) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .collection('media')
        .doc('localization')
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            final result = VideoMediaLocalization.fromMap(doc.data()!);
            localizationCache[videoId] = result;
            return result;
          }
          return const VideoMediaLocalization();
        });
  }

  /// Clear cache for a specific video (e.g., on dispose)
  void clearCache(String videoId) {
    localizationCache.remove(videoId);
    credibilityCache.remove(videoId);
    streamingCache.remove(videoId);
  }

  /// Clear entire cache
  void clearAllCaches() {
    localizationCache.clear();
    credibilityCache.clear();
    streamingCache.clear();
  }

  // ==========================================================================
  // BACKWARD COMPATIBILITY: Fallback to legacy fields on main video doc
  // ==========================================================================
  // During migration, some videos may still have data on the main doc.
  // These fallbacks ensure the app works with both old and new schemas.

  Future<VideoMediaLocalization> _fallbackLocalization(String videoId) async {
    try {
      final doc = await _firestore.collection('videos').doc(videoId).get();
      if (!doc.exists) return const VideoMediaLocalization();
      final data = doc.data()!;

      // Try legacy nested media map first, then top-level fields
      final media = data['media'] as Map<String, dynamic>? ?? {};

      final subtitles = _extractStringMap(
        media['subtitles'] ?? data['subtitles'],
      );
      final dubbedVideos = _extractStringMap(
        media['dubbedVideos'] ?? data['dubbedVideos'],
      );
      final audioTracks = _extractStringMap(
        media['audioTracks'] ?? data['audioTracks'],
      );

      final result = VideoMediaLocalization(
        subtitles: subtitles,
        dubbedVideos: dubbedVideos,
        audioTracks: audioTracks,
      );

      // Always populate cache to prevent repeating fallback reads
      localizationCache[videoId] = result;
      return result;
    } catch (e) {
      debugPrint('[VideoMediaService] Fallback localization error: $e');
      final emptyResult = const VideoMediaLocalization();
      localizationCache[videoId] = emptyResult;
      return emptyResult;
    }
  }

  Future<VideoMediaCredibility> _fallbackCredibility(String videoId) async {
    try {
      final doc = await _firestore.collection('videos').doc(videoId).get();
      if (!doc.exists) {
        final emptyResult = const VideoMediaCredibility();
        credibilityCache[videoId] = emptyResult;
        return emptyResult;
      }
      final data = doc.data()!;

      // Read legacy credibility fields from main doc
      final result = VideoMediaCredibility.fromMap(data);
      credibilityCache[videoId] = result;
      return result;
    } catch (e) {
      debugPrint('[VideoMediaService] Fallback credibility error: $e');
      final emptyResult = const VideoMediaCredibility();
      credibilityCache[videoId] = emptyResult;
      return emptyResult;
    }
  }

  Map<String, String> _extractStringMap(dynamic value) {
    if (value == null) return {};
    if (value is Map) {
      return Map<String, String>.from(
        value.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
      );
    }
    return {};
  }
}
