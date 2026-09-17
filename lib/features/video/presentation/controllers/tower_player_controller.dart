import 'dart:async';
import 'dart:math';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';
import 'package:truthworld/features/video/presentation/controllers/player_lock_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_mixins/tower_mixins.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:universal_html/html.dart' as html;
import 'package:video_player/video_player.dart';

class TowerPlayerController extends BaseController
    with
        WidgetsBindingObserver,
        TowerPlayerAbrMixin,
        TowerPlayerAdMixin,
        TowerPlayerBackgroundAudioMixin,
        TowerPlayerEngagementMixin,
        TowerPlayerGesturesMixin,
        TowerPlayerKeyboardMixin,
        TowerPlayerModesMixin,
        TowerPlayerNavigationMixin,
        TowerPlayerSleepTimerMixin,
        TowerPlayerTracksMixin {
  bool _isClosed = false;
  @override
  bool get isClosed => _isClosed;

  bool get _isTransientDomError {
    final err =
        '${videoPlayerController.value.errorDescription ?? ''} ${errorDescription.value}'.toLowerCase();
    return err.contains('removed from the document') ||
        err.contains('play() request was interrupted') ||
        err.contains('the play() request was interrupted') ||
        err.contains('aborterror') ||
        err.contains('notallowederror') ||
        err.contains('media_err_aborted') ||
        err.contains('client returned a buffer') ||
        err.contains('bad_index') ||
        err.contains('pause()') ||
        err.contains('user gesture');
  }

  Timer? _errorDebounceTimer;

  TowerPlayerController({required this.videoPlayerController, this.tag}) {
    try {
      _rxValue = videoPlayerController.value.obs;
      isInitialized.value = videoPlayerController.value.isInitialized;
      aspectRatio.value = videoPlayerController.value.aspectRatio;
      isPlaying.value = videoPlayerController.value.isPlaying;
      hasError.value = false;
      errorDescription.value =
          videoPlayerController.value.errorDescription ?? '';
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TowerPlayerController.ctor');
      _rxValue = const VideoPlayerValue.uninitialized().obs;
      isInitialized.value = false;
    }
  }

  // ── Global registry ───────────────────────────────────────
  static final List<TowerPlayerController> _activePlayers = [];
  static List<TowerPlayerController> get activePlayers =>
      List.unmodifiable(_activePlayers);

  /// Find active TowerPlayerController by tag or fallback to any registered/active instance
  static TowerPlayerController? getForTagOrActive(String? tag) {
    if (tag != null &&
        tag.isNotEmpty &&
        Get.isRegistered<TowerPlayerController>(tag: tag)) {
      return Get.find<TowerPlayerController>(tag: tag);
    }
    if (Get.isRegistered<TowerPlayerController>()) {
      return Get.find<TowerPlayerController>();
    }
    if (_activePlayers.isNotEmpty) {
      if (tag != null && tag.isNotEmpty) {
        final match = _activePlayers.firstWhereOrNull((p) => p.tag == tag);
        if (match != null) return match;
      }
      return _activePlayers.last;
    }
    return null;
  }

  static const MethodChannel _pipChannel = MethodChannel(
    'com.example.truthworld/pip',
  );

  // Persistent media preferences
  static final _box = GetStorage();

  static bool get globalSubtitlesEnabled =>
      _box.read('pref_global_subtitles_enabled') ?? false;
  static set globalSubtitlesEnabled(bool value) =>
      _box.write('pref_global_subtitles_enabled', value);

  static String get globalActiveSubLang =>
      _box.read('pref_global_active_sub_lang') ?? 'Off';
  static set globalActiveSubLang(String value) =>
      _box.write('pref_global_active_sub_lang', value);

  static bool get globalAudioOnly =>
      _box.read('pref_global_audio_only') ?? false;
  static set globalAudioOnly(bool value) =>
      _box.write('pref_global_audio_only', value);

  static double get globalPlaybackSpeed =>
      _box.read('pref_global_playback_speed') ?? 1.0;
  static set globalPlaybackSpeed(double value) =>
      _box.write('pref_global_playback_speed', value);

  static String? get globalQualityPreference =>
      _box.read('pref_global_quality_preference') ?? 'Auto';
  static set globalQualityPreference(String? value) =>
      _box.write('pref_global_quality_preference', value);

  static void Function(BuildContext context, TowerPlayerController ctrl)?
  showMobileSettingsCallback;

  static void pauseAllActivePlayers({TowerPlayerController? except}) {
    for (final p in _activePlayers) {
      if (p != except && p.vv.isPlaying) p.videoPlayerController.pause();
    }
  }

  // ── Core ──────────────────────────────────────────────────
  @override
  VideoPlayerController videoPlayerController;
  @override
  ChewieController? chewieController;
  @override
  final FocusNode focusNode = FocusNode();
  @override
  final String? tag;

  void _initChewieController() {
    if (chewieController != null) {
      try {
        if (chewieController!.videoPlayerController != videoPlayerController) {
          chewieController!.pause();
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerController.initChewie.pause',
        );
      }
      try {
        chewieController!.dispose();
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerController.initChewie.dispose',
        );
      }
      chewieController = null;
    }
    chewieController = ChewieController(
      videoPlayerController: videoPlayerController,
      looping: isLooping.value,
      showControls: false,
      autoInitialize: true,
      allowedScreenSleep: false,
      placeholder: const ColoredBox(
        color: AppColors.bgPage,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
      ),
      errorBuilder: (context, errorMessage) {
        if (errorMessage.contains('removed from the document') ||
            errorMessage.contains('play() request was interrupted') ||
            errorMessage.contains('The play() request was interrupted') ||
            errorMessage.contains('AbortError') ||
            errorMessage.contains('NotAllowedError')) {
          return const SizedBox.shrink();
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.brand,
        handleColor: AppColors.brand,
        bufferedColor: AppColors.brand.withValues(alpha: 0.33),
        backgroundColor: AppColors.brand.withValues(alpha: 0.2),
      ),
      cupertinoProgressColors: ChewieProgressColors(
        playedColor: AppColors.brand,
        handleColor: AppColors.brand,
        bufferedColor: AppColors.brand.withValues(alpha: 0.33),
        backgroundColor: AppColors.brand.withValues(alpha: 0.2),
      ),
      deviceOrientationsOnEnterFullScreen:
          videoPlayerController.value.aspectRatio > 1.0
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
      deviceOrientationsAfterFullScreen: const [DeviceOrientation.portraitUp],
      systemOverlaysOnEnterFullScreen: const [],
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
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.videoController',
      );
    }
    return null;
  }

  // ── Reactive video state ──────────────────────────────────
  late Rx<VideoPlayerValue> _rxValue;
  @override
  VideoPlayerValue get vv => _rxValue.value;

  final RxBool isInitialized = false.obs;
  @override
  final RxDouble aspectRatio = 1.777.obs;
  @override
  final RxBool isPlaying = false.obs;
  @override
  final RxBool hasError = false.obs;
  final RxString errorDescription = ''.obs;
  final RxBool showFullscreenActionsDock = true.obs;
  final RxBool isZoomToFill = false.obs;
  final RxDouble zoomScale = 1.0.obs;

  String get zoomLabel {
    if (isZoomToFill.value) return 'Fill screen';
    if (zoomScale.value == 1.0) return 'Fit (1.0x)';
    final valStr = zoomScale.value % 1 == 0
        ? zoomScale.value.toInt().toString()
        : zoomScale.value.toStringAsFixed(1);
    return '${valStr}x';
  }

  void setZoomScale(double scale, {bool fill = false}) {
    if (fill) {
      isZoomToFill.value = true;
      zoomScale.value = 1.0;
      showToast('Zoom to Fill');
    } else {
      isZoomToFill.value = false;
      zoomScale.value = scale;
      final valStr = scale % 1 == 0
          ? scale.toInt().toString()
          : scale.toStringAsFixed(1);
      showToast(scale == 1.0 ? 'Original (Fit)' : 'Zoom ${valStr}x');
    }
  }

  void toggleZoomToFill() {
    if (isZoomToFill.value) {
      setZoomScale(1.0);
    } else {
      setZoomScale(1.0, fill: true);
    }
  }

  // ── UI ────────────────────────────────────────────────────
  @override
  final RxBool controlsVisible = true.obs;
  @override
  final RxBool settingsOpen = false.obs;
  final RxBool isBuffering = false.obs;
  @override
  final RxBool isDragging = false.obs;
  final Rx<Duration> dragPos = Duration.zero.obs;
  final RxString toastMessage = ''.obs;
  @override
  final RxBool isFullScreen = false.obs;
  final RxBool userExitedFullscreen = false.obs;
  final RxBool progressBarHovered = false.obs;
  @override
  final RxBool showCommentsPopup = false.obs;
  @override
  final RxBool showTranscriptPopup = false.obs;
  @override
  final RxBool showFactCheckPopup = false.obs;
  @override
  final RxBool showLiveChat = false.obs;

  // ── Ad State Bridge ──────────────────────────────────────
  VideoPlayerController? _audioTrackController;

  bool get isPremiumUser {
    try {
      if (!Get.isRegistered<AuthService>()) return false;
      return AuthService.to.isPremiumUser.value;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.isPremiumUser',
      );
      return false;
    }
  }

  /// Determines if ads should be suppressed based on user's active premium plan and mode.
  /// - TruthWorld Premium ($2) & Fact-Checked ($3): Ad-free for all playback modes.
  /// - Audio Premium (₹40): Ad-free specifically when playing in Audio-only Mode.
  bool get shouldSuppressAds {
    try {
      if (!Get.isRegistered<AuthService>()) return false;
      final auth = AuthService.to;
      if (!auth.isPremiumUser.value) return false;
      final planId = auth.premiumPlanId.value;
      if (planId == 'audio_monthly') {
        return isAudioOnly.value || TowerPlayerController.globalAudioOnly;
      }
      return true;
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.shouldSuppressAds',
      );
      return false;
    }
  }

  // ── Sleep timer & Lock Screen ─────────────────────────────
  @override
  SleepTimerService get sleepTimerService => SleepTimerService.to;
  late final PlayerLockController lockController = Get.put(
    PlayerLockController(),
    tag: tag,
  );

  RxInt get sleepTimerRemainingSeconds => sleepTimerService.remainingSeconds;
  RxBool get isSleepTimerActive => sleepTimerService.isActive.obs;
  RxBool get isSleepTimerAtEndOfVideo => sleepTimerService.isAtEndOfVideo.obs;

  // ── Playback ──────────────────────────────────────────────
  @override
  final RxDouble playbackSpeed = 1.0.obs;
  @override
  final RxBool isLooping = false.obs;

  // ── Playback Authority ────────────────────────────────────
  VideoPlaybackSource? _videoPlaybackSource;

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
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.activePlayback.sync',
      );
    }
    return _videoPlaybackSource ??= VideoPlaybackSource(videoPlayerController);
  }

  // ── Global Subtitle Appearance Options ─────────────────────
  static final RxString globalSubtitleFontSizeOption = 'Normal'.obs;
  static final Rx<Color> globalSubtitleTextColor = Colors.white.obs;
  static final Rx<Color> globalSubtitleBgColor = Colors.black.obs;
  static final RxDouble globalSubtitleBgOpacity = 0.75.obs;
  static final RxString globalSubtitleEdgeStyle = 'Drop Shadow'.obs;
  static final RxString globalSubtitleFontFamily = 'Roboto'.obs;

  static void resetSubtitleStyleToDefault() {
    globalSubtitleFontSizeOption.value = 'Normal';
    globalSubtitleTextColor.value = Colors.white;
    globalSubtitleBgColor.value = Colors.black;
    globalSubtitleBgOpacity.value = 0.75;
    globalSubtitleEdgeStyle.value = 'Drop Shadow';
    globalSubtitleFontFamily.value = 'Roboto';
  }

  static TextStyle getSubtitleTextStyle({
    required String fontFamily,
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    required List<Shadow> shadows,
  }) {
    switch (fontFamily) {
      case 'Merriweather':
        return GoogleFonts.merriweather(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          shadows: shadows,
        );
      case 'Roboto Mono':
        return GoogleFonts.robotoMono(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          shadows: shadows,
        );
      case 'Oswald':
        return GoogleFonts.oswald(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          shadows: shadows,
        );
      case 'Outfit':
        return GoogleFonts.outfit(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          shadows: shadows,
        );
      case 'Roboto':
      default:
        return GoogleFonts.roboto(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          shadows: shadows,
        );
    }
  }

  // ── Volume ────────────────────────────────────────────────
  @override
  final RxDouble volume = 1.0.obs;
  @override
  final RxBool isMuted = false.obs;
  final RxBool volumeSliderVis = false.obs;
  double _volumeBeforeMute = 1;

  // ── Stats for Nerds ───────────────────────────────────────
  final RxBool showStatsForNerds = false.obs;

  double get bufferHealthSeconds {
    final pos = videoPlayerController.value.position;
    final buffered = videoPlayerController.value.buffered;
    if (buffered.isEmpty) return 0;
    for (final r in buffered) {
      if (r.start <= pos && r.end >= pos) {
        return (r.end - pos).inMilliseconds / 1000.0;
      }
    }
    for (final r in buffered) {
      if (r.start > pos) return (r.end - r.start).inMilliseconds / 1000.0;
    }
    return 0;
  }

  // ── Analytics ─────────────────────────────────────────────
  final List<PlayerEvent> _events = [];
  int _totalWatchSeconds = 0;

  // ── Retry ─────────────────────────────────────────────────
  int _retryCount = 0;
  static const int _maxRetries = 3;

  // ── Internal state ────────────────────────────────────────
  final _timers = TimerBag();
  DateTime _lastTrackSync = DateTime(2000);
  @override
  bool hasEnded = false;

  // ─── Lifecycle ───────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isClosed) {
        for (final p in _activePlayers) {
          if (p != this && p.vv.isPlaying) {
            p.videoPlayerController.pause();
          }
        }
      }
    });
    if (!_activePlayers.contains(this)) _activePlayers.add(this);

    try {
      if (Get.isRegistered<UserSettingsController>()) {
        final settings = UserSettingsController.to;
        showStatsForNerds.value = settings.playback.value.statsForNerdsEnabled;
        isAutoplay.value = settings.playback.value.autoplayNext;
      } else if (Get.isRegistered<VideoController>(tag: tag)) {
        isAutoplay.value = Get.find<VideoController>(tag: tag).isAutoplay.value;
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.loadSettings',
      );
    }

    _attachVideoListener();
    startHideTimer();
    initABR();
    initAudioService();
    _trackAnalytics(PlayerEvent('player_init'));

    final isFromMiniplayer =
        (Get.arguments is Map && Get.arguments['isFromMiniplayer'] == true) ||
            VideoPlaybackHandoff.hasActivePosition(
              tag ?? videoController?.video.id ?? '',
            ) ||
            videoPlayerController.value.position > Duration.zero;

    if (isFromMiniplayer) {
      preRollPlayed = true;
    }

    final initialSponsorAd = Get.isRegistered<AdService>()
        ? AdService.to.getSponsorAdForVideo(videoController?.video.id)
        : null;
    final hasInitialAds = !shouldSuppressAds &&
        !isFromMiniplayer &&
        Get.isRegistered<AdService>() &&
        (initialSponsorAd != null ||
            AdService.to.getSkippableVideoAds().isNotEmpty);
    if (hasInitialAds && !preRollPlayed) {
      preRollPlayed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isClosed) return;
        if (videoPlayerController.value.isPlaying) {
          try {
            videoPlayerController.pause();
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'TowerPlayerController.pausePreRoll',
            );
          }
        }
        if (initialSponsorAd != null) {
          startSponsorAd(initialSponsorAd, isPreRoll: true);
        } else {
          startAd(isPreRoll: true);
        }
      });
    }

    subtitlesEnabled.value = TowerPlayerController.globalSubtitlesEnabled;
    activeSubLang.value = TowerPlayerController.globalActiveSubLang;
    final shouldAudioOnly = TowerPlayerController.globalAudioOnly ||
        (Get.arguments is Map && Get.arguments['isAudioOnly'] == true);
    isAudioOnly.value = shouldAudioOnly;
    playbackSpeed.value = TowerPlayerController.globalPlaybackSpeed;

    if (playbackSpeed.value != 1.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isClosed &&
            (videoPlayerController.value.playbackSpeed - playbackSpeed.value)
                    .abs() >
                0.001) {
          try {
            videoPlayerController.setPlaybackSpeed(playbackSpeed.value);
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'TowerPlayerController.setPlaybackSpeed',
            );
          }
        }
      });
    }

    if (shouldAudioOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        toggleAudioOnly();
      });
    }

    _initChewieController();

    if (kIsWeb) {
      webFullscreenSub = html.document.onFullscreenChange.listen((_) {
        final isFs = html.document.fullscreenElement != null;
        if (isFullScreen.value != isFs) {
          isFullScreen.value = isFs;
          try {
            final vc = videoController;
            if (vc != null) {
              vc.isFullScreen.value = isFs;
            }
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'TowerPlayerController.webFullscreenSync',
            );
          }
          onInteraction();
        }
      });
    }

    if (!Get.isRegistered<TowerPlayerController>(tag: tag)) {
      Get.put<TowerPlayerController>(this, tag: tag);
    }

    if (!kIsWeb) {
      _pipChannel.setMethodCallHandler((call) async {
        if (call.method == 'onPipModeChanged') {
          final isInPip = call.arguments as bool;
          for (final player in _activePlayers) {
            player.isPiP.value = isInPip;
            if (isInPip) {
              player.controlsVisible.value = false;
              player.settingsOpen.value = false;
            }
          }
        }
      });
    }
  }

  void _attachVideoListener() {
    _videoPlaybackSource = VideoPlaybackSource(videoPlayerController);
    sleepTimerService.setActivePlayback(activePlayback);
    videoPlayerController.addListener(_onVpcUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      try {
        var volumeScale = 1.0;
        if (Get.isRegistered<UserSettingsController>()) {
          final mode =
              UserSettingsController.to.playback.value.volumeNormalizationMode;
          switch (mode) {
            case 'Light':
              volumeScale = 0.90;
            case 'Standard':
              volumeScale = 0.80;
            case 'Aggressive':
              volumeScale = 0.70;
            case 'Off':
            default:
              volumeScale = 1.0;
          }
        }
        if ((videoPlayerController.value.volume - volumeScale).abs() > 0.001) {
          videoPlayerController.setVolume(volumeScale);
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerController.volumeScale',
        );
      }
    });
  }

  // ── VPC listener ──────────────────────────────────────────
  void _onVpcUpdate() {
    try {
      final val = videoPlayerController.value;
      _rxValue.value = val;
      isBuffering.value = val.isBuffering;
      playbackSpeed.value = val.playbackSpeed;
      if (isLooping.value != val.isLooping) isLooping.value = val.isLooping;

      if (isInitialized.value != val.isInitialized) {
        isInitialized.value = val.isInitialized;
      }
      if (aspectRatio.value != val.aspectRatio) {
        aspectRatio.value = val.aspectRatio;
        updateAutoPip(isPlaying.value);
      }
      if (isPlaying.value != val.isPlaying) {
        isPlaying.value = val.isPlaying;
        updateAutoPip(val.isPlaying);
      }
      final isErr = val.hasError && !_isTransientDomError;
      if (isErr) {
        var isSuppressed = false;
        try {
          final vc = videoController;
          if (vc != null &&
              (vc.isAutoSwitching.value || vc.isRecoveringFromFormatError)) {
            isSuppressed = true;
          }
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'TowerPlayerController.vpcUpdate.checkSuppressed',
          );
        }

        if (!isSuppressed) {
          _errorDebounceTimer?.cancel();
          _errorDebounceTimer = Timer(const Duration(milliseconds: 800), () {
            if (!_isClosed &&
                videoPlayerController.value.hasError &&
                !_isTransientDomError) {
              hasError.value = true;
            }
          });
        }
      } else {
        _errorDebounceTimer?.cancel();
        if (hasError.value) {
          hasError.value = false;
        }
      }
      if (errorDescription.value != (val.errorDescription ?? '')) {
        errorDescription.value = val.errorDescription ?? '';
      }

      // Sync alternate audio player
      final audioCtrl = _audioTrackController;
      if (audioCtrl != null && audioCtrl.value.isInitialized) {
        if (videoPlayerController.value.volume > 0.0) {
          videoPlayerController.setVolume(0);
        }
        final targetVol = isMuted.value ? 0.0 : volume.value;
        if (audioCtrl.value.volume != targetVol) {
          audioCtrl.setVolume(targetVol);
        }
        if (val.playbackSpeed != audioCtrl.value.playbackSpeed) {
          audioCtrl.setPlaybackSpeed(val.playbackSpeed);
        }

        final audioDur = audioCtrl.value.duration;
        if (audioDur > Duration.zero && val.position > audioDur) {
          if (audioCtrl.value.isPlaying) {
            audioCtrl.pause();
          }
        } else {
          if (val.isPlaying && !audioCtrl.value.isPlaying) {
            audioCtrl.play();
          } else if (!val.isPlaying && audioCtrl.value.isPlaying) {
            audioCtrl.pause();
          }
          final drift =
              (val.position - audioCtrl.value.position).inMilliseconds.abs();
          if (drift > 300) {
            audioCtrl.seekTo(val.position);
          }
        }
      }

      // Ad triggers
      final hasRealVideoAds =
          Get.isRegistered<AdService>() &&
          (AdService.to.getSkippableVideoAds().isNotEmpty ||
              AdService.to.getSponsorAdForVideo(videoController?.video.id) !=
                  null);
      if (!shouldSuppressAds && hasRealVideoAds) {
        final sponsorAd = Get.isRegistered<AdService>()
            ? AdService.to.getSponsorAdForVideo(videoController?.video.id)
            : null;

        if (!preRollPlayed && (val.isPlaying || val.isInitialized)) {
          preRollPlayed = true;
          if (sponsorAd != null) {
            startSponsorAd(sponsorAd, isPreRoll: true);
            return;
          } else if (AdService.to.getSkippableVideoAds().isNotEmpty) {
            startAd(isPreRoll: true);
            return;
          }
        }
      }

      if (isShowingAd.value) {
        if (val.isPlaying) {
          videoPlayerController.pause();
        }
        if (_audioTrackController != null &&
            _audioTrackController!.value.isPlaying) {
          _audioTrackController!.pause();
        }
        return;
      }

      if (!shouldSuppressAds && !isShowingAd.value && hasRealVideoAds) {
        final currentPos = val.position;
        final totalDur = val.duration;

        final sponsorAd = Get.isRegistered<AdService>()
            ? AdService.to.getSponsorAdForVideo(videoController?.video.id)
            : null;

        if (sponsorAd != null &&
            !sponsorMidRollPlayed &&
            totalDur.inSeconds > 420 &&
            currentPos.inSeconds >= 420 &&
            val.isPlaying) {
          sponsorMidRollPlayed = true;
          startSponsorAd(sponsorAd, isPreRoll: false);
          return;
        } else if (sponsorAd == null &&
            !midRollPlayed &&
            totalDur.inSeconds > 180 &&
            currentPos.inSeconds >= (totalDur.inSeconds / 2).floor() &&
            val.isPlaying) {
          midRollPlayed = true;
          startAd(isPreRoll: false);
          return;
        }
      }

      // Subtitle sync
      if (val.isPlaying &&
          subtitlesEnabled.value &&
          subtitleSegments.isNotEmpty) {
        startSubtitleSyncTimer();
      } else {
        stopSubtitleSyncTimer();
      }
      syncActiveSubtitle();

      // Chapter sync
      if (chapters.isNotEmpty) {
        final chapter = binarySearchChapter(val.position);
        if (currentChapter.value != chapter) currentChapter.value = chapter;
      } else {
        currentChapter.value = null;
      }

      // Active claim sync
      syncActiveClaim(val.position);

      // Throttled track sync
      final now = DateTime.now();
      if (now.difference(_lastTrackSync).inSeconds >= 2) {
        _lastTrackSync = now;
        _syncTracksWithVideoController();
      }

      if (isErr && _retryCount < _maxRetries) _scheduleRetry();

      if (sleepTimerService.mode.value == SleepTimerMode.endOfVideo) {
        final rem = (val.duration - val.position).inSeconds;
        sleepTimerService.remainingSeconds.value = rem.clamp(
          0,
          double.maxFinite.toInt(),
        );
      }

      if (val.position >= val.duration &&
          val.duration > Duration.zero &&
          !hasEnded) {
        hasEnded = true;
        onTrackEnded();
      } else if (val.position < val.duration) {
        hasEnded = false;
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.onVpcUpdate',
      );
    }
  }

  @override
  void onClose() {
    _isClosed = true;
    WidgetsBinding.instance.removeObserver(this);
    stopSubtitleSyncTimer();
    stopCommentsAutoPlay();
    try {
      chewieController?.removeListener(onInternalChewieChanged);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.onClose.removeInternalChewie',
      );
    }
    try {
      videoController?.chewieController?.removeListener(onOuterChewieChanged);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.onClose.removeOuterChewie',
      );
    }
    if (adPlayerController != null) {
      try {
        adPlayerController!.removeListener(onAdVpcUpdate);
        adPlayerController!.dispose();
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerController.onClose.adPlayer',
        );
      }
    }
    if (_audioTrackController != null) {
      try {
        _audioTrackController!.dispose();
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerController.onClose.audioTrack',
        );
      }
      _audioTrackController = null;
    }
    if (chewieController != null) {
      try {
        chewieController!.pause();
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerController.onClose.pauseChewie',
        );
      }
      try {
        chewieController!.dispose();
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerController.onClose.disposeChewie',
        );
      }
      chewieController = null;
    }
    _activePlayers.remove(this);
    autoplayTimer?.cancel();
    _timers.cancelAll();
    webFullscreenSub?.cancel();
    if (isFullScreen.value) {
      isFullScreen.value = false;
      if (kIsWeb) {
        try {
          if (html.document.fullscreenElement != null) {
            html.document.exitFullscreen();
          }
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'TowerPlayerController.onClose.exitFullscreen',
          );
        }
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      }
    }
    _errorDebounceTimer?.cancel();
    singleTapTimer?.cancel();
    focusNode.dispose();
    try {
      videoPlayerController.removeListener(_onVpcUpdate);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.onClose.removeVpcListener',
      );
    }
    if (isBackgroundAudioActive) {
      audioService?.deactivateBackgroundPlayback();
      isBackgroundAudioActive = false;
    }
    abr.onClose();
    if (!kIsWeb) {
      _pipChannel.setMethodCallHandler(null);
    }
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    handleAppLifecycleStateChanged(state);
  }

  // ── Controller sync ──────────────────────────────────────
  void sync(VideoPlayerController vpc) {
    _errorDebounceTimer?.cancel();
    if (videoPlayerController == vpc && _videoPlaybackSource != null) return;
    try {
      videoPlayerController.removeListener(_onVpcUpdate);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.sync.removeVpcListener',
      );
    }
    try {
      _videoPlaybackSource?.dispose();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.sync.disposePlaybackSource',
      );
    }

    videoPlayerController = vpc;
    _videoPlaybackSource = VideoPlaybackSource(vpc);
    sleepTimerService.setActivePlayback(activePlayback);

    if (isShowingAd.value) {
      try {
        videoPlayerController.pause();
        videoPlayerController.seekTo(Duration.zero);
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'TowerPlayerController.sync.pauseAd',
        );
      }
    }

    try {
      _rxValue.value = vpc.value;
      isInitialized.value = vpc.value.isInitialized;
      aspectRatio.value = vpc.value.aspectRatio;
      isPlaying.value = !isShowingAd.value && vpc.value.isPlaying;
      hasError.value = false;
      errorDescription.value = '';
      if (tag != null && Get.isRegistered<VideoController>(tag: tag)) {
        isAudioOnly.value =
            Get.find<VideoController>(tag: tag).isAudioOnly.value;
      } else if (Get.isRegistered<VideoController>()) {
        isAudioOnly.value = Get.find<VideoController>().isAudioOnly.value;
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.sync.initValues',
      );
      isInitialized.value = false;
    }

    try {
      videoPlayerController.addListener(_onVpcUpdate);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.sync.addListener',
      );
    }
    abr.attachVideoController(videoPlayerController);
    _initChewieController();
    update();
  }

  void _syncTracksWithVideoController() {
    try {
      if (!Get.isRegistered<VideoController>(tag: tag)) return;
      final vc = Get.find<VideoController>(tag: tag);

      if (vc.availableSubtitles.isNotEmpty &&
          (subtitleTracks.isEmpty ||
              subtitleTracks.length != vc.availableSubtitles.length)) {
        subtitleTracks.assignAll(
          vc.availableSubtitles
              .map(
                (t) => SubtitleTrack(
                  label: t.label,
                  langCode: t.langCode,
                  url: t.url,
                  isDefault: t.isDefault,
                ),
              )
              .toList(),
        );

        SubtitleTrack? bestTrack;
        if (Get.isRegistered<UserLanguagesService>()) {
          final service = UserLanguagesService.to;
          bestTrack = subtitleTracks.firstWhereOrNull(
            (t) => service.isLanguageMatch(
              t.label,
              t.langCode,
              service.primaryLanguage.value,
            ),
          );
          if (bestTrack == null) {
            for (final lang in service.secondaryLanguages) {
              bestTrack = subtitleTracks.firstWhereOrNull(
                (t) => service.isLanguageMatch(t.label, t.langCode, lang),
              );
              if (bestTrack != null) break;
            }
          }
          if (bestTrack == null) {
            for (final lang in service.knownLanguages) {
              bestTrack = subtitleTracks.firstWhereOrNull(
                (t) => service.isLanguageMatch(t.label, t.langCode, lang),
              );
              if (bestTrack != null) break;
            }
          }
        }

        if (bestTrack != null) {
          setSubtitles(enabled: true, track: bestTrack);
        } else if (TowerPlayerController.globalSubtitlesEnabled) {
          final prefLang = TowerPlayerController.globalActiveSubLang;
          final match = subtitleTracks.firstWhereOrNull(
            (t) => t.label == prefLang,
          );
          if (match != null) {
            setSubtitles(enabled: true, track: match);
          } else if (subtitleTracks.isNotEmpty && activeSubLang.value.isEmpty) {
            setSubtitles(enabled: true, track: subtitleTracks.first);
          }
        }
      }

      if (vc.availableAudioTracks.isNotEmpty &&
          (audioTracks.isEmpty ||
              audioTracks.length != vc.availableAudioTracks.length)) {
        audioTracks.assignAll(
          vc.availableAudioTracks
              .map(
                (t) => AudioTrack(
                  label: t.label,
                  langCode: t.langCode,
                  type: t.type,
                  url: t.url,
                ),
              )
              .toList(),
        );

        AudioTrack? bestAudio;
        if (Get.isRegistered<UserLanguagesService>()) {
          final service = UserLanguagesService.to;
          bestAudio = audioTracks.firstWhereOrNull(
            (t) => service.isLanguageMatch(
              t.label,
              t.langCode,
              service.primaryLanguage.value,
            ),
          );
          if (bestAudio == null) {
            for (final lang in service.secondaryLanguages) {
              bestAudio = audioTracks.firstWhereOrNull(
                (t) => service.isLanguageMatch(t.label, t.langCode, lang),
              );
              if (bestAudio != null) break;
            }
          }
          if (bestAudio == null) {
            for (final lang in service.knownLanguages) {
              bestAudio = audioTracks.firstWhereOrNull(
                (t) => service.isLanguageMatch(t.label, t.langCode, lang),
              );
              if (bestAudio != null) break;
            }
          }
        }

        if (bestAudio != null) {
          setAudioLanguage(bestAudio);
        } else if (audioTracks.isNotEmpty) {
          activeAudioLang.value = audioTracks.first.label;
        }
      }

      final displayChapters = vc.getDisplayChapters();
      if (displayChapters.isNotEmpty &&
          chapters.length != displayChapters.length) {
        chapters.assignAll(displayChapters);
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.syncTracksWithVideoController',
      );
    }
  }

  @override
  Future<void> togglePlayPause() async {
    cancelPendingTap();
    if (isShowingAd.value) {
      togglePlayPauseAd();
      return;
    }
    try {
      if (activePlayback.isPlaying) {
        await activePlayback.pause();
        await _audioTrackController?.pause();
        _stopWatchTimer();
        _trackAnalytics(
          PlayerEvent(
            'pause',
            data: {'position': activePlayback.position.inSeconds},
          ),
        );
      } else {
        if (activePlayback.duration > Duration.zero &&
            activePlayback.position >= activePlayback.duration) {
          await activePlayback.seek(Duration.zero);
          await _audioTrackController?.seekTo(Duration.zero);
        }
        pauseAllActivePlayers(except: this);
        HoverPreviewCoordinator.globalMute.value = true;
        await activePlayback.play();
        await _audioTrackController?.play();
        _startWatchTimer();
        _trackAnalytics(
          PlayerEvent(
            'play',
            data: {'position': activePlayback.position.inSeconds},
          ),
        );
      }
      onInteraction();
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.togglePlayPause',
      );
    }
  }

  @override
  Future<void> seekTo(Duration pos) async {
    try {
      hasEnded = false;
      await activePlayback.seek(pos);
      syncActiveSubtitle();
      if (_audioTrackController != null &&
          _audioTrackController!.value.isInitialized) {
        final audioDur = _audioTrackController!.value.duration;
        if (audioDur > Duration.zero && pos <= audioDur) {
          await _audioTrackController!.seekTo(pos);
        } else {
          await _audioTrackController!.pause();
        }
      }
      onInteraction();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TowerPlayerController.seekTo');
    }
  }

  @override
  Future<void> seekRelative(
    int seconds, {
    bool showFeedbackToast = true,
  }) async {
    final current = activePlayback.position;
    final total = activePlayback.duration;
    final maxSecs = total.inSeconds > 0 ? total.inSeconds : 1;
    final newPos = Duration(
      seconds: (current.inSeconds + seconds).clamp(0, maxSecs),
    );
    await seekTo(newPos);
    if (showFeedbackToast) {
      showToast(seconds > 0 ? '+${seconds}s' : '${seconds}s');
    }
  }

  // ─── Volume ──────────────────────────────────────────────
  @override
  void setVolume(double vol) {
    volume.value = vol.clamp(0.0, 1.0);
    isMuted.value = vol == 0;
    try {
      if (_audioTrackController != null) {
        videoPlayerController.setVolume(0);
        _audioTrackController!.setVolume(isMuted.value ? 0.0 : volume.value);
      } else {
        videoPlayerController.setVolume(isMuted.value ? 0.0 : volume.value);
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.setVolume',
      );
    }
    if (isAudioOnly.value) audioService?.setVolume(volume.value);
    onInteraction();
  }

  @override
  void toggleMute() {
    if (isMuted.value) {
      setVolume(_volumeBeforeMute);
    } else {
      _volumeBeforeMute = volume.value;
      setVolume(0);
    }
  }

  IconData get volumeIcon {
    if (isMuted.value || volume.value == 0) return Icons.volume_off_rounded;
    if (volume.value < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  // ─── Speed ───────────────────────────────────────────────
  @override
  void setSpeed(double speed) {
    try {
      videoPlayerController.setPlaybackSpeed(speed);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.setSpeed.video',
      );
    }
    try {
      _audioTrackController?.setPlaybackSpeed(speed);
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerController.setSpeed.audioTrack',
      );
    }
    playbackSpeed.value = speed;
    TowerPlayerController.globalPlaybackSpeed = speed;
    activePanel.value = '';
    _trackAnalytics(PlayerEvent('speed_change', data: {'speed': speed}));
  }

  // ─── Toast ───────────────────────────────────────────────
  @override
  void showToast(String msg) {
    toastMessage.value = msg;
    _timers.set(
      'toast',
      Duration(milliseconds: PT.kToastDurationMs.toInt()),
      () => toastMessage.value = '',
    );
  }

  // ─── Error recovery ──────────────────────────────────────
  void _scheduleRetry() {
    _retryCount++;
    _timers.set(
      'retry',
      Duration(seconds: pow(2, _retryCount).toInt()),
      () async {
        try {
          await videoPlayerController.initialize();
          await videoPlayerController.play();
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'TowerPlayerController.scheduleRetry',
          );
        }
      },
    );
  }

  void retryManual() {
    _retryCount = 0;
    _scheduleRetry();
  }

  // ─── Analytics ───────────────────────────────────────────
  void _trackAnalytics(PlayerEvent event) => _events.add(event);

  void _startWatchTimer() {
    _timers.setPeriodic(
      'watch',
      const Duration(seconds: 1),
      (_) => _totalWatchSeconds++,
    );
  }

  void _stopWatchTimer() => _timers.cancel('watch');

  // ── Mixin Bridge Hooks & Backward-Compatible Delegators ────
  @override
  Rx<VideoPlayerValue> get rxValue => _rxValue;

  @override
  PlaybackSource? get videoPlaybackSource => _videoPlaybackSource;

  @override
  VideoPlayerController? get audioTrackController => _audioTrackController;

  @override
  set audioTrackController(VideoPlayerController? ctrl) =>
      _audioTrackController = ctrl;

  @override
  void startWatchTimer() => _startWatchTimer();

  @override
  void stopWatchTimer() => _stopWatchTimer();

  @override
  void resetRetryCount() {
    _retryCount = 0;
  }

  @override
  bool get isShowingAdValue => isShowingAd.value;

  @override
  bool get isFullScreenValue => isFullScreen.value;

  @override
  TimerBag get timers => _timers;

  @override
  int get seekStepSeconds {
    if (Get.isRegistered<UserSettingsController>()) {
      return UserSettingsController.to.playback.value.seekDurationSeconds;
    }
    return 10;
  }

  @override
  void trackAnalytics(PlayerEvent event) => _trackAnalytics(event);

  // Backward-compatible delegators for private calls
  SubtitleSegment? _findSubtitle(Duration pos) => findSubtitle(pos);
  VideoChapter? _binarySearchChapter(Duration pos) => binarySearchChapter(pos);
  void _startCommentsAutoPlay() => startCommentsAutoPlay();
  void _stopCommentsAutoPlay() => stopCommentsAutoPlay();
  void _updateAutoPlayComment() => updateAutoPlayComment();
  void _navigateToVideo(Video video, VideoController vc) =>
      executeNavigateToVideo(video, vc);
  void _onTrackEnded() => onTrackEnded();
  void _initABR() => initABR();
  void _initAudioService() => initAudioService();
  Future<void> _handleEnterBackground() => handleEnterBackground();
  Future<void> _handleExitBackground() => handleExitBackground();
  String _resolveBackgroundMediaUrl(VideoController vc) =>
      resolveBackgroundMediaUrl(vc);
}
