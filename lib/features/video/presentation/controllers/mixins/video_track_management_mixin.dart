import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/core/utils/firestore_cache_extension.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
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
  RxSet<String> get blacklistedStreamUrls;
  RxBool get isAudioOnly;
  RxBool get isSwitchingResolution;
  RxBool get isAutoSwitching;
  VideoPlayerController? get videoPlayerController;
  bool get isVpcInitialized;
  RxBool get isPlayerInitialized;
  RxList<SubtitleTrack> get availableSubtitles;
  RxList<AudioTrack> get availableAudioTracks;
  RxList<VideoTrack> get availableVideoTracks;
  Rx<VideoTrack?> get activeVideoTrack;
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

              if (directDownloadUrl != null &&
                  directDownloadUrl.isNotEmpty &&
                  !blacklistedStreamUrls.contains(directDownloadUrl)) {
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
                    if (blacklistedStreamUrls.contains(url)) return null;
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
                    !video.originalUrl.contains('.mpd') &&
                    !blacklistedStreamUrls.contains(video.originalUrl)
                ? video.originalUrl
                : (video.videoUrl.isNotEmpty &&
                        !video.videoUrl.contains('.m3u8') &&
                        !video.videoUrl.contains('.mpd') &&
                        !blacklistedStreamUrls.contains(video.videoUrl)
                    ? video.videoUrl
                    : (!blacklistedStreamUrls.contains(lowestFoundUrl)
                        ? lowestFoundUrl
                        : (video.originalUrl.isNotEmpty
                            ? video.originalUrl
                            : video.videoUrl)));

            // The completed variants from resolution_jobs define the authentic resolution ladder.
            // Never merge higher unverified or synthetic tiers that inflate native resolution.
            final completeLadder = VideoResolutionV2.ensureCompleteLadder(
              foundVariants,
              fallbackUrl: baseMediaUrl,
            ).where((r) => !blacklistedStreamUrls.contains(r.url)).toList();
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

      // FALLBACK 1: If no resolutions from resolution_jobs, check video.adaptiveResolutions (non-synthetic only)
      if (availableResolutions.isEmpty &&
          video.adaptiveResolutions.isNotEmpty) {
        final modelResolutions = video.adaptiveResolutions
            .where((r) => r.url.trim().isNotEmpty && !r.isSynthetic && !blacklistedStreamUrls.contains(r.url))
            .toList();
        if (modelResolutions.isNotEmpty) {
          final baseMediaUrl = video.originalUrl.isNotEmpty &&
                  !video.originalUrl.contains('.m3u8') &&
                  !video.originalUrl.contains('.mpd') &&
                  !blacklistedStreamUrls.contains(video.originalUrl)
              ? video.originalUrl
              : (video.videoUrl.isNotEmpty &&
                      !video.videoUrl.contains('.m3u8') &&
                      !video.videoUrl.contains('.mpd') &&
                      !blacklistedStreamUrls.contains(video.videoUrl)
                  ? video.videoUrl
                  : (modelResolutions.isNotEmpty ? modelResolutions.last.url : ''));

          final completeLadder = VideoResolutionV2.ensureCompleteLadder(
            modelResolutions,
            fallbackUrl: baseMediaUrl,
          ).where((r) => !blacklistedStreamUrls.contains(r.url)).toList();
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

      // FALLBACK 2: If still empty, fallback to HLS / Original (never fabricate fake resolutions)
      if (availableResolutions.isEmpty) {
        debugPrint('[VideoController] 💡 Using model fallback for resolutions');
        final baseMediaUrl = video.originalUrl.isNotEmpty &&
                !video.originalUrl.contains('.m3u8') &&
                !video.originalUrl.contains('.mpd') &&
                !blacklistedStreamUrls.contains(video.originalUrl)
            ? video.originalUrl
            : (video.videoUrl.isNotEmpty &&
                    !video.videoUrl.contains('.m3u8') &&
                    !video.videoUrl.contains('.mpd') &&
                    !blacklistedStreamUrls.contains(video.videoUrl)
                ? video.videoUrl
                : '');

        if (video.hlsUrl.isNotEmpty && !blacklistedStreamUrls.contains(video.hlsUrl)) {
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
          final nativeH = videoPlayerController?.value.isInitialized == true
              ? videoPlayerController!.value.size.height.toInt()
              : 0;
          final fallbackLabel = nativeH > 0 ? '${nativeH}p' : 'Original';
          availableResolutions.add(
            VideoResolutionV2(
              label: fallbackLabel,
              url: baseMediaUrl,
              width: 0,
              height: nativeH,
              bitrate: 0,
            ),
          );
        } else if (video.originalUrl.isNotEmpty &&
            !blacklistedStreamUrls.contains(video.originalUrl) &&
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
                !video.originalUrl.contains('.mpd') &&
                !blacklistedStreamUrls.contains(video.originalUrl)
            ? video.originalUrl
            : (video.videoUrl.isNotEmpty &&
                    !video.videoUrl.contains('.m3u8') &&
                    !video.videoUrl.contains('.mpd') &&
                    !blacklistedStreamUrls.contains(video.videoUrl)
                ? video.videoUrl
                : availableResolutions.last.url);

        final completeLadder = VideoResolutionV2.ensureCompleteLadder(
          availableResolutions,
          fallbackUrl: baseMediaUrl,
        ).where((r) => !blacklistedStreamUrls.contains(r.url)).toList();

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
      var subs = Map<String, String>.from(video.mediaSubtitles);
      if (subs.isEmpty) {
        final loc = await VideoMediaService().getLocalization(video.id);
        subs = Map<String, String>.from(loc.subtitles);
      }
      final primaryLang = normalizeLanguageCode(video.language.isNotEmpty ? video.language : 'en');
      if (video.transcriptionUrl.isNotEmpty &&
          !subs.containsKey(primaryLang) &&
          !subs.containsKey(video.language)) {
        subs[primaryLang] = video.transcriptionUrl;
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
            if (pathOrUrl.startsWith('gs://') ||
                pathOrUrl.startsWith('https://storage.googleapis.com/') ||
                pathOrUrl.startsWith('https://firebasestorage.googleapis.com/')) {
              try {
                url = await FirebaseStorage.instance
                    .refFromURL(pathOrUrl)
                    .getDownloadURL();
              } catch (_) {
                // If refFromURL fails on tokenless GCS URL, extract path
                final stripped = pathOrUrl.replaceFirst(RegExp('^https?://[^/]+/[^/]+/'), '').replaceFirst(RegExp('^gs://[^/]+/'), '');
                url = await FirebaseStorage.instance.ref(stripped).getDownloadURL();
              }
            } else if (pathOrUrl.startsWith('subtitles/') || pathOrUrl.startsWith('videos/')) {
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
      // 0. Synchronous zero-latency initialization from authentic in-memory model
      if (availableAudioTracks.isEmpty && (video.audioTracks.isNotEmpty || video.language.isNotEmpty)) {
        final initialAudio = <AudioTrack>[];
        final origLangName = supportedLanguages.firstWhereOrNull((l) => l.code == video.language)?.name ?? video.language.toUpperCase();
        initialAudio.add(AudioTrack(label: 'Original ($origLangName)', langCode: video.language));
        for (final entry in video.audioTracks.entries) {
          final l = supportedLanguages.firstWhereOrNull((lang) => lang.code == entry.key);
          final label = l?.name != null ? '${l!.name} (Audio)' : '${entry.key.toUpperCase()} (Audio)';
          initialAudio.add(AudioTrack(label: label, langCode: entry.key, type: 'Audio', url: entry.value));
        }
        availableAudioTracks.assignAll(initialAudio);
      }

      if (availableVideoTracks.isEmpty && (video.dubbedVideos.isNotEmpty || video.language.isNotEmpty)) {
        final initialVideos = <VideoTrack>[];
        final origLangName = supportedLanguages.firstWhereOrNull((l) => l.code == video.language)?.name ?? video.language.toUpperCase();
        initialVideos.add(VideoTrack(label: 'Original ($origLangName)', langCode: video.language));
        for (final entry in video.dubbedVideos.entries) {
          final l = supportedLanguages.firstWhereOrNull((lang) => lang.code == entry.key);
          final label = l?.name != null ? '${l!.name} (Video)' : '${entry.key.toUpperCase()} (Video)';
          initialVideos.add(VideoTrack(label: label, langCode: entry.key, type: 'Video', url: entry.value));
        }
        availableVideoTracks.assignAll(initialVideos);
      }

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
      if (loc.dubbedVideos.isNotEmpty) {
        dubbedVideosMap.addAll(loc.dubbedVideos);
      }

      // If still empty, check Firestore video document directly for dubbedVideos
      if (dubbedVideosMap.isEmpty) {
        try {
          final videoDoc = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .doc(video.id)
              .getCacheFirst();
          if (isClosed) return;
          if (videoDoc.exists && videoDoc.data() != null) {
            final data = videoDoc.data()!;
            final directDubbed = data['dubbedVideos'] as Map? ??
                (data['media'] is Map ? (data['media']['dubbedVideos'] as Map?) : null);
            if (directDubbed != null) {
              directDubbed.forEach((k, v) {
                if (k is String && v is String && v.isNotEmpty) {
                  dubbedVideosMap[k] = v;
                }
              });
            }
          }
        } catch (_) {}
      }

      final fetchAudioTasks = <Future<AudioTrack?>>[];
      final fetchVideoTasks = <Future<VideoTrack?>>[];

      final origLangName = supportedLanguages.firstWhereOrNull((l) => l.code == video.language)?.name ?? video.language.toUpperCase();

      // Add original audio track
      fetchAudioTasks.add(
        Future.value(
          AudioTrack(
            label: 'Original ($origLangName)',
            langCode: video.language,
          ),
        ),
      );

      // Add original video track
      fetchVideoTasks.add(
        Future.value(
          VideoTrack(
            label: 'Original ($origLangName)',
            langCode: video.language,
          ),
        ),
      );

      // Fetch audio tracks
      for (final entry in audioTracksMap.entries) {
        final langCode = entry.key;
        final pathOrUrl = entry.value;

        fetchAudioTasks.add(() async {
          try {
            var url = pathOrUrl;
            if (!url.contains('token=')) {
              final ref = StorageUtils.getStorageRef(url);
              if (ref != null) {
                try {
                  url = await ref.getDownloadURL();
                } catch (e) {
                  debugPrint('[AudioDiscovery] getDownloadURL failed for $url: $e');
                }
              }
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

      // Fetch dubbed video tracks generated from studio videos tab
      for (final entry in dubbedVideosMap.entries) {
        final langCode = entry.key;
        final pathOrUrl = entry.value;

        fetchVideoTasks.add(() async {
          try {
            var url = pathOrUrl;
            if (!url.contains('token=')) {
              final ref = StorageUtils.getStorageRef(url);
              if (ref != null) {
                try {
                  url = await ref.getDownloadURL();
                } catch (e) {
                  debugPrint('[VideoDiscovery] getDownloadURL failed for $url: $e');
                }
              }
            }

            final lang = supportedLanguages.firstWhereOrNull(
              (l) => l.code == langCode,
            );
            final label = lang?.name != null
                ? '${lang!.name} (Video)'
                : '${langCode.toUpperCase()} (Video)';

            return VideoTrack(
              label: label,
              langCode: langCode,
              type: 'Video',
              url: url,
            );
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'VideoTrackManagementMixin.fetchAvailableVideoTracks.dubbedUrl',
            );
            return null;
          }
        }());
      }

      if (isClosed) return;
      final audioResults = await Future.wait(fetchAudioTasks);
      if (isClosed) return;
      final foundAudio = audioResults.whereType<AudioTrack>().toList();
      availableAudioTracks.assignAll(foundAudio);

      final videoResults = await Future.wait(fetchVideoTasks);
      if (isClosed) return;
      final foundVideos = videoResults.whereType<VideoTrack>().toList();
      availableVideoTracks.assignAll(foundVideos);

      VideoTrack? preferredVideo;
      if (Get.isRegistered<UserLanguagesService>()) {
        final service = UserLanguagesService.to;
        final primary = service.primaryLanguage.value;
        preferredVideo = foundVideos.firstWhereOrNull(
          (t) => t.type != 'Original' && service.isLanguageMatch(t.label, t.langCode, primary),
        );
      }

      if (preferredVideo != null) {
        if (activeVideoTrack.value?.label != preferredVideo.label) {
          activeVideoTrack.value = preferredVideo;
          if (videoPlayerController != null &&
              videoPlayerController?.dataSource != preferredVideo.url &&
              preferredVideo.url != null &&
              preferredVideo.url!.isNotEmpty) {
            unawaited(setVideoTrack(preferredVideo));
          }
        }
      } else if (activeVideoTrack.value == null && foundVideos.isNotEmpty) {
        activeVideoTrack.value = foundVideos.first;
      }

      debugPrint(
        '[VideoController] ✅ Loaded ${foundAudio.length} audio tracks and ${foundVideos.length} video tracks',
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

  Future<void> setVideoTrack(VideoTrack track) async {
    activeVideoTrack.value = track;
    final towerCtrl = TowerPlayerController.getForTagOrActive(video.id);
    if (track.type == 'Original' || track.url == null || track.url!.isEmpty) {
      final targetUrl = currentResolution.value?.url ?? video.videoUrl;
      await initializeVideoPlayer(overrideUrl: targetUrl);
    } else {
      await initializeVideoPlayer(overrideUrl: track.url);
    }
    towerCtrl?.showToast('Video: ${track.label}');
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
    if (blacklistedStreamUrls.contains(res.url)) {
      debugPrint('[VideoController] ⚠️ Cannot switch to blacklisted resolution: ${res.label} (${res.url})');
      return;
    }
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
