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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
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
  Future<VideoMediaLocalization> getLocalization(
    String videoId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && localizationCache.containsKey(videoId)) {
      return localizationCache[videoId]!;
    }

    try {
      final locDocRef = _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .collection('media')
          .doc('localization');

      final doc = forceRefresh ? await locDocRef.get() : await locDocRef.getCacheFirst();

      if (doc.exists && doc.data() != null) {
        final result = VideoMediaLocalization.fromMap(doc.data()!);
        localizationCache[videoId] = result;
        return result;
      }

      // Fallback: try reading from top-level fields on main video doc
      return await _fallbackLocalization(videoId);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoMediaService.getLocalization',
      );
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
          .collection(FirestoreCollections.videos)
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
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoMediaService.getCredibility',
      );
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
          .collection(FirestoreCollections.videos)
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
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoMediaService.getStreaming',
      );
      return const VideoMediaStreaming();
    }
  }

  /// Stream credibility data for real-time updates during pipeline processing
  Stream<VideoMediaCredibility> streamCredibility(String videoId) {
    return _firestore
        .collection(FirestoreCollections.videos)
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
        .collection(FirestoreCollections.videos)
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
      final doc = await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .get();
      if (!doc.exists) return const VideoMediaLocalization();
      final data = doc.data()!;

      // Try legacy nested media map first, then top-level fields
      final media = data['media'] as Map<String, dynamic>? ?? {};

      final subtitles = _extractStringMap(
        media['subtitles'] ?? data['subtitles'],
      );
      if (subtitles.isEmpty) {
        final directTranscript = (media['transcriptionUrl'] as String?)?.isNotEmpty == true
            ? (media['transcriptionUrl'] as String)
            : ((data['transcriptionUrl'] as String?)?.isNotEmpty == true
                ? (data['transcriptionUrl'] as String)
                : ((data['transcriptUrl'] as String?)?.isNotEmpty == true
                    ? (data['transcriptUrl'] as String)
                    : null));
        if (directTranscript != null && directTranscript.isNotEmpty) {
          subtitles['en'] = directTranscript;
        }
      }
      final dubbedVideos = _extractStringMap(
        media['dubbedVideos'] ?? data['dubbedVideos'] ?? media['dubbed'] ?? data['dubbed'],
      );
      final audioTracks = _extractStringMap(
        media['audioTracks'] ?? data['audioTracks'] ?? media['audio'] ?? data['audio'],
      );

      // Support flat dotted keys (e.g. 'audioTracks.es', 'dubbedVideos.es')
      data.forEach((key, val) {
        if (val is String && val.isNotEmpty) {
          if (key.startsWith('audioTracks.')) {
            final code = key.substring('audioTracks.'.length);
            if (code.isNotEmpty) audioTracks[code] = val;
          } else if (key.startsWith('media.audioTracks.')) {
            final code = key.substring('media.audioTracks.'.length);
            if (code.isNotEmpty) audioTracks[code] = val;
          } else if (key.startsWith('dubbedVideos.')) {
            final code = key.substring('dubbedVideos.'.length);
            if (code.isNotEmpty) dubbedVideos[code] = val;
          } else if (key.startsWith('media.dubbedVideos.')) {
            final code = key.substring('media.dubbedVideos.'.length);
            if (code.isNotEmpty) dubbedVideos[code] = val;
          } else if (key.startsWith('subtitles.')) {
            final code = key.substring('subtitles.'.length);
            if (code.isNotEmpty) subtitles[code] = val;
          } else if (key.startsWith('media.subtitles.')) {
            final code = key.substring('media.subtitles.'.length);
            if (code.isNotEmpty) subtitles[code] = val;
          }
        }
      });

      // Also check video_jobs outputs if audioTracks or dubbedVideos is still empty (creator/owner only)
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final videoOwnerId = (data['userId'] as String?) ??
          (data['ownerId'] as String?) ??
          (data['channelId'] as String?);
      final canAccessVideoJobs = currentUserId != null &&
          currentUserId.isNotEmpty &&
          currentUserId == videoOwnerId;

      if ((audioTracks.isEmpty || dubbedVideos.isEmpty) && canAccessVideoJobs) {
        try {
          final jobDoc = await _firestore.collection('video_jobs').doc(videoId).get();
          if (jobDoc.exists && jobDoc.data() != null) {
            final jobData = jobDoc.data()!;
            final jobOutputs = jobData['outputs'] as Map<String, dynamic>?;
            final jobAudios = _extractStringMap(jobOutputs?['audioTracks']);
            final jobVideos = _extractStringMap(jobOutputs?['dubbedVideos']);
            final stages = jobData['stages'] as Map<String, dynamic>?;
            stages?.forEach((sKey, sVal) {
              if (sKey.startsWith('dubbing_') && sVal is Map) {
                final lang = sKey.replaceFirst('dubbing_', '');
                if (sVal['audioUrl'] is String && (sVal['audioUrl'] as String).isNotEmpty) {
                  jobAudios[lang] = sVal['audioUrl'] as String;
                }
                if (sVal['videoUrl'] is String && (sVal['videoUrl'] as String).isNotEmpty) {
                  jobVideos[lang] = sVal['videoUrl'] as String;
                }
              }
            });
            if (audioTracks.isEmpty && jobAudios.isNotEmpty) {
              audioTracks.addAll(jobAudios);
            }
            if (dubbedVideos.isEmpty && jobVideos.isNotEmpty) {
              dubbedVideos.addAll(jobVideos);
            }
          }
        } catch (_) {}
      }

      final result = VideoMediaLocalization(
        subtitles: subtitles,
        dubbedVideos: dubbedVideos,
        audioTracks: audioTracks,
      );

      // Always populate cache to prevent repeating fallback reads
      localizationCache[videoId] = result;
      return result;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoMediaService._fallbackLocalization',
      );
      const emptyResult = VideoMediaLocalization();
      localizationCache[videoId] = emptyResult;
      return emptyResult;
    }
  }

  Future<VideoMediaCredibility> _fallbackCredibility(String videoId) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.videos)
          .doc(videoId)
          .get();
      if (!doc.exists) {
        const emptyResult = VideoMediaCredibility();
        credibilityCache[videoId] = emptyResult;
        return emptyResult;
      }
      final data = doc.data()!;

      // Read legacy credibility fields from main doc
      final result = VideoMediaCredibility.fromMap(data);
      credibilityCache[videoId] = result;
      return result;
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoMediaService._fallbackCredibility',
      );
      const emptyResult = VideoMediaCredibility();
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
