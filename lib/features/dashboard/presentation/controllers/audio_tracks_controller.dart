import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/download_helper.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/audio_tracks_barrel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/multi_audio_player_controller.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

export 'audio_tracks/audio_tracks_barrel.dart';

/// Industry-Standard Multi-Language Audio Tracks & Dubs Management Coordinator
class AudioTracksController extends BaseController with ContentValidationMixin {
  static const String _tag = 'AudioTracksController';

  final AudioTracksContextManager _contextManager = AudioTracksContextManager();
  final AudioTracksLanguageManager _languageManager =
      AudioTracksLanguageManager();
  final AudioTracksEditorManager _editorManager = AudioTracksEditorManager();
  final AudioTracksUploadManager _uploadManager = AudioTracksUploadManager();
  final AudioTracksCommentaryManager _commentaryManager =
      AudioTracksCommentaryManager();
  late final AudioTracksPlaybackController playbackController =
      Get.isRegistered<AudioTracksPlaybackController>()
          ? Get.find<AudioTracksPlaybackController>()
          : Get.put(AudioTracksPlaybackController());

  // Sub-manager accessors for advanced modular usage
  AudioTracksContextManager get contextManager => _contextManager;
  AudioTracksLanguageManager get languageManager => _languageManager;
  AudioTracksEditorManager get editorManager => _editorManager;
  AudioTracksUploadManager get uploadManager => _uploadManager;
  AudioTracksCommentaryManager get commentaryManager => _commentaryManager;

  // Upload state delegation
  RxBool get isUploading => _uploadManager.isUploading;
  RxDouble get uploadProgress => _uploadManager.uploadProgress;
  RxString get uploadStatus => _uploadManager.uploadStatus;
  RxString get uploadingLanguageCode => _uploadManager.uploadingLanguageCode;

  // Active Context delegation
  RxString get channelId => _contextManager.channelId;
  RxList<Video> get videos => _contextManager.videos;
  RxList<Video> get filteredVideos => _contextManager.filteredVideos;
  RxString get searchQuery => _contextManager.searchQuery;
  Rxn<Video> get selectedVideo => _contextManager.selectedVideo;
  late final TextEditingController searchController = trackTextController(TextEditingController());

  // Language & Tab delegation
  RxString get activeTab => _languageManager.activeTab;
  RxList<String> get availableLanguages => _languageManager.availableLanguages;
  RxMap<String, String> get customLanguages => _languageManager.customLanguages;
  RxString get selectedLanguage => _languageManager.selectedLanguage;
  RxList<LanguageRequest> get languageRequests =>
      _languageManager.languageRequests;
  RxList<LanguageRequest> get clientLanguageRequests =>
      _languageManager.clientLanguageRequests;
  RxBool get isLoadingRequests => _languageManager.isLoadingRequests;
  RxBool get showRequestsPanel => _languageManager.showRequestsPanel;

  // Editor delegation
  RxList<AudioTrackItem> get currentTracks => _editorManager.currentTracks;
  final RxList<VideoTrackItem> currentVideoTracks = <VideoTrackItem>[].obs;
  RxList<CommentaryTrackItem> get commentaryTracks =>
      _editorManager.commentaryTracks;
  RxBool get isSaving => _editorManager.isSaving;
  RxBool get isLoadingTracks => _editorManager.isLoadingTracks;
  RxBool get hasUnsavedChanges => _editorManager.hasUnsavedChanges;

  List<({String code, String name})> get supportedLanguages =>
      kSupportedLanguages;

  List<({String code, String name})> get elevenLabsV4SupportedLanguages =>
      kElevenLabsV4SupportedLanguages;

  List<({String code, String name})> get chirp3HdSupportedLanguages =>
      kElevenLabsV4SupportedLanguages;

  // Active AI dubbing generation tracking & progress state
  static final Map<String, Set<String>> _globalActiveDubbingJobs = {};
  static final Map<String, Map<String, AudioDubbingProgressState>>
      _globalDubbingProgress = {};

  /// Registers active dubbing languages for a video across upload/studio lifecycles.
  static void registerActiveDubbingJob({
    required String videoId,
    required List<String> targetLanguages,
  }) {
    final now = DateTime.now();
    for (final lang in targetLanguages) {
      final clean = lang.trim().toLowerCase();
      if (clean.isEmpty) continue;
      _globalActiveDubbingJobs.putIfAbsent(videoId, () => {}).add(clean);
      _globalDubbingProgress.putIfAbsent(videoId, () => {})[clean] =
          AudioDubbingProgressState(
            langCode: clean,
            startedAt: now,
            stageTitle: 'Analyzing audio & transcribing dialogue',
            etaText: '~20-30 sec',
          );
    }
  }

  /// Synchronizes active dubbing generation if this controller has the video selected or open.
  void registerActiveDubbingForVideo({
    required String videoId,
    required List<String> targetLanguages,
  }) {
    registerActiveDubbingJob(videoId: videoId, targetLanguages: targetLanguages);
    final now = DateTime.now();
    final v = selectedVideo.value;
    if (v != null && v.id == videoId) {
      for (final lang in targetLanguages) {
        final clean = lang.trim().toLowerCase();
        if (clean.isEmpty) continue;
        generatingDubLanguages.add(clean);
        dubbingProgress[clean] = AudioDubbingProgressState(
          langCode: clean,
          startedAt: now,
          stageTitle: 'Analyzing audio & transcribing dialogue',
          etaText: '~20-30 sec',
        );
        if (!availableLanguages.contains(clean)) {
          availableLanguages.add(clean);
        }
        var foundTrack = false;
        for (final track in currentTracks) {
          if (track.languageCode.trim().toLowerCase() == clean) {
            track.status = 'Generating...';
            foundTrack = true;
          }
        }
        if (!foundTrack) {
          currentTracks.add(
            AudioTrackItem(
              id: '${v.id}_$clean',
              languageCode: clean,
              languageName: getLanguageName(clean),
              audioUrl: '',
              status: 'Generating...',
            ),
          );
        }
      }
      currentTracks.refresh();
      syncCurrentVideoTracks();
      _startProgressTicker();
      _listenToDubbingJob(videoId);
    }
  }

  final RxSet<String> generatingDubLanguages = <String>{}.obs;
  final RxMap<String, AudioDubbingProgressState> dubbingProgress =
      <String, AudioDubbingProgressState>{}.obs;
  final Set<String> _notifiedDubLanguages = <String>{};

  StreamSubscription<DocumentSnapshot>? _aiDubbingJobSub;
  StreamSubscription<DocumentSnapshot>? _videoJobFallbackSub;
  StreamSubscription<DocumentSnapshot>? _videoDocSub;
  StreamSubscription<DocumentSnapshot>? _locDocSub;
  Timer? _progressTickerTimer;

  AudioDubbingProgressState? getDubbingProgress(String langCode) =>
      dubbingProgress[langCode];

  @override
  void onInit() {
    super.onInit();
    initializeContentFilters();
    unawaited(
      _contextManager.initializeContext(
        onViewStateChanged: setViewState,
        onError: setError,
      ),
    );
  }

  @override
  void onClose() {
    _progressTickerTimer?.cancel();
    _aiDubbingJobSub?.cancel();
    _videoJobFallbackSub?.cancel();
    _videoDocSub?.cancel();
    _locDocSub?.cancel();
    MultiAudioPlayerController.pauseAll();
    MultiAudioPlayerController.disposeAll();
    playbackController.stop();
    _contextManager.dispose();
    _languageManager.dispose();
    super.onClose();
  }

  /// Determines if a Firestore video_jobs record is a dead zombie (> 10 minutes old with no update).
  bool _isJobZombie(Map<String, dynamic> data, Map<String, dynamic>? stage) {
    final now = DateTime.now().millisecondsSinceEpoch;
    int? timestamp;
    // CRITICAL: Actively updated jobs are actively progressing and must never be treated as zombies.
    // Check updatedAt timestamps first before falling back to startedAt or createdAt.
    if (stage != null && stage['updatedAt'] is num) {
      timestamp = (stage['updatedAt'] as num).toInt();
    } else if (data['updatedAt'] is num) {
      timestamp = (data['updatedAt'] as num).toInt();
    } else if (stage != null && stage['updatedAt'] is Timestamp) {
      timestamp = (stage['updatedAt'] as Timestamp).millisecondsSinceEpoch;
    } else if (data['updatedAt'] is Timestamp) {
      timestamp = (data['updatedAt'] as Timestamp).millisecondsSinceEpoch;
    } else if (stage != null && stage['startedAt'] is num) {
      timestamp = (stage['startedAt'] as num).toInt();
    } else if (stage != null && stage['startedAt'] is Timestamp) {
      timestamp = (stage['startedAt'] as Timestamp).millisecondsSinceEpoch;
    } else if (data['createdAt'] is num) {
      timestamp = (data['createdAt'] as num).toInt();
    } else if (data['createdAt'] is Timestamp) {
      timestamp = (data['createdAt'] as Timestamp).millisecondsSinceEpoch;
    }

    if (timestamp == null) return false;
    // Max allowable active idle duration for AI dubbing without updates: 10 minutes (600,000 ms)
    const maxActiveDurationMs = 10 * 60 * 1000;
    return (now - timestamp) > maxActiveDurationMs;
  }

  void _markLanguageDubCompleted(String videoId, String lang, String newUrl) {
    generatingDubLanguages.remove(lang);
    dubbingProgress.remove(lang);
    _globalActiveDubbingJobs[videoId]?.remove(lang);
    _globalDubbingProgress[videoId]?.remove(lang);

    for (final track in currentTracks) {
      if (track.languageCode == lang) {
        track.status = 'Published';
        if (newUrl.isNotEmpty) {
          track.audioUrl = newUrl;
          track.isResolved = true;
        }
      }
    }

    for (final track in currentVideoTracks) {
      if (track.languageCode == lang) {
        track.status = 'Published';
        if (newUrl.isNotEmpty) {
          track.videoUrl = newUrl;
          track.isResolved = true;
        }
      }
    }
    currentVideoTracks.refresh();
  }

  void _startProgressTicker() {
    _progressTickerTimer?.cancel();
    _progressTickerTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (generatingDubLanguages.isEmpty) {
        _progressTickerTimer?.cancel();
        _progressTickerTimer = null;
        return;
      }
      final vId = selectedVideo.value?.id;
      var updated = false;
      for (final lang in generatingDubLanguages.toList()) {
        final current = dubbingProgress[lang];
        if (current != null && current.isGenerating) {
          final startedAt = current.startedAt ?? DateTime.now();
          final elapsedSec = DateTime.now().difference(startedAt).inSeconds;

          // 1. Hard Timeout Check: Voice dubbing must never spin beyond 10 minutes (600 seconds)
          if (elapsedSec > 600) {
            logger.warning('Dubbing generation timed out for $lang (elapsed: $elapsedSec s)', tag: _tag);
            var recoveredUrl = '';
            if (vId != null) {
              final loc = await VideoMediaService().getLocalization(vId, forceRefresh: true);
              recoveredUrl = loc.audioTracks[lang] ?? '';
            }
            if (recoveredUrl.isNotEmpty) {
              _markLanguageDubCompleted(vId!, lang, recoveredUrl);
              currentTracks.refresh();
              await refreshVideoLocalization(vId);
              final notifKey = '${vId}_$lang';
              if (!_notifiedDubLanguages.contains(notifKey)) {
                _notifiedDubLanguages.add(notifKey);
                showSuccess('${getLanguageName(lang)} dubbed audio track is ready!');
              }
              updated = true;
            } else {
              generatingDubLanguages.remove(lang);
              dubbingProgress.remove(lang);
              if (vId != null) {
                _globalActiveDubbingJobs[vId]?.remove(lang);
                _globalDubbingProgress[vId]?.remove(lang);
              }
              for (final track in currentTracks) {
                if (track.languageCode == lang && track.audioUrl.isEmpty) {
                  track.status = 'Not added';
                }
              }
              currentTracks.refresh();
              AppSnackbar.warning(
                'AI voice dubbing for ${getLanguageName(lang)} timed out in the cloud. You can retry with one tap.',
              );
              updated = true;
            }
            continue;
          }

          // 🚀 Fast-Track Progressive Check:
          // If the audio track is already generated and published in cloud,
          // complete immediately without waiting for any ticker delay!
          final fastCachedUrl = (selectedVideo.value?.audioTracks[lang] ?? '').isNotEmpty
              ? selectedVideo.value!.audioTracks[lang]!
              : (VideoMediaService.localizationCache[vId]?.audioTracks[lang] ?? '');
          if (fastCachedUrl.isNotEmpty && vId != null) {
            _markLanguageDubCompleted(vId, lang, fastCachedUrl);
            currentTracks.refresh();
            await refreshVideoLocalization(vId);
            final notifKey = '${vId}_$lang';
            if (!_notifiedDubLanguages.contains(notifKey)) {
              _notifiedDubLanguages.add(notifKey);
              showSuccess('${getLanguageName(lang)} dubbed audio track is ready!');
            }
            updated = true;
            continue;
          }

          if (current.progress < 94) {
            final nextProgress = current.progress + 1;
            var step = current.stageStep;
            var title = current.stageTitle;
            var eta = current.etaText;
            if (nextProgress >= 85) {
              step = 4;
              title = 'Mastering audio ducking & synchronization';
              eta = 'Finalizing shortly';
            } else if (nextProgress >= 55) {
              step = 3;
              title = 'Synthesizing AI voice in ${getLanguageName(lang)}';
              eta = '~10-15 sec';
            } else if (nextProgress >= 28) {
              step = 2;
              title = 'Translating speech to ${getLanguageName(lang)}';
              eta = '~15-20 sec';
            } else {
              step = 1;
              title = 'Analyzing audio & transcribing dialogue';
              eta = '~20-30 sec';
            }
            final updatedState = current.copyWith(
              progress: nextProgress,
              stageStep: step,
              stageTitle: title,
              totalStepsText: 'Step $step of 4',
              etaText: eta,
            );
            dubbingProgress[lang] = updatedState;
            if (vId != null) {
              _globalDubbingProgress.putIfAbsent(vId, () => {})[lang] = updatedState;
            }
            updated = true;
          } else if (current.progress >= 94 && vId != null) {
            // Proactively verify Firestore when at 94% ("Finalizing shortly")
            // using fresh server reads across localization, videos, and video_jobs
            var audioUrl = '';
            var isCloudFailed = false;
            try {
              final loc = await VideoMediaService().getLocalization(vId, forceRefresh: true);
              audioUrl = loc.audioTracks[lang] ?? '';

              if (audioUrl.isEmpty) {
                final vDoc = await FirebaseFirestore.instance
                    .collection(FirestoreCollections.videos)
                    .doc(vId)
                    .get();
                if (vDoc.exists && vDoc.data() != null) {
                  final vData = vDoc.data()!;
                  final vTracks = (vData['audioTracks'] as Map<String, dynamic>?) ?? {};
                  audioUrl = (vTracks[lang] as String?) ??
                      (vData['audioTracks.$lang'] as String?) ??
                      (vData['media.audioTracks.$lang'] as String?) ??
                      '';
                }
              }

              if (audioUrl.isEmpty) {
                final jobDoc = await FirebaseFirestore.instance
                    .collection('video_jobs')
                    .doc(vId)
                    .get();
                if (jobDoc.exists && jobDoc.data() != null) {
                  final jData = jobDoc.data()!;
                  final jOutputs = (jData['outputs'] as Map<String, dynamic>?) ?? {};
                  final jAudios = (jOutputs['audioTracks'] as Map<String, dynamic>?) ?? {};
                  final jStages = (jData['stages'] as Map<String, dynamic>?) ?? {};
                  audioUrl = (jAudios[lang] as String?) ??
                      (jData['outputs.audioTracks.$lang'] as String?) ??
                      ((jStages['dubbing_$lang'] as Map<String, dynamic>?)?['audioUrl'] as String?) ??
                      '';

                  final jStatus = (jData['status'] as String?)?.toLowerCase();
                  final dubStage = jStages['dubbing_$lang'] as Map<String, dynamic>?;
                  final generalDub = jStages['dubbing'] as Map<String, dynamic>?;
                  if (jStatus == 'failed' || dubStage?['status'] == 'failed' || generalDub?['status'] == 'failed') {
                    isCloudFailed = true;
                  }
                }
              }
            } catch (pollErr) {
              logger.warning('Active dub polling check error: $pollErr', tag: _tag);
            }

            if (isCloudFailed && audioUrl.isEmpty) {
              generatingDubLanguages.remove(lang);
              dubbingProgress.remove(lang);
              _globalActiveDubbingJobs[vId]?.remove(lang);
              _globalDubbingProgress[vId]?.remove(lang);
              for (final track in currentTracks) {
                if (track.languageCode == lang && track.audioUrl.isEmpty) {
                  track.status = 'Not added';
                }
              }
              currentTracks.refresh();
              AppSnackbar.warning(
                'AI voice dubbing for ${getLanguageName(lang)} encountered an issue in the cloud. Please tap Retry.',
              );
              updated = true;
              continue;
            }

            if (audioUrl.isNotEmpty) {
              _markLanguageDubCompleted(vId, lang, audioUrl);
              currentTracks.refresh();
              await refreshVideoLocalization(vId);
              final notifKey = '${vId}_$lang';
              if (!_notifiedDubLanguages.contains(notifKey)) {
                _notifiedDubLanguages.add(notifKey);
                showSuccess('${getLanguageName(lang)} dubbed audio track is ready!');
              }
              updated = true;
            } else {
              // Still generating/mastering in cloud.
              // Smoothly advance from 94% to 98% with dynamic status so UI doesn't look frozen!
              final elapsedSec = current.startedAt != null
                  ? DateTime.now().difference(current.startedAt!).inSeconds
                  : 180;

              var nextProgress = current.progress;
              var stageTitle = current.stageTitle;
              var eta = current.etaText;

              if (current.progress < 98) {
                final targetProg = (94 + ((elapsedSec - 160) ~/ 12)).clamp(94, 98);
                if (targetProg > current.progress) {
                  nextProgress = targetProg;
                }
              }

              if (nextProgress >= 97) {
                stageTitle = 'Mastering audio ducking & synchronization';
                eta = 'Almost ready...';
              } else if (nextProgress >= 95) {
                stageTitle = 'Mastering audio ducking & synchronization';
                eta = 'Syncing cloud tracks...';
              } else {
                stageTitle = 'Mastering audio ducking & synchronization';
                eta = 'Finalizing shortly';
              }

              if (nextProgress != current.progress || eta != current.etaText) {
                final updatedState = current.copyWith(
                  progress: nextProgress,
                  stageStep: 4,
                  totalStepsText: 'Step 4 of 4',
                  stageTitle: stageTitle,
                  etaText: eta,
                );
                dubbingProgress[lang] = updatedState;
                _globalDubbingProgress.putIfAbsent(vId, () => {})[lang] = updatedState;
                updated = true;
              }
            }
          }
        }
      }
      if (updated) {
        dubbingProgress.refresh();
      }
    });
  }

  void setActiveTab(String tab) => _languageManager.setActiveTab(tab);

  void toggleRequestsPanel() => _languageManager.toggleRequestsPanel();

  void setChannelContext(String id) =>
      _contextManager.setChannelContext(id, onViewStateChanged: setViewState);

  void setSearchQuery(String query) => _contextManager.setSearchQuery(query);

  /// Selects active video and bootstraps localization tracks, commentaries, and request streams.
  Future<void> selectVideo(Video? video, {bool force = false}) async {
    if (!force && video != null && selectedVideo.value?.id == video.id) {
      return;
    }
    await playbackController.stop();
    await _contextManager.selectVideo(
      video,
      force: force,
      onVideoSelected: (v) async {
        MultiAudioPlayerController.pauseAll();
        _editorManager.hasUnsavedChanges.value = false;
        if (v == null) {
          _languageManager.clear();
          _editorManager.clear();
          currentVideoTracks.clear();
          _aiDubbingJobSub?.cancel();
          _videoDocSub?.cancel();
          _locDocSub?.cancel();
          _progressTickerTimer?.cancel();
          _notifiedDubLanguages.clear();
          return;
        }

        logger.info(
          'Selected video for audio tracks editing session: ${v.title}',
          tag: _tag,
        );

        _languageManager.listenToLanguageRequests(v.id);

        // 1. Restore any active generating dubbing tasks from memory cache immediately
        // with strict TTL pruning (discard anything older than 5 minutes)
        final now = DateTime.now();
        final cachedGenerating = _globalActiveDubbingJobs[v.id] ?? {};
        final cachedProgress = _globalDubbingProgress[v.id] ?? {};

        final expiredLangs = <String>{};
        for (final entry in cachedProgress.entries) {
          final job = entry.value;
          final started = job.startedAt;
          if (started == null || now.difference(started).inMinutes >= 5) {
            expiredLangs.add(entry.key);
          }
        }
        for (final lang in expiredLangs) {
          cachedGenerating.remove(lang);
          cachedProgress.remove(lang);
          _globalActiveDubbingJobs[v.id]?.remove(lang);
          _globalDubbingProgress[v.id]?.remove(lang);
        }

        generatingDubLanguages.addAll(cachedGenerating);
        dubbingProgress.addAll(cachedProgress);

        final localization = await VideoMediaService().getLocalization(
          v.id,
          forceRefresh: cachedGenerating.isNotEmpty,
        );

        // Extract commentary items
        final commentaryList = <CommentaryTrackItem>[];
        localization.commentaryVideos.forEach((key, map) {
          commentaryList.add(CommentaryTrackItem.fromMap(key, map));
        });
        _editorManager.commentaryTracks.value = commentaryList;

        // Extract audio tracks (merge v.audioTracks and localization.audioTracks so no tracks are lost)
        final audioMap = Map<String, String>.from(v.audioTracks)
          ..addAll(localization.audioTracks);
        final baseLang = v.language.isNotEmpty ? v.language : 'en';
        final langs = audioMap.keys.toList();
        langs.remove(baseLang);
        langs.insert(0, baseLang);

        // Automatically discover in-flight dubbing requested during video upload or from video metadata
        final allRequestedDubLangs = <String>{
          ...v.dubbingLanguages,
          ...cachedGenerating,
        };
        for (final dubLang in allRequestedDubLangs) {
          final clean = dubLang.trim().toLowerCase();
          if (clean.isEmpty || clean == baseLang.toLowerCase()) continue;
          final alreadyHasAudio = (audioMap[clean] ?? '').trim().isNotEmpty;
          if (!alreadyHasAudio) {
            generatingDubLanguages.add(clean);
            _globalActiveDubbingJobs.putIfAbsent(v.id, () => {}).add(clean);
            if (!dubbingProgress.containsKey(clean)) {
              final initialProgress = AudioDubbingProgressState(
                langCode: clean,
                startedAt: v.createdAt.toDate(),
                stageTitle: 'Analyzing audio & transcribing dialogue',
                etaText: '~20-30 sec',
              );
              dubbingProgress[clean] = initialProgress;
              _globalDubbingProgress.putIfAbsent(v.id, () => {})[clean] = initialProgress;
            }
            if (!langs.contains(clean)) {
              langs.add(clean);
            }
          }
        }

        // Keep generating languages in availableLanguages so they remain visible when switching tabs
        for (final genLang in generatingDubLanguages.toList()) {
          if (audioMap.containsKey(genLang) &&
              (audioMap[genLang] ?? '').trim().isNotEmpty) {
            generatingDubLanguages.remove(genLang);
            dubbingProgress.remove(genLang);
            _globalActiveDubbingJobs[v.id]?.remove(genLang);
            _globalDubbingProgress[v.id]?.remove(genLang);
          } else if (!langs.contains(genLang)) {
            langs.add(genLang);
          }
        }

        _languageManager.availableLanguages.value = langs;
        _languageManager.selectedLanguage.value = baseLang;

        await _editorManager.parseAllAudioTracks(
          video: v,
          availableLanguages: langs,
          entireAudioMap: audioMap,
          generatingLanguages: generatingDubLanguages,
          languageNameResolver: getLanguageName,
        );
        syncCurrentVideoTracks();
        selectedVideo.refresh();

        if (generatingDubLanguages.isNotEmpty) {
          _startProgressTicker();
        }

        // 2. Attach real-time Firestore video_jobs listener to stay synced with backend
        _listenToDubbingJob(v.id);
      },
    );
  }

  /// Updates the original video language in database and refreshes workspace.
  Future<void> updateOriginalVideoLanguage(String newLangCode) async {
    final v = selectedVideo.value;
    if (v == null || newLangCode.isEmpty) return;
    try {
      final normCode = normalizeLanguageCode(newLangCode);
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.videos)
          .doc(v.id)
          .update({
            'language': normCode,
            'sourceLanguage': normCode,
            'primaryLanguage': normCode,
            'executionPlan.primaryLanguage': normCode,
          });
      final updatedVideo = v.copyWith(language: normCode);
      selectedVideo.value = updatedVideo;

      // Invalidate VideoMediaService localizationCache for this video
      VideoMediaService.localizationCache.remove(v.id);

      if (!availableLanguages.contains(normCode)) {
        availableLanguages.insert(0, normCode);
      }
      selectedLanguage.value = normCode;

      final audioMap = Map<String, String>.from(updatedVideo.audioTracks)
        ..addAll(VideoMediaService.localizationCache[v.id]?.audioTracks ?? const {});
      await _editorManager.parseAllAudioTracks(
        video: updatedVideo,
        availableLanguages: availableLanguages,
        entireAudioMap: audioMap,
        generatingLanguages: generatingDubLanguages,
        languageNameResolver: getLanguageName,
      );
      syncCurrentVideoTracks();
      selectedVideo.refresh();
      showSuccess('Original video language updated to ${getLanguageName(normCode)}.');
    } catch (e) {
      logger.error('Failed updating original video language', error: e, tag: _tag);
      showError('Unable to update video language. Please try again.');
    }
  }

  /// Switches active editing language track.
  void switchLanguageTrack(String langCode) {
    _languageManager.switchLanguageTrack(
      langCode,
      onLanguageSwitched: (code) {
        _editorManager.hasUnsavedChanges.value = false;
        final audioMap = selectedVideo.value?.audioTracks ?? {};
        _editorManager.parseAudioTracksForLanguage(
          code,
          audioMap,
          selectedVideoId: selectedVideo.value?.id,
          baseLanguage: selectedVideo.value?.language,
        );
      },
    );
  }

  /// Adds a new language layer to the available languages catalog.
  void addLanguageLayer(String langCode) {
    _languageManager.addLanguageLayer(
      langCode,
      onLanguageAdded: (code) {
        _editorManager.hasUnsavedChanges.value = true;
        _syncCurrentTracks();
      },
      onShowSuccess: showSuccess,
    );
  }

  /// Adds a custom language and activates it as a layer.
  void addCustomLanguage(String langCode, String langName) {
    _languageManager.addCustomLanguage(
      langCode,
      langName,
      onLanguageAdded: (code) {
        _editorManager.hasUnsavedChanges.value = true;
        _syncCurrentTracks();
      },
      onShowSuccess: showSuccess,
    );
  }

  /// Permanently deletes an audio track and its cloud references for the active video.
  Future<void> deleteAudioTrack(String langCode) async {
    final video = selectedVideo.value;
    if (video == null) return;

    final cleanCode = langCode.trim().toLowerCase();
    final baseLang = video.language.isNotEmpty
        ? video.language.trim().toLowerCase()
        : 'en';

    if (cleanCode == baseLang) {
      AppSnackbar.info('Cannot remove primary video audio language.');
      return;
    }

    try {
      // 1. Stop playback if active
      if (playbackController.activeTrackId.value == '${video.id}_$cleanCode') {
        await playbackController.stop();
      }

      // 2. Remove language from active lists
      availableLanguages.remove(cleanCode);
      generatingDubLanguages.remove(cleanCode);
      dubbingProgress.remove(cleanCode);
      _globalActiveDubbingJobs[video.id]?.remove(cleanCode);
      _globalDubbingProgress[video.id]?.remove(cleanCode);
      _notifiedDubLanguages.remove('${video.id}_$cleanCode');

      // 3. Remove from currentTracks immediately
      currentTracks.removeWhere(
        (t) => t.languageCode.trim().toLowerCase() == cleanCode,
      );
      currentTracks.refresh();

      // 4. Construct updated audioTracks map without this language
      final cachedLoc = VideoMediaService.localizationCache[video.id];
      final currentMap = Map<String, String>.from(
        cachedLoc?.audioTracks ?? video.audioTracks,
      );
      final trackUrl = currentMap[cleanCode] ?? currentMap[langCode] ?? '';
      currentMap.remove(cleanCode);
      currentMap.remove(langCode);
      currentMap.removeWhere((k, v) => k.trim().toLowerCase() == cleanCode);

      // 5. Update local model & static cache
      final updatedVideo = video.copyWith(audioTracks: currentMap);
      selectedVideo.value = updatedVideo;

      VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
        subtitles: cachedLoc?.subtitles ?? video.mediaSubtitles,
        dubbedVideos: cachedLoc?.dubbedVideos ?? video.dubbedVideos,
        audioTracks: currentMap,
        commentaryVideos: cachedLoc?.commentaryVideos ?? const {},
      );

      // 6. Switch selected language if the deleted language was active
      if (selectedLanguage.value.trim().toLowerCase() == cleanCode) {
        _languageManager.selectedLanguage.value = baseLang;
      }

      _editorManager.hasUnsavedChanges.value = false;
      selectedVideo.refresh();
      currentTracks.refresh();

      // 7. Delete from Firestore media/localization document
      try {
        final locDocRef = FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .doc(video.id)
            .collection('media')
            .doc('localization');

        final locSnap = await locDocRef.get();
        if (locSnap.exists) {
          final locData = locSnap.data() ?? {};
          await locDocRef.update({
            'audioTracks': currentMap,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Clean any legacy flat dotted fields stored directly on locDoc
          final flatKeys = locData.keys.where((k) {
            final lk = k.toLowerCase();
            return lk == 'audiotracks.$cleanCode' ||
                lk == 'audiotracks.$langCode' ||
                lk == 'media.audiotracks.$cleanCode' ||
                lk == 'media.audiotracks.$langCode';
          }).toList();
          if (flatKeys.isNotEmpty) {
            final flatDeletes = <String, dynamic>{};
            for (final k in flatKeys) {
              flatDeletes[k] = FieldValue.delete();
            }
            await locDocRef.set(flatDeletes, SetOptions(merge: true));
          }
        } else {
          await locDocRef.set({
            'audioTracks': currentMap,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        logger.warning('Failed updating localization in Firestore: $e', tag: _tag);
      }

      // 8. Delete from main Firestore video document
      try {
        final videoDocRef = FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .doc(video.id);

        final videoSnap = await videoDocRef.get();
        if (videoSnap.exists) {
          final vData = videoSnap.data() ?? {};
          final videoUpdates = <String, dynamic>{
            'audioTracks': currentMap,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if (vData['media'] is Map) {
            videoUpdates['media.audioTracks'] = currentMap;
          }

          await videoDocRef.update(videoUpdates);

          // Clean any legacy flat dotted fields stored directly on videoDoc
          final flatKeys = vData.keys.where((k) {
            final lk = k.toLowerCase();
            return lk == 'audiotracks.$cleanCode' ||
                lk == 'audiotracks.$langCode' ||
                lk == 'media.audiotracks.$cleanCode' ||
                lk == 'media.audiotracks.$langCode';
          }).toList();
          if (flatKeys.isNotEmpty) {
            final flatDeletes = <String, dynamic>{};
            for (final k in flatKeys) {
              flatDeletes[k] = FieldValue.delete();
            }
            await videoDocRef.set(flatDeletes, SetOptions(merge: true));
          }
        } else {
          await videoDocRef.set({
            'audioTracks': currentMap,
            'media': {
              'audioTracks': currentMap,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (e) {
        logger.warning('Failed updating video document in Firestore: $e', tag: _tag);
      }

      // 9. Clean video_jobs document so pipeline listeners/fallbacks never revive it
      try {
        final jobDocRef = FirebaseFirestore.instance
            .collection('video_jobs')
            .doc(video.id);
        final jobSnap = await jobDocRef.get();
        if (jobSnap.exists) {
          final jData = jobSnap.data() ?? {};
          final jobUpdates = <String, dynamic>{};

          final outputs = jData['outputs'];
          if (outputs is Map && outputs['audioTracks'] is Map) {
            final currentOutputs = Map<String, dynamic>.from(outputs['audioTracks'] as Map);
            currentOutputs.remove(cleanCode);
            currentOutputs.remove(langCode);
            currentOutputs.removeWhere((k, _) => k.toLowerCase() == cleanCode);
            jobUpdates['outputs.audioTracks'] = currentOutputs;
          }
          if (jData['audioTracks'] is Map) {
            final currentAudios = Map<String, dynamic>.from(jData['audioTracks'] as Map);
            currentAudios.remove(cleanCode);
            currentAudios.remove(langCode);
            currentAudios.removeWhere((k, _) => k.toLowerCase() == cleanCode);
            jobUpdates['audioTracks'] = currentAudios;
          }
          final stages = jData['stages'];
          if (stages is Map) {
            if (stages.containsKey('dubbing_$cleanCode')) {
              jobUpdates['stages.dubbing_$cleanCode'] = FieldValue.delete();
            }
            if (stages.containsKey('dubbing_$langCode')) {
              jobUpdates['stages.dubbing_$langCode'] = FieldValue.delete();
            }
            if (stages.containsKey('translating_$cleanCode')) {
              jobUpdates['stages.translating_$cleanCode'] = FieldValue.delete();
            }
            if (stages.containsKey('translating_$langCode')) {
              jobUpdates['stages.translating_$langCode'] = FieldValue.delete();
            }
          }
          final executionPlan = jData['executionPlan'];
          if (executionPlan is Map) {
            if (executionPlan['dubbingLanguages'] is List) {
              final list = List<dynamic>.from(executionPlan['dubbingLanguages'] as List)
                ..removeWhere((item) =>
                    item.toString().toLowerCase() == cleanCode ||
                    item.toString().toLowerCase() == langCode.toLowerCase());
              jobUpdates['executionPlan.dubbingLanguages'] = list;
            }
            if (executionPlan['languages'] is List) {
              final list = List<dynamic>.from(executionPlan['languages'] as List)
                ..removeWhere((item) =>
                    item.toString().toLowerCase() == cleanCode ||
                    item.toString().toLowerCase() == langCode.toLowerCase());
              jobUpdates['executionPlan.languages'] = list;
            }
          }
          final onDemand = stages is Map ? stages['onDemandAI'] : null;
          if (onDemand is Map && onDemand['requestedLanguages'] is List) {
            final list = List<dynamic>.from(onDemand['requestedLanguages'] as List)
              ..removeWhere((item) =>
                  item.toString().toLowerCase() == cleanCode ||
                  item.toString().toLowerCase() == langCode.toLowerCase());
            jobUpdates['stages.onDemandAI.requestedLanguages'] = list;
          }

          if (jobUpdates.isNotEmpty) {
            await jobDocRef.update(jobUpdates).catchError((_) {});
          }
        }
      } catch (_) {}

      // Clean separate video_jobs matching videoId
      try {
        final jobsSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videoJobs)
            .where('videoId', isEqualTo: video.id)
            .get();

        for (final doc in jobsSnap.docs) {
          final data = doc.data();
          final jobTarget = (data['targetLanguage'] ?? '').toString().toLowerCase();
          if (jobTarget == cleanCode || jobTarget == langCode.toLowerCase()) {
            await doc.reference.delete().catchError((_) {});
          }
        }
      } catch (_) {}

      // 10. Best-effort deletion of audio file in Firebase Storage if applicable
      if (trackUrl.isNotEmpty &&
          (trackUrl.startsWith('gs://') ||
              trackUrl.contains('firebasestorage.googleapis.com'))) {
        try {
          await FirebaseStorage.instance.refFromURL(trackUrl).delete();
        } catch (_) {}
      }

      showSuccess('Removed ${getLanguageName(cleanCode)} audio track');
    } catch (e, stack) {
      logger.error('Failed to delete audio track', error: e, stackTrace: stack, tag: _tag);
      showError('Unable to remove audio track. Please check your connection and try again.');
    }
  }

  /// Permanently deletes a dubbed video track and its cloud references for the active video.
  Future<void> deleteDubbedVideoTrack(String langCode) async {
    final video = selectedVideo.value;
    if (video == null) return;

    final cleanCode = langCode.trim().toLowerCase();
    final baseLang = video.language.isNotEmpty
        ? video.language.trim().toLowerCase()
        : 'en';

    if (cleanCode == baseLang) {
      AppSnackbar.info('Cannot remove primary original video.');
      return;
    }

    try {
      // 1. Remove from in-flight generation states
      generatingDubLanguages.remove(cleanCode);
      dubbingProgress.remove(cleanCode);
      _globalActiveDubbingJobs[video.id]?.remove(cleanCode);
      _globalDubbingProgress[video.id]?.remove(cleanCode);
      _notifiedDubLanguages.remove('${video.id}_$cleanCode');

      // 2. Remove from currentVideoTracks immediately
      currentVideoTracks.removeWhere(
        (t) => t.languageCode.trim().toLowerCase() == cleanCode,
      );
      currentVideoTracks.refresh();

      // 3. Construct updated dubbedVideos map without this language
      final cachedLoc = VideoMediaService.localizationCache[video.id];
      final currentMap = Map<String, String>.from(
        cachedLoc?.dubbedVideos ?? video.dubbedVideos,
      );
      final videoUrl = currentMap[cleanCode] ?? currentMap[langCode] ?? '';
      currentMap.remove(cleanCode);
      currentMap.remove(langCode);
      currentMap.removeWhere((k, v) => k.trim().toLowerCase() == cleanCode);

      // 4. Update local model & static cache
      final updatedVideo = video.copyWith(dubbedVideos: currentMap);
      selectedVideo.value = updatedVideo;

      VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
        subtitles: cachedLoc?.subtitles ?? video.mediaSubtitles,
        dubbedVideos: currentMap,
        audioTracks: cachedLoc?.audioTracks ?? video.audioTracks,
        commentaryVideos: cachedLoc?.commentaryVideos ?? const {},
      );

      _editorManager.hasUnsavedChanges.value = false;
      selectedVideo.refresh();
      currentVideoTracks.refresh();

      // 5. Delete from Firestore media/localization document
      try {
        final locDocRef = FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .doc(video.id)
            .collection('media')
            .doc('localization');

        final locSnap = await locDocRef.get();
        if (locSnap.exists) {
          final locData = locSnap.data() ?? {};
          await locDocRef.update({
            'dubbedVideos': currentMap,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Clean any legacy flat dotted fields stored directly on locDoc
          final flatKeys = locData.keys.where((k) {
            final lk = k.toLowerCase();
            return lk == 'dubbedvideos.$cleanCode' ||
                lk == 'dubbedvideos.$langCode' ||
                lk == 'media.dubbedvideos.$cleanCode' ||
                lk == 'media.dubbedvideos.$langCode';
          }).toList();
          if (flatKeys.isNotEmpty) {
            final flatDeletes = <String, dynamic>{};
            for (final k in flatKeys) {
              flatDeletes[k] = FieldValue.delete();
            }
            await locDocRef.set(flatDeletes, SetOptions(merge: true));
          }
        } else {
          await locDocRef.set({
            'dubbedVideos': currentMap,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        logger.warning('Failed updating localization dubbedVideos in Firestore: $e', tag: _tag);
      }

      // 6. Delete from main Firestore video document
      try {
        final videoDocRef = FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .doc(video.id);

        final videoSnap = await videoDocRef.get();
        if (videoSnap.exists) {
          final vData = videoSnap.data() ?? {};
          final videoUpdates = <String, dynamic>{
            'dubbedVideos': currentMap,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if (vData['media'] is Map) {
            videoUpdates['media.dubbedVideos'] = currentMap;
          }

          await videoDocRef.update(videoUpdates);

          // Clean any legacy flat dotted fields stored directly on videoDoc
          final flatKeys = vData.keys.where((k) {
            final lk = k.toLowerCase();
            return lk == 'dubbedvideos.$cleanCode' ||
                lk == 'dubbedvideos.$langCode' ||
                lk == 'media.dubbedvideos.$cleanCode' ||
                lk == 'media.dubbedvideos.$langCode';
          }).toList();
          if (flatKeys.isNotEmpty) {
            final flatDeletes = <String, dynamic>{};
            for (final k in flatKeys) {
              flatDeletes[k] = FieldValue.delete();
            }
            await videoDocRef.set(flatDeletes, SetOptions(merge: true));
          }
        } else {
          await videoDocRef.set({
            'dubbedVideos': currentMap,
            'media': {
              'dubbedVideos': currentMap,
            },
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (e) {
        logger.warning('Failed updating video document dubbedVideos in Firestore: $e', tag: _tag);
      }

      // 7. Delete physical storage video file if applicable
      if (videoUrl.isNotEmpty &&
          (videoUrl.startsWith('gs://') ||
              videoUrl.contains('firebasestorage.googleapis.com'))) {
        try {
          await FirebaseStorage.instance.refFromURL(videoUrl).delete();
        } catch (_) {}
      }

      // 8. Clean video_jobs document so pipeline listeners/fallbacks never revive it
      try {
        final jobDocRef = FirebaseFirestore.instance
            .collection('video_jobs')
            .doc(video.id);
        final jobSnap = await jobDocRef.get();
        if (jobSnap.exists) {
          final jData = jobSnap.data() ?? {};
          final jobUpdates = <String, dynamic>{};
          final outputs = jData['outputs'];
          if (outputs is Map && outputs['dubbedVideos'] is Map) {
            final currentOutputs = Map<String, dynamic>.from(outputs['dubbedVideos'] as Map);
            currentOutputs.remove(cleanCode);
            currentOutputs.remove(langCode);
            currentOutputs.removeWhere((k, _) => k.toLowerCase() == cleanCode);
            jobUpdates['outputs.dubbedVideos'] = currentOutputs;
          }
          final stages = jData['stages'];
          if (stages is Map) {
            if (stages.containsKey('dubbing_$cleanCode')) {
              jobUpdates['stages.dubbing_$cleanCode'] = FieldValue.delete();
            }
            if (stages.containsKey('dubbing_$langCode')) {
              jobUpdates['stages.dubbing_$langCode'] = FieldValue.delete();
            }
          }
          if (jobUpdates.isNotEmpty) {
            await jobDocRef.update(jobUpdates).catchError((_) {});
          }
        }
      } catch (_) {}

      // Delete associated video_jobs matching videoId
      try {
        final jobsSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videoJobs)
            .where('videoId', isEqualTo: video.id)
            .get();

        for (final doc in jobsSnap.docs) {
          final data = doc.data();
          final jobTarget = (data['targetLanguage'] ?? '').toString().toLowerCase();
          if (jobTarget == cleanCode || jobTarget == langCode.toLowerCase()) {
            await doc.reference.delete().catchError((_) {});
          }
        }
      } catch (_) {}

      showSuccess('Removed ${getLanguageName(cleanCode)} dubbed video');
    } catch (e, stack) {
      logger.error('Failed to delete dubbed video track', error: e, stackTrace: stack, tag: _tag);
      showError('Unable to remove dubbed video. Please check your connection and try again.');
    }
  }

  /// Removes a language layer and synchronizes tracks.
  /// If an audio track exists for this language, it is deleted from database and storage.
  Future<void> removeLanguageLayer(String langCode) async {
    final baseLang = selectedVideo.value?.language ?? 'en';
    if (langCode == baseLang) {
      AppSnackbar.info('Cannot remove primary video audio language.');
      return;
    }

    final v = selectedVideo.value;
    final cachedLoc = v != null ? VideoMediaService.localizationCache[v.id] : null;
    final cleanCode = langCode.trim().toLowerCase();
    final hasAudioTrack = (v?.audioTracks.keys.any((k) => k.toLowerCase() == cleanCode) == true) ||
        (cachedLoc?.audioTracks.keys.any((k) => k.toLowerCase() == cleanCode) == true) ||
        currentTracks.any((t) => t.languageCode.toLowerCase() == cleanCode && t.audioUrl.trim().isNotEmpty);

    if (hasAudioTrack) {
      await deleteAudioTrack(cleanCode);
      return;
    }

    _languageManager.removeLanguageLayer(
      cleanCode,
      baseLang: baseLang,
      onLanguageRemoved: (code) {
        _editorManager.hasUnsavedChanges.value = true;
        _syncCurrentTracks();
      },
      onShowSuccess: showSuccess,
    );
  }

  void _syncCurrentTracks() {
    final v = selectedVideo.value;
    if (v == null) return;
    final cachedLoc = VideoMediaService.localizationCache[v.id];
    final audioMap = Map<String, String>.from(
      cachedLoc?.audioTracks ?? v.audioTracks,
    );
    _editorManager.parseAllAudioTracks(
      video: v,
      availableLanguages: availableLanguages,
      entireAudioMap: audioMap,
      generatingLanguages: generatingDubLanguages,
      languageNameResolver: getLanguageName,
    );
    syncCurrentVideoTracks();
    selectedVideo.refresh();
  }

  /// Synchronizes video tracks (original base video + multi-language dubbed videos) for the active video.
  void syncCurrentVideoTracks() {
    final v = selectedVideo.value;
    if (v == null) {
      currentVideoTracks.clear();
      return;
    }
    final baseLang = v.language.isNotEmpty ? v.language : 'en';
    final cachedLoc = VideoMediaService.localizationCache[v.id];
    final dubbedMap = Map<String, String>.from(v.dubbedVideos)
      ..addAll(cachedLoc?.dubbedVideos ?? const {});

    final list = <VideoTrackItem>[];

    // 1. Original / Base Video
    list.add(
      VideoTrackItem(
        id: '${v.id}_${baseLang}_video',
        languageCode: baseLang,
        languageName:
            '${getLanguageName(baseLang).replaceAll('(Base)', '').trim()} (Original)',
        videoUrl: v.videoUrl,
        thumbnailUrl: v.thumbnailUrl,
        isBaseTrack: true,
        isResolved: v.videoUrl.isNotEmpty,
      ),
    );

    // 2. Dubbed Videos from dubbedVideos map & any generating languages
    final allDubLangs = <String>{...dubbedMap.keys, ...generatingDubLanguages};
    for (final code in allDubLangs) {
      final cleanCode = code.trim().toLowerCase();
      if (cleanCode == baseLang.toLowerCase()) continue;
      final url = dubbedMap[cleanCode] ?? dubbedMap[code] ?? '';
      final isGenerating = generatingDubLanguages.contains(code) ||
          generatingDubLanguages.contains(cleanCode);

      final status = url.trim().isNotEmpty
          ? 'Published'
          : (isGenerating ? 'Generating...' : 'Not added');

      list.add(
        VideoTrackItem(
          id: '${v.id}_${cleanCode}_video',
          languageCode: cleanCode,
          languageName: getLanguageName(cleanCode),
          videoUrl: url,
          thumbnailUrl: v.thumbnailUrl,
          isResolved: url.trim().isNotEmpty,
          status: status,
          role: 'Dubbed video',
        ),
      );
    }

    currentVideoTracks.value = list;
  }

  void exportVideoTrackLinkToClipboard(String linkUrl) =>
      _editorManager.exportTrackLinkToClipboard(
        linkUrl,
        onShowSuccess: showSuccess,
        onShowError: showError,
      );

  void updateTrackUrl(int index, String newStorageLink) =>
      _editorManager.updateTrackUrl(index, newStorageLink);

  void exportTrackLinkToClipboard(String linkUrl) =>
      _editorManager.exportTrackLinkToClipboard(
        linkUrl,
        onShowSuccess: showSuccess,
        onShowError: showError,
      );

  Future<void> downloadAudioTrack(AudioTrackItem track) =>
      _editorManager.downloadAudioTrack(
        track,
        selectedVideo: selectedVideo.value,
        onShowSuccess: showSuccess,
        onShowError: showError,
      );

  Future<void> downloadCommentaryTrack(CommentaryTrackItem track) =>
      _editorManager.downloadCommentaryTrack(
        track,
        onShowSuccess: showSuccess,
        onShowError: showError,
      );

  Future<void> saveCurrentAudioTracks() =>
      _editorManager.saveCurrentAudioTracks(
        selectedVideo: selectedVideo.value,
        selectedLanguage: selectedLanguage.value,
        onShowSuccess: showSuccess,
        onShowError: handleError,
        onVideoRefreshed: () {
          final v = selectedVideo.value;
          if (v != null) {
            final cachedLoc = VideoMediaService.localizationCache[v.id];
            if (cachedLoc != null) {
              selectedVideo.value = v.copyWith(audioTracks: cachedLoc.audioTracks);
            }
          }
          selectedVideo.refresh();
        },
      );

  Future<bool> uploadTrackFile({
    required PlatformFile file,
    required String title,
    required String langCode,
    required String type,
  }) => _uploadManager.uploadTrackFile(
    file: file,
    title: title,
    langCode: langCode,
    type: type,
    selectedVideo: selectedVideo.value,
    onLanguageSynced: (code) {
      if (!availableLanguages.contains(code)) {
        availableLanguages.add(code);
      }
      selectedLanguage.value = code;
      final videoId = selectedVideo.value?.id;
      if (videoId != null &&
          VideoMediaService.localizationCache[videoId] != null) {
        _editorManager.parseAudioTracksForLanguage(
          code,
          VideoMediaService.localizationCache[videoId]!.audioTracks,
          selectedVideoId: videoId,
          baseLanguage: selectedVideo.value?.language,
        );
      }
    },
    onVideoRefreshed: () => selectedVideo.refresh(),
    onShowSuccess: showSuccess,
    onShowError: showError,
  );

  Future<bool> uploadMultipleTrackFiles({
    required List<BatchTrackUploadConfig> items,
  }) async {
    isUploading.value = true;
    try {
      return await _commentaryManager.uploadMultipleTrackFiles(
        items: items,
        selectedVideo: selectedVideo.value,
        onProgressUpdate: (val) => uploadProgress.value = val,
        onStatusUpdate: (val) => uploadStatus.value = val,
        onCommentaryUpdated: (list) => commentaryTracks.value = list,
        onLanguageSynced: (code, audioMap) {
          if (!availableLanguages.contains(code)) {
            availableLanguages.add(code);
          }
          _editorManager.parseAudioTracksForLanguage(
            selectedLanguage.value.isEmpty ? 'en' : selectedLanguage.value,
            audioMap,
            selectedVideoId: selectedVideo.value?.id,
            baseLanguage: selectedVideo.value?.language,
          );
        },
        onVideoRefreshed: () => selectedVideo.refresh(),
        onShowSuccess: showSuccess,
        onShowError: showError,
      );
    } finally {
      isUploading.value = false;
      uploadProgress.value = 0.0;
      uploadStatus.value = '';
    }
  }

  Future<void> deleteCommentaryTrack(String trackId) =>
      _commentaryManager.deleteCommentaryTrack(
        trackId: trackId,
        selectedVideo: selectedVideo.value,
        onCommentaryUpdated: (list) => commentaryTracks.value = list,
        onVideoRefreshed: () => selectedVideo.refresh(),
        onShowSuccess: showSuccess,
        onShowError: showError,
      );

  Future<bool> uploadSingleAudioDubForLanguage({
    required String langCode,
    required PlatformFile file,
  }) => _uploadManager.uploadSingleAudioDubForLanguage(
    langCode: langCode,
    file: file,
    selectedVideo: selectedVideo.value,
    onLanguageSynced: (code, audioMap) {
      if (!availableLanguages.contains(code)) {
        availableLanguages.add(code);
      }
      _editorManager.parseAudioTracksForLanguage(
        selectedLanguage.value.isEmpty ? 'en' : selectedLanguage.value,
        audioMap,
        selectedVideoId: selectedVideo.value?.id,
        baseLanguage: selectedVideo.value?.language,
      );
    },
    onVideoRefreshed: () => selectedVideo.refresh(),
    onShowSuccess: showSuccess,
    onShowError: showError,
  );

  Future<void> updateDubUrlForLanguage(String langCode, String url) async {
    await _uploadManager.updateDubUrlForLanguage(
      langCode: langCode,
      url: url,
      selectedVideo: selectedVideo.value,
      onLanguageSynced: (code, audioMap) {
        if (!availableLanguages.contains(code) && url.trim().isNotEmpty) {
          availableLanguages.add(code);
        }
        _editorManager.parseAudioTracksForLanguage(
          selectedLanguage.value.isEmpty ? 'en' : selectedLanguage.value,
          audioMap,
          selectedVideoId: selectedVideo.value?.id,
          baseLanguage: selectedVideo.value?.language,
        );
      },
      onVideoRefreshed: () => selectedVideo.refresh(),
    );
  }

  Future<void> removeDubForLanguage(String langCode) async {
    await deleteAudioTrack(langCode);
  }

  /// Triggers TruthWorld AI Voice Dubbing pipeline for a single target language.
  Future<bool> triggerAIDubbingForLanguage({
    required String langCode,
    String dubbingTier = 'audio_track',
    String voiceType = 'cloned',
    bool enableDiarization = false,
    String priorityMode = 'accuracy',
    bool isCinemaGrade = false,
    String voiceGender = 'auto',
    bool isDirectlyPaid = false,
  }) => triggerAIDubbingForLanguages(
    langCodes: [langCode],
    dubbingTier: dubbingTier,
    voiceType: voiceType,
    enableDiarization: enableDiarization,
    priorityMode: priorityMode,
    isCinemaGrade: isCinemaGrade,
    voiceGender: voiceGender,
    isDirectlyPaid: isDirectlyPaid,
  );

  /// Triggers TruthWorld AI Voice Dubbing pipeline for one or multiple target languages
  /// in a single parallel cloud job (capped at 5 languages per trigger per backend limits).
  Future<bool> triggerAIDubbingForLanguages({
    required List<String> langCodes,
    String dubbingTier = 'audio_track',
    String voiceType = 'cloned',
    bool enableDiarization = false,
    String priorityMode = 'accuracy',
    bool isCinemaGrade = false,
    String voiceGender = 'auto',
    bool isDirectlyPaid = false,
  }) async {
    final video = selectedVideo.value;
    if (video == null) {
      showError('No video selected.');
      return false;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showError('Please sign in to generate AI voice dubbing.');
      return false;
    }

    final baseLang = video.language.trim().toLowerCase();
    final targetLangs = langCodes
        .map((c) => c.trim().toLowerCase())
        .where((c) => c.isNotEmpty && c != baseLang)
        .toSet()
        .take(5)
        .toList();

    if (targetLangs.isEmpty) {
      showError(
        'Please select at least one target language different from the original video language.',
      );
      return false;
    }

    // Resolve channel context
    final targetChanId = channelId.value.isNotEmpty
        ? channelId.value
        : (video.channelId.isNotEmpty ? video.channelId : user.uid);
    Channel? chan;
    try {
      final chanDoc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.channels)
          .doc(targetChanId)
          .get();
      if (chanDoc.exists && chanDoc.data() != null) {
        chan = Channel.fromMap(chanDoc.data()!, chanDoc.id);
      }
    } catch (e) {
      logger.warning('Could not resolve channel for dubbing: $e', tag: _tag);
    }

    final durationSecs = video.durationSeconds > 0
        ? video.durationSeconds
        : (video.durationValue.inSeconds > 0 ? video.durationValue.inSeconds : 60);
    final tierObj = DubbingProductionTier.fromId(dubbingTier);
    final isEffectiveCinema = isCinemaGrade || tierObj.isCinemaGrade;
    final isEffectiveVoiceClone = voiceType != 'standard' &&
        (voiceType == 'cloned' ||
            voiceType == 'voice_clone' ||
            tierObj.isVoiceClone);

    final dubbingCost = ChannelWalletService.calculateProductionTierCost(
      tierId: dubbingTier,
      languageCount: targetLangs.length,
      durationSeconds: durationSecs,
      channel: chan,
    );

    final langDisplayNames = targetLangs.map(getLanguageName).join(', ');
    WalletTransaction? walletTx;
    if (dubbingCost > 0 && !isDirectlyPaid) {
      if (chan == null) {
        showError('Unable to verify channel revenue account. Please ensure you have a valid channel to proceed with AI audio dubbing.');
        return false;
      }
      final walletService = ChannelWalletService();
      final balance = await walletService.getSpendableBalanceForChannelId(chan.id);
      if (!balance.canAfford(dubbingCost)) {
        final rate = ChannelWalletService.getFlatRateForTier(
          durationSeconds: durationSecs,
          tierId: dubbingTier,
        );
        showError(
          '${tierObj.name} dubbing is not free. Channel revenue of \$${balance.totalSpendableBalance.toStringAsFixed(2)} is insufficient for the flat cost of \$${dubbingCost.toStringAsFixed(2)} (\$${rate.toStringAsFixed(2)}/lang for ${durationSecs}s video). Please pay directly to proceed.',
        );
        return false;
      }

      final dubLabel = '${tierObj.name} Dubbing';
      walletTx = await walletService.spendBalance(
        channel: chan,
        userId: user.uid,
        amount: dubbingCost,
        category: WalletTransactionCategory.aiDubbing,
        description: '$dubLabel for "${video.title}" ($langDisplayNames)',
        metadata: {
          'videoId': video.id,
          'targetLanguage': targetLangs.first,
          'targetLanguages': targetLangs,
          'durationSeconds': durationSecs,
          'voiceType': tierObj.ttsEngine,
          'dubbingTier': dubbingTier,
          'costUSD': dubbingCost,
          'isVoiceClone': isEffectiveVoiceClone,
          'isCinemaGrade': isEffectiveCinema,
          'paidFromRevenue': true,
        },
      );

      if (walletTx == null) {
        showError('Unable to deduct audio dubbing payment from channel revenue. Please ensure your account has sufficient funds.');
        return false;
      }
    }

    final startedAt = DateTime.now();
    for (final langCode in targetLangs) {
      generatingDubLanguages.add(langCode);
      _globalActiveDubbingJobs.putIfAbsent(video.id, () => {}).add(langCode);
      _notifiedDubLanguages.remove('${video.id}_$langCode');

      final initialProgress = AudioDubbingProgressState(
        langCode: langCode,
        startedAt: startedAt,
      );
      dubbingProgress[langCode] = initialProgress;
      _globalDubbingProgress.putIfAbsent(video.id, () => {})[langCode] =
          initialProgress;

      if (!availableLanguages.contains(langCode)) {
        availableLanguages.add(langCode);
      }

      var foundTrack = false;
      for (final track in currentTracks) {
        if (track.languageCode == langCode) {
          track.status = 'Generating...';
          foundTrack = true;
        }
      }
      if (!foundTrack) {
        currentTracks.add(
          AudioTrackItem(
            id: '${video.id}_$langCode',
            languageCode: langCode,
            languageName: getLanguageName(langCode),
            audioUrl: '',
            status: 'Generating...',
          ),
        );
      }
    }
    currentTracks.refresh();
    _startProgressTicker();

    final payloadJson = jsonEncode({
      'videoId': video.id,
      'channelId': targetChanId,
      'isDubbingFree': chan?.isDubbingFree ?? (dubbingCost == 0),
      'features': [
        'dubbing',
        if (enableDiarization || isEffectiveCinema) 'diarization',
      ],
      'targetLanguages': targetLangs,
      'priorityMode': priorityMode,
      'voiceGender': voiceGender,
      'durationSeconds': durationSecs,
      'autoChapters': false,
      'dubbingMode': isEffectiveVoiceClone ? 'voice_clone' : 'standard',
      'dubbingTier': dubbingTier,
      'cinemaGrade': isEffectiveCinema,
      'isCinemaGrade': isEffectiveCinema,
      'stemIsolation': true,
      if (walletTx != null) 'walletTransactionId': walletTx.id,
      if (dubbingCost > 0) 'paidFromRevenue': true,
      if (isDirectlyPaid) 'paidDirectly': true,
    });

    Future<http.Response> sendTriggerRequest({required bool forceRefresh}) async {
      final token = await user.getIdToken(forceRefresh);
      final url = Uri.parse(
        '${AppConfig.cloudFunctionsBaseUrl}/triggerVideoAIFeatures',
      );
      return http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: payloadJson,
          )
          .timeout(const Duration(seconds: 35));
    }

    void rollbackOptimisticLanguages() {
      for (final langCode in targetLangs) {
        generatingDubLanguages.remove(langCode);
        dubbingProgress.remove(langCode);
        _globalActiveDubbingJobs[video.id]?.remove(langCode);
        _globalDubbingProgress[video.id]?.remove(langCode);
        for (final track in currentTracks) {
          if (track.languageCode == langCode && track.audioUrl.isEmpty) {
            track.status = 'Not added';
          }
        }
      }
      currentTracks.refresh();
    }

    Future<void> markTriggeredSuccess() async {
      if (walletTx != null) {
        await FirebaseFirestore.instance.collection(FirestoreCollections.videos).doc(video.id).set({
          'dubbingPaid': true,
          'dubbingCostUSD': dubbingCost,
          'dubbingDurationSeconds': durationSecs,
          'voiceGender': voiceGender,
          'dubbingWalletTxId': walletTx.id,
          'dubbingTier': dubbingTier,
          'cinemaGrade': isEffectiveCinema,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Proactively reset video_jobs stages for the target languages so listeners never observe stale failures
      try {
        final jobRef = FirebaseFirestore.instance.collection('video_jobs').doc(video.id);
        final stageUpdates = <String, dynamic>{
          'status': 'processing',
          'updatedAt': FieldValue.serverTimestamp(),
        };
        for (final lang in targetLangs) {
          stageUpdates['stages.dubbing_$lang'] = {
            'status': 'pending',
            'progress': 0,
            'startedAt': startedAt.millisecondsSinceEpoch,
          };
          stageUpdates['stages.translating_$lang'] = {
            'status': 'pending',
            'progress': 0,
            'startedAt': startedAt.millisecondsSinceEpoch,
          };
        }
        await jobRef.set(stageUpdates, SetOptions(merge: true));
      } catch (jobErr) {
        logger.warning('Failed to pre-reset video_jobs stages: $jobErr', tag: _tag);
      }

      final summary = targetLangs.length == 1
          ? getLanguageName(targetLangs.first)
          : '${targetLangs.length} languages ($langDisplayNames)';
      showSuccess(
        '${tierObj.name} dubbing initiated for $summary. Processing in the background.',
      );
      _listenToDubbingJob(
        video.id,
        targetLangs.length == 1 ? targetLangs.first : null,
      );
    }

    try {
      var pipelineTriggered = false;
      String? friendlyErrorMessage;

      void parseResponseError(http.Response res) {
        String? backendMsg;
        try {
          final parsed = jsonDecode(res.body);
          if (parsed is Map && parsed['error'] is String) {
            backendMsg = parsed['error'] as String;
          }
        } catch (_) {}

        if (res.statusCode == 409) {
          friendlyErrorMessage = backendMsg ??
              'AI dubbing is already in progress for this video. Please wait a moment for completion.';
        } else if (res.statusCode == 402) {
          friendlyErrorMessage = backendMsg ??
              'Channel wallet has insufficient funds for audio dubbing. Please add funds to proceed.';
        } else if (res.statusCode == 429) {
          friendlyErrorMessage = backendMsg ??
              'Too many AI jobs are currently processing for your channel. Please try again shortly.';
        } else if (res.statusCode == 403) {
          friendlyErrorMessage = backendMsg ??
              'You do not have authorization to generate dubbed audio tracks for this video.';
        } else if (res.statusCode == 400) {
          friendlyErrorMessage = backendMsg ??
              'Invalid video settings for AI dubbing. Please verify your video details.';
        }
      }

      try {
        final response = await sendTriggerRequest(forceRefresh: false);
        if (response.statusCode == 200) {
          pipelineTriggered = true;
          await markTriggeredSuccess();
          return true;
        } else {
          logger.warning(
            'triggerVideoAIFeatures returned HTTP ${response.statusCode}: ${response.body}',
            tag: _tag,
          );
          parseResponseError(response);
        }
      } catch (httpError) {
        logger.warning(
          'triggerVideoAIFeatures HTTP failed, using retry fallback: $httpError',
          tag: _tag,
        );
      }

      // If non-200 was a deterministic client/business error (400, 402, 403, 409, 429),
      // do not blindly retry or fallback; inform user with actionable standard English.
      if (!pipelineTriggered && friendlyErrorMessage != null) {
        rollbackOptimisticLanguages();
        showError(friendlyErrorMessage!);
        return false;
      }

      // If HTTP timed out or failed with transient 5xx, retry with fresh ID token
      if (!pipelineTriggered) {
        try {
          final retryResponse = await sendTriggerRequest(forceRefresh: true);
          if (retryResponse.statusCode == 200) {
            pipelineTriggered = true;
            await markTriggeredSuccess();
            return true;
          } else {
            logger.warning(
              'triggerVideoAIFeatures retry returned HTTP ${retryResponse.statusCode}: ${retryResponse.body}',
              tag: _tag,
            );
            parseResponseError(retryResponse);
            if (friendlyErrorMessage != null) {
              rollbackOptimisticLanguages();
              showError(friendlyErrorMessage!);
              return false;
            }
          }
        } catch (_) {}
      }

      // 🛡️ Industry Standard Fault-Tolerant Fallback:
      // When Cloud Functions HTTP endpoint experiences high network latency or cold-start timeouts,
      // update Firestore documents directly so the serverless onVideoPublished Firestore trigger
      // (Scenario B: languagesChanged) automatically dispatches dubbing-processing via Pub/Sub.
      if (!pipelineTriggered) {
        try {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final firestore = FirebaseFirestore.instance;

          // 1. Direct write to videos/{video.id} to trigger onVideoPublished (Scenario B: languagesChanged)
          await firestore.collection(FirestoreCollections.videos).doc(video.id).set({
            'aiFeatures': {
              'generateDubbing': true,
              'dubbingLanguages': FieldValue.arrayUnion(targetLangs),
              'translationLanguages': FieldValue.arrayUnion(targetLangs),
              'dubbingTier': dubbingTier,
              'voiceGender': voiceGender,
              'dubbingMode': isEffectiveVoiceClone ? 'voice_clone' : 'standard',
            },
            if (walletTx != null) 'dubbingPaid': true,
            if (walletTx != null) 'dubbingWalletTxId': walletTx.id,
            if (walletTx != null) 'dubbingCostUSD': dubbingCost,
            if (walletTx != null) 'dubbingDurationSeconds': durationSecs,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // 2. Direct write to canonical video_jobs/{video.id}
          final stageUpdates = <String, dynamic>{
            'dubbing': {'status': 'pending', 'progress': 0, 'startedAt': nowMs},
            'onDemandAI': {
              'status': 'running',
              'progress': 10,
              'requestedFeatures': ['dubbing'],
              'requestedLanguages': targetLangs,
              'startedAt': nowMs,
            },
          };
          for (final lang in targetLangs) {
            stageUpdates['dubbing_$lang'] = {
              'status': 'pending',
              'progress': 0,
              'startedAt': nowMs,
            };
          }

          await firestore.collection(FirestoreCollections.videoJobs).doc(video.id).set({
            'jobId': video.id,
            'videoId': video.id,
            'userId': user.uid,
            'channelId': targetChanId,
            'videoUrl': video.videoUrl,
            'fileName': video.title,
            'status': 'processing',
            'paidFromWallet': walletTx != null,
            'walletTransactionId': walletTx?.id,
            'dubbingTier': dubbingTier,
            'durationSeconds': durationSecs,
            'executionPlan': {
              'jobId': video.id,
              'videoId': video.id,
              'primaryLanguage': video.language.isNotEmpty ? video.language : 'en',
              'languages': targetLangs,
              'dubbingLanguages': targetLangs,
              'enableDubbing': true,
              'generateDubbing': true,
              'dubbingTier': dubbingTier,
              'dubbingMode': isEffectiveVoiceClone ? 'voice_clone' : 'standard',
              'voiceGender': voiceGender,
              'cinemaGrade': isEffectiveCinema,
              'stemIsolation': true,
              'durationSeconds': durationSecs,
            },
            'stages': stageUpdates,
            'createdAt': nowMs,
            'updatedAt': nowMs,
          }, SetOptions(merge: true));

          pipelineTriggered = true;
          await markTriggeredSuccess();
          return true;
        } catch (fsErr) {
          logger.error('Direct Firestore dubbing trigger fallback failed: $fsErr', tag: _tag);
        }
      }

      if (!pipelineTriggered) {
        rollbackOptimisticLanguages();
        showError(
          friendlyErrorMessage ??
              'Unable to initiate AI dubbing service. Please check your internet connection and try again.',
        );
        return false;
      }
    } catch (e) {
      logger.error('Error initiating AI dubbing for $targetLangs', error: e, tag: _tag);
      rollbackOptimisticLanguages();
      showError('Unable to start AI dubbing. Please try again.');
      return false;
    }
    return true;
  }

  void _listenToDubbingJob(String videoId, [String? specificLangCode]) {
    _aiDubbingJobSub?.cancel();
    _videoJobFallbackSub?.cancel();
    _videoDocSub?.cancel();
    _locDocSub?.cancel();

    void checkAndCompleteTrack(String lang, String? url) {
      if (url != null && url.isNotEmpty && generatingDubLanguages.contains(lang)) {
        _markLanguageDubCompleted(videoId, lang, url);
        currentTracks.refresh();
        unawaited(refreshVideoLocalization(videoId));
        final notifKey = '${videoId}_$lang';
        if (!_notifiedDubLanguages.contains(notifKey)) {
          _notifiedDubLanguages.add(notifKey);
          showSuccess('${getLanguageName(lang)} dubbed audio track is ready!');
        }
      }
    }

    // 1. Direct real-time listener on the video document for instant progressive audio delivery
    _videoDocSub = FirebaseFirestore.instance
        .collection(FirestoreCollections.videos)
        .doc(videoId)
        .snapshots()
        .listen((videoSnap) async {
      if (!videoSnap.exists || videoSnap.data() == null) return;
      final videoData = videoSnap.data()!;
      final audioTracksMap = (videoData['audioTracks'] as Map<String, dynamic>?) ??
          ((videoData['media'] as Map<String, dynamic>?)?['audioTracks'] as Map<String, dynamic>?) ??
          {};

      for (final lang in generatingDubLanguages.toList()) {
        final url = (audioTracksMap[lang] as String?) ??
            (videoData['audioTracks.$lang'] as String?) ??
            (videoData['media.audioTracks.$lang'] as String?);
        checkAndCompleteTrack(lang, url);
      }
    }, onError: (e) {
      logger.warning('Error listening to video doc audio tracks: $e', tag: _tag);
    });

    // 1b. Real-time listener on video media/localization subcollection
    _locDocSub = FirebaseFirestore.instance
        .collection(FirestoreCollections.videos)
        .doc(videoId)
        .collection('media')
        .doc('localization')
        .snapshots()
        .listen((locSnap) {
      if (!locSnap.exists || locSnap.data() == null) return;
      final locData = locSnap.data()!;
      final audioMap = (locData['audioTracks'] as Map<String, dynamic>?) ?? {};

      for (final lang in generatingDubLanguages.toList()) {
        final url = (audioMap[lang] as String?) ??
            (locData['audioTracks.$lang'] as String?);
        checkAndCompleteTrack(lang, url);
      }
    }, onError: (e) {
      logger.warning('Error listening to localization audio tracks: $e', tag: _tag);
    });

    final v = selectedVideo.value;
    final resolvedJobId = (v?.jobId?.isNotEmpty == true) ? v!.jobId! : videoId;

    // 2. Real-time listener on video_jobs pipeline execution state
    Future<void> handleJobSnapshot(DocumentSnapshot snap) async {
      if (!snap.exists || snap.data() == null) return;
      final data = snap.data()! as Map<String, dynamic>;
      final jobStatus = (data['status'] as String?)?.toLowerCase();
      final stages = (data['stages'] as Map<String, dynamic>?) ?? {};
      final onDemand = stages['onDemandAI'] as Map<String, dynamic>?;
      final dubbing = stages['dubbing'] as Map<String, dynamic>?;
      final outputs = (data['outputs'] as Map<String, dynamic>?) ?? {};
      final outputAudioTracks =
          (outputs['audioTracks'] as Map<String, dynamic>?) ?? {};

      final onDemandStatus = (onDemand?['status'] as String?)?.toLowerCase();
      final dubStatus = (dubbing?['status'] as String?)?.toLowerCase();

      final executionPlan =
          (data['executionPlan'] as Map<String, dynamic>?) ?? {};
      final planDubLangs = (executionPlan['dubbingLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (executionPlan['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final onDemandLangs = (onDemand?['requestedLanguages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      final allJobLangs = <String>{
        ...planDubLangs,
        ...onDemandLangs,
        ...?specificLangCode == null ? null : [specificLangCode],
        ...generatingDubLanguages,
        ...(_globalActiveDubbingJobs[videoId] ?? {}),
      };

      for (final stageKey in stages.keys) {
        if (stageKey.startsWith('translating_')) {
          allJobLangs.add(stageKey.replaceFirst('translating_', ''));
        } else if (stageKey.startsWith('dubbing_')) {
          allJobLangs.add(stageKey.replaceFirst('dubbing_', ''));
        }
      }

      final currentVideo = selectedVideo.value;
      final baseLang = currentVideo?.language.toLowerCase().trim() ?? 'en';
      final newlyCompletedGeneratingLangs = <String>{};

      for (final lang in allJobLangs) {
        final cleanLang = lang.trim().toLowerCase();
        if (cleanLang.isEmpty || cleanLang == baseLang) continue;

        final transStage = stages['translating_$lang'] as Map<String, dynamic>?;
        final dubStage = stages['dubbing_$lang'] as Map<String, dynamic>?;

        final hasAudioUrlInOutput = (outputAudioTracks.containsKey(lang) &&
                (outputAudioTracks[lang] as String? ?? '').isNotEmpty) ||
            ((data['outputs.audioTracks.$lang'] as String? ?? '').isNotEmpty) ||
            ((data['audioTracks.$lang'] as String? ?? '').isNotEmpty) ||
            ((data['audioTracks'] as Map<String, dynamic>?)?[lang] as String? ?? '')
                .isNotEmpty ||
            (((stages['dubbing_$lang'] as Map<String, dynamic>?)?['audioUrl'] as String? ?? '').isNotEmpty);
        final hasAudioInVideo = ((currentVideo?.audioTracks.containsKey(lang) ?? false) &&
                (currentVideo?.audioTracks[lang] ?? '').isNotEmpty) ||
            (VideoMediaService.localizationCache[videoId]?.audioTracks[lang] ?? '')
                .isNotEmpty;

        final hasAudio = hasAudioUrlInOutput || hasAudioInVideo;

        final isDubStageCompleted = (dubStage?['status'] == 'completed' ||
            (dubStage?['progress'] as num?) == 100) && hasAudio;
        final isOverallCompleted = (dubStatus == 'completed' ||
            onDemandStatus == 'completed' ||
            jobStatus == 'completed') && hasAudio;

        final isCompleted = isDubStageCompleted ||
            isOverallCompleted ||
            hasAudio;

        final currentProgress = dubbingProgress[lang] ??
            _globalDubbingProgress[videoId]?[lang];
        final startedAtMs = currentProgress?.startedAt?.millisecondsSinceEpoch ?? 0;

        int getStageTimestampMs(Map<String, dynamic>? stage) {
          if (stage == null) return 0;
          final completedAt = stage['completedAt'];
          if (completedAt is num) return completedAt.toInt();
          if (completedAt is Timestamp) return completedAt.millisecondsSinceEpoch;
          final failedAt = stage['failedAt'];
          if (failedAt is num) return failedAt.toInt();
          if (failedAt is Timestamp) return failedAt.millisecondsSinceEpoch;
          final updatedAt = stage['updatedAt'];
          if (updatedAt is num) return updatedAt.toInt();
          if (updatedAt is Timestamp) return updatedAt.millisecondsSinceEpoch;
          final startedAt = stage['startedAt'];
          if (startedAt is num) return startedAt.toInt();
          if (startedAt is Timestamp) return startedAt.millisecondsSinceEpoch;
          return 0;
        }

        final dubStageTimestamp = getStageTimestampMs(dubStage);
        final transStageTimestamp = getStageTimestampMs(transStage);
        final jobTimestamp = getStageTimestampMs(data);

        final effectiveDubTime = dubStageTimestamp > 0 ? dubStageTimestamp : jobTimestamp;
        final effectiveTransTime = transStageTimestamp > 0 ? transStageTimestamp : jobTimestamp;

        final isStaleDubFailure = dubStage?['status'] == 'failed' &&
            startedAtMs > 0 &&
            effectiveDubTime > 0 &&
            effectiveDubTime < startedAtMs;
        final isStaleTransFailure = transStage?['status'] == 'failed' &&
            startedAtMs > 0 &&
            effectiveTransTime > 0 &&
            effectiveTransTime < startedAtMs;
        final isStaleJobFailure = jobStatus == 'failed' &&
            startedAtMs > 0 &&
            jobTimestamp > 0 &&
            jobTimestamp < startedAtMs;

        final isDubFailed = dubStage?['status'] == 'failed' && !isStaleDubFailure;
        final isTransFailed = transStage?['status'] == 'failed' && !isStaleTransFailure;
        final isJobFailed = jobStatus == 'failed' && !isCompleted && !isStaleJobFailure;

        final isZombie = _isJobZombie(data, dubStage ?? onDemand) &&
            (startedAtMs == 0 || effectiveDubTime <= 0 || effectiveDubTime >= startedAtMs);

        final isFailed = isDubFailed ||
            isTransFailed ||
            isJobFailed ||
            (isZombie && !isCompleted);

        final wasGenerating = generatingDubLanguages.contains(lang) ||
            (_globalActiveDubbingJobs[videoId]?.contains(lang) ?? false);

        if (isCompleted) {
          final newUrl = (outputAudioTracks[lang] as String?) ??
              (data['outputs.audioTracks.$lang'] as String?) ??
              ((data['audioTracks'] as Map<String, dynamic>?)?[lang] as String?) ??
              (data['audioTracks.$lang'] as String?) ??
              ((stages['dubbing_$lang'] as Map<String, dynamic>?)?['audioUrl'] as String?) ??
              (dubStage?['audioUrl'] as String?) ??
              currentVideo?.audioTracks[lang] ??
              VideoMediaService.localizationCache[videoId]?.audioTracks[lang] ??
              '';

          _markLanguageDubCompleted(videoId, lang, newUrl);

          final notifKey = '${videoId}_$lang';
          if (wasGenerating && !_notifiedDubLanguages.contains(notifKey)) {
            _notifiedDubLanguages.add(notifKey);
            newlyCompletedGeneratingLangs.add(lang);
          }
        } else if (isFailed) {
          generatingDubLanguages.remove(lang);
          dubbingProgress.remove(lang);
          _globalActiveDubbingJobs[videoId]?.remove(lang);
          _globalDubbingProgress[videoId]?.remove(lang);

          for (final track in currentTracks) {
            if (track.languageCode == lang && track.audioUrl.isEmpty) {
              track.status = 'Not added';
            }
          }
          currentTracks.refresh();
          if (!isZombie && wasGenerating) {
            showError(
              'AI Voice Dubbing for ${getLanguageName(lang)} encountered an issue. Please try again.',
            );
          }
        } else {
          // If this stage is a zombie (> 5 mins old), NEVER resurrect it into generating status!
          if (isZombie) {
            continue;
          }

          final transStatus =
              (transStage?['status'] as String?)?.toLowerCase();
          final singleDubStatus =
              (dubStage?['status'] as String?)?.toLowerCase();

          final isActivelyRunning = singleDubStatus == 'running' ||
              singleDubStatus == 'queued' ||
              singleDubStatus == 'pending' ||
              singleDubStatus == 'processing' ||
              transStatus == 'running' ||
              transStatus == 'queued' ||
              transStatus == 'pending' ||
              transStatus == 'processing' ||
              dubStatus == 'running' ||
              dubStatus == 'pending' ||
              dubStatus == 'processing' ||
              wasGenerating;

          if (!isActivelyRunning) {
            continue;
          }

          // Actively generating or queued!
          generatingDubLanguages.add(lang);
          _globalActiveDubbingJobs.putIfAbsent(videoId, () => {}).add(lang);

          var calculatedProgress = 15;
          var stageTitle = 'Analyzing audio & transcribing dialogue';
          var stageStep = 1;
          var eta = '~1-2 min';

          final onDemandProg = onDemand?['progress'] as num?;
          final dubProg = dubStage?['progress'] as num?;
          final transProg = transStage?['progress'] as num?;

          // Read real cloud progress directly if available
          if (dubProg != null && dubProg > 0) {
            calculatedProgress = dubProg.toInt();
          } else if (singleDubStatus == 'running' ||
              (transStatus == 'completed' && singleDubStatus != 'failed')) {
            final p = dubProg?.toInt() ?? 25;
            calculatedProgress = 60 + (p * 0.3).toInt().clamp(0, 30);
          } else if (transStatus == 'running' ||
              (onDemandStatus == 'running' && (onDemandProg ?? 0) >= 30)) {
            final p = transProg?.toInt() ?? (onDemandProg?.toInt() ?? 25);
            calculatedProgress = 30 + (p * 0.3).toInt().clamp(0, 30);
          } else {
            calculatedProgress = (onDemandProg?.toInt() ?? 15).clamp(10, 30);
          }

          final existingProgress = dubbingProgress[lang]?.progress ?? 0;
          if (calculatedProgress < existingProgress) {
            calculatedProgress = existingProgress;
          }

          // Strict alignment of Step and Title to calculatedProgress:
          if (calculatedProgress >= 85) {
            stageStep = 4;
            stageTitle = 'Mastering audio ducking & synchronization';
            eta = calculatedProgress >= 95 ? 'Syncing cloud tracks...' : 'Finalizing shortly';
          } else if (calculatedProgress >= 55) {
            stageStep = 3;
            stageTitle = 'Synthesizing AI voice in ${getLanguageName(lang)}';
            eta = '~10-15 sec';
          } else if (calculatedProgress >= 28) {
            stageStep = 2;
            stageTitle = 'Translating speech to ${getLanguageName(lang)}';
            eta = '~15-20 sec';
          } else {
            stageStep = 1;
            stageTitle = 'Analyzing audio & transcribing dialogue';
            eta = '~20-30 sec';
          }

          final progressState = AudioDubbingProgressState(
            langCode: lang,
            progress: calculatedProgress,
            stageTitle: stageTitle,
            stageStep: stageStep,
            totalStepsText: 'Step $stageStep of 4',
            etaText: eta,
          );

          dubbingProgress[lang] = progressState;
          _globalDubbingProgress
              .putIfAbsent(videoId, () => {})[lang] = progressState;

          if (!availableLanguages.contains(lang)) {
            availableLanguages.add(lang);
          }

          var exists = false;
          for (final track in currentTracks) {
            if (track.languageCode == lang) {
              track.status = 'Generating...';
              exists = true;
            }
          }
          if (!exists) {
            currentTracks.add(
              AudioTrackItem(
                id: '${videoId}_$lang',
                languageCode: lang,
                languageName: getLanguageName(lang),
                audioUrl: '',
                status: 'Generating...',
              ),
            );
          }
          currentTracks.refresh();
          _startProgressTicker();
        }
      }

      if (newlyCompletedGeneratingLangs.isNotEmpty) {
        currentTracks.refresh();
        await refreshVideoLocalization(videoId);
        for (final l in newlyCompletedGeneratingLangs) {
          showSuccess('${getLanguageName(l)} dubbed audio track is ready!');
        }
      }
    }

    _aiDubbingJobSub = FirebaseFirestore.instance
        .collection('video_jobs')
        .doc(resolvedJobId)
        .snapshots()
        .listen(handleJobSnapshot, onError: (e) {
      logger.warning('Error listening to dubbing job ($resolvedJobId): $e', tag: _tag);
    });

    if (resolvedJobId != videoId) {
      _videoJobFallbackSub = FirebaseFirestore.instance
          .collection('video_jobs')
          .doc(videoId)
          .snapshots()
          .listen(handleJobSnapshot, onError: (e) {
        logger.warning('Error listening to fallback video job ($videoId): $e', tag: _tag);
      });
    }
  }

  /// Refreshes video localization data and reloads audio tracks in-place without re-invoking selectVideo.
  Future<void> refreshVideoLocalization(String videoId) async {
    VideoMediaService().clearCache(videoId);
    final doc = await FirebaseFirestore.instance
        .collection(FirestoreCollections.videos)
        .doc(videoId)
        .get();
    if (!doc.exists || doc.data() == null) return;

    final updatedVideo = Video.fromDocumentSnapshot(doc);
    final localization = await VideoMediaService().getLocalization(
      videoId,
      forceRefresh: true,
    );

    // Extract commentary items
    final commentaryList = <CommentaryTrackItem>[];
    localization.commentaryVideos.forEach((key, map) {
      commentaryList.add(CommentaryTrackItem.fromMap(key, map));
    });
    _editorManager.commentaryTracks.value = commentaryList;

    // Extract and merge audio tracks
    final audioMap = Map<String, String>.from(updatedVideo.audioTracks)
      ..addAll(localization.audioTracks);
    final langs = audioMap.keys.toList();
    final baseLang = updatedVideo.language.isNotEmpty ? updatedVideo.language : 'en';
    if (!langs.contains(baseLang)) {
      langs.insert(0, baseLang);
    }

    // Keep generating languages in availableLanguages so they remain visible
    for (final genLang in generatingDubLanguages.toList()) {
      if (audioMap.containsKey(genLang) &&
          (audioMap[genLang] ?? '').trim().isNotEmpty) {
        generatingDubLanguages.remove(genLang);
        dubbingProgress.remove(genLang);
        _globalActiveDubbingJobs[videoId]?.remove(genLang);
        _globalDubbingProgress[videoId]?.remove(genLang);
      } else if (!langs.contains(genLang)) {
        langs.add(genLang);
      }
    }

    _languageManager.availableLanguages.value = langs;
    if (!langs.contains(_languageManager.selectedLanguage.value)) {
      _languageManager.selectedLanguage.value = langs.isNotEmpty ? langs.first : baseLang;
    }

    selectedVideo.value = updatedVideo.copyWith(audioTracks: audioMap);

    await _editorManager.parseAllAudioTracks(
      video: selectedVideo.value!,
      availableLanguages: langs,
      entireAudioMap: audioMap,
      generatingLanguages: generatingDubLanguages,
      languageNameResolver: getLanguageName,
    );
    syncCurrentVideoTracks();
    selectedVideo.refresh();
    currentTracks.refresh();

    if (generatingDubLanguages.isEmpty) {
      _progressTickerTimer?.cancel();
      _progressTickerTimer = null;
    }
  }

  /// Downloads original video audio track to serve as reference in external DAW / studio.
  Future<void> downloadOriginalVideoAudio() async {
    final video = selectedVideo.value;
    if (video == null) {
      showError('No video selected.');
      return;
    }
    final rawBase = video.language.isNotEmpty ? video.language : 'en';
    final baseLabel = getLanguageName(rawBase);
    final cleanTitle = StudioMediaDownloadService.getCleanTitle(video);

    await StudioMediaDownloadService.downloadAudioTrack(
      video: video,
      langCode: rawBase,
      langLabel: baseLabel.isNotEmpty ? baseLabel : 'Original',
      cleanTitle: cleanTitle,
      tracksController: this,
    );
  }

  /// Proactively forces a fresh Firestore check across all collections and resolves dubbing state.
  Future<void> checkDubbingStatus([String? specificLang]) async {
    final vId = selectedVideo.value?.id;
    if (vId == null) {
      showError('Please select a video first.');
      return;
    }

    final targetLangs = specificLang != null ? [specificLang] : generatingDubLanguages.toList();
    if (targetLangs.isEmpty) {
      AppSnackbar.info('No active generation jobs for this video.');
      return;
    }

    var resolvedAny = false;
    VideoMediaService().clearCache(vId);
    final loc = await VideoMediaService().getLocalization(vId, forceRefresh: true);

    // Also check direct video document
    final vDoc = await FirebaseFirestore.instance.collection(FirestoreCollections.videos).doc(vId).get();
    final vData = vDoc.data() ?? {};
    final vAudioMap = (vData['audioTracks'] as Map<String, dynamic>?) ?? {};

    // Also check video_jobs
    final jobDoc = await FirebaseFirestore.instance.collection('video_jobs').doc(vId).get();
    final jobData = jobDoc.data() ?? {};
    final jobOutputs = (jobData['outputs'] as Map<String, dynamic>?) ?? {};
    final jobAudioTracks = (jobOutputs['audioTracks'] as Map<String, dynamic>?) ?? {};
    final stages = (jobData['stages'] as Map<String, dynamic>?) ?? {};

    for (final lang in targetLangs) {
      var foundUrl = loc.audioTracks[lang] ?? '';
      if (foundUrl.isEmpty) {
        foundUrl = (vAudioMap[lang] as String?) ??
            (vData['audioTracks.$lang'] as String?) ??
            (vData['media.audioTracks.$lang'] as String?) ??
            '';
      }
      if (foundUrl.isEmpty) {
        foundUrl = (jobAudioTracks[lang] as String?) ??
            (jobData['outputs.audioTracks.$lang'] as String?) ??
            ((stages['dubbing_$lang'] as Map<String, dynamic>?)?['audioUrl'] as String?) ??
            '';
      }

      if (foundUrl.isNotEmpty) {
        _markLanguageDubCompleted(vId, lang, foundUrl);
        resolvedAny = true;
        final notifKey = '${vId}_$lang';
        if (!_notifiedDubLanguages.contains(notifKey)) {
          _notifiedDubLanguages.add(notifKey);
          showSuccess('${getLanguageName(lang)} dubbed audio track is ready!');
        }
      } else {
        final dubStage = stages['dubbing_$lang'] as Map<String, dynamic>?;
        if (dubStage?['status'] == 'failed' || jobData['status'] == 'failed') {
          generatingDubLanguages.remove(lang);
          dubbingProgress.remove(lang);
          _globalActiveDubbingJobs[vId]?.remove(lang);
          _globalDubbingProgress[vId]?.remove(lang);
          for (final track in currentTracks) {
            if (track.languageCode == lang && track.audioUrl.isEmpty) {
              track.status = 'Not added';
            }
          }
          currentTracks.refresh();
          showError('AI Dubbing for ${getLanguageName(lang)} encountered an issue. You can retry.');
          return;
        }
      }
    }

    if (resolvedAny) {
      currentTracks.refresh();
      await refreshVideoLocalization(vId);
    } else {
      AppSnackbar.info('Dubbing is actively processing in the cloud. We will notify you once complete.');
    }
  }

  /// Cancels generation tracking for a language and resets its track state to 'Not added'.
  void cancelDubbing(String langCode) {
    final vId = selectedVideo.value?.id;
    generatingDubLanguages.remove(langCode);
    dubbingProgress.remove(langCode);
    if (vId != null) {
      _globalActiveDubbingJobs[vId]?.remove(langCode);
      _globalDubbingProgress[vId]?.remove(langCode);
    }
    for (final track in currentTracks) {
      if (track.languageCode == langCode && track.audioUrl.isEmpty) {
        track.status = 'Not added';
      }
    }
    for (final track in currentVideoTracks) {
      if (track.languageCode == langCode && track.videoUrl.isEmpty) {
        track.status = 'Not added';
      }
    }
    currentTracks.refresh();
    currentVideoTracks.refresh();
    AppSnackbar.info('Dubbing generation for ${getLanguageName(langCode)} was canceled.');
  }

  /// Retries AI Dubbing for a target language.
  Future<void> retryDubbing(String langCode) async {
    cancelDubbing(langCode);
    final vId = selectedVideo.value?.id;
    if (vId != null) {
      _notifiedDubLanguages.remove('${vId}_$langCode');
    }
    await triggerAIDubbingForLanguage(langCode: langCode);
  }

  String getLanguageName(String code) {
    final clean = code.trim().toLowerCase();
    if (_languageManager.customLanguages.containsKey(clean)) {
      return _languageManager.customLanguages[clean]!;
    }
    return getSupportedLanguageName(code);
  }
}
