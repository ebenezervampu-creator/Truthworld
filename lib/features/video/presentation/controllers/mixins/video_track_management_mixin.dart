import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_engagement_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_transcript_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player/video_player.dart';

/// Mixin handling resolution discovery, adaptive switching, subtitle tracks, audio tracks, and translation requests.
mixin VideoTrackManagementMixin on GetxController {
  Video get video;
  RxList<VideoResolutionV2> get availableResolutions;
  Rx<VideoResolutionV2?> get currentResolution;
  RxBool get isAudioOnly;
  RxBool get isSwitchingResolution;
  RxBool get isAutoSwitching;
  VideoPlayerController? get videoPlayerController;
  RxList<SubtitleTrack> get availableSubtitles;
  RxList<AudioTrack> get availableAudioTracks;
  VideoTranscriptController get transcriptController;
  VideoEngagementController get engagementController;

  Future<void> initializeVideoPlayer({String? overrideUrl});

  Future<void> fetchAvailableResolutions() async {
    try {
      final docId = video.id;
      debugPrint('[VideoController] 🔍 Fetching resolutions for: $docId');

      final doc = await FirebaseFirestore.instance
          .collection('resolution_jobs')
          .doc(docId)
          .getCacheFirst();

      if (doc.exists) {
        final data = doc.data();
        debugPrint('[VideoController] 📄 Doc data found: ${data != null}');

        if (data != null && data['variants'] != null) {
          final variants = data['variants'] as Map<String, dynamic>;
          debugPrint('[VideoController] 📊 Variants count: ${variants.length}');

          final fetchTasks = <Future<VideoResolutionV2?>>[];
          final foundVariants = <VideoResolutionV2>[];

          for (final entry in variants.entries) {
            final variantData = entry.value as Map<String, dynamic>;
            final status = variantData['status'];
            final label = variantData['label'] ?? entry.key;

            debugPrint('[VideoController] 🛠️ Variant $label status: $status');

            if (status == 'completed') {
              final directDownloadUrl = variantData['downloadUrl'] as String?;
              final outputPath = variantData['outputPath'] as String?;

              if (directDownloadUrl != null && directDownloadUrl.isNotEmpty) {
                foundVariants.add(
                  VideoResolutionV2(
                    label: label as String,
                    url: directDownloadUrl,
                    width: (variantData['width'] as num?)?.toInt() ?? 0,
                    height: (variantData['height'] as num?)?.toInt() ?? 0,
                    bitrate: (variantData['bitrateKbps'] as num?)?.toInt() ?? 0,
                  ),
                );
              } else if (outputPath != null && outputPath.isNotEmpty) {
                fetchTasks.add(() async {
                  try {
                    String url;
                    if (outputPath.startsWith('gs://')) {
                      url = await FirebaseStorage.instance
                          .refFromURL(outputPath)
                          .getDownloadURL();
                    } else {
                      url = await FirebaseStorage.instance
                          .ref(outputPath)
                          .getDownloadURL();
                    }
                    return VideoResolutionV2(
                      label: label as String,
                      url: url,
                      width: (variantData['width'] as num?)?.toInt() ?? 0,
                      height: (variantData['height'] as num?)?.toInt() ?? 0,
                      bitrate:
                          (variantData['bitrateKbps'] as num?)?.toInt() ?? 0,
                    );
                  } catch (e, s) {
                    ErrorHandler.log(
                      e,
                      stackTrace: s,
                      tag: 'VideoTrackManagementMixin.fetchAvailableResolutions.url',
                    );
                    return null;
                  }
                }());
              }
            }
          }

          if (fetchTasks.isNotEmpty) {
            final results = await Future.wait(fetchTasks);
            foundVariants.addAll(results.whereType<VideoResolutionV2>());
          }

          if (foundVariants.isNotEmpty) {
            // Sort by height descending
            foundVariants.sort((a, b) => b.height.compareTo(a.height));
            availableResolutions.assignAll(foundVariants);

            // Update ABR ladder with real variants
            if (Get.isRegistered<AdaptiveBitrateController>()) {
              final abr = Get.find<AdaptiveBitrateController>();
              final ladder = foundVariants.reversed
                  .map(ResolutionTier.fromVideoResolution)
                  .toList();

              if (ladder.isNotEmpty) {
                abr.resolutionLadder = ladder;
                abr.currentTierIndex.value = (ladder.length / 2).floor();
              }
            }

            debugPrint(
              '[VideoController] ✅ Successfully loaded ${availableResolutions.length} resolutions',
            );
          }
        } else {
          debugPrint('[VideoController] ⚠️ No variants field in document');
        }
      } else {
        debugPrint('[VideoController] ℹ️ No resolution job found for $docId');
      }

      // FALLBACK 1: If no resolutions from resolution_jobs, check video.adaptiveResolutions
      if (availableResolutions.isEmpty &&
          video.adaptiveResolutions.isNotEmpty) {
        final modelResolutions = video.adaptiveResolutions
            .where((r) => r.url.trim().isNotEmpty)
            .toList();
        if (modelResolutions.isNotEmpty) {
          modelResolutions.sort((a, b) => b.height.compareTo(a.height));
          availableResolutions.assignAll(modelResolutions);

          if (Get.isRegistered<AdaptiveBitrateController>()) {
            final abr = Get.find<AdaptiveBitrateController>();
            final ladder = modelResolutions.reversed
                .map(ResolutionTier.fromVideoResolution)
                .toList();
            if (ladder.isNotEmpty) {
              abr.resolutionLadder = ladder;
              abr.currentTierIndex.value = (ladder.length / 2).floor();
            }
          }
          debugPrint(
            '[VideoController] 💡 Loaded ${availableResolutions.length} resolutions from video.adaptiveResolutions',
          );
        }
      }

      // FALLBACK 2: If still empty, fallback to HLS / Original & standard ladder
      if (availableResolutions.isEmpty) {
        debugPrint('[VideoController] 💡 Using model fallback for resolutions');
        final baseMediaUrl = video.originalUrl.isNotEmpty &&
                !video.originalUrl.contains('.m3u8') &&
                !video.originalUrl.contains('.mpd')
            ? video.originalUrl
            : (video.videoUrl.isNotEmpty &&
                    !video.videoUrl.contains('.m3u8') &&
                    !video.videoUrl.contains('.mpd')
                ? video.videoUrl
                : '');

        if (video.hlsUrl.isNotEmpty) {
          availableResolutions.add(
            VideoResolutionV2(
              label: 'Auto',
              url: video.hlsUrl,
              width: 0,
              height: 0,
              bitrate: 0,
            ),
          );
        }

        if (baseMediaUrl.isNotEmpty) {
          availableResolutions.addAll([
            VideoResolutionV2(
              label: '1080p',
              url: baseMediaUrl,
              width: 1920,
              height: 1080,
              bitrate: 4500000,
            ),
            VideoResolutionV2(
              label: '720p',
              url: baseMediaUrl,
              width: 1280,
              height: 720,
              bitrate: 2500000,
            ),
            VideoResolutionV2(
              label: '480p',
              url: baseMediaUrl,
              width: 854,
              height: 480,
              bitrate: 1200000,
            ),
            VideoResolutionV2(
              label: '360p',
              url: baseMediaUrl,
              width: 640,
              height: 360,
              bitrate: 800000,
            ),
            VideoResolutionV2(
              label: '240p',
              url: baseMediaUrl,
              width: 426,
              height: 240,
              bitrate: 400000,
            ),
            VideoResolutionV2(
              label: '144p',
              url: baseMediaUrl,
              width: 256,
              height: 144,
              bitrate: 200000,
            ),
          ]);
        } else if (video.originalUrl.isNotEmpty &&
            !availableResolutions.any((r) => r.label == 'Original')) {
          availableResolutions.add(
            VideoResolutionV2(
              label: 'Original',
              url: video.originalUrl,
              width: 0,
              height: 0,
              bitrate: 0,
            ),
          );
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoTrackManagementMixin.fetchAvailableResolutions',
      );
    }
  }

  Future<void> fetchAvailableSubtitles() async {
    try {
      var subs = video.mediaSubtitles;
      if (subs.isEmpty) {
        final loc = await VideoMediaService().getLocalization(video.id);
        subs = loc.subtitles;
      }
      if (subs.isEmpty) {
        debugPrint('[VideoController] ℹ️ No subtitles found in video metadata');
        return;
      }

      final fetchTasks = <Future<SubtitleTrack?>>[];

      for (final entry in subs.entries) {
        final langCode = entry.key;
        final pathOrUrl = entry.value;

        fetchTasks.add(() async {
          try {
            var url = pathOrUrl;
            if (pathOrUrl.startsWith('gs://')) {
              url = await FirebaseStorage.instance
                  .refFromURL(pathOrUrl)
                  .getDownloadURL();
            } else if (pathOrUrl.startsWith('subtitles/')) {
              url = await FirebaseStorage.instance
                  .ref(pathOrUrl)
                  .getDownloadURL();
            }

            final lang = supportedLanguages.firstWhereOrNull(
              (l) => l.code == langCode,
            );
            final label =
                lang?.name ??
                (langCode.length <= 3 ? langCode.toUpperCase() : langCode);

            return SubtitleTrack(label: label, langCode: langCode, url: url);
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'VideoTrackManagementMixin.fetchAvailableSubtitles.url',
            );
            return null;
          }
        }());
      }

      final results = await Future.wait(fetchTasks);
      final found = results.whereType<SubtitleTrack>().toList();
      availableSubtitles.assignAll(found);

      debugPrint('[VideoController] ✅ Loaded ${found.length} subtitle tracks');
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoTrackManagementMixin.fetchAvailableSubtitles',
      );
    }
  }

  /// Proactively finds, downloads, and parses the transcript/subtitles for this video
  Future<void> loadTranscriptForVideo() =>
      transcriptController.loadTranscriptForVideo(
        video,
        defaultSubtitleUrl: availableSubtitles.firstOrNull?.url,
      );

  /// Fetches the AI Summary from moderation.summary in the video document or credibility cache
  Future<void> fetchSummary() => transcriptController.fetchSummary(video);

  Future<void> fetchAvailableAudioTracks() async {
    try {
      var audioTracksMap = video.audioTracks;
      if (audioTracksMap.isEmpty) {
        final loc = await VideoMediaService().getLocalization(video.id);
        audioTracksMap = loc.audioTracks;
      }
      final dubbedVideosMap = video.dubbedVideos;
      final fetchTasks = <Future<AudioTrack?>>[];

      // Add original track
      fetchTasks.add(
        Future.value(
          AudioTrack(
            label:
                'Original (${supportedLanguages.firstWhereOrNull((l) => l.code == video.language)?.name ?? video.language.toUpperCase()})',
            langCode: video.language,
          ),
        ),
      );

      // Fetch audio tracks
      for (final entry in audioTracksMap.entries) {
        final langCode = entry.key;
        final pathOrUrl = entry.value;

        fetchTasks.add(() async {
          try {
            var url = pathOrUrl;
            if (pathOrUrl.startsWith('gs://')) {
              url = await FirebaseStorage.instance
                  .refFromURL(pathOrUrl)
                  .getDownloadURL();
            }

            final lang = supportedLanguages.firstWhereOrNull(
              (l) => l.code == langCode,
            );
            final label = lang?.name != null
                ? '${lang!.name} (Audio)'
                : '${langCode.toUpperCase()} (Audio)';

            return AudioTrack(
              label: label,
              langCode: langCode,
              type: 'Audio',
              url: url,
            );
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'VideoTrackManagementMixin.fetchAvailableAudioTracks.url',
            );
            return null;
          }
        }());
      }

      // Fetch dubbed video tracks
      for (final entry in dubbedVideosMap.entries) {
        final langCode = entry.key;
        final pathOrUrl = entry.value;

        fetchTasks.add(() async {
          try {
            var url = pathOrUrl;
            if (pathOrUrl.startsWith('gs://')) {
              url = await FirebaseStorage.instance
                  .refFromURL(pathOrUrl)
                  .getDownloadURL();
            }

            final lang = supportedLanguages.firstWhereOrNull(
              (l) => l.code == langCode,
            );
            final label = lang?.name != null
                ? '${lang!.name} (Video)'
                : '${langCode.toUpperCase()} (Video)';

            return AudioTrack(
              label: label,
              langCode: langCode,
              type: 'Video',
              url: url,
            );
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'VideoTrackManagementMixin.fetchAvailableAudioTracks.dubbedUrl',
            );
            return null;
          }
        }());
      }

      final results = await Future.wait(fetchTasks);
      final found = results.whereType<AudioTrack>().toList();
      availableAudioTracks.assignAll(found);

      debugPrint(
        '[VideoController] ✅ Loaded ${found.length} audio tracks (including original)',
      );
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoTrackManagementMixin.fetchAvailableAudioTracks',
      );
    }
  }

  void listenToLanguageRequests() {
    engagementController.fetchLanguageRequests(video.id);
  }

  Future<void> submitLanguageRequest({
    required String language,
    required String type,
  }) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) {
      AppSnackbar.warning('Please sign in to request a language.');
      return;
    }

    try {
      final docId = '${video.id}_${type}_${language.replaceAll(' ', '_')}';
      final ref = FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .collection('language_requests')
          .doc(docId);

      final docSnap = await ref.get();
      var requesters = <dynamic>[];
      if (docSnap.exists) {
        requesters = docSnap.data()?['requesters'] as List<dynamic>? ?? [];
      }

      if (requesters.contains(userId)) {
        AppSnackbar.info('You have already requested this language.');
        return;
      }

      requesters.add(userId);

      await ref.set({
        'language': language,
        'type': type,
        'count': requesters.length,
        'requesters': requesters,
        'createdAt': (docSnap.exists && docSnap.data() != null)
            ? docSnap.data()!['createdAt']
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      listenToLanguageRequests();
      AppSnackbar.success('Language request submitted!');
    } catch (e) {
      ErrorHandler.log(e, context: 'VideoController.submitLanguageRequest');
      AppSnackbar.error('Unable to submit language request. Please try again.');
    }
  }

  Future<bool> requestLanguage(String language, String type) async {
    try {
      await submitLanguageRequest(language: language, type: type);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setResolution(
    VideoResolutionV2 res, {
    bool isManual = true,
  }) async {
    if (currentResolution.value?.url == res.url &&
        currentResolution.value?.label == res.label) {
      return;
    }

    if (videoPlayerController != null &&
        videoPlayerController!.value.isInitialized &&
        videoPlayerController!.dataSource == res.url) {
      currentResolution.value = res;
      return;
    }

    final currentPosition =
        videoPlayerController?.value.position ?? Duration.zero;
    final wasPlaying = videoPlayerController?.value.isPlaying ?? false;

    isSwitchingResolution.value = true;
    isAutoSwitching.value = !isManual;
    currentResolution.value = res;

    try {
      await initializeVideoPlayer(overrideUrl: res.url);

      if (videoPlayerController != null) {
        await videoPlayerController!.seekTo(currentPosition);
        if (wasPlaying) {
          await videoPlayerController!.play();
        }
      }
    } finally {
      isSwitchingResolution.value = false;
      isAutoSwitching.value = false;
    }
  }

  Future<void> setResolutionByIndex(int index) async {
    if (index < 0 || index >= availableResolutions.length) return;

    if (Get.isRegistered<AdaptiveBitrateController>()) {
      final abr = Get.find<AdaptiveBitrateController>();
      final tier = abr.resolutionLadder[index];

      final res = availableResolutions.firstWhereOrNull(
        (r) => r.height == tier.height,
      );
      if (res != null) {
        setResolution(res);
      }
    }
  }
}
