import 'dart:async';
import 'dart:io' as io;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:truthworld/core/constants/ai_languages.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/services/dubbing_quote_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/download_helper.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/utils/web_platform_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dubbing/data/dubbing_service.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_job.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_language.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_project.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_wallet.dart';
import 'package:truthworld/features/dubbing/presentation/views/components/dubbing_wallet_modal.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// GetX Controller orchestrating TruthWorld Standalone Dubbing Studio.
class DubbingStudioController extends GetxController {
  final DubbingService _service = DubbingService();
  final DubbingQuoteService _quoteService = DubbingQuoteService();

  // --- Real-Time Server Pricing State ---
  final Rxn<DubbingQuote> serverQuote = Rxn<DubbingQuote>();
  final RxBool isQuoteLoading = false.obs;
  int _quoteRequestId = 0;

  // --- Source Selection Mode ---
  /// 'channel_videos' (default for signed-in creators) or 'file_upload' (ad-hoc file ingest)
  final RxString sourceInputMode = 'channel_videos'.obs;

  // --- Channel & Channel Videos State ---
  final Rxn<Channel> userChannel = Rxn<Channel>();
  final RxList<Video> channelVideos = <Video>[].obs;
  final RxList<Video> filteredChannelVideos = <Video>[].obs;
  final Rxn<Video> selectedChannelVideo = Rxn<Video>();
  final RxBool isLoadingChannelVideos = false.obs;
  final RxString channelVideoSearchQuery = ''.obs;
  final RxMap<String, String> selectedVideoAudioTracks = <String, String>{}.obs;
  final RxBool isLoadingVideoTracks = false.obs;

  // --- Studio Configuration & State ---
  final Rx<DubbingMode> mode = DubbingMode.dubbing.obs;
  final RxString sourceLanguage = 'en'.obs;
  final RxList<String> targetLanguages = <String>[].obs;
  final RxString mediaUrl = ''.obs;
  final RxString mediaTitle = 'Untitled Project'.obs;
  final RxInt estimatedDurationSeconds = 60.obs;
  final RxInt estimatedCharacterCount = 1000.obs;

  // --- Persistent Projects State ---
  final RxList<DubbingProject> savedProjects = <DubbingProject>[].obs;
  final Rxn<DubbingProject> activeProject = Rxn<DubbingProject>();
  final RxList<DubbingJob> projectJobs = <DubbingJob>[].obs;
  final RxBool isLoadingProjects = false.obs;
  final RxBool isSavingProject = false.obs;
  final RxBool isEditingProjectTitle = false.obs;
  final RxBool showSourceEditor = false.obs;
  final TextEditingController createProjectTitleController = TextEditingController();
  final TextEditingController projectTitleEditController = TextEditingController();
  final TextEditingController hubSearchController = TextEditingController();
  Timer? _saveDebounceTimer;

  // --- Projects Hub Filter & View Mode ---
  /// 'all' | 'completed' | 'processing' | 'failed'
  final RxString hubFilterStatus = 'all'.obs;
  final RxString hubSearchQuery = ''.obs;
  final RxBool hubIsGridView = true.obs;
  RxMap<String, VideoPlayerController>? _hubFrameControllersBacking;
  RxMap<String, VideoPlayerController> get hubFrameControllers =>
      _hubFrameControllersBacking ??= <String, VideoPlayerController>{}.obs;

  Set<String>? _hubFrameLoadingUrlsBacking;
  Set<String> get _hubFrameLoadingUrls => _hubFrameLoadingUrlsBacking ??= <String>{};

  String? getProjectThumbnailUrl(DubbingProject project) {
    final vid = project.videoId;
    if (vid == null || vid.isEmpty) return null;
    final match = channelVideos.where((v) => v.id == vid).firstOrNull;
    final thumb = match?.thumbnailUrl.trim() ?? '';
    return thumb.isNotEmpty ? thumb : null;
  }

  void ensureHubVideoFrame(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty ||
        !trimmed.startsWith('http') ||
        hubFrameControllers.containsKey(trimmed) ||
        _hubFrameLoadingUrls.contains(trimmed) ||
        hubFrameControllers.length >= 12) {
      return;
    }
    _hubFrameLoadingUrls.add(trimmed);
    unawaited(_initHubVideoFrame(trimmed));
  }

  Future<void> _initHubVideoFrame(String url) async {
    VideoPlayerController? ctrl;
    try {
      ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      await ctrl.setVolume(0);
      if (ctrl.value.duration > const Duration(seconds: 1)) {
        await ctrl.seekTo(const Duration(milliseconds: 500));
      }
      await ctrl.pause();
      if (isClosed) {
        await ctrl.dispose();
        return;
      }
      hubFrameControllers[url] = ctrl;
    } catch (_) {
      try {
        await ctrl?.dispose();
      } catch (_) {}
    } finally {
      _hubFrameLoadingUrls.remove(url);
    }
  }

  List<DubbingProject> get filteredHubProjects {
    final status = hubFilterStatus.value;
    final query = hubSearchQuery.value.trim().toLowerCase();
    return savedProjects.where((p) {
      if (status != 'all' && p.latestStatus != status) return false;
      if (query.isEmpty) return true;
      if (p.title.toLowerCase().contains(query)) return true;
      if (p.pickedFileName.toLowerCase().contains(query)) return true;
      final langMatch = [
        ...p.dubbedLanguages,
        ...p.subtitledLanguages,
        ...p.targetLanguages,
      ].any((code) => DubbingLanguage.findByCode(code).name.toLowerCase().contains(query));
      return langMatch;
    }).toList(growable: false);
  }

  // --- Picked File & Upload State (Up to 2 Hours / 4GB) ---
  final Rxn<PlatformFile> pickedFile = Rxn<PlatformFile>();
  final RxString pickedFileName = ''.obs;
  final RxInt pickedFileSizeBytes = 0.obs;
  final RxBool isUploadingMedia = false.obs;
  final RxDouble uploadProgress = 0.0.obs;
  final RxString uploadStatus = ''.obs;
  final RxBool showManualUrlInput = false.obs;

  // --- Custom Controls ---
  final RxBool isolateVocals = true.obs;
  final RxBool preserveBgm = true.obs;
  final RxDouble bgmDuckingPercent = 25.0.obs;
  /// Voice cloning is never on by default: the creator turns it on and confirms consent.
  final RxBool voiceCloningEnabled = false.obs;
  final RxBool voiceCloneConsent = false.obs;
  final RxBool twoStageReviewEnabled = true.obs;
  final RxBool publishToTruthworld = false.obs;

  // --- Speaker Management ---
  final RxList<DubbingSpeaker> speakers = <DubbingSpeaker>[
    const DubbingSpeaker(
      id: 'speaker_1',
      label: 'Speaker 1 (Primary Host)',
      assignedVoiceId: 'voice_telugu_charan',
      isCloned: true,
    ),
  ].obs;

  // --- Active Job & Playback ---
  final Rxn<DubbingJob> activeJob = Rxn<DubbingJob>();
  final RxBool isSubmitting = false.obs;
  final RxBool isLoadingWallet = false.obs;
  final RxBool isRegeneratingLine = false.obs;
  final RxBool isExportingAssets = false.obs;
  final RxString activePreviewLanguage = ''.obs;
  final RxString activePlaybackTrack = 'original'.obs;
  final RxBool isDubbedAudioFallbackActive = false.obs;
  final RxInt playbackPositionMs = 0.obs;
  final RxInt totalDurationMs = 60000.obs;
  final RxDouble playbackSpeed = 1.0.obs;
  final RxBool isPlaying = false.obs;
  final RxBool isPlayerInitialized = false.obs;
  final RxBool isPlayerLoading = false.obs;
  final RxString playerError = ''.obs;
  VideoPlayerController? videoPlayerController;
  ja.AudioPlayer? _dubbedAudioPlayer;
  WebAudioPlayerAdapter? _webDubbedAudioPlayer;
  String? _activePreviewBlobUrl;
  String _loadedMediaUrl = '';
  String _loadedDubbedAudioUrl = '';

  // --- Wallet & Credits ---
  final Rxn<DubbingWallet> wallet = Rxn<DubbingWallet>();
  final RxBool isPurchasingCredits = false.obs;
  final RxInt selectedPurchaseTierUsd = 10.obs;

  /// Live spendable balance in the creator's TruthWorld Studio Channel Wallet.
  double get studioWalletSpendableBalance {
    final chan = userChannel.value;
    if (chan == null) return 0.0;
    try {
      final spendable = ChannelWalletService().getSpendableBalance(channel: chan);
      return spendable.totalSpendableBalance;
    } catch (_) {
      return chan.walletBalanceUSD;
    }
  }

  StreamSubscription<DubbingJob?>? _jobSub;
  final Set<String> _autoExportedJobIds = <String>{};
  final Set<String> _autoSwitchedJobIds = <String>{};
  Worker? _authWorker;
  Worker? _authStateWorker;
  Worker? _settingsWorker;

  @override
  void onInit() {
    super.onInit();
    refreshWallet();
    loadUserChannelAndVideos();
    loadSavedProjects();

    _settingsWorker = everAll(
      [
        isolateVocals,
        preserveBgm,
        bgmDuckingPercent,
        twoStageReviewEnabled,
        publishToTruthworld,
      ],
      (_) => scheduleProjectAutoSave(),
    );

    // Re-sync channel videos, projects, and wallet whenever user logs in or out
    if (Get.isRegistered<AuthService>()) {
      _authWorker = ever(AuthService.to.userDisplayName, (_) {
        refreshWallet();
        loadUserChannelAndVideos();
        loadSavedProjects();
      });
      _authStateWorker = ever(AuthService.to.isAuthenticated, (_) {
        refreshWallet();
        loadUserChannelAndVideos();
        loadSavedProjects();
      });
    }

    // Check if a specific video was passed in route navigation (deep link from Studio)
    final args = Get.arguments;
    if (args is Map) {
      if (args['video'] is Video) {
        final v = args['video'] as Video;
        unawaited(_openProjectForDeepLinkedVideo(v));
      } else if (args['videoId'] is String) {
        unawaited(_openProjectForDeepLinkedVideoId(args['videoId'] as String));
      } else if (args['project'] is DubbingProject) {
        unawaited(openProject(args['project'] as DubbingProject));
      }
    }
  }

  @override
  void onClose() {
    _saveDebounceTimer?.cancel();
    createProjectTitleController.dispose();
    projectTitleEditController.dispose();
    hubSearchController.dispose();
    _settingsWorker?.dispose();
    _authWorker?.dispose();
    _authStateWorker?.dispose();
    _jobSub?.cancel();
    if (_hubFrameControllersBacking != null) {
      for (final ctrl in _hubFrameControllersBacking!.values) {
        unawaited(ctrl.dispose());
      }
      _hubFrameControllersBacking!.clear();
    }
    _hubFrameLoadingUrlsBacking?.clear();
    disposePreviewPlayer();
    super.onClose();
  }

  // --- Video / Audio Preview Player ---

  Future<void> _disposeDubbedAudioPlayer() async {
    final oldAudioPlayer = _dubbedAudioPlayer;
    _dubbedAudioPlayer = null;
    final oldWebAudioPlayer = _webDubbedAudioPlayer;
    _webDubbedAudioPlayer = null;
    _loadedDubbedAudioUrl = '';
    isDubbedAudioFallbackActive.value = false;
    if (oldAudioPlayer != null) {
      try {
        await oldAudioPlayer.stop();
        await oldAudioPlayer.dispose();
      } catch (_) {}
    }
    if (oldWebAudioPlayer != null) {
      try {
        oldWebAudioPlayer.stop();
        oldWebAudioPlayer.dispose();
      } catch (_) {}
    }
  }

  Future<void> disposePreviewPlayer({bool preserveDubbedAudio = false}) async {
    if (!preserveDubbedAudio) {
      await _disposeDubbedAudioPlayer();
    }
    final oldCtrl = videoPlayerController;
    videoPlayerController = null;
    _loadedMediaUrl = '';
    isPlayerInitialized.value = false;
    isPlaying.value = false;
    playbackPositionMs.value = 0;
    playerError.value = '';
    if (oldCtrl != null) {
      oldCtrl.removeListener(_onPlayerTick);
      await oldCtrl.dispose();
    }
    if (_activePreviewBlobUrl != null && _activePreviewBlobUrl!.isNotEmpty) {
      WebPlatformUtils.revokeBlobUrl(_activePreviewBlobUrl!);
      _activePreviewBlobUrl = null;
    }
  }

  void _onPlayerTick() {
    final ctrl = videoPlayerController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    playbackPositionMs.value = ctrl.value.position.inMilliseconds;
    isPlaying.value = ctrl.value.isPlaying;
    final dur = ctrl.value.duration.inMilliseconds;
    if (dur > 0) {
      totalDurationMs.value = dur;
    }
    final audioPlayer = _dubbedAudioPlayer;
    if (audioPlayer != null &&
        audioPlayer.processingState != ja.ProcessingState.idle &&
        audioPlayer.processingState != ja.ProcessingState.loading) {
      final audioPos = audioPlayer.position;
      final audioDur = audioPlayer.duration;
      final driftMs = (ctrl.value.position - audioPos).inMilliseconds.abs();
      if (ctrl.value.isPlaying && !audioPlayer.playing) {
        if (audioDur == null || ctrl.value.position < audioDur) {
          unawaited(audioPlayer.seek(ctrl.value.position));
          unawaited(audioPlayer.play());
        }
      } else if (!ctrl.value.isPlaying && audioPlayer.playing) {
        unawaited(audioPlayer.pause());
      } else if (driftMs > 450 && (audioDur == null || ctrl.value.position < audioDur)) {
        unawaited(audioPlayer.seek(ctrl.value.position));
      }
      return;
    }
    final webAudio = _webDubbedAudioPlayer;
    if (webAudio != null) {
      final videoSec = ctrl.value.position.inMilliseconds / 1000.0;
      final audioDurSec = webAudio.duration;
      final hasValidDur = audioDurSec.isFinite && audioDurSec > 0;
      final driftSec = (videoSec - webAudio.currentTime).abs();
      if (ctrl.value.isPlaying && !webAudio.isPlaying) {
        if (!hasValidDur || videoSec < audioDurSec) {
          webAudio.seek(videoSec);
          webAudio.play();
        }
      } else if (!ctrl.value.isPlaying && webAudio.isPlaying) {
        webAudio.pause();
      } else if (driftSec > 0.45 && (!hasValidDur || videoSec < audioDurSec)) {
        webAudio.seek(videoSec);
      }
    }
  }

  Future<void> loadPreviewMedia(String url, {bool isBlob = false}) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      await disposePreviewPlayer();
      return;
    }
    if (_loadedMediaUrl == trimmed && isPlayerInitialized.value) return;

    await disposePreviewPlayer();
    if (isBlob) {
      _activePreviewBlobUrl = trimmed;
    }
    _loadedMediaUrl = trimmed;
    isPlayerLoading.value = true;
    playerError.value = '';

    try {
      final resolvedUrl = isBlob ? trimmed : await StorageUtils.resolveUrl(trimmed);
      final targetUrl = resolvedUrl.isNotEmpty ? resolvedUrl : trimmed;
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(targetUrl));
      videoPlayerController = ctrl;
      await ctrl.initialize();
      ctrl.addListener(_onPlayerTick);
      final dur = ctrl.value.duration.inMilliseconds;
      totalDurationMs.value = dur > 0 ? dur : estimatedDurationSeconds.value * 1000;
      playbackSpeed.value = 1.0;
      isPlayerInitialized.value = true;
    } catch (e) {
      logger.warning('Preview media load failed: $e', tag: 'DubbingStudioController');
      playerError.value = 'Unable to preview this video in the browser. You can still dub or download it directly.';
      isPlayerInitialized.value = false;
    } finally {
      isPlayerLoading.value = false;
    }
  }

  Future<void> _loadSourcePreview() async {
    final jobSrc = activeJob.value?.sourceMediaUrl.trim() ?? '';
    final urlToLoad = jobSrc.isNotEmpty ? jobSrc : mediaUrl.value.trim();
    if (pickedFile.value != null && !urlToLoad.startsWith('http')) {
      await loadPreviewFromPlatformFile(pickedFile.value!);
    } else if (urlToLoad.isNotEmpty) {
      await loadPreviewMedia(urlToLoad);
    }
  }

  /// Switches the preview monitor between `'original'` and a dubbed target language (e.g. `'te'`).
  Future<void> selectPlaybackTrack(String trackKey, {bool autoTriggered = false}) async {
    final normalizedKey = trackKey.trim().isEmpty ? 'original' : trackKey.trim();
    final job = activeJob.value;
    final previousPos = videoPlayerController?.value.isInitialized == true
        ? videoPlayerController!.value.position
        : Duration.zero;
    final wasPlaying = videoPlayerController?.value.isPlaying == true;

    if (normalizedKey == 'original' || job == null) {
      activePlaybackTrack.value = 'original';
      await _disposeDubbedAudioPlayer();
      await _loadSourcePreview();
      final ctrl = videoPlayerController;
      if (ctrl != null && ctrl.value.isInitialized) {
        await ctrl.setVolume(1.0);
        await ctrl.setPlaybackSpeed(playbackSpeed.value);
        if (previousPos > Duration.zero && previousPos < ctrl.value.duration) {
          await ctrl.seekTo(previousPos);
        }
        if (wasPlaying) {
          await ctrl.play();
        }
      }
      return;
    }

    activePreviewLanguage.value = normalizedKey;
    // Look up dubbed video/audio across activeJob and all completed jobs in this project
    String? findDubbedVideoUrl(String lang) {
      final activeUrl = job.dubbedVideoUrlFor(lang);
      if (activeUrl != null && activeUrl.isNotEmpty) return activeUrl;
      for (final j in projectJobs) {
        final u = j.dubbedVideoUrlFor(lang);
        if (u != null && u.isNotEmpty) return u;
      }
      return null;
    }

    String? findDubbedAudioUrl(String lang) {
      final activeUrl = job.dubbedAudioUrlFor(lang);
      if (activeUrl != null && activeUrl.isNotEmpty) return activeUrl;
      for (final j in projectJobs) {
        final u = j.dubbedAudioUrlFor(lang);
        if (u != null && u.isNotEmpty) return u;
      }
      return null;
    }

    final dubbedVideoUrl = findDubbedVideoUrl(normalizedKey);
    if (dubbedVideoUrl != null && dubbedVideoUrl.isNotEmpty) {
      activePlaybackTrack.value = normalizedKey;
      await _disposeDubbedAudioPlayer();
      await loadPreviewMedia(dubbedVideoUrl);
      final ctrl = videoPlayerController;
      if (ctrl != null && ctrl.value.isInitialized) {
        await ctrl.setVolume(1.0);
        await ctrl.setPlaybackSpeed(playbackSpeed.value);
        if (previousPos > Duration.zero && previousPos < ctrl.value.duration) {
          await ctrl.seekTo(previousPos);
        }
        if (wasPlaying) {
          await ctrl.play();
        }
        return;
      }
      // Fallback to dubbed audio synced with muted original video if the MP4 fails browser decode
      final fallbackAudio = findDubbedAudioUrl(normalizedKey);
      var fallbackOk = false;
      if (fallbackAudio != null && fallbackAudio.isNotEmpty) {
        fallbackOk = await _loadDubbedAudioSyncedWithOriginal(
          fallbackAudio,
          previousPos: previousPos,
          wasPlaying: wasPlaying,
        );
      }
      if (!fallbackOk && !autoTriggered && !isExportingAssets.value) {
        await exportPackage(silent: true);
        final refreshedJob = activeJob.value;
        final refreshedVideo = refreshedJob?.dubbedVideoUrlFor(normalizedKey);
        if (refreshedVideo != null && refreshedVideo.isNotEmpty && refreshedVideo != dubbedVideoUrl) {
          await loadPreviewMedia(refreshedVideo);
          final refreshedCtrl = videoPlayerController;
          if (refreshedCtrl != null && refreshedCtrl.value.isInitialized) {
            await refreshedCtrl.setVolume(1.0);
            await refreshedCtrl.setPlaybackSpeed(playbackSpeed.value);
            if (previousPos > Duration.zero && previousPos < refreshedCtrl.value.duration) {
              await refreshedCtrl.seekTo(previousPos);
            }
            if (wasPlaying) {
              await refreshedCtrl.play();
            }
            return;
          }
        }
        final refreshedAudio = refreshedJob?.dubbedAudioUrlFor(normalizedKey);
        if (refreshedAudio != null && refreshedAudio.isNotEmpty) {
          fallbackOk = await _loadDubbedAudioSyncedWithOriginal(
            refreshedAudio,
            previousPos: previousPos,
            wasPlaying: wasPlaying,
          );
        }
      }
      if (!fallbackOk) {
        activePlaybackTrack.value = 'original';
        await _loadSourcePreview();
        if (!autoTriggered) {
          final langName = DubbingLanguage.findByCode(normalizedKey).name;
          AppSnackbar.warning('Unable to play the $langName dubbed track in this browser. You can download it directly.');
        }
      }
      return;
    }

    final dubbedAudioUrl = findDubbedAudioUrl(normalizedKey);
    if (dubbedAudioUrl != null && dubbedAudioUrl.isNotEmpty) {
      activePlaybackTrack.value = normalizedKey;
      if (job.sourceMediaType == 'audio') {
        await _disposeDubbedAudioPlayer();
        await loadPreviewMedia(dubbedAudioUrl);
      } else {
        var loaded = await _loadDubbedAudioSyncedWithOriginal(
          dubbedAudioUrl,
          previousPos: previousPos,
          wasPlaying: wasPlaying,
        );
        if (!loaded && !autoTriggered && !isExportingAssets.value) {
          await exportPackage(silent: true);
          final refreshedJob = activeJob.value;
          final refreshedVideo = refreshedJob?.dubbedVideoUrlFor(normalizedKey);
          if (refreshedVideo != null && refreshedVideo.isNotEmpty) {
            await _disposeDubbedAudioPlayer();
            await loadPreviewMedia(refreshedVideo);
            final refreshedCtrl = videoPlayerController;
            if (refreshedCtrl != null && refreshedCtrl.value.isInitialized) {
              await refreshedCtrl.setVolume(1.0);
              await refreshedCtrl.setPlaybackSpeed(playbackSpeed.value);
              if (previousPos > Duration.zero && previousPos < refreshedCtrl.value.duration) {
                await refreshedCtrl.seekTo(previousPos);
              }
              if (wasPlaying) {
                await refreshedCtrl.play();
              }
              return;
            }
          }
          final refreshedAudio = refreshedJob?.dubbedAudioUrlFor(normalizedKey);
          if (refreshedAudio != null && refreshedAudio.isNotEmpty) {
            loaded = await _loadDubbedAudioSyncedWithOriginal(
              refreshedAudio,
              previousPos: previousPos,
              wasPlaying: wasPlaying,
            );
          }
        }
        if (!loaded) {
          activePlaybackTrack.value = 'original';
          if (!autoTriggered) {
            final langName = DubbingLanguage.findByCode(normalizedKey).name;
            AppSnackbar.warning('Unable to play the $langName dubbed audio in this browser. You can download it directly.');
          }
          return;
        }
      }
      if (!autoTriggered && job.sourceMediaType != 'audio' && !isExportingAssets.value) {
        unawaited(exportPackage(silent: true));
      }
      return;
    }

    if (!autoTriggered) {
      final langName = DubbingLanguage.findByCode(normalizedKey).name;
      AppSnackbar.info('Dubbed track for $langName is not ready yet.');
    }
  }

  Future<bool> _loadDubbedAudioSyncedWithOriginal(
    String audioUrl, {
    Duration previousPos = Duration.zero,
    bool wasPlaying = false,
  }) async {
    final trimmed = audioUrl.trim();
    if (trimmed.isEmpty) return false;

    if (videoPlayerController == null || !isPlayerInitialized.value) {
      await _loadSourcePreview();
    }

    final videoCtrl = videoPlayerController;
    if (videoCtrl != null && videoCtrl.value.isInitialized) {
      await videoCtrl.setVolume(0.0);
    }

    if (_loadedDubbedAudioUrl != trimmed ||
        (_dubbedAudioPlayer == null && _webDubbedAudioPlayer == null)) {
      await _disposeDubbedAudioPlayer();
      _loadedDubbedAudioUrl = trimmed;
      final resolvedUrl = await StorageUtils.resolveUrl(trimmed);
      final targetUrl = resolvedUrl.isNotEmpty ? resolvedUrl : trimmed;
      final candidateUrls = <String>[
        targetUrl,
        if (trimmed != targetUrl && (trimmed.startsWith('http://') || trimmed.startsWith('https://')))
          trimmed,
      ];

      var loadedAny = false;
      for (final candidate in candidateUrls) {
        try {
          final audioPlayer = ja.AudioPlayer();
          final isFirebaseTokenUrl =
              candidate.contains('firebasestorage.googleapis.com') && candidate.contains('token=');
          final headers = (kIsWeb || isFirebaseTokenUrl)
              ? null
              : StorageUtils.getSyncMediaHeaders(targetUrl: candidate);
          await audioPlayer.setUrl(candidate, headers: headers);
          _dubbedAudioPlayer = audioPlayer;
          isDubbedAudioFallbackActive.value = true;
          loadedAny = true;
          break;
        } catch (e) {
          logger.warning('Dubbed audio just_audio load failed: $e', tag: 'DubbingStudioController');
        }
      }

      if (!loadedAny && kIsWeb) {
        for (final candidate in candidateUrls) {
          final webOk = await _loadWebDubbedAudio(candidate);
          if (webOk) {
            isDubbedAudioFallbackActive.value = true;
            loadedAny = true;
            break;
          }
        }
      }

      if (!loadedAny) {
        await _disposeDubbedAudioPlayer();
        if (videoCtrl != null && videoCtrl.value.isInitialized) {
          await videoCtrl.setVolume(1.0);
        }
        return false;
      }
    }

    final audioPlayer = _dubbedAudioPlayer;
    if (audioPlayer != null) {
      await audioPlayer.setSpeed(playbackSpeed.value);
      final aDur = audioPlayer.duration;
      if (previousPos > Duration.zero && (aDur == null || previousPos < aDur)) {
        await audioPlayer.seek(previousPos);
      }
      if (wasPlaying) {
        unawaited(audioPlayer.play());
      }
    }
    final webAudio = _webDubbedAudioPlayer;
    if (webAudio != null) {
      webAudio.setPlaybackRate(playbackSpeed.value);
      final prevSec = previousPos.inMilliseconds / 1000.0;
      final aDur = webAudio.duration;
      if (prevSec > 0 && (!aDur.isFinite || aDur <= 0 || prevSec < aDur)) {
        webAudio.seek(prevSec);
      }
      if (wasPlaying) {
        webAudio.play();
      }
    }
    if (videoCtrl != null && videoCtrl.value.isInitialized) {
      if (previousPos > Duration.zero && previousPos < videoCtrl.value.duration) {
        await videoCtrl.seekTo(previousPos);
      }
      if (wasPlaying) {
        await videoCtrl.play();
      }
    }
    return true;
  }

  Future<bool> _loadWebDubbedAudio(String url) async {
    final completer = Completer<bool>();
    final player = WebPlatformUtils.createAudioPlayer();
    void completeOnce(bool ok) {
      if (!completer.isCompleted) {
        completer.complete(ok);
      }
    }

    player.init(
      useCors: false,
      onPlay: () {},
      onPause: () {},
      onEnded: () {},
      onWaiting: () {},
      onCanPlay: () => completeOnce(true),
      onError: (_) => completeOnce(false),
      onDurationChange: (dur) {
        if (dur.isFinite && dur > 0) {
          completeOnce(true);
        }
      },
    );
    player.load(url, volume: 1.0);

    final ok = await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => false,
    );
    if (ok) {
      _webDubbedAudioPlayer = player;
      return true;
    }
    try {
      player.stop();
      player.dispose();
    } catch (_) {}
    return false;
  }

  void _maybeAutoSwitchToDubbedTrack(DubbingJob job) {
    if (job.status != DubbingJobStatus.completed || job.mode != DubbingMode.dubbing) {
      return;
    }
    if (job.targetLanguages.isEmpty) return;

    final rawLang = activePreviewLanguage.value;
    final targetLang = job.targetLanguages.contains(rawLang)
        ? rawLang
        : job.targetLanguages.first;

    final hasDubbedVideo = (job.dubbedVideoUrlFor(targetLang) ?? '').isNotEmpty;
    final hasDubbedAudio = (job.dubbedAudioUrlFor(targetLang) ?? '').isNotEmpty;
    if (!hasDubbedVideo && !hasDubbedAudio) return;

    // Upgrade from audio fallback to full dubbed MP4 if user is already on the dubbed track
    if (activePlaybackTrack.value == targetLang &&
        hasDubbedVideo &&
        isDubbedAudioFallbackActive.value) {
      unawaited(selectPlaybackTrack(targetLang, autoTriggered: true));
      return;
    }

    if (_autoSwitchedJobIds.contains(job.id)) return;
    _autoSwitchedJobIds.add(job.id);
    unawaited(selectPlaybackTrack(targetLang, autoTriggered: true));
  }

  Future<void> loadPreviewFromPlatformFile(PlatformFile file) async {
    final ext = file.extension?.toLowerCase() ?? '';
    final isAudio = const {'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'}.contains(ext);
    final mimeType = isAudio
        ? (ext == 'mp3'
            ? 'audio/mpeg'
            : ext == 'wav'
                ? 'audio/wav'
                : 'audio/mp4')
        : 'video/mp4';

    if (kIsWeb && file.bytes != null) {
      final blobUrl = WebPlatformUtils.createBlobUrl(file.bytes!, mimeType);
      if (blobUrl.isNotEmpty) {
        await loadPreviewMedia(blobUrl, isBlob: true);
      }
    } else if (!kIsWeb && file.path != null) {
      await disposePreviewPlayer();
      isPlayerLoading.value = true;
      playerError.value = '';
      try {
        final ctrl = VideoPlayerController.file(io.File(file.path!));
        videoPlayerController = ctrl;
        await ctrl.initialize();
        ctrl.addListener(_onPlayerTick);
        final dur = ctrl.value.duration.inMilliseconds;
        totalDurationMs.value = dur > 0 ? dur : estimatedDurationSeconds.value * 1000;
        isPlayerInitialized.value = true;
      } catch (e) {
        logger.warning('Local preview load failed: $e', tag: 'DubbingStudioController');
        playerError.value = 'Unable to preview this file locally. You can still upload and dub it.';
      } finally {
        isPlayerLoading.value = false;
      }
    }
  }

  Future<void> togglePlayback() async {
    final ctrl = videoPlayerController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final audioPlayer = _dubbedAudioPlayer;
    final webAudio = _webDubbedAudioPlayer;
    if (ctrl.value.isPlaying) {
      await ctrl.pause();
      if (audioPlayer != null) {
        await audioPlayer.pause();
      }
      webAudio?.pause();
    } else {
      if (ctrl.value.position >= ctrl.value.duration) {
        await ctrl.seekTo(Duration.zero);
        if (audioPlayer != null) {
          await audioPlayer.seek(Duration.zero);
        }
        webAudio?.seek(0.0);
      }
      await ctrl.play();
      if (audioPlayer != null) {
        await audioPlayer.seek(ctrl.value.position);
        unawaited(audioPlayer.play());
      }
      if (webAudio != null) {
        webAudio.seek(ctrl.value.position.inMilliseconds / 1000.0);
        webAudio.play();
      }
    }
  }

  Future<void> seekToPercent(double percent) async {
    final ctrl = videoPlayerController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final dur = ctrl.value.duration.inMilliseconds;
    if (dur <= 0) return;
    final targetMs = (dur * percent.clamp(0.0, 1.0)).toInt();
    final targetDuration = Duration(milliseconds: targetMs);
    await ctrl.seekTo(targetDuration);
    final audioPlayer = _dubbedAudioPlayer;
    if (audioPlayer != null) {
      final aDur = audioPlayer.duration;
      await audioPlayer.seek(aDur != null && targetDuration >= aDur ? aDur : targetDuration);
    }
    final webAudio = _webDubbedAudioPlayer;
    if (webAudio != null) {
      final aDur = webAudio.duration;
      final targetSec = targetMs / 1000.0;
      webAudio.seek((aDur.isFinite && aDur > 0 && targetSec >= aDur) ? aDur : targetSec);
    }
    playbackPositionMs.value = targetMs;
  }

  Future<void> setPlaybackSpeed(double speed) async {
    playbackSpeed.value = speed;
    final ctrl = videoPlayerController;
    if (ctrl != null && ctrl.value.isInitialized) {
      await ctrl.setPlaybackSpeed(speed);
    }
    final audioPlayer = _dubbedAudioPlayer;
    if (audioPlayer != null) {
      await audioPlayer.setSpeed(speed);
    }
    _webDubbedAudioPlayer?.setPlaybackRate(speed);
  }

  // --- Channel Videos Management ---

  /// Loads the authenticated creator's channel and all uploaded channel videos.
  Future<void> loadUserChannelAndVideos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      channelVideos.clear();
      filteredChannelVideos.clear();
      selectedChannelVideo.value = null;
      userChannel.value = null;
      return;
    }

    isLoadingChannelVideos.value = true;
    try {
      // 1. Fetch channel owned by current user
      QuerySnapshot<Map<String, dynamic>>? chanSnap;
      try {
        chanSnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.channels)
            .where('ownerId', isEqualTo: user.uid)
            .limit(1)
            .get();
      } catch (_) {}

      if (chanSnap != null && chanSnap.docs.isNotEmpty) {
        userChannel.value = Channel.fromMap(chanSnap.docs.first.data(), chanSnap.docs.first.id);
        // Refresh wallet with channel context to merge free credits & waivers
        await refreshWallet();
      }

      final targetChannelId = userChannel.value?.id ?? '';

      // 2. Query videos where ownerId == user.uid
      QuerySnapshot<Map<String, dynamic>>? querySnap;
      try {
        querySnap = await FirebaseFirestore.instance
            .collection(FirestoreCollections.videos)
            .where('ownerId', isEqualTo: user.uid)
            .get();
      } catch (_) {}

      final Map<String, Video> vMap = {};
      if (querySnap != null) {
        for (final doc in querySnap.docs) {
          final video = Video.fromDocumentSnapshot(doc);
          vMap[video.id] = video;
        }
      }

      // Query videos by channelId if different
      if (targetChannelId.isNotEmpty && targetChannelId != user.uid) {
        QuerySnapshot<Map<String, dynamic>>? chanVideosSnap;
        try {
          chanVideosSnap = await FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('channelId', isEqualTo: targetChannelId)
              .get();
        } catch (_) {}
        if (chanVideosSnap != null) {
          for (final doc in chanVideosSnap.docs) {
            final video = Video.fromDocumentSnapshot(doc);
            vMap[video.id] = video;
          }
        }
      }

      final list = vMap.values.toList();
      list.sort((a, b) => b.uploadedAt.toDate().compareTo(a.uploadedAt.toDate()));

      channelVideos.assignAll(list);
      applyChannelVideoFilter();

      // Only auto-select a channel video if a project is open and references it
      final proj = activeProject.value;
      if (proj != null && proj.videoId != null && proj.videoId!.isNotEmpty) {
        final match = channelVideos.where((v) => v.id == proj.videoId).firstOrNull;
        if (match != null && selectedChannelVideo.value?.id != match.id) {
          await selectChannelVideo(match, autoSave: false);
        }
      } else if (proj != null && channelVideos.isEmpty && proj.sourceMediaUrl.isEmpty) {
        sourceInputMode.value = 'file_upload';
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, context: 'DubbingStudioController.loadUserChannelAndVideos');
    } finally {
      isLoadingChannelVideos.value = false;
    }
  }

  Future<void> _loadAndSelectVideoById(String id, {bool autoSave = true}) async {
    try {
      final doc = await FirebaseFirestore.instance.collection(FirestoreCollections.videos).doc(id).get();
      if (doc.exists && doc.data() != null) {
        final video = Video.fromDocumentSnapshot(doc);
        await selectChannelVideo(video, autoSave: autoSave);
      }
    } catch (e) {
      logger.warning('Failed to load video by id: $e', tag: 'DubbingStudioController');
    }
  }

  void searchChannelVideos(String query) {
    channelVideoSearchQuery.value = query;
    applyChannelVideoFilter();
  }

  void applyChannelVideoFilter() {
    final q = channelVideoSearchQuery.value.trim().toLowerCase();
    if (q.isEmpty) {
      filteredChannelVideos.assignAll(channelVideos);
      return;
    }
    filteredChannelVideos.assignAll(
      channelVideos.where((v) {
        final title = v.title.toLowerCase();
        final desc = v.description.toLowerCase();
        return title.contains(q) || desc.contains(q);
      }).toList(),
    );
  }

  /// Selects a channel video, populating the dubbing workspace and existing audio tracks.
  Future<void> selectChannelVideo(Video video, {bool autoSave = true}) async {
    final prevVideoTitle = selectedChannelVideo.value?.title;
    selectedChannelVideo.value = video;
    sourceInputMode.value = 'channel_videos';
    if (activeProject.value == null ||
        mediaTitle.value.isEmpty ||
        mediaTitle.value == 'Untitled Project' ||
        mediaTitle.value == 'My Multilingual Project' ||
        (prevVideoTitle != null && mediaTitle.value == prevVideoTitle)) {
      mediaTitle.value = video.title;
      projectTitleEditController.text = video.title;
    }
    mediaUrl.value = video.videoUrl.isNotEmpty
        ? video.videoUrl
        : (video.hlsUrl.isNotEmpty ? video.hlsUrl : '');
    // Dubbing v1.0 only supports English as source language; never let video metadata
    // override sourceLanguage to an unsupported code.
    sourceLanguage.value = DubbingLanguage.activeSourceCode;
    final dur = video.durationSeconds > 0
        ? video.durationSeconds
        : (video.durationValue.inSeconds > 0 ? video.durationValue.inSeconds : 60);
    estimatedDurationSeconds.value = dur;
    estimatedCharacterCount.value = (dur * 15).clamp(200, 50000);
    totalDurationMs.value = dur * 1000;
    unawaited(loadPreviewMedia(mediaUrl.value));

    // Fetch existing audio tracks for this video (exact same as Studio)
    isLoadingVideoTracks.value = true;
    try {
      final loc = await VideoMediaService().getLocalization(video.id, forceRefresh: true);
      final tracks = <String, String>{};
      tracks.addAll(video.audioTracks);
      tracks.addAll(loc.audioTracks);
      selectedVideoAudioTracks.assignAll(tracks);
    } catch (e) {
      selectedVideoAudioTracks.assignAll(video.audioTracks);
    } finally {
      isLoadingVideoTracks.value = false;
    }
    if (autoSave) {
      scheduleProjectAutoSave();
    }
    await fetchServerQuote();
  }

  /// Fetches authoritative server quote using DubbingQuoteService (getDubbingQuote).
  Future<void> fetchServerQuote() async {
    final videoId = selectedChannelVideo.value?.id;
    final dur = estimatedDurationSeconds.value;
    final targetLangs = targetLanguages.toList();
    if (targetLangs.isEmpty) {
      serverQuote.value = null;
      return;
    }
    final reqId = ++_quoteRequestId;
    isQuoteLoading.value = true;
    try {
      final quote = await _quoteService.fetch(
        videoId: videoId ?? '',
        targetLanguages: targetLangs,
        durationSeconds: dur,
      );
      if (reqId == _quoteRequestId) {
        serverQuote.value = quote;
      }
    } catch (e) {
      logger.warning('Failed to fetch dubbing quote: $e', tag: 'DubbingStudioController');
    } finally {
      if (reqId == _quoteRequestId) {
        isQuoteLoading.value = false;
      }
    }
  }

  /// Opens the selected video directly in Truthworld Studio's Audio Tracks tab.
  void openInStudioAudioTracks(Video video) {
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().setSelectedIndex(7); // Audio Tracks tab
    }
    Get.toNamed(AppRoutes.dashboard, arguments: {'selectedIndex': 7, 'video': video, 'videoId': video.id});
  }

  void resetActiveJob() {
    _jobSub?.cancel();
    _jobSub = null;
    activeJob.value = null;
    activePlaybackTrack.value = 'original';
    unawaited(_disposeDubbedAudioPlayer());
    unawaited(_loadSourcePreview());
  }

  void _upsertProjectJob(DubbingJob job) {
    final idx = projectJobs.indexWhere((j) => j.id == job.id);
    if (idx >= 0) {
      projectJobs[idx] = job;
    } else {
      projectJobs.insert(0, job);
    }
  }

  void _listenToJob(String jobId) {
    _jobSub?.cancel();
    activePlaybackTrack.value = 'original';
    _jobSub = _service.streamJob(jobId).listen((job) {
      if (job != null) {
        activeJob.value = job;
        _upsertProjectJob(job);
        final needsFullArtifacts = job.exportUrls == null ||
            (job.mode == DubbingMode.dubbing &&
                ((job.sourceMediaType != 'audio' && job.dubbedVideoByLanguage.isEmpty) ||
                    job.dubbedAudioByLanguage.isEmpty ||
                    job.dialogueAudioByLanguage.isEmpty ||
                    job.translationJsonByLanguage.isEmpty ||
                    job.reportJson == null));
        if (job.status == DubbingJobStatus.completed &&
            needsFullArtifacts &&
            !_autoExportedJobIds.contains(job.id)) {
          _autoExportedJobIds.add(job.id);
          unawaited(exportPackage(silent: true));
        }
        if (job.status == DubbingJobStatus.completed) {
          _maybeAutoSwitchToDubbedTrack(job);
          unawaited(_syncCompletedJobToActiveProject(job));
        } else if (job.status == DubbingJobStatus.failed) {
          unawaited(_syncJobStatusToActiveProject(job.id, 'failed'));
        }
      }
    });
  }

  bool get hasInFlightJob {
    final job = activeJob.value;
    if (job == null) return false;
    return job.status != DubbingJobStatus.completed && job.status != DubbingJobStatus.failed;
  }

  /// Triggers dubbing for the selected channel video via the real backend pipeline
  /// through createDubbingJob, debited from the channel wallet (Option B).
  Future<void> dubChannelVideo() async {
    if (hasInFlightJob) {
      AppSnackbar.info('A dubbing project is already processing. Please wait for it to finish.');
      return;
    }
    final video = selectedChannelVideo.value;
    if (video == null) {
      AppSnackbar.warning('Please select a video from your channel first.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await signInWithGoogle();
      if (!AuthService.to.isUserSignedIn) return;
    }

    final baseLang = video.language.trim().toLowerCase();
    final targetLangs = targetLanguages
        .map((c) => c.trim().toLowerCase())
        .where((c) => c.isNotEmpty && c != baseLang)
        .toSet()
        .toList();

    if (targetLangs.isEmpty) {
      AppSnackbar.warning(
        'Please select at least one target language different from the source language (${video.language}).',
      );
      return;
    }

    if (_voiceCloneConsentMissing()) return;

    if (!hasSufficientBalance) {
      AppSnackbar.warning(
        'Insufficient balance in Studio Wallet (\$${studioWalletSpendableBalance.toStringAsFixed(2)} available vs \$${calculatedCostUsd.toStringAsFixed(2)} required). Please top up your channel wallet.',
      );
      return;
    }

    isSubmitting.value = true;
    try {
      final targetChanId = video.channelId.isNotEmpty
          ? video.channelId
          : (userChannel.value?.id ?? user!.uid);

      final res = await _service.createJob(
        title: video.title,
        mode: mode.value,
        sourceMediaUrl: video.videoUrl,
        sourceMediaType: 'video',
        durationSeconds: estimatedDurationSeconds.value,
        characterCount: estimatedCharacterCount.value,
        sourceLanguage: isDubbingSourceSupported(sourceLanguage.value)
            ? sourceLanguage.value
            : DubbingLanguage.activeSourceCode,
        targetLanguages: targetLangs,
        voiceCloningEnabled: voiceCloningEnabled.value,
        voiceCloneConsent: voiceCloningEnabled.value && voiceCloneConsent.value,
        twoStageReviewEnabled: twoStageReviewEnabled.value,
        publishToTruthworld: true,
        demuxOptions: {
          'isolateVocals': isolateVocals.value,
          'preserveBgm': preserveBgm.value,
          'bgmDuckLevelPercent': bgmDuckingPercent.value,
          'noiseSuppression': true,
        },
        speakers: speakers.map((s) => s.toMap()).toList(),
        videoId: video.id,
        channelId: targetChanId,
      );

      if (res['success'] == true && res['jobId'] != null) {
        final jobId = res['jobId'] as String;
        final isSubOnly = mode.value == DubbingMode.subtitlesOnly;
        AppSnackbar.success(
          isSubOnly
              ? 'Subtitles started for "${video.title}"!'
              : 'Dubbing started for "${video.title}"! All dubbed audio tracks will be stored in your video\'s Audio Tracks tab in Studio.',
        );
        await _recordJobInActiveProject(jobId, mode: mode.value, langs: targetLangs);
        _listenToJob(jobId);
        await refreshWallet();
        await selectChannelVideo(video, autoSave: false);
      } else {
        final message = res['message'] as String? ?? 'Unable to start dubbing. Please try again.';
        AppSnackbar.error(message);
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, context: 'DubbingStudioController.dubChannelVideo');
      AppSnackbar.error('Unable to start dubbing. Please check your connection and try again.');
    } finally {
      isSubmitting.value = false;
    }
  }

  // --- Computed Pricing ---
  /// Industry reference cost comparison (~$22 per 10 mins).
  double get industryBenchmarkCostUsd {
    final mins = (estimatedDurationSeconds.value / 60.0).ceil();
    return (mins / 10.0) * 22.0 * targetLanguages.length;
  }

  /// Authoritative server-priced dubbing charge:
  /// Higher of $0.30 per minute or $0.30 per 1,000 characters per language.
  double get calculatedCostUsd {
    if (serverQuote.value != null && serverQuote.value!.isReady) {
      return serverQuote.value!.dubbingChargeUsd;
    }
    final numLangs = targetLanguages.length;
    final minuteCost = (estimatedDurationSeconds.value / 60.0) * 0.30 * numLangs;
    final charCost = (estimatedCharacterCount.value / 1000.0) * 0.30 * numLangs;
    return minuteCost > charCost ? minuteCost : charCost;
  }

  int get totalCharactersRequired =>
      estimatedCharacterCount.value * targetLanguages.length;

  /// Complimentary characters granted directly to the creator's channel by Super Admin
  int get channelFreeCredits {
    try {
      return userChannel.value?.freeDubbingCredits ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Combined available characters (personal wallet characters + channel granted characters)
  int get totalAvailableCharacters =>
      (wallet.value?.balanceCredits ?? 0) + channelFreeCredits;

  /// Whether 100% free dubbing is active via either user wallet or creator channel privileges
  bool get isFreeDubbingActive {
    try {
      return wallet.value?.isDubbingFree == true ||
          userChannel.value?.isDubbingFree == true ||
          (wallet.value?.specialDiscountPercent ?? 0) >= 100 ||
          (userChannel.value?.effectiveDubbingDiscountPercent ?? 0) >= 100;
    } catch (_) {
      return false;
    }
  }

  bool get hasSufficientBalance {
    if (isFreeDubbingActive) return true;
    return studioWalletSpendableBalance >= calculatedCostUsd;
  }

  // --- Actions ---
  Future<void> refreshWallet() async {
    if (!AuthService.to.isUserSignedIn || isLoadingWallet.value) return;
    isLoadingWallet.value = true;
    try {
      final fetched = await _service.fetchWallet();
      // Synthesize channel privileges if channel holds granted credits or free waiver
      final chanCredits = channelFreeCredits;
      final freeActive = isFreeDubbingActive;
      if (chanCredits > 0 || freeActive) {
        wallet.value = DubbingWallet(
          userId: fetched.userId,
          balanceCredits: fetched.balanceCredits + chanCredits,
          balanceUsd: fetched.balanceUsd,
          trialClaimed: fetched.trialClaimed,
          totalCharactersUsed: fetched.totalCharactersUsed,
          totalSpentUsd: fetched.totalSpentUsd,
          specialDiscountPercent: freeActive
              ? 100.0
              : ((userChannel.value?.effectiveDubbingDiscountPercent ?? 0) > fetched.specialDiscountPercent
                  ? userChannel.value!.effectiveDubbingDiscountPercent
                  : fetched.specialDiscountPercent),
          specialDiscountType: freeActive ? 'free' : (userChannel.value?.dubbingDiscountType ?? fetched.specialDiscountType),
          isDubbingFree: freeActive,
          discountReason: userChannel.value?.quotaIncreaseReason ?? fetched.discountReason,
          discountAppliedBy: fetched.discountAppliedBy,
          transactions: fetched.transactions,
        );
      } else {
        wallet.value = fetched;
      }
    } finally {
      isLoadingWallet.value = false;
    }
  }

  /// Claim or verify free trial characters.
  Future<void> claimFreeTrial() async {
    await _service.claimFreeTrial();
    await refreshWallet();
    AppSnackbar.success('1,000 Free Characters active in your wallet! You can test dubbing before paying.');
  }

  /// Turns voice cloning on or off. Turning it off also clears the consent confirmation.
  void setVoiceCloning(bool enabled) {
    voiceCloningEnabled.value = enabled;
    if (!enabled) voiceCloneConsent.value = false;
    scheduleProjectAutoSave();
  }

  /// Switches between Dub (`DubbingMode.dubbing`) and Subtitles (`DubbingMode.subtitlesOnly`) tabs.
  void setMode(DubbingMode newMode) {
    if (mode.value == newMode) return;
    mode.value = newMode;
    scheduleProjectAutoSave();
    fetchServerQuote();
  }

  /// Updates the active project's title and schedules auto-save.
  void setProjectTitle(String title) {
    mediaTitle.value = title;
    scheduleProjectAutoSave();
  }

  /// True (and tells the creator) when cloning is on but consent has not been confirmed.
  bool _voiceCloneConsentMissing() {
    if (voiceCloningEnabled.value && !voiceCloneConsent.value) {
      AppSnackbar.warning(
        'To clone voices, please confirm that you are the speaker or have the speakers\' permission, or turn voice cloning off.',
      );
      return true;
    }
    return false;
  }

  /// Purchase Dubbing Credits directly using TruthWorld Studio Channel Wallet.
  /// The server no longer sells credits (2026-11-24); it answers with a message, shown as-is.
  Future<bool> purchaseCreditsWithStudioWallet({
    required int amountUsd,
    required int credits,
  }) async {
    final chan = userChannel.value;
    if (chan == null) {
      AppSnackbar.warning('No active channel found. Please sign in with your creator channel account.');
      return false;
    }

    if (studioWalletSpendableBalance < amountUsd) {
      AppSnackbar.warning(
        'Insufficient Studio Wallet balance (\$${studioWalletSpendableBalance.toStringAsFixed(2)} available vs \$$amountUsd required). You can add funds to your channel wallet or use direct checkout.',
      );
      return false;
    }

    isPurchasingCredits.value = true;
    try {
      final res = await _service.purchaseCreditsWithStudioWallet(
        channelId: chan.id,
        amountUsd: amountUsd,
        credits: credits,
      );

      if (res['success'] == true) {
        await refreshWallet();
        await loadUserChannelAndVideos();
        AppSnackbar.success(
          'Successfully added ${credits.toString()} characters to your Dubbing Wallet using Studio Wallet!',
        );
        return true;
      } else {
        AppSnackbar.error(
          res['message'] as String? ?? 'Unable to complete credit purchase with Studio Wallet.',
        );
        return false;
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, context: 'DubbingStudioController.purchaseCreditsWithStudioWallet');
      AppSnackbar.error('Unable to complete credit purchase with Studio Wallet. Please try again.');
      return false;
    } finally {
      isPurchasingCredits.value = false;
    }
  }

  /// Google Sign-In helper.
  Future<void> signInWithGoogle() async {
    try {
      await AuthService.to.signInWithGoogle();
      if (AuthService.to.isUserSignedIn) {
        AppSnackbar.success('Signed in successfully as ${AuthService.to.userDisplayName.value ?? 'Creator'}');
        await refreshWallet();
        if (pickedFile.value != null && mediaUrl.value.isEmpty && !isUploadingMedia.value) {
          await startUpload();
        }
      }
    } catch (e) {
      if (e is GoogleSignInException && e.isCancelled) {
        // User intentionally cancelled or dismissed the Google Sign-In prompt.
        return;
      }
      ErrorHandler.log(
        e,
        tag: 'DubbingStudioController.signInWithGoogle',
      );
      AppSnackbar.error('Unable to complete Google Sign-In. Please check your connection and try again.');
    }
  }

  /// Sign out helper for Dubbing Studio.
  Future<void> signOut() async {
    try {
      _saveDebounceTimer?.cancel();
      _jobSub?.cancel();
      _jobSub = null;
      if (Get.isRegistered<AuthService>()) {
        await AuthService.to.signOut();
      }
      userChannel.value = null;
      channelVideos.clear();
      filteredChannelVideos.clear();
      selectedChannelVideo.value = null;
      savedProjects.clear();
      activeProject.value = null;
      activeJob.value = null;
      projectJobs.clear();
      wallet.value = const DubbingWallet(userId: '');
      await disposePreviewPlayer();
      AppSnackbar.info('Signed out successfully.');
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, context: 'DubbingStudioController.signOut');
      AppSnackbar.error('Unable to sign out. Please check your connection and try again.');
    }
  }

  void clearPickedFile() {
    pickedFile.value = null;
    pickedFileName.value = '';
    pickedFileSizeBytes.value = 0;
    uploadProgress.value = 0.0;
    uploadStatus.value = '';
    mediaUrl.value = '';
    estimatedDurationSeconds.value = 120;
    estimatedCharacterCount.value = 2000;
    scheduleProjectAutoSave();
  }

  String formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h}h ${m}m ${s}s';
    } else if (m > 0) {
      return '${m}m ${s}s';
    } else {
      return '${s}s';
    }
  }

  String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  Future<int> _probeDuration(PlatformFile file) async {
    final ext = file.extension?.toLowerCase() ?? '';
    final isAudio = const {'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'}.contains(ext);
    final mimeType = isAudio
        ? (ext == 'mp3'
            ? 'audio/mpeg'
            : ext == 'wav'
                ? 'audio/wav'
                : 'audio/mp4')
        : 'video/mp4';

    try {
      if (kIsWeb) {
        if (file.bytes != null) {
          final dur = await WebPlatformUtils.getVideoDurationFromBytes(file.bytes!, mimeType);
          if (dur != null && dur.inSeconds > 0) {
            return dur.inSeconds;
          }
          final blobUrl = WebPlatformUtils.createBlobUrl(file.bytes!, mimeType);
          if (blobUrl.isNotEmpty) {
            final tempCtrl = VideoPlayerController.networkUrl(Uri.parse(blobUrl));
            await tempCtrl.initialize();
            final sec = tempCtrl.value.duration.inSeconds;
            await tempCtrl.dispose();
            WebPlatformUtils.revokeBlobUrl(blobUrl);
            if (sec > 0) return sec;
          }
        }
      } else if (file.path != null) {
        final tempCtrl = VideoPlayerController.file(io.File(file.path!));
        await tempCtrl.initialize();
        final sec = tempCtrl.value.duration.inSeconds;
        await tempCtrl.dispose();
        if (sec > 0) return sec;
      }
    } catch (e) {
      ErrorHandler.log(e, context: 'DubbingStudioController._probeDuration');
    }
    return 120;
  }

  /// Picks media file up to 2 hours duration and 4GB in size.
  Future<void> pickMediaFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp4', 'mov', 'mkv', 'webm', 'avi', 'flv', '3gp', 'm4v',
          'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac',
        ],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      // 4GB size limit (accommodates 2 hours 1080p video)
      const maxSizeBytes = 4 * 1024 * 1024 * 1024;
      if (file.size > maxSizeBytes) {
        AppSnackbar.warning('Selected file exceeds the 4GB upload limit.');
        return;
      }

      pickedFile.value = file;
      pickedFileName.value = file.name;
      pickedFileSizeBytes.value = file.size;

      // Auto-populate project title from clean file name unless the creator typed a custom one
      if (mediaTitle.value.isEmpty ||
          mediaTitle.value == 'Untitled Project' ||
          mediaTitle.value == 'My Multilingual Project' ||
          mediaTitle.value == selectedChannelVideo.value?.title) {
        final dotIndex = file.name.lastIndexOf('.');
        final cleanTitle = dotIndex > 0 ? file.name.substring(0, dotIndex) : file.name;
        mediaTitle.value = cleanTitle.replaceAll('_', ' ').replaceAll('-', ' ');
        projectTitleEditController.text = mediaTitle.value;
      }

      uploadStatus.value = 'Checking media duration...';
      final duration = await _probeDuration(file);
      const maxDurationSeconds = 2 * 60 * 60; // 2 hours = 7,200 seconds
      if (duration > maxDurationSeconds) {
        clearPickedFile();
        AppSnackbar.warning(
          'Selected video (${formatDuration(duration)}) exceeds the maximum 2-hour duration limit for dubbing.',
        );
        return;
      }

      estimatedDurationSeconds.value = duration > 0 ? duration : 120;
      estimatedCharacterCount.value = ((estimatedDurationSeconds.value / 60.0) * 1000).round().clamp(500, 250000);
      totalDurationMs.value = estimatedDurationSeconds.value * 1000;
      unawaited(loadPreviewFromPlatformFile(file));

      if (AuthService.to.isUserSignedIn) {
        await startUpload();
      } else {
        uploadStatus.value = 'Ready to upload (Sign in to proceed)';
      }
    } catch (e) {
      ErrorHandler.log(e, context: 'DubbingStudioController.pickMediaFile');
      AppSnackbar.error('Failed to select file. Please try again.');
    }
  }

  /// Uploads the picked file to Firebase Storage with real-time percentage progress.
  Future<void> startUpload() async {
    final file = pickedFile.value;
    if (file == null) return;
    if (!AuthService.to.isUserSignedIn) {
      await signInWithGoogle();
      if (!AuthService.to.isUserSignedIn) return;
    }

    isUploadingMedia.value = true;
    uploadProgress.value = 0.05;
    uploadStatus.value = 'Connecting to secure cloud storage...';

    try {
      final uid = AuthService.to.uid;
      final ext = file.extension?.toLowerCase() ?? 'mp4';
      final mimeType = switch (ext) {
        'mp3' => 'audio/mpeg',
        'wav' => 'audio/wav',
        'm4a' || 'aac' => 'audio/mp4',
        'ogg' => 'audio/ogg',
        'flac' => 'audio/flac',
        'webm' => 'video/webm',
        'mov' => 'video/quicktime',
        'mkv' => 'video/x-matroska',
        _ => 'video/mp4',
      };

      final sanitizedName = file.name.replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_');
      final path = 'dubbing_uploads/$uid/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
      final storageRef = FirebaseStorage.instance.ref(path);

      final fileBytes = file.bytes ??
          (file.path != null && !kIsWeb ? await io.File(file.path!).readAsBytes() : null);

      if (fileBytes == null) {
        throw Exception('Could not read file data from device.');
      }

      final metadata = SettableMetadata(
        contentType: mimeType,
        customMetadata: {
          'uploaderId': uid,
          'originalName': file.name,
          'size': file.size.toString(),
          'durationSeconds': estimatedDurationSeconds.value.toString(),
        },
      );

      final uploadTask = storageRef.putData(fileBytes, metadata);
      uploadTask.snapshotEvents.listen(
        (snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            uploadProgress.value = progress;
            uploadStatus.value = 'Uploading ${(progress * 100).toStringAsFixed(0)}%...';
          }
        },
        onError: (err) {
          logger.warning('Dubbing upload progress notice: $err', tag: 'DubbingStudioController');
        },
      );

      final snap = await uploadTask;
      final downloadUrl = await snap.ref.getDownloadURL();
      mediaUrl.value = downloadUrl;
      uploadStatus.value = 'Upload complete';
      uploadProgress.value = 1.0;
      scheduleProjectAutoSave();
      AppSnackbar.success('Media uploaded successfully! Ready for dubbing.');
    } catch (e) {
      ErrorHandler.log(e, context: 'DubbingStudioController.startUpload');
      uploadStatus.value = 'Upload failed';
      if (e is FirebaseException && (e.code == 'unauthorized' || e.code == 'permission-denied')) {
        AppSnackbar.error('Unable to upload right now. Please sign in and try again.');
      } else {
        AppSnackbar.error('Unable to upload file. Please check your connection and try again.');
      }
    } finally {
      isUploadingMedia.value = false;
    }
  }

  void toggleTargetLanguage(String code) {
    if (!DubbingLanguage.activeOutputCodes.contains(code.toLowerCase())) {
      final lang = DubbingLanguage.findByCode(code);
      AppSnackbar.info('${lang.name} will be available soon. Currently available: Telugu, Hindi, Marathi, Tamil, and Malayalam.');
      return;
    }
    if (targetLanguages.contains(code)) {
      targetLanguages.remove(code);
    } else {
      targetLanguages.add(code);
    }
    scheduleProjectAutoSave();
    fetchServerQuote();
  }

  void setSourceLanguage(String code) {
    if (!isDubbingSourceSupported(code)) {
      final lang = DubbingLanguage.findByCode(code);
      AppSnackbar.info('${lang.name} will be available soon. Currently available source language: English.');
      return;
    }
    sourceLanguage.value = DubbingLanguage.activeSourceCode;
    scheduleProjectAutoSave();
  }

  /// Launch the dubbing job.
  Future<void> startDubbingJob() async {
    if (hasInFlightJob) {
      AppSnackbar.info('A dubbing project is already processing. Please wait for it to finish.');
      return;
    }
    if (!AuthService.to.isUserSignedIn) {
      await signInWithGoogle();
      if (!AuthService.to.isUserSignedIn) return;
    }

    // If working on a channel video, execute the unified Studio pipeline
    if (sourceInputMode.value == 'channel_videos') {
      if (selectedChannelVideo.value == null) {
        AppSnackbar.warning('Please select a video from your channel first to start dubbing.');
        return;
      }
      await dubChannelVideo();
      return;
    }

    if (isUploadingMedia.value) {
      AppSnackbar.info('Media file is still uploading. Please wait a moment...');
      return;
    }

    if (mediaUrl.value.isEmpty) {
      if (pickedFile.value != null) {
        await startUpload();
      }
      if (mediaUrl.value.isEmpty) {
        AppSnackbar.warning('Please select a video or audio file first.');
        return;
      }
    }

    if (targetLanguages.isEmpty) {
      AppSnackbar.warning('Please select at least one output language.');
      return;
    }

    if (_voiceCloneConsentMissing()) return;

    if (!hasSufficientBalance) {
      AppSnackbar.warning(
        'Insufficient balance in Studio Wallet (\$${studioWalletSpendableBalance.toStringAsFixed(2)} available vs \$${calculatedCostUsd.toStringAsFixed(2)} required). Please top up your channel wallet.',
      );
      Get.dialog(const DubbingWalletModal());
      return;
    }

    isSubmitting.value = true;
    try {
      final pickedExt = pickedFile.value?.extension?.toLowerCase() ?? '';
      final isAudioUpload = const {'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'}.contains(pickedExt);
      final res = await _service.createJob(
        title: mediaTitle.value,
        mode: mode.value,
        sourceMediaUrl: mediaUrl.value,
        sourceMediaType: isAudioUpload ? 'audio' : 'video',
        durationSeconds: estimatedDurationSeconds.value,
        characterCount: estimatedCharacterCount.value,
        sourceLanguage: isDubbingSourceSupported(sourceLanguage.value)
            ? sourceLanguage.value
            : DubbingLanguage.activeSourceCode,
        targetLanguages: targetLanguages.toList(),
        voiceCloningEnabled: voiceCloningEnabled.value,
        voiceCloneConsent: voiceCloningEnabled.value && voiceCloneConsent.value,
        twoStageReviewEnabled: twoStageReviewEnabled.value,
        publishToTruthworld: publishToTruthworld.value,
        demuxOptions: {
          'isolateVocals': isolateVocals.value,
          'preserveBgm': preserveBgm.value,
          'bgmDuckLevelPercent': bgmDuckingPercent.value,
          'noiseSuppression': true,
        },
        speakers: speakers.map((s) => s.toMap()).toList(),
        channelId: userChannel.value?.id,
      );

      if (res['success'] == true && res['jobId'] != null) {
        final jobId = res['jobId'] as String;
        final isSubOnly = mode.value == DubbingMode.subtitlesOnly;
        AppSnackbar.success(
          isSubOnly
              ? 'Generating subtitles! Your SRT and VTT files will be ready shortly.'
              : 'Dubbing started! Preparing your audio and transcript.',
        );
        await _recordJobInActiveProject(jobId, mode: mode.value, langs: targetLanguages.toList());
        _listenToJob(jobId);
        await refreshWallet();
      } else {
        final message = res['message'] as String? ?? 'Unable to start dubbing job. Please try again.';
        AppSnackbar.error(message);
        if (message.toLowerCase().contains('insufficient credits') ||
            message.toLowerCase().contains('top up')) {
          Get.dialog(const DubbingWalletModal());
        }
      }
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Save edited transcription or translation lines (Pre-TTS Review).
  Future<void> saveSegmentEdits({
    required String language,
    required List<DubbingSegment> segments,
    bool approveForTTS = false,
  }) async {
    final job = activeJob.value;
    if (job == null) return;

    final success = await _service.updateTranscription(
      jobId: job.id,
      language: language,
      segments: segments,
      approveForTTS: approveForTTS,
    );

    if (success) {
      AppSnackbar.success(
        approveForTTS
            ? 'Approved! Generating dubbed voices now.'
            : 'Changes saved successfully.',
      );
    } else {
      AppSnackbar.error('Unable to save changes. Please try again.');
    }
  }

  /// Re-synthesize a single line after TTS (Post-TTS line adjustment).
  Future<void> regenerateLine({
    required String language,
    required String segmentId,
    required String newText,
    double speed = 1.0,
  }) async {
    final job = activeJob.value;
    if (job == null) return;

    isRegeneratingLine.value = true;
    try {
      final success = await _service.regenerateSegment(
        jobId: job.id,
        language: language,
        segmentId: segmentId,
        newText: newText,
        speedMultiplier: speed,
      );

      if (success) {
        AppSnackbar.success('Regenerating line with your updated settings.');
      } else {
        AppSnackbar.error('Unable to regenerate this line right now.');
      }
    } finally {
      isRegeneratingLine.value = false;
    }
  }

  /// Export and generate download package.
  Future<void> exportPackage({bool silent = false}) async {
    final job = activeJob.value;
    if (job == null) return;

    if (job.status != DubbingJobStatus.completed) {
      if (!silent) {
        AppSnackbar.info('Dubbing is currently in progress. Export links will be ready once processing completes.');
      }
      return;
    }

    if (isExportingAssets.value) return;
    isExportingAssets.value = true;
    try {
      final res = await _service.exportAssets(job.id);
      if (res != null && res['success'] == true) {
        final updatedExportUrls = res['exportUrls'] is Map
            ? Map<String, dynamic>.from(res['exportUrls'] as Map)
            : job.exportUrls;
        final updatedSegments = Map<String, List<DubbingSegment>>.from(job.segmentsByLanguage);
        if (res['segmentsByLanguage'] is Map) {
          (res['segmentsByLanguage'] as Map).forEach((k, v) {
            if (v is List) {
              updatedSegments['$k'] = v
                  .whereType<Map>()
                  .map((m) => DubbingSegment.fromMap(Map<String, dynamic>.from(m)))
                  .toList();
            }
          });
        }

        final updatedJob = DubbingJob(
          id: job.id,
          userId: job.userId,
          title: job.title,
          mode: job.mode,
          status: DubbingJobStatus.completed,
          progressPercent: 100,
          currentStepMessage: job.mode == DubbingMode.subtitlesOnly
              ? 'Subtitles are ready to download.'
              : 'All dubbed files are ready.',
          sourceMediaUrl: job.sourceMediaUrl,
          sourceMediaType: job.sourceMediaType,
          durationSeconds: job.durationSeconds,
          characterCount: job.characterCount,
          sourceLanguage: job.sourceLanguage,
          targetLanguages: job.targetLanguages,
          voiceCloningEnabled: job.voiceCloningEnabled,
          twoStageReviewEnabled: job.twoStageReviewEnabled,
          publishToTruthworld: job.publishToTruthworld,
          costUsd: job.costUsd,
          totalCharactersCharged: job.totalCharactersCharged,
          speakers: job.speakers,
          segmentsByLanguage: updatedSegments,
          exportUrls: updatedExportUrls,
          videoId: job.videoId,
          pipelineJobId: job.pipelineJobId,
          channelId: job.channelId,
          error: job.error,
          createdAt: job.createdAt,
          stages: job.stages,
        );
        activeJob.value = updatedJob;
        _upsertProjectJob(updatedJob);
        _maybeAutoSwitchToDubbedTrack(updatedJob);
        unawaited(_syncCompletedJobToActiveProject(updatedJob));
        if (!silent) {
          AppSnackbar.success('Your downloads are ready. Choose a language below.');
        }
      } else {
        final fallbackJob = await _service.enrichJobFromFirestoreFallbacks(job);
        final gainedAssets = fallbackJob.dubbedVideoByLanguage.length > job.dubbedVideoByLanguage.length ||
            fallbackJob.dubbedAudioByLanguage.length > job.dubbedAudioByLanguage.length ||
            fallbackJob.dialogueAudioByLanguage.length > job.dialogueAudioByLanguage.length ||
            fallbackJob.translationJsonByLanguage.length > job.translationJsonByLanguage.length ||
            fallbackJob.subtitlesSrt.length > job.subtitlesSrt.length ||
            fallbackJob.segmentsByLanguage.length > job.segmentsByLanguage.length ||
            (fallbackJob.reportJson != null && job.reportJson == null);
        if (gainedAssets) {
          activeJob.value = fallbackJob;
          _upsertProjectJob(fallbackJob);
          _maybeAutoSwitchToDubbedTrack(fallbackJob);
          unawaited(_syncCompletedJobToActiveProject(fallbackJob));
          if (!silent) {
            AppSnackbar.success('Your downloads are ready. Choose a language below.');
          }
        } else if (!silent) {
          final msg = res?['message']?.toString().trim();
          AppSnackbar.warning(
            (msg != null && msg.isNotEmpty)
                ? msg
                : 'Unable to retrieve export assets right now. Please try again shortly.',
          );
        }
      }
    } finally {
      isExportingAssets.value = false;
    }
  }

  /// Downloads one output artifact with an explicit filename.
  Future<void> downloadExportArtifact(String url, String fileName) async {
    final trimmed = DubbingService.toBrowserDownloadUrl(url);
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      AppSnackbar.warning('This artifact is not available yet. Please refresh downloads.');
      return;
    }
    try {
      await DownloadHelper.downloadFromUrl(trimmed, fileName);
      AppSnackbar.success('Downloading $fileName');
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, context: 'DubbingStudioController.downloadExportArtifact');
      await openExportLink(trimmed);
    }
  }

  /// Opens one export file. Links from exportDubbingAssets are short-lived; if one has expired,
  /// preparing the downloads again issues fresh links.
  Future<void> openExportLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      AppSnackbar.warning('This download is not available. Please prepare the downloads again.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        AppSnackbar.warning('We couldn\'t open this download. Please prepare the downloads again and retry.');
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, context: 'DubbingStudioController.openExportLink');
      AppSnackbar.warning('We couldn\'t open this download. Please prepare the downloads again and retry.');
    }
  }

  // ── Persistent Projects Management ─────────────────────────────

  bool get _isSignedIn =>
      Get.isRegistered<AuthService>() && AuthService.to.isUserSignedIn;

  String get _currentUid {
    if (Get.isRegistered<AuthService>() && AuthService.to.uid.isNotEmpty) {
      return AuthService.to.uid;
    }
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  /// Loads all saved [DubbingProject] documents for the current user,
  /// plus any legacy `studio_dubbing_jobs` not yet attached to a project.
  Future<void> loadSavedProjects() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? _currentUid;
    if (user == null || uid.isEmpty || !_isSignedIn) {
      savedProjects.clear();
      return;
    }

    isLoadingProjects.value = true;
    try {
      final results = await Future.wait([
        _service.fetchUserProjects(uid),
        _service.fetchUserJobs(uid),
      ]);
      final projects = results[0] as List<DubbingProject>;
      final jobs = results[1] as List<DubbingJob>;

      final linkedJobIds = <String>{};
      for (final p in projects) {
        linkedJobIds.addAll(p.jobIds);
      }

      final merged = <DubbingProject>[...projects];
      for (final j in jobs) {
        if (!linkedJobIds.contains(j.id)) {
          merged.add(DubbingProject.fromLegacyJob(j));
        }
      }
      merged.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      savedProjects.assignAll(merged);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, context: 'DubbingStudioController.loadSavedProjects');
    } finally {
      isLoadingProjects.value = false;
    }
  }

  /// Creates a new project, persists it to Firestore, and opens its Studio workspace.
  Future<DubbingProject?> createNewProject({String? title}) async {
    if (!_isSignedIn) {
      await signInWithGoogle();
      if (!_isSignedIn) return null;
    }

    final uid = _currentUid;
    if (uid.isEmpty) return null;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cleanTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : 'Untitled Project';
    final project = DubbingProject(
      id: 'proj_${nowMs}_${uid.hashCode.abs()}',
      userId: uid,
      title: cleanTitle,
      sourceInputMode: channelVideos.isNotEmpty ? 'channel_videos' : 'file_upload',
      channelId: userChannel.value?.id,
      sourceLanguage: DubbingLanguage.activeSourceCode,
      targetLanguages: const [],
      mode: DubbingMode.dubbing,
      createdAt: nowMs,
      updatedAt: nowMs,
    );

    isSavingProject.value = true;
    try {
      await _service.saveProject(project);
      savedProjects.insert(0, project);
      await openProject(project);
      return project;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, context: 'DubbingStudioController.createNewProject');
      AppSnackbar.error('Unable to create project right now. Please try again.');
      return null;
    } finally {
      isSavingProject.value = false;
    }
  }

  /// Creates a new project from the Hub dropzone and immediately opens the media file picker.
  Future<void> quickUploadFromHub() async {
    final proj = await createNewProject(title: 'Untitled Project');
    if (proj == null) return;
    sourceInputMode.value = 'file_upload';
    await pickMediaFile();
  }

  /// Creates a new project from a pasted media URL in the Hub dropzone.
  Future<void> quickPasteUrlFromHub(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final proj = await createNewProject(title: 'Untitled Project');
    if (proj == null) return;
    sourceInputMode.value = 'file_upload';
    showManualUrlInput.value = true;
    mediaUrl.value = trimmed;
    await loadPreviewMedia(trimmed);
    scheduleProjectAutoSave();
  }

  /// Opens an existing [DubbingProject], restoring its settings, source media, and jobs.
  Future<void> openProject(DubbingProject project) async {
    _saveDebounceTimer?.cancel();
    _jobSub?.cancel();
    _jobSub = null;
    await disposePreviewPlayer();

    activeProject.value = project;
    mediaTitle.value = project.title;
    projectTitleEditController.text = project.title;
    isEditingProjectTitle.value = false;
    sourceInputMode.value = project.sourceInputMode;
    sourceLanguage.value = isDubbingSourceSupported(project.sourceLanguage)
        ? project.sourceLanguage
        : DubbingLanguage.activeSourceCode;
    targetLanguages.assignAll(project.targetLanguages);
    mode.value = project.mode;
    voiceCloningEnabled.value = project.voiceCloningEnabled;
    voiceCloneConsent.value = false;
    isolateVocals.value = project.isolateVocals;
    preserveBgm.value = project.preserveBgm;
    bgmDuckingPercent.value = project.bgmDuckingPercent;
    twoStageReviewEnabled.value = project.twoStageReviewEnabled;
    publishToTruthworld.value = project.publishToTruthworld;
    mediaUrl.value = project.sourceMediaUrl;
    pickedFile.value = null;
    pickedFileName.value = project.pickedFileName;
    pickedFileSizeBytes.value = 0;
    uploadProgress.value = 0.0;
    uploadStatus.value = '';
    estimatedDurationSeconds.value = project.durationSeconds > 0 ? project.durationSeconds : 60;
    estimatedCharacterCount.value = project.characterCount > 0 ? project.characterCount : 1000;
    totalDurationMs.value = estimatedDurationSeconds.value * 1000;
    activeJob.value = null;
    projectJobs.clear();
    activePlaybackTrack.value = 'original';
    showSourceEditor.value = project.sourceMediaUrl.isEmpty && (project.videoId == null || project.videoId!.isEmpty);

    if (project.videoId != null && project.videoId!.isNotEmpty) {
      final match = channelVideos.where((v) => v.id == project.videoId).firstOrNull;
      if (match != null) {
        await selectChannelVideo(match, autoSave: false);
      } else {
        await _loadAndSelectVideoById(project.videoId!, autoSave: false);
      }
    } else {
      selectedChannelVideo.value = null;
      selectedVideoAudioTracks.clear();
      if (project.sourceMediaUrl.isNotEmpty) {
        unawaited(loadPreviewMedia(project.sourceMediaUrl));
      }
    }

    if (project.jobIds.isNotEmpty) {
      final fetched = await Future.wait(project.jobIds.map(_service.fetchJobById));
      final validJobs = fetched.whereType<DubbingJob>().toList();
      validJobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      projectJobs.assignAll(validJobs);
      if (validJobs.isNotEmpty) {
        activeJob.value = validJobs.first;
        _listenToJob(validJobs.first.id);
      }
    }

    if (targetLanguages.isNotEmpty) {
      unawaited(fetchServerQuote());
    }
  }

  /// Saves and closes the currently open project, returning to the Projects Hub.
  Future<void> closeActiveProject() async {
    await saveActiveProject(immediate: true);
    _jobSub?.cancel();
    _jobSub = null;
    activeProject.value = null;
    activeJob.value = null;
    projectJobs.clear();
    selectedChannelVideo.value = null;
    selectedVideoAudioTracks.clear();
    pickedFile.value = null;
    pickedFileName.value = '';
    mediaUrl.value = '';
    mediaTitle.value = 'Untitled Project';
    targetLanguages.clear();
    isEditingProjectTitle.value = false;
    showSourceEditor.value = false;
    await disposePreviewPlayer();
    unawaited(loadSavedProjects());
  }

  /// Deletes a saved [DubbingProject].
  Future<void> deleteProject(DubbingProject project) async {
    if (!project.id.startsWith('legacy_')) {
      await _service.deleteProject(project.id);
    }
    savedProjects.removeWhere((p) => p.id == project.id);
    if (activeProject.value?.id == project.id) {
      _jobSub?.cancel();
      _jobSub = null;
      activeProject.value = null;
      activeJob.value = null;
      projectJobs.clear();
      await disposePreviewPlayer();
    }
    AppSnackbar.info('Project deleted.');
  }

  /// Schedules a debounced Firestore save for the active project.
  void scheduleProjectAutoSave() {
    if (activeProject.value == null) return;
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(saveActiveProject(immediate: true));
    });
  }

  /// Builds an updated [DubbingProject] snapshot from the current controller state.
  DubbingProject _buildUpdatedProjectSnapshot(DubbingProject current) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final uid = current.userId.isNotEmpty ? current.userId : _currentUid;
    final resolvedId = current.id.startsWith('legacy_')
        ? 'proj_${nowMs}_${uid.hashCode.abs()}'
        : current.id;
    final selectedVid = selectedChannelVideo.value;
    final pickedExt = pickedFile.value?.extension?.toLowerCase() ?? '';
    final isAudio = const {'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'}.contains(pickedExt);

    return current.copyWith(
      id: resolvedId,
      userId: uid,
      title: mediaTitle.value.trim().isNotEmpty ? mediaTitle.value.trim() : current.title,
      sourceInputMode: sourceInputMode.value,
      videoId: sourceInputMode.value == 'channel_videos' ? selectedVid?.id : null,
      clearVideoId: sourceInputMode.value != 'channel_videos' || selectedVid == null,
      channelId: selectedVid?.channelId ?? userChannel.value?.id ?? current.channelId,
      sourceMediaUrl: mediaUrl.value,
      sourceMediaType: sourceInputMode.value == 'channel_videos'
          ? 'video'
          : (isAudio ? 'audio' : current.sourceMediaType),
      pickedFileName: pickedFileName.value,
      durationSeconds: estimatedDurationSeconds.value,
      characterCount: estimatedCharacterCount.value,
      sourceLanguage: sourceLanguage.value,
      targetLanguages: targetLanguages.toList(),
      mode: mode.value,
      voiceCloningEnabled: voiceCloningEnabled.value,
      isolateVocals: isolateVocals.value,
      preserveBgm: preserveBgm.value,
      bgmDuckingPercent: bgmDuckingPercent.value,
      twoStageReviewEnabled: twoStageReviewEnabled.value,
      publishToTruthworld: publishToTruthworld.value,
      updatedAt: nowMs,
    );
  }

  /// Persists the active project immediately to Firestore and updates [savedProjects].
  Future<void> saveActiveProject({bool immediate = false}) async {
    if (!immediate) {
      scheduleProjectAutoSave();
      return;
    }
    _saveDebounceTimer?.cancel();
    final current = activeProject.value;
    if (current == null) return;

    final updated = _buildUpdatedProjectSnapshot(current);
    if (updated.userId.isEmpty) return;

    activeProject.value = updated;
    final idx = savedProjects.indexWhere((p) => p.id == current.id || p.id == updated.id);
    if (idx >= 0) {
      savedProjects[idx] = updated;
    } else {
      savedProjects.insert(0, updated);
    }

    isSavingProject.value = true;
    try {
      await _service.saveProject(updated);
    } finally {
      isSavingProject.value = false;
    }
  }

  Future<void> _recordJobInActiveProject(
    String jobId, {
    required DubbingMode mode,
    required List<String> langs,
  }) async {
    final current = activeProject.value;
    if (current == null) return;
    final updatedIds = <String>[jobId, ...current.jobIds.where((id) => id != jobId)];
    final updatedSnapshot = _buildUpdatedProjectSnapshot(current).copyWith(
      jobIds: updatedIds,
      latestJobId: jobId,
      latestStatus: 'processing',
    );
    activeProject.value = updatedSnapshot;
    await saveActiveProject(immediate: true);
  }

  Future<void> _syncCompletedJobToActiveProject(DubbingJob job) async {
    final current = activeProject.value;
    if (current == null) return;
    final dubbedSet = <String>{...current.dubbedLanguages};
    final subSet = <String>{...current.subtitledLanguages};
    if (job.mode == DubbingMode.dubbing) {
      dubbedSet.addAll(job.targetLanguages);
    }
    subSet.addAll(job.targetLanguages);
    final updated = current.copyWith(
      dubbedLanguages: dubbedSet.toList(),
      subtitledLanguages: subSet.toList(),
      latestJobId: job.id,
      latestStatus: 'completed',
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    activeProject.value = updated;
    final idx = savedProjects.indexWhere((p) => p.id == updated.id);
    if (idx >= 0) {
      savedProjects[idx] = updated;
    }
    if (!updated.id.startsWith('legacy_')) {
      await _service.saveProject(updated);
    }
  }

  Future<void> _syncJobStatusToActiveProject(String jobId, String status) async {
    final current = activeProject.value;
    if (current == null) return;
    if (current.latestJobId == jobId && current.latestStatus == status) return;
    final updated = current.copyWith(
      latestJobId: jobId,
      latestStatus: status,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    activeProject.value = updated;
    if (!updated.id.startsWith('legacy_')) {
      await _service.saveProject(updated);
    }
  }

  Future<void> _openProjectForDeepLinkedVideo(Video video) async {
    if (_isSignedIn) {
      final proj = await createNewProject(title: video.title);
      if (proj != null) {
        await selectChannelVideo(video, autoSave: true);
        return;
      }
    }
    sourceInputMode.value = 'channel_videos';
    await selectChannelVideo(video, autoSave: false);
  }

  Future<void> _openProjectForDeepLinkedVideoId(String videoId) async {
    sourceInputMode.value = 'channel_videos';
    await _loadAndSelectVideoById(videoId, autoSave: false);
    final v = selectedChannelVideo.value;
    if (v != null && _isSignedIn) {
      final proj = await createNewProject(title: v.title);
      if (proj != null) {
        await selectChannelVideo(v, autoSave: true);
      }
    }
  }

  // ── Combined Output Artifacts Across All Jobs in Active Project ──

  /// Merges per-language maps across [projectJobs] (plus [activeJob]) so every
  /// dubbed video, audio track, and subtitle generated for this project remains available.
  Map<String, String> _mergeProjectLanguageMap(
    Map<String, String> Function(DubbingJob j) selector,
  ) {
    final result = <String, String>{};
    final ordered = <DubbingJob>[
      ...projectJobs.reversed,
      if (activeJob.value != null) activeJob.value!,
    ];
    for (final j in ordered) {
      result.addAll(selector(j));
    }
    return result;
  }

  Map<String, String> get combinedDubbedVideosByLang =>
      _mergeProjectLanguageMap((j) => j.dubbedVideoByLanguage);

  Map<String, String> get combinedDubbedAudiosByLang =>
      _mergeProjectLanguageMap((j) => j.dubbedAudioByLanguage);

  Map<String, String> get combinedDialogueAudiosByLang =>
      _mergeProjectLanguageMap((j) => j.dialogueAudioByLanguage);

  Map<String, String> get combinedTranslationJsonByLang =>
      _mergeProjectLanguageMap((j) => j.translationJsonByLanguage);

  Map<String, String> get combinedSubtitlesSrtByLang =>
      _mergeProjectLanguageMap((j) => j.subtitlesSrt);

  Map<String, String> get combinedSubtitlesVttByLang =>
      _mergeProjectLanguageMap((j) => j.subtitlesVtt);

  List<String> get allProjectOutputLanguages {
    final seen = <String>{};
    final ordered = <String>[];
    void addAll(Iterable<String> codes) {
      for (final c in codes) {
        final norm = c.trim();
        if (norm.isNotEmpty && seen.add(norm)) {
          ordered.add(norm);
        }
      }
    }
    if (activeJob.value != null) {
      addAll(activeJob.value!.targetLanguages);
    }
    for (final j in projectJobs) {
      addAll(j.targetLanguages);
    }
    addAll(combinedDubbedVideosByLang.keys);
    addAll(combinedDubbedAudiosByLang.keys);
    addAll(combinedSubtitlesSrtByLang.keys);
    addAll(combinedSubtitlesVttByLang.keys);
    return ordered;
  }

  List<String> get allProjectDubbedLanguages {
    final seen = <String>{};
    final ordered = <String>[];
    void addAll(Iterable<String> codes) {
      for (final c in codes) {
        final norm = c.trim();
        if (norm.isNotEmpty && seen.add(norm)) {
          ordered.add(norm);
        }
      }
    }
    if (activeJob.value != null && activeJob.value!.mode == DubbingMode.dubbing) {
      addAll(activeJob.value!.targetLanguages);
    }
    for (final j in projectJobs) {
      if (j.mode == DubbingMode.dubbing) {
        addAll(j.targetLanguages);
      }
    }
    addAll(combinedDubbedVideosByLang.keys);
    addAll(combinedDubbedAudiosByLang.keys);
    return ordered;
  }
}
