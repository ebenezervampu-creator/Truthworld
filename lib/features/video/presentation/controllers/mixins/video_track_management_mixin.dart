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
import 'package:truthworld/features/video/presentation/controllers/downloads/download_resolution_manager.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
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
  bool get isVpcInitialized;
  RxList<SubtitleTrack> get availableSubtitles;
  RxList<AudioTrack> get availableAudioTracks;
  VideoTranscriptController get transcriptController;
  VideoEngagementController get engagementController;
  Duration? get initialSeekPosition;
  set initialSeekPosition(Duration? pos);

  bool _isFetchingAudioTracks = false;

  AdaptiveBitrateController? _resolveAbr() {
    if (Get.isRegistered<AdaptiveBitrateController>(tag: video.id)) {
      return Get.find<AdaptiveBitrateController>(tag: video.id);
    }
    if (Get.isRegistered<AdaptiveBitrateController>()) {
      return Get.find<AdaptiveBitrateController>();
    }
    return null;
  }

  Future<void> initializeVideoPlayer({String? overrideUrl});

  Future<void> fetchAvailableResolutions() async {
    if (isClosed) return;
    try {
      final docId = video.id;
      debugPrint('[VideoController] 🔍 Fetching resolutions for: $docId');

      final doc = await FirebaseFirestore.instance
          .collection('resolution_jobs')
          .doc(docId)
          .getCacheFirst();

      if (isClosed) return;

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
                    label: label.toString(),
                    url: directDownloadUrl,
                    width: (variantData['width'] as num?)?.toInt() ?? 0,
                    height: (variantData['height'] as num?)?.toInt() ??
                        DownloadResolutionManager.inferHeightFromLabel(label.toString()),
                    bitrate: (variantData['bitrateKbps'] as num?)?.toInt() ?? 0,
                    fps: (variantData['fps'] as num?)?.toInt() ??
                        VideoResolutionV2.inferFpsFromLabel(label.toString()),
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
                      label: label.toString(),
                      url: url,
                      width: (variantData['width'] as num?)?.toInt() ?? 0,
                      height: (variantData['height'] as num?)?.toInt() ??
                          DownloadResolutionManager.inferHeightFromLabel(label.toString()),
                      bitrate:
                          (variantData['bitrateKbps'] as num?)?.toInt() ?? 0,
                      fps: (variantData['fps'] as num?)?.toInt() ??
                          VideoResolutionV2.inferFpsFromLabel(label.toString()),
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
            if (isClosed) return;
            foundVariants.addAll(results.whereType<VideoResolutionV2>());
          }

          if (foundVariants.isNotEmpty) {
            final sortedFound = [...foundVariants]
              ..sort((a, b) => a.height.compareTo(b.height));
            final lowestFoundUrl = sortedFound.first.url;

            final baseMediaUrl = video.originalUrl.isNotEmpty &&
                    !video.originalUrl.contains('.m3u8') &&
                    !video.originalUrl.contains('.mpd')
                ? video.originalUrl
                : (video.videoUrl.isNotEmpty &&
                        !video.videoUrl.contains('.m3u8') &&
                        !video.videoUrl.contains('.mpd')
                    ? video.videoUrl
                    : lowestFoundUrl);

            // Merge with existing adaptiveResolutions from video model if present
            final combinedVariants = <VideoResolutionV2>[...foundVariants];
            for (final modelRes in video.adaptiveResolutions) {
              if (modelRes.url.trim().isNotEmpty &&
                  !combinedVariants.any((r) =>
                      r.label.toLowerCase() == modelRes.label.toLowerCase() ||
                      (r.height == modelRes.height && r.fps == modelRes.fps))) {
                combinedVariants.add(modelRes);
              }
            }

            final completeLadder = VideoResolutionV2.ensureCompleteLadder(
              combinedVariants,
              fallbackUrl: baseMediaUrl,
            );
            availableResolutions.assignAll(completeLadder);

            // Update ABR ladder with complete variants
            final abr = _resolveAbr();
            if (abr != null) {
              final ladder = completeLadder.reversed
                  .map(ResolutionTier.fromVideoResolution)
                  .toList();
              if (ladder.isNotEmpty) {
                abr.updateLadder(
                  ladder,
                  activeHeight: currentResolution.value?.height,
                  activeFps: currentResolution.value?.fps,
                );
              }
            }

            debugPrint(
              '[VideoController] ✅ Successfully loaded ${availableResolutions.length} resolutions (complete ladder guaranteed)',
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
          final baseMediaUrl = video.originalUrl.isNotEmpty &&
                  !video.originalUrl.contains('.m3u8') &&
                  !video.originalUrl.contains('.mpd')
              ? video.originalUrl
              : (video.videoUrl.isNotEmpty &&
                      !video.videoUrl.contains('.m3u8') &&
                      !video.videoUrl.contains('.mpd')
                  ? video.videoUrl
                  : (modelResolutions.isNotEmpty ? modelResolutions.last.url : ''));

          final completeLadder = VideoResolutionV2.ensureCompleteLadder(
            modelResolutions,
            fallbackUrl: baseMediaUrl,
          );
          availableResolutions.assignAll(completeLadder);

          final abr = _resolveAbr();
          if (abr != null) {
            final ladder = completeLadder.reversed
                .map(ResolutionTier.fromVideoResolution)
                .toList();
            if (ladder.isNotEmpty) {
              abr.updateLadder(
                ladder,
                activeHeight: currentResolution.value?.height,
                activeFps: currentResolution.value?.fps,
              );
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

      // FINAL GUARANTEE: A video must NEVER have an incomplete resolution ladder.
      // If higher resolutions (e.g. 1080p, 720p) exist but lower tiers (480p, 360p, 240p, 144p) are missing,
      // backfill them immediately so the viewer always has access to all standard resolution options.
      if (availableResolutions.isNotEmpty) {
        final baseMediaUrl = video.originalUrl.isNotEmpty &&
                !video.originalUrl.contains('.m3u8') &&
                !video.originalUrl.contains('.mpd')
            ? video.originalUrl
            : (video.videoUrl.isNotEmpty &&
                    !video.videoUrl.contains('.m3u8') &&
                    !video.videoUrl.contains('.mpd')
                ? video.videoUrl
                : availableResolutions.last.url);

        final completeLadder = VideoResolutionV2.ensureCompleteLadder(
          availableResolutions,
          fallbackUrl: baseMediaUrl,
        );

        if (completeLadder.length != availableResolutions.length) {
          availableResolutions.assignAll(completeLadder);
          final abr = _resolveAbr();
          if (abr != null) {
            final ladder = completeLadder.reversed
                .map(ResolutionTier.fromVideoResolution)
                .toList();
            if (ladder.isNotEmpty) {
              abr.updateLadder(
                ladder,
                activeHeight: currentResolution.value?.height,
                activeFps: currentResolution.value?.fps,
              );
            }
          }
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
      if (isClosed) return;
      final found = results.whereType<SubtitleTrack>().toList();
      availableSubtitles.assignAll(found);

      debugPrint('[VideoController] ✅ Loaded ${found.length} subtitle tracks');

      // If audio tracks only has original, retry audio track discovery now that subtitles are resolved
      if (availableAudioTracks.length <= 1 && found.isNotEmpty && !_isFetchingAudioTracks && !isClosed) {
        unawaited(fetchAvailableAudioTracks());
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoTrackManagementMixin.fetchAvailableSubtitles',
      );
    }
  }

  /// Proactively finds, downloads, and parses the transcript/subtitles for this video
  Future<void> loadTranscriptForVideo({bool forceRefresh = false}) =>
      transcriptController.loadTranscriptForVideo(
        video,
        defaultSubtitleUrl: availableSubtitles.firstOrNull?.url,
        forceRefresh: forceRefresh,
      );

  /// Fetches the AI Summary from moderation.summary in the video document or credibility cache
  Future<void> fetchSummary() => transcriptController.fetchSummary(video);

  Future<void> fetchAvailableAudioTracks() async {
    if (isClosed || _isFetchingAudioTracks) return;
    _isFetchingAudioTracks = true;
    try {
      final audioTracksMap = Map<String, String>.from(video.audioTracks);
      final loc = await VideoMediaService().getLocalization(video.id);
      if (isClosed) return;
      if (audioTracksMap.isEmpty) {
        audioTracksMap.addAll(loc.audioTracks);
      }

      // If still empty, check Firestore video document directly
      if (audioTracksMap.isEmpty) {
        try {
          final videoDoc = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .doc(video.id)
              .getCacheFirst();
          if (isClosed) return;
          if (videoDoc.exists && videoDoc.data() != null) {
            final data = videoDoc.data()!;
            final directAudio = data['audioTracks'] as Map? ??
                (data['media'] is Map ? (data['media']['audioTracks'] as Map?) : null);
            if (directAudio != null) {
              directAudio.forEach((k, v) {
                if (k is String && v is String && v.isNotEmpty) {
                  audioTracksMap[k] = v;
                }
              });
            }
          }
        } catch (_) {}
      }

      if (isClosed) return;

      // If still empty, discover from subtitle job ID or Storage audio/ folder
      if (audioTracksMap.isEmpty) {
        var detectedJobId = video.jobId;
        if (detectedJobId == null || detectedJobId.isEmpty) {
          final allUrls = <String>[
            ...video.mediaSubtitles.values,
            ...loc.subtitles.values,
            ...availableSubtitles.map((s) => s.url),
            video.factCheckUrl,
            video.transcriptionUrl,
            video.videoUrl,
            video.originalUrl,
          ];
          for (final rawUrl in allUrls) {
            if (rawUrl.isEmpty) continue;
            final u = Uri.decodeFull(rawUrl);
            final match = RegExp(r'job_[a-zA-Z0-9_\-]+').firstMatch(u);
            if (match != null) {
              detectedJobId = match.group(0);
              debugPrint('[AudioDiscovery] 🔍 Detected jobId from URL: $detectedJobId');
              break;
            }
          }
        }

        if (detectedJobId != null && detectedJobId.isNotEmpty) {
          final candidateLangs = <String>{
            ...video.mediaSubtitles.keys,
            ...loc.subtitles.keys,
            ...availableSubtitles.map((s) => s.langCode),
            ...video.languages,
          }.where((l) => l.isNotEmpty && l != video.language).toSet();

          if (candidateLangs.isNotEmpty) {
            await Future.wait(
              candidateLangs.map((langCode) async {
                if (isClosed) return;
                if (audioTracksMap.containsKey(langCode)) return;
                try {
                  debugPrint('[AudioDiscovery] Scanning Storage for audio/$detectedJobId/$langCode');
                  final storageRef = FirebaseStorage.instance.ref('audio/$detectedJobId/$langCode');
                  final listResult = await storageRef.list(const ListOptions(maxResults: 10));
                  if (isClosed) return;
                  debugPrint('[AudioDiscovery] Items found in audio/$detectedJobId/$langCode: ${listResult.items.length}');
                  if (listResult.items.isNotEmpty) {
                    final bestItem = listResult.items.firstWhereOrNull(
                      (item) => item.name == 'stitched.mp3' || item.name == 'full.mp3',
                    ) ?? listResult.items.firstWhereOrNull(
                      (item) => item.name.endsWith('.mp3') || item.name.endsWith('.wav') || item.name.endsWith('.m4a'),
                    ) ?? listResult.items.first;
                    final downloadUrl = await bestItem.getDownloadURL();
                    if (isClosed) return;
                    debugPrint('[AudioDiscovery] ✅ Resolved track for $langCode: $downloadUrl');
                    audioTracksMap[langCode] = downloadUrl;
                  }
                } catch (storageErr) {
                  debugPrint('[AudioDiscovery] ⚠️ Storage check for $langCode failed: $storageErr');
                }
              }),
            );
          }

          if (isClosed) return;

          if (audioTracksMap.isNotEmpty) {
            // Persist discovered audio tracks back to Firestore so subsequent loads are immediate
            FirebaseFirestore.instance.collection(FirestoreCollections.videos).doc(video.id).set({
              'audioTracks': audioTracksMap,
              'media': {'audioTracks': audioTracksMap},
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).catchError((e) {
              debugPrint('[AudioDiscovery] ⚠️ Failed to persist audioTracks to video doc: $e');
            });

            FirebaseFirestore.instance.collection(FirestoreCollections.videos).doc(video.id).collection('media').doc('localization').set({
              'audioTracks': audioTracksMap,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).catchError((e) {
              debugPrint('[AudioDiscovery] ⚠️ Failed to persist audioTracks to localization doc: $e');
            });
          }
        }
      }

      if (isClosed) return;

      final dubbedVideosMap = Map<String, String>.from(video.dubbedVideos);
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
              try {
                url = await FirebaseStorage.instance
                    .refFromURL(pathOrUrl)
                    .getDownloadURL();
              } catch (_) {
                final stripped = pathOrUrl.replaceFirst(RegExp('^gs://[^/]+/'), '');
                url = await FirebaseStorage.instance.ref(stripped).getDownloadURL();
              }
            } else if (pathOrUrl.startsWith('audio/') || pathOrUrl.startsWith('audiotracks/') || pathOrUrl.startsWith('videos/')) {
              url = await FirebaseStorage.instance
                  .ref(pathOrUrl)
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
            // If direct download failed, it may be a directory holding audio chunks
            try {
              final ref = pathOrUrl.startsWith('gs://')
                  ? FirebaseStorage.instance.refFromURL(pathOrUrl)
                  : FirebaseStorage.instance.ref(pathOrUrl);
              final listRes = await ref.list(const ListOptions(maxResults: 5));
              if (listRes.items.isNotEmpty) {
                final item = listRes.items.firstWhereOrNull(
                  (i) => i.name.endsWith('.mp3') || i.name.endsWith('.wav') || i.name.endsWith('.m4a'),
                ) ?? listRes.items.first;
                final resolvedUrl = await item.getDownloadURL();
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
                  url: resolvedUrl,
                );
              }
            } catch (_) {}

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

        // Skip if this language is already handled as audio
        if (audioTracksMap.containsKey(langCode)) continue;

        fetchTasks.add(() async {
          try {
            var url = pathOrUrl;
            if (pathOrUrl.startsWith('gs://')) {
              try {
                url = await FirebaseStorage.instance
                    .refFromURL(pathOrUrl)
                    .getDownloadURL();
              } catch (_) {
                final stripped = pathOrUrl.replaceFirst(RegExp('^gs://[^/]+/'), '');
                url = await FirebaseStorage.instance.ref(stripped).getDownloadURL();
              }
            } else if (pathOrUrl.startsWith('videos/') || pathOrUrl.startsWith('audio/')) {
              url = await FirebaseStorage.instance.ref(pathOrUrl).getDownloadURL();
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

      if (isClosed) return;
      final results = await Future.wait(fetchTasks);
      if (isClosed) return;
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
    } finally {
      _isFetchingAudioTracks = false;
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
    if (isClosed) return;
    if (isSwitchingResolution.value) return;
    if (currentResolution.value?.url == res.url &&
        currentResolution.value?.label == res.label &&
        currentResolution.value?.height == res.height) {
      return;
    }

    if (videoPlayerController != null &&
        isVpcInitialized &&
        videoPlayerController!.dataSource == res.url) {
      currentResolution.value = res;
      final towerCtrl = TowerPlayerController.getForTagOrActive(video.id);
      final qualityText = isManual
          ? 'Quality: ${res.label}'
          : 'Quality: ${res.label} (Auto)';
      towerCtrl?.showToast(qualityText);
      return;
    }

    isSwitchingResolution.value = true;
    isAutoSwitching.value = !isManual;
    currentResolution.value = res;

    final towerCtrl = TowerPlayerController.getForTagOrActive(video.id);

    if (isManual) {
      // Manual resolution selection (e.g. 720p, 480p, 1080p):
      // The user explicitly requested this resolution. This CAN cause buffering.
      // Immediately set buffering so the player displays the buffering spinner while loading the requested quality.
      towerCtrl?.isBuffering.value = true;
      towerCtrl?.abr.playbackState.value = PlaybackState.buffering;
      try {
        videoPlayerController?.pause();
      } catch (_) {}
    }

    try {
      await initializeVideoPlayer(overrideUrl: res.url);

      // Display HUD toast notification
      final qualityText = isManual
          ? 'Quality: ${res.label}'
          : 'Quality: ${res.label} (Auto)';
      towerCtrl?.showToast(qualityText);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoTrackManagementMixin.setResolution',
      );
    } finally {
      isSwitchingResolution.value = false;
      isAutoSwitching.value = false;
      if (isManual) {
        towerCtrl?.isBuffering.value =
            videoPlayerController?.value.isBuffering ?? false;
        if (videoPlayerController?.value.isPlaying == true) {
          towerCtrl?.abr.playbackState.value = PlaybackState.playing;
        }
      }
    }
  }

  Future<void> setResolutionByIndex(int index) async {
    if (index < 0 || index >= availableResolutions.length) return;

    final abr = _resolveAbr();
    if (abr != null && index >= 0 && index < abr.resolutionLadder.length) {
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
