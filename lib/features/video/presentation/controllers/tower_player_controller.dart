import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/features/video/data/services/storyboard_service.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';
import 'package:truthworld/features/video/presentation/controllers/player_lock_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_mixins/tower_mixins.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_components.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_overlay_manager.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:truthworld/features/video/presentation/services/video_playback_queue_service.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/core/audio_analysis_service.dart';
import 'package:video_player/video_player.dart';

export 'tower_player/tower_player_components.dart';
export 'tower_player_overlay_manager.dart';

/// TowerPlayerController: Core video playback controller orchestrating Chewie,
/// ABR streaming, ads, background audio, gestures, and subtitle/track sync.
class TowerPlayerController extends BaseController
    with
        WidgetsBindingObserver,
        TowerPlayerStateMixin,
        TowerPlayerAbrMixin,
        TowerPlayerAdMixin,
        TowerPlayerBackgroundAudioMixin,
        TowerPlayerEngagementMixin,
        TowerPlayerTruthReportMixin,
        TowerPlayerGesturesMixin,
        TowerPlayerKeyboardMixin,
        TowerPlayerModesMixin,
        TowerPlayerNavigationMixin,
        TowerPlayerSleepTimerMixin,
        TowerPlayerTimelineMixin,
        TowerPlayerTracksMixin,
        TowerPlayerUIStateMixin,
        TowerPlayerPlaybackControlMixin {
  bool _isClosed = false;
  @override
  bool get isClosed => _isClosed;
  Worker? _langWorker;

  TowerPlayerController({required this.videoPlayerController, this.tag}) {
    if (tag != null) {
      TowerPlayerRegistry.clearDisposed(tag!);
    }
    try {
      rxValue = videoPlayerController.value.obs;
      isInitialized.value = videoPlayerController.value.isInitialized;
      if (videoPlayerController.value.isInitialized &&
          videoPlayerController.value.aspectRatio > 0) {
        aspectRatio.value = videoPlayerController.value.aspectRatio;
      } else {
        final isShort = videoController?.video.isShort ?? false;
        aspectRatio.value = isShort ? (9 / 16) : (16 / 9);
      }
      isPlaying.value = videoPlayerController.value.isPlaying;
      hasError.value = false;
      errorDescription.value =
          videoPlayerController.value.errorDescription ?? '';
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TowerPlayerController.ctor');
      rxValue = const VideoPlayerValue.uninitialized().obs;
      isInitialized.value = false;
    }
  }

  // ── Overlay Manager & UI State Contracts ──────────────────
  @override
  late final TowerPlayerOverlayManager overlayManager = TowerPlayerOverlayManager(
    onOverlayChanged: (overlay) {
      if (overlay != TowerPlayerOverlay.none) {
        cancelHideTimer();
        controlsVisible.value = true;
      } else {
        startHideTimer();
      }
    },
  );

  @override
  bool get isPlayingValue => isPlaying.value;

  @override
  bool get isScrubbingValue => isScrubbing.value;

  /// Effective duration: guards against truncated streams (< 5s) when model duration is known (> 10s)
  @override
  Duration get effectiveDuration {
    final playerDur = rxValue.value.duration;
    final modelDur = videoController?.video.durationValue ?? Duration.zero;
    if (modelDur > const Duration(seconds: 10) && playerDur <= const Duration(seconds: 5)) {
      return modelDur;
    }
    return playerDur > Duration.zero ? playerDur : modelDur;
  }

  // ── Global Registry ───────────────────────────────────────
  static List<TowerPlayerController> get activePlayers =>
      TowerPlayerRegistry.activePlayers;
  static TowerPlayerController? getForTagOrActive(String? tag) =>
      TowerPlayerRegistry.getForTagOrActive(tag);
  static void pauseAllActivePlayers({TowerPlayerController? except}) =>
      TowerPlayerRegistry.pauseAllActivePlayers(except: except);
  static void Function(BuildContext context, TowerPlayerController ctrl)?
      get showMobileSettingsCallback =>
          TowerPlayerRegistry.showMobileSettingsCallback;
  static set showMobileSettingsCallback(
          void Function(BuildContext context, TowerPlayerController ctrl)?
              cb) =>
      TowerPlayerRegistry.showMobileSettingsCallback = cb;

  // ── Persistent Media Preferences ──────────────────────────
  static bool get globalSubtitlesEnabled =>
      TowerPlayerPreferences.globalSubtitlesEnabled;
  static set globalSubtitlesEnabled(bool v) =>
      TowerPlayerPreferences.globalSubtitlesEnabled = v;
  static String get globalActiveSubLang =>
      TowerPlayerPreferences.globalActiveSubLang;
  static set globalActiveSubLang(String v) =>
      TowerPlayerPreferences.globalActiveSubLang = v;
  static bool get globalAudioOnly => TowerPlayerPreferences.globalAudioOnly;
  static set globalAudioOnly(bool v) =>
      TowerPlayerPreferences.globalAudioOnly = v;
  static double get globalPlaybackSpeed =>
      TowerPlayerPreferences.globalPlaybackSpeed;
  static set globalPlaybackSpeed(double v) =>
      TowerPlayerPreferences.globalPlaybackSpeed = v;
  static String? get globalQualityPreference =>
      TowerPlayerPreferences.globalQualityPreference;
  static set globalQualityPreference(String? v) =>
      TowerPlayerPreferences.globalQualityPreference = v;

  // ── Global Subtitle Appearance Options ─────────────────────
  static RxString get globalSubtitleFontSizeOption =>
      TowerPlayerPreferences.globalSubtitleFontSizeOption;
  static Rx<Color> get globalSubtitleTextColor =>
      TowerPlayerPreferences.globalSubtitleTextColor;
  static Rx<Color> get globalSubtitleBgColor =>
      TowerPlayerPreferences.globalSubtitleBgColor;
  static RxDouble get globalSubtitleBgOpacity =>
      TowerPlayerPreferences.globalSubtitleBgOpacity;
  static RxString get globalSubtitleEdgeStyle =>
      TowerPlayerPreferences.globalSubtitleEdgeStyle;
  static RxString get globalSubtitleFontFamily =>
      TowerPlayerPreferences.globalSubtitleFontFamily;
  static void resetSubtitleStyleToDefault() =>
      TowerPlayerPreferences.resetSubtitleStyleToDefault();
  static TextStyle getSubtitleTextStyle({
    required String fontFamily,
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    required List<Shadow> shadows,
  }) =>
      TowerPlayerPreferences.getSubtitleTextStyle(
        fontFamily: fontFamily,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        shadows: shadows,
      );


  @override
  VideoPlayerController videoPlayerController;
  late final Rx<VideoPlayerController> rxVideoPlayerController =
      videoPlayerController.obs;
  @override
  ChewieController? chewieController;
  @override
  final String? tag;

  AudioAnalysisService? _audioAnalysisService;
  AudioAnalysisService get audioAnalysisService =>
      _audioAnalysisService ??= AudioAnalysisService(playerCtrl: this);

  void _initChewieController() {
    TowerPlayerChewieConfigurator.safeDispose(
      chewieController,
      currentVpc: videoPlayerController,
    );
    chewieController = TowerPlayerChewieConfigurator.create(
      videoPlayerController: videoPlayerController,
      isLooping: isLooping.value,
    );
    setupChewieListeners();
  }

  @override
  VideoController? get videoController {
    try {
      if (tag != null && Get.isRegistered<VideoController>(tag: tag)) {
        return Get.find<VideoController>(tag: tag);
      }
      final formattedTag = tag != null
          ? (tag!.startsWith('video_') ? tag! : 'video_$tag')
          : null;
      if (formattedTag != null &&
          Get.isRegistered<VideoController>(tag: formattedTag)) {
        return Get.find<VideoController>(tag: formattedTag);
      }
      if (Get.isRegistered<VideoController>()) {
        return Get.find<VideoController>();
      }
    } catch (e, s) {
      ErrorHandler.log(
          e, stackTrace: s, tag: 'TowerPlayerController.videoController');
    }
    return null;
  }

  // ── Playback Authority ────────────────────────────────────
  @override
  PlaybackSource get activePlayback {
    try {
      final vc = videoController;
      if (vc != null &&
          vc.videoPlayerController != null &&
          vc.videoPlayerController != videoPlayerController) {
        sync(vc.videoPlayerController!);
      }
    } catch (e, s) {
      ErrorHandler.log(
          e, stackTrace: s, tag: 'TowerPlayerController.activePlayback.sync');
    }
    return videoPlaybackSource ??= VideoPlaybackSource(videoPlayerController);
  }

  // ── Lifecycle ─────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    TowerPlayerRegistry.register(this);
    _attachVideoListener();

    void performInitialSetup() {
      if (isClosed) return;
      TowerPlayerRegistry.pauseAllActivePlayers(except: this);

      TowerPlayerLifecycleHelper.loadUserSettings(
        tag: tag,
        showStatsForNerds: showStatsForNerds,
        isAutoplay: isAutoplay,
      );

      startHideTimer();
      initABR();
      initAudioService();
      if (audioService != null && audioService!.isActive.value) {
        try {
          audioService!.deactivateBackgroundPlayback();
        } catch (_) {}
      }
      trackAnalytics(PlayerEvent('player_init'));

      if (videoController != null) {
        ever(videoController!.availableAudioTracks, (_) => _syncTracksWithVideoController());
        ever(videoController!.availableVideoTracks, (_) => _syncTracksWithVideoController());
        ever(videoController!.availableSubtitles, (_) => _syncTracksWithVideoController());
        _syncTracksWithVideoController();
      }

      if (Get.isRegistered<UserLanguagesService>()) {
        _langWorker = ever(UserLanguagesService.to.primaryLanguage, (_) {
          _syncTracksWithVideoController();
        });
      }

      final vid = videoController?.video;
      if (vid != null) {
        VideoPlaybackQueueService.to.onVideoLoaded(vid);
        if (vid.durationValue > Duration.zero) {
          storyboardTrack.value = StoryboardService.generateHighDensityTrack(
            totalDuration: vid.durationValue,
            multiSheetUrls: vid.storyboardVariants,
            singleSheetUrl: vid.storyboardUrl,
            thumbnailVariants: vid.thumbnailVariants,
          );
        }
      }

      final isFromMiniplayer =
          TowerPlayerLifecycleHelper.isFromMiniplayerOrResumed(
        arguments: Get.arguments,
        tag: tag,
        videoId: videoController?.video.id,
        currentPosition: videoPlayerController.value.position,
      );

      if (isFromMiniplayer) {
        preRollPlayed = true;
      }

      try {
        TowerPlayerLifecycleHelper.triggerInitialPreRollAd(
          isClosed: isClosed,
          shouldSuppressAds: shouldSuppressAds,
          isFromMiniplayer: isFromMiniplayer,
          preRollPlayed: preRollPlayed,
          videoId: videoController?.video.id,
          videoPlayerController: videoPlayerController,
          onStartSponsorAd: (ad, {required isPreRoll}) =>
              startSponsorAd(ad, isPreRoll: isPreRoll),
          onStartAd: startAd,
          setPreRollPlayed: (v) => preRollPlayed = v,
        );
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerController.triggerInitialPreRollAd',
        );
      }

      TowerPlayerLifecycleHelper.applyInitialPreferences(
        arguments: Get.arguments,
        subtitlesEnabled: subtitlesEnabled,
        activeSubLang: activeSubLang,
        isAudioOnly: isAudioOnly,
        playbackSpeed: playbackSpeed,
        vpc: videoPlayerController,
        onSetAudioOnly: setAudioOnly,
        onToggleAudioOnly: toggleAudioOnly,
        initialAudioOnly: videoController?.isAudioOnly.value ?? false,
        isClosed: () => isClosed,
      );

      _initChewieController();

      webFullscreenSub = TowerPlayerLifecycleHelper.initWebFullscreenListener(
        isFullScreen: isFullScreen,
        getVideoController: () => videoController,
        onInteraction: onInteraction,
        onExitFullscreen: resetZoom,
      );

      if (!Get.isRegistered<TowerPlayerController>(tag: tag)) {
        Get.put<TowerPlayerController>(this, tag: tag);
      }

      TowerPlayerRegistry.initPipChannel();
    }

    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        performInitialSetup();
      });
    } else {
      performInitialSetup();
    }
  }

  @override
  void onInteraction() {
    if (kIsWeb && isHoverSuppressed) return;
    if (!controlsVisible.value) {
      controlsVisible.value = true;
    }
    if (!isMuted.value) {
      if (hasAlternateAudioTrack) {
        if (videoPlayerController.value.volume > 0.0) {
          try {
            videoPlayerController.setVolume(0.0);
          } catch (_) {}
        }
        if (audioTrackController != null &&
            audioTrackController!.value.isInitialized &&
            audioTrackController!.value.volume == 0.0) {
          try {
            audioTrackController!.setVolume(volume.value > 0 ? volume.value : 1.0);
          } catch (_) {}
        }
      } else if (videoPlayerController.value.volume == 0.0) {
        try {
          videoPlayerController.setVolume(volume.value > 0 ? volume.value : 1.0);
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'TowerPlayerController.onInteraction',
          );
        }
      }
    }
    if (!isDragging.value) {
      startHideTimer();
    }
  }

  void _attachVideoListener() {
    videoPlaybackSource = VideoPlaybackSource(videoPlayerController);
    sleepTimerService.setActivePlayback(activePlayback);
    videoPlayerController.addListener(_onVpcUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      try {
        if (hasAlternateAudioTrack) {
          videoPlayerController.setVolume(0.0);
          return;
        }
        if (kIsWeb && (videoPlayerController.value.volume == 0.0 || isMuted.value)) {
          // Preserve muted autoplay state on Web until user interaction occurs (like YouTube)
          return;
        }
        final volumeScale =
            TowerPlayerVpcEventHandler.getNormalizedVolumeScale();
        if ((videoPlayerController.value.volume - volumeScale).abs() > 0.001) {
          videoPlayerController.setVolume(volumeScale);
        }
      } catch (e, s) {
        ErrorHandler.log(
            e, stackTrace: s, tag: 'TowerPlayerController.volumeScale');
      }
    });
  }

  // ── VPC listener ──────────────────────────────────────────
  bool _isHandlingVpcUpdate = false;

  void _onVpcUpdate() {
    if (_isHandlingVpcUpdate || _isClosed) return;
    _isHandlingVpcUpdate = true;
    try {
      final val = videoPlayerController.value;
      rxValue.value = val;
      isBuffering.value = val.isBuffering;
      playbackSpeed.value = val.playbackSpeed;
      if (isLooping.value != val.isLooping) isLooping.value = val.isLooping;

      if (isInitialized.value != val.isInitialized) {
        isInitialized.value = val.isInitialized;
        update();
        rxVideoPlayerController.refresh();
      }
      if (val.isInitialized &&
          val.aspectRatio > 0 &&
          aspectRatio.value != val.aspectRatio) {
        aspectRatio.value = val.aspectRatio;
        updateAutoPip(isPlaying.value);
      }
      if (isPlaying.value != val.isPlaying) {
        isPlaying.value = val.isPlaying;
        updateAutoPip(val.isPlaying);
      }

      final vc = videoController;
      final isSuppressed = vc != null &&
          (vc.isAutoSwitching.value || vc.isRecoveringFromFormatError);
      errorDebounceTimer = TowerPlayerVpcEventHandler.evaluatePlaybackErrors(
        val: val,
        currentErrorDesc: errorDescription.value,
        isAutoSwitchingOrRecovering: isSuppressed,
        isClosed: _isClosed,
        vpc: videoPlayerController,
        currentTimer: errorDebounceTimer,
        setHasError: (v) => hasError.value = v,
        setErrorDescription: (v) => errorDescription.value = v,
      );

      // Sync alternate audio track
      TowerPlayerVpcEventHandler.syncAlternateAudioTrack(
        mainVpc: videoPlayerController,
        audioCtrl: audioTrackController,
        isMuted: isMuted.value,
        volume: volume.value,
        hasAlternateAudioTrack: hasAlternateAudioTrack,
      );

      // Ad triggers
      var adHandled = false;
      try {
        adHandled = TowerPlayerVpcEventHandler.handleAdTriggers(
          val: val,
          effectiveDuration: effectiveDuration,
          shouldSuppressAds: shouldSuppressAds,
          hasRealVideoAds: TowerPlayerAdPolicyEvaluator.hasRealVideoAds(
            videoId: videoController?.video.id,
          ),
          isShowingAd: isShowingAd.value,
          mainVpc: videoPlayerController,
          audioCtrl: audioTrackController,
          videoId: videoController?.video.id,
          preRollPlayed: preRollPlayed,
          midRollPlayed: midRollPlayed,
          sponsorMidRollPlayed: sponsorMidRollPlayed,
          onStartSponsorAd: (ad, {required isPreRoll}) =>
              startSponsorAd(ad, isPreRoll: isPreRoll),
          onStartAd: startAd,
          setPreRollPlayed: (v) => preRollPlayed = v,
          setMidRollPlayed: (v) => midRollPlayed = v,
          setSponsorMidRollPlayed: (v) => sponsorMidRollPlayed = v,
        );
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerController.onVpcUpdate.adTriggers',
        );
      }
      if (adHandled) return;

      // Sync metadata (subtitles, chapters, claims, tracks)
      TowerPlayerVpcEventHandler.syncPlaybackMetadata(
        val: val,
        subtitlesEnabled: subtitlesEnabled.value,
        hasSubtitles: subtitleSegments.isNotEmpty ||
            (videoController?.transcriptSegments.isNotEmpty ?? false),
        startSubtitleSyncTimer: startSubtitleSyncTimer,
        stopSubtitleSyncTimer: stopSubtitleSyncTimer,
        syncActiveSubtitle: syncActiveSubtitle,
        chapters: chapters,
        currentChapter: currentChapter,
        binarySearchChapter: binarySearchChapter,
        syncActiveClaim: syncActiveClaim,
        lastTrackSync: lastTrackSync,
        onSyncTracks: _syncTracksWithVideoController,
        setLastTrackSync: (t) => lastTrackSync = t,
        isTranscriptVisible:
            (videoController?.isTranscriptVisible.value ?? false) ||
                showTranscriptPopup.value,
      );

      // Evaluate high-signal visual evidence in audio-only mode
      if (isAudioOnly.value) {
        evaluateVisualEvidenceSignals(val.position);
      }

      if (val.hasError &&
          retryCount < TowerPlayerPlaybackControlMixin.maxRetries) {
        scheduleRetry();
      }

      final effectiveDur = effectiveDuration;

      if (sleepTimerService.mode.value == SleepTimerMode.endOfVideo) {
        final rem = (effectiveDur - val.position).inSeconds;
        sleepTimerService.remainingSeconds.value =
            rem.clamp(0, double.maxFinite.toInt());
      }

      // Near-end trigger: When watching in fullscreen and video is coming to an end
      // (within the last 10 seconds), automatically reveal the recommended videos overlay.
      if (effectiveDur > const Duration(seconds: 15)) {
        final remaining = effectiveDur - val.position;
        if (isFullScreen.value &&
            remaining > Duration.zero &&
            remaining <= const Duration(seconds: 10) &&
            !hasShownNearEndMoreVideos) {
          hasShownNearEndMoreVideos = true;
          openMoreVideos();
        } else if (remaining > const Duration(seconds: 15)) {
          hasShownNearEndMoreVideos = false;
        }
      }

      if (val.position >= effectiveDur &&
          effectiveDur > Duration.zero &&
          !hasEnded) {
        hasEnded = true;
        onTrackEnded();
      } else if (val.position < effectiveDur) {
        hasEnded = false;
      }
    } catch (e, s) {
      ErrorHandler.log(
          e, stackTrace: s, tag: 'TowerPlayerController.onVpcUpdate');
    } finally {
      _isHandlingVpcUpdate = false;
    }
  }

  @override
  void onClose() {
    if (_isClosed) return;
    _isClosed = true;
    _langWorker?.dispose();
    _langWorker = null;
    WidgetsBinding.instance.removeObserver(this);
    stopSubtitleSyncTimer();
    stopCommentsAutoPlay();
    stopFactOverlayTimers();
    try {
      chewieController?.removeListener(onInternalChewieChanged);
    } catch (_) {}
    try {
      videoController?.chewieController?.removeListener(onOuterChewieChanged);
    } catch (_) {}
    TowerPlayerLifecycleHelper.disposeControllers(
      adPlayerController: adPlayerController,
      audioTrackController: audioTrackController,
      videoPlayerController: videoPlayerController,
      webFullscreenSub: webFullscreenSub,
      errorDebounceTimer: errorDebounceTimer,
      singleTapTimer: singleTapTimer,
      autoplayTimer: autoplayTimer,
      focusNode: focusNode,
      isFullScreen: isFullScreen.value,
      onAdVpcUpdate: onAdVpcUpdate,
      onVpcUpdate: _onVpcUpdate,
    );
    audioTrackController = null;
    TowerPlayerChewieConfigurator.safeDispose(chewieController);
    chewieController = null;
    TowerPlayerRegistry.unregister(this);
    if (tag != null) {
      TowerPlayerRegistry.markDisposed(tag!);
    }
    timers.cancelAll();
    overlayTranscriptAutoScrollTimer?.cancel();
    overlayTranscriptScrollController.dispose();
    if (isFullScreen.value) isFullScreen.value = false;
    if (isBackgroundAudioActive) {
      audioService?.deactivateBackgroundPlayback();
      isBackgroundAudioActive = false;
    }
    if (Get.isRegistered<AdaptiveBitrateController>(tag: tag)) {
      Get.delete<AdaptiveBitrateController>(tag: tag, force: true);
    } else {
      abr.onClose();
    }
    overlayManager.dispose();
    TowerPlayerRegistry.disposePipChannel();
    if (Get.isRegistered<PlayerLockController>(tag: tag)) {
      Get.delete<PlayerLockController>(tag: tag, force: true);
    }
    _audioAnalysisService?.onClose();
    _audioAnalysisService = null;
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    handleAppLifecycleStateChanged(state);
  }

  // ── Controller sync ──────────────────────────────────────
  void sync(VideoPlayerController vpc) {
    errorDebounceTimer?.cancel();
    hasShownNearEndMoreVideos = false;
    showMoreVideos.value = false;
    if (videoPlayerController == vpc && videoPlaybackSource != null) {
      final isInit = vpc.value.isInitialized;
      if (isInitialized.value != isInit || rxValue.value != vpc.value) {
        rxValue.value = vpc.value;
        isInitialized.value = isInit;
        if (isInit && vpc.value.aspectRatio > 0) {
          aspectRatio.value = vpc.value.aspectRatio;
        }
        isPlaying.value = !isShowingAd.value && vpc.value.isPlaying;
        update();
        rxVideoPlayerController.refresh();
      }
      return;
    }

    final (source, isInit) = TowerPlayerLifecycleHelper.syncController(
      currentVpc: videoPlayerController,
      newVpc: vpc,
      currentSource: videoPlaybackSource,
      isShowingAd: isShowingAd.value,
      onVpcUpdate: _onVpcUpdate,
    );
    videoPlayerController = vpc;
    rxVideoPlayerController.value = vpc;
    if (hasAlternateAudioTrack) {
      try {
        vpc.setVolume(0.0);
      } catch (_) {}
    }
    videoPlaybackSource = source;
    sleepTimerService.setActivePlayback(activePlayback);
    if (Get.isRegistered<AudioOnlyService>()) {
      try {
        final audioSvc = Get.find<AudioOnlyService>();
        if (audioSvc.isActive.value || audioSvc.isPlaying.value) {
          audioSvc.deactivateBackgroundPlayback();
        }
      } catch (_) {}
    }

    try {
      showFactCheckPopup.value = false;
      showCommentsPopup.value = false;
      showTranscriptPopup.value = false;
      overlayManager.close();

      rxValue.value = vpc.value;
      isInitialized.value = isInit;
      if (isInit && vpc.value.aspectRatio > 0) {
        aspectRatio.value = vpc.value.aspectRatio;
      }
      isPlaying.value = !isShowingAd.value && vpc.value.isPlaying;
      hasError.value = false;
      errorDescription.value = '';
      update();
      rxVideoPlayerController.refresh();
      if (tag != null && Get.isRegistered<VideoController>(tag: tag)) {
        final vc = Get.find<VideoController>(tag: tag);
        isAudioOnly.value = vc.isAudioOnly.value;
        playbackMode.value =
            vc.isAudioOnly.value ? PlaybackMode.audio : PlaybackMode.video;
        TowerPlayerController.globalAudioOnly = vc.isAudioOnly.value;
      } else if (Get.isRegistered<VideoController>()) {
        final vc = Get.find<VideoController>();
        isAudioOnly.value = vc.isAudioOnly.value;
        playbackMode.value =
            vc.isAudioOnly.value ? PlaybackMode.audio : PlaybackMode.video;
        TowerPlayerController.globalAudioOnly = vc.isAudioOnly.value;
      }
    } catch (e, s) {
      ErrorHandler.log(
          e, stackTrace: s, tag: 'TowerPlayerController.sync.initValues');
      isInitialized.value = false;
    }

    abr.attachVideoController(videoPlayerController);
    _initChewieController();
    update();
  }

  void _syncTracksWithVideoController() {
    final vc = videoController;
    if (vc == null) return;
    TowerPlayerTrackSyncHelper.syncTracks(
      vc: vc,
      subtitleTracks: subtitleTracks,
      activeSubLang: activeSubLang,
      setSubtitles: setSubtitles,
      audioTracks: audioTracks,
      activeAudioLang: activeAudioLang,
      setAudioLanguage: setAudioLanguage,
      videoTracks: videoTracks,
      activeVideoLang: activeVideoLang,
      setVideoLanguage: setVideoLanguage,
      chapters: chapters,
    );
  }
}
