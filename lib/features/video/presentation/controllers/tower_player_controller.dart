import 'dart:async';
import 'dart:convert';
import 'package:universal_html/js.dart' as js;
import 'dart:math';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:chewie/chewie.dart';
import 'adaptive_birate_controller.dart';
import 'audio_only_service.dart';
import 'video_controller.dart';
import '../../data/models/video.dart';
import '../../data/models/video_chapter.dart';
import '../widgets/language_request_dialog.dart';
import '../views/player/models/player_models.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/features/video/presentation/views/player/dialogs/keyboard_shortcuts_dialog.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/ad_service.dart';

class TowerPlayerController extends GetxController {
  // ── Global registry ───────────────────────────────────────
  static final List<TowerPlayerController> _activePlayers = [];

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

  static void pauseAllActivePlayers({TowerPlayerController? except}) {
    for (final p in _activePlayers) {
      if (p != except && p.vv.isPlaying) p.videoPlayerController.pause();
    }
  }

  // ── Core ──────────────────────────────────────────────────
  VideoPlayerController videoPlayerController;
  ChewieController? chewieController;
  final FocusNode focusNode = FocusNode();
  final String? tag;

  void _initChewieController() {
    chewieController?.dispose();
    chewieController = ChewieController(
      videoPlayerController: videoPlayerController,
      autoPlay: false,
      looping: isLooping.value,
      showControls: false, // Maintain custom overlays
      autoInitialize: true,
      allowedScreenSleep: false,
      aspectRatio: null,
      placeholder: Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF9B30FF)),
        ),
      ),
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
      materialProgressColors: ChewieProgressColors(
        playedColor: const Color(0xFF9B30FF),
        handleColor: const Color(0xFF9B30FF),
        bufferedColor: const Color(0x559B30FF),
        backgroundColor: const Color(0x339B30FF),
      ),
      cupertinoProgressColors: ChewieProgressColors(
        playedColor: const Color(0xFF9B30FF),
        handleColor: const Color(0xFF9B30FF),
        bufferedColor: const Color(0x559B30FF),
        backgroundColor: const Color(0x339B30FF),
      ),
      deviceOrientationsOnEnterFullScreen:
          videoPlayerController.value.aspectRatio > 1.0
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
      deviceOrientationsAfterFullScreen: const [DeviceOrientation.portraitUp],
      systemOverlaysOnEnterFullScreen: const [],
      systemOverlaysAfterFullScreen: SystemUiOverlay.values,
    );
    _setupChewieListeners();
  }

  TowerPlayerController({required this.videoPlayerController, this.tag}) {
    _rxValue = videoPlayerController.value.obs;
  }

  VideoController? get videoController {
    if (tag == null) return null;
    try {
      if (Get.isRegistered<VideoController>(tag: tag)) {
        return Get.find<VideoController>(tag: tag);
      }
    } catch (_) {}
    return null;
  }

  // ── Reactive video state ──────────────────────────────────
  late Rx<VideoPlayerValue> _rxValue;
  VideoPlayerValue get vv => _rxValue.value;

  // ── UI ────────────────────────────────────────────────────
  final RxBool controlsVisible = true.obs;
  final RxBool settingsOpen = false.obs;
  final RxBool isBuffering = false.obs;
  final RxBool isDragging = false.obs;
  final Rx<Duration> dragPos = Duration.zero.obs;
  final RxBool showDoubleTapLeft = false.obs;
  final RxBool showDoubleTapRight = false.obs;
  final RxString toastMessage = ''.obs;
  final RxBool isFullScreen = false.obs;
  final RxBool userExitedFullscreen = false.obs;
  final RxBool progressBarHovered = false.obs; // desktop hover
  final RxBool showCommentsPopup = false.obs;
  final RxBool showTranscriptPopup = false.obs;

  // ── Ad Player State ────────────────────────────────────────
  final RxBool isShowingAd = false.obs;
  final Rxn<MockAd> currentAd = Rxn<MockAd>();
  final RxInt adTimeRemaining = 0.obs;
  final RxInt skipCountdown = 0.obs;
  final RxBool adCanSkip = false.obs;
  VideoPlayerController? adPlayerController;
  VideoPlayerController? _audioTrackController;
  bool _preRollPlayed = false;
  bool _midRollPlayed = false;
  bool _sponsorMidRollPlayed = false;

  bool get isPremiumUser {
    try {
      if (!Get.isRegistered<AuthService>()) return false;
      return AuthService.to.isPremiumUser.value;
    } catch (_) {
      return false;
    }
  }

  // ── Navigation lock — prevent concurrent video switches ────
  final RxBool isNavigatingToVideo = false.obs;

  StreamSubscription? _webFullscreenSub;

  // ── Long-press 2× speed ───────────────────────────────────
  final RxBool isLongPressSpeedUp = false.obs;
  double _preLongPressSpeed = 1.0;

  // ── Sleep timer ───────────────────────────────────────────
  final RxInt sleepTimerRemainingSeconds = 0.obs;
  final RxBool isSleepTimerActive = false.obs;

  // ── Swipe gesture HUD ─────────────────────────────────────
  final RxDouble brightness = 1.0.obs;
  final RxBool showSwipeVolumeHUD = false.obs;
  final RxBool showSwipeBrightnessHUD = false.obs;
  final RxDouble swipeVolumeLevel = 0.0.obs;
  final RxDouble swipeBrightnessLevel = 0.0.obs;

  // ── Settings sub-panels ───────────────────────────────────
  final RxString activePanel = ''.obs;

  // ── Playback ──────────────────────────────────────────────
  final RxDouble playbackSpeed = 1.0.obs;
  final RxBool isLooping = false.obs;
  final RxBool isAutoplay = true.obs;

  void toggleAutoplay() {
    isAutoplay.toggle();
    try {
      if (Get.isRegistered<VideoController>(tag: tag)) {
        Get.find<VideoController>(tag: tag).isAutoplay.value = isAutoplay.value;
      }
    } catch (_) {}
    showToast(isAutoplay.value ? 'Autoplay ON' : 'Autoplay OFF');
  }

  // ── ABR / quality ─────────────────────────────────────────
  final AdaptiveBitrateController abr = AdaptiveBitrateController();
  List<ResolutionTier> resolutionTiers = [];

  // ── Audio only ────────────────────────────────────────────
  final RxBool isAudioOnly = false.obs;
  AudioOnlyService? _audioService;

  // ── Subtitles ─────────────────────────────────────────────
  final RxBool subtitlesEnabled = false.obs;
  final RxString activeSubLang = 'Off'.obs;
  final RxList<SubtitleTrack> subtitleTracks = <SubtitleTrack>[].obs;
  final RxList<SubtitleSegment> subtitleSegments = <SubtitleSegment>[].obs;
  final RxString currentSubtitle = ''.obs;

  // ── Audio tracks ──────────────────────────────────────────
  final RxString activeAudioLang = 'English'.obs;
  final RxList<AudioTrack> audioTracks = <AudioTrack>[].obs;

  // ── Content metadata ──────────────────────────────────────
  ContentMetadata contentMeta = const ContentMetadata(
    rating: 'U/A 16+',
    genre: 'Action · Drama',
    releaseYear: '2024',
    duration: '2h 14m',
    director: 'N/A',
    cast: 'N/A',
    advisories: ['Violence', 'Strong Language'],
  );

  // ── Volume ────────────────────────────────────────────────
  final RxDouble volume = 1.0.obs;
  final RxBool isMuted = false.obs;
  final RxBool volumeSliderVis = false.obs;
  double _volumeBeforeMute = 1.0;

  // ── Seek preview ──────────────────────────────────────────
  final RxBool seekPreviewVis = false.obs;
  final Rx<Duration> seekPreviewPos = Duration.zero.obs;
  final RxDouble seekPreviewX = 0.0.obs;

  // ── PiP ───────────────────────────────────────────────────
  final RxBool isPiP = false.obs;

  // ── Stats for Nerds ───────────────────────────────────────
  final RxBool showStatsForNerds = false.obs;

  double get bufferHealthSeconds {
    final pos = videoPlayerController.value.position;
    final buffered = videoPlayerController.value.buffered;
    if (buffered.isEmpty) return 0.0;
    for (final r in buffered) {
      if (r.start <= pos && r.end >= pos) {
        return (r.end - pos).inMilliseconds / 1000.0;
      }
    }
    for (final r in buffered) {
      if (r.start > pos) return (r.end - r.start).inMilliseconds / 1000.0;
    }
    return 0.0;
  }

  // ── Playlist navigation ───────────────────────────────────
  bool get hasPreviousVideo {
    try {
      if (Get.isRegistered<VideoController>(tag: tag)) {
        final vc = Get.find<VideoController>(tag: tag);
        if (vc.playlistVideos.isNotEmpty && vc.currentPlaylistIndex.value > 0) {
          return true;
        }
        final idx = vc.recommendedVideos.indexWhere((v) => v.id == vc.video.id);
        return idx > 0 || (idx == -1 && vc.recommendedVideos.isNotEmpty);
      }
    } catch (_) {}
    return false;
  }

  bool get hasNextVideo {
    try {
      if (Get.isRegistered<VideoController>(tag: tag)) {
        final vc = Get.find<VideoController>(tag: tag);
        if (vc.playlistVideos.isNotEmpty &&
            vc.currentPlaylistIndex.value < vc.playlistVideos.length - 1) {
          return true;
        }
        final idx = vc.recommendedVideos.indexWhere((v) => v.id == vc.video.id);
        if (idx >= 0) return idx < vc.recommendedVideos.length - 1;
        return vc.recommendedVideos.isNotEmpty;
      }
    } catch (_) {}
    return false;
  }

  // ── Chapters ──────────────────────────────────────────────
  final RxList<VideoChapter> chapters = <VideoChapter>[].obs;
  final Rx<VideoChapter?> currentChapter = Rx<VideoChapter?>(null);

  // ── Analytics ─────────────────────────────────────────────
  final List<PlayerEvent> _events = [];
  int _totalWatchSeconds = 0;

  // ── Retry ─────────────────────────────────────────────────
  int _retryCount = 0;
  static const int _maxRetries = 3;

  // ── Internal state ────────────────────────────────────────
  final _timers = TimerBag();
  // Throttle: sync tracks at most once per 2 s to avoid expensive iteration every frame
  DateTime _lastTrackSync = DateTime(2000);
  // Double-tap position tracking
  double _doubleTapX = 0;
  // Guard: prevent _onTrackEnded firing repeatedly every VPC tick
  bool _hasEnded = false;

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();

    // Pause all other players first
    for (final p in _activePlayers) {
      if (p != this && p.vv.isPlaying) p.videoPlayerController.pause();
    }
    if (!_activePlayers.contains(this)) _activePlayers.add(this);

    // Load saved autoplay preference
    try {
      if (Get.isRegistered<VideoController>(tag: tag)) {
        isAutoplay.value = Get.find<VideoController>(tag: tag).isAutoplay.value;
      }
    } catch (_) {}

    _attachVideoListener();
    startHideTimer();
    _initABR();
    _initAudioService();
    _trackAnalytics(PlayerEvent('player_init'));

    // Load global media preferences
    subtitlesEnabled.value = TowerPlayerController.globalSubtitlesEnabled;
    activeSubLang.value = TowerPlayerController.globalActiveSubLang;
    isAudioOnly.value = TowerPlayerController.globalAudioOnly;
    playbackSpeed.value = TowerPlayerController.globalPlaybackSpeed;

    // Apply preferred playback speed
    if (playbackSpeed.value != 1.0) {
      videoPlayerController.setPlaybackSpeed(playbackSpeed.value);
    }

    if (TowerPlayerController.globalAudioOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        toggleAudioOnly();
      });
    }

    _initChewieController();

    if (!Get.isRegistered<TowerPlayerController>(tag: tag)) {
      Get.put<TowerPlayerController>(this, tag: tag, permanent: false);
    }
  }

  void _initABR() {
    if (!Get.isRegistered<AdaptiveBitrateController>(tag: tag)) {
      Get.put(abr, tag: tag, permanent: false);
    }

    List<ResolutionTier> ladder = ResolutionTier.defaultLadder;
    try {
      if (Get.isRegistered<VideoController>(tag: tag)) {
        final vc = Get.find<VideoController>(tag: tag);
        if (vc.availableResolutions.isNotEmpty) {
          ladder = vc.availableResolutions.reversed
              .map(
                (v) => ResolutionTier(
                  label: v.label,
                  url: v.url,
                  height: v.height,
                  bitrate: v.bitrate,
                  minBandwidth: (v.bitrate * 1.2).toInt(),
                ),
              )
              .toList();
        }
      }
    } catch (_) {}

    abr.initialize(ladder: ladder, vpc: videoPlayerController);

    abr.onTierChanged = (tierIndex, isManual) {
      try {
        if (!Get.isRegistered<VideoController>(tag: tag)) return;
        final vc = Get.find<VideoController>(tag: tag);
        if (vc.isSwitchingResolution.value) return;
        if (tierIndex >= 0 && tierIndex < abr.resolutionLadder.length) {
          final tier = abr.resolutionLadder[tierIndex];
          final match = vc.availableResolutions.firstWhereOrNull(
            (r) => r.height == tier.height,
          );
          if (match != null && vc.currentResolution.value?.url != match.url) {
            vc.setResolution(match, isManual: isManual);
          }
        }
      } catch (e) {
        debugPrint('[TowerPlayer] ABR tier change error: $e');
      }
    };

    // Apply global quality preference
    final pref = TowerPlayerController.globalQualityPreference;
    if (pref != null) {
      if (pref == 'Auto') {
        abr.enableAutoMode();
      } else {
        final matchIdx = abr.resolutionLadder.indexWhere(
          (t) => t.label == pref,
        );
        if (matchIdx != -1) {
          abr.setManualTier(matchIdx);
        }
      }
    }
  }

  void _initAudioService() {
    _audioService = Get.isRegistered<AudioOnlyService>()
        ? Get.find<AudioOnlyService>()
        : Get.put(AudioOnlyService(), permanent: false);
    _audioService!.setCallbacks(
      onNext: playNext,
      onPrevious: playPrevious,
      onEnded: _onTrackEnded,
    );
  }

  void _attachVideoListener() =>
      videoPlayerController.addListener(_onVpcUpdate);

  // ── VPC listener — optimised ──────────────────────────────
  void _onVpcUpdate() {
    try {
      final val = videoPlayerController.value;
      _rxValue.value = val;
      isBuffering.value = val.isBuffering;
      playbackSpeed.value = val.playbackSpeed;
      if (isLooping.value != val.isLooping) isLooping.value = val.isLooping;

      // Sync alternate audio player
      final audioCtrl = _audioTrackController;
      if (audioCtrl != null && audioCtrl.value.isInitialized) {
        // Keep main player muted if alternate audio is active
        if (videoPlayerController.value.volume > 0.0) {
          videoPlayerController.setVolume(0.0);
        }
        
        // Sync volume
        final targetVol = isMuted.value ? 0.0 : volume.value;
        if (audioCtrl.value.volume != targetVol) {
          audioCtrl.setVolume(targetVol);
        }

        // Sync Play/Pause
        if (val.isPlaying && !audioCtrl.value.isPlaying) {
          audioCtrl.play();
        } else if (!val.isPlaying && audioCtrl.value.isPlaying) {
          audioCtrl.pause();
        }

        // Sync Speed
        if (val.playbackSpeed != audioCtrl.value.playbackSpeed) {
          audioCtrl.setPlaybackSpeed(val.playbackSpeed);
        }

        // Sync Position if drift > 300ms
        final drift = (val.position - audioCtrl.value.position).inMilliseconds.abs();
        if (drift > 300) {
          audioCtrl.seekTo(val.position);
        }
      }

      // Ad Interceptor (Pre-roll and Mid-roll)
      final hasRealVideoAds =
          Get.isRegistered<AdService>() &&
          (AdService.to.getSkippableVideoAds().isNotEmpty ||
              AdService.to.getSponsorAdForVideo(videoController?.video.id) !=
                  null);
      if (!isPremiumUser && !isShowingAd.value && hasRealVideoAds) {
        final currentPos = val.position;
        final totalDur = val.duration;

        final sponsorAd = Get.isRegistered<AdService>()
            ? AdService.to.getSponsorAdForVideo(videoController?.video.id)
            : null;

        if (!_preRollPlayed && val.isPlaying && currentPos > Duration.zero) {
          _preRollPlayed = true;
          if (sponsorAd != null) {
            _startSponsorAd(sponsorAd, isPreRoll: true);
          } else {
            _startAd(isPreRoll: true);
          }
        } else if (sponsorAd != null &&
            !_sponsorMidRollPlayed &&
            totalDur.inSeconds > 420 &&
            currentPos.inSeconds >= 420 &&
            val.isPlaying) {
          _sponsorMidRollPlayed = true;
          _startSponsorAd(sponsorAd, isPreRoll: false);
        } else if (sponsorAd == null &&
            !_midRollPlayed &&
            totalDur.inSeconds > 180 &&
            currentPos.inSeconds >= (totalDur.inSeconds / 2).floor() &&
            val.isPlaying) {
          _midRollPlayed = true;
          _startAd(isPreRoll: false);
        }
      }

      // Subtitle lookup
      if (subtitlesEnabled.value && subtitleSegments.isNotEmpty) {
        final pos = val.position;
        final seg = _findSubtitle(pos);
        currentSubtitle.value = seg?.text ?? '';
      } else {
        currentSubtitle.value = '';
      }

      // Chapter lookup — binary search O(log n)
      if (chapters.isNotEmpty) {
        final chapter = _binarySearchChapter(val.position);
        if (currentChapter.value != chapter) currentChapter.value = chapter;
      } else {
        currentChapter.value = null;
      }

      // Throttled track sync — max once per 2 s
      final now = DateTime.now();
      if (now.difference(_lastTrackSync).inSeconds >= 2) {
        _lastTrackSync = now;
        _syncTracksWithVideoController();
      }

      // Error → retry
      if (val.hasError && _retryCount < _maxRetries) _scheduleRetry();

      // Ended → autoplay (guarded to fire exactly once)
      if (val.position >= val.duration &&
          val.duration > Duration.zero &&
          !_hasEnded) {
        _hasEnded = true;
        _onTrackEnded();
      } else if (val.position < val.duration) {
        _hasEnded = false;
      }
    } catch (e) {
      debugPrint('[TowerPlayer] VPC update error: $e');
    }
  }

  // O(n/2) subtitle lookup — good enough given small segment count
  SubtitleSegment? _findSubtitle(Duration pos) {
    for (final s in subtitleSegments) {
      if (pos >= s.start && pos <= s.end) return s;
      if (s.start > pos) break; // segments are sorted
    }
    return null;
  }

  // Binary search chapters by start time
  VideoChapter? _binarySearchChapter(Duration pos) {
    if (chapters.isEmpty) return null;
    int lo = 0, hi = chapters.length - 1, result = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (chapters[mid].startTime <= pos) {
        result = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return result >= 0 ? chapters[result] : null;
  }

  @override
  void onClose() {
    try {
      chewieController?.removeListener(_onInternalChewieChanged);
    } catch (_) {}
    try {
      videoController?.chewieController?.removeListener(_onOuterChewieChanged);
    } catch (_) {}
    if (adPlayerController != null) {
      try {
        adPlayerController!.removeListener(_onAdVpcUpdate);
        adPlayerController!.dispose();
      } catch (_) {}
    }
    if (_audioTrackController != null) {
      try {
        _audioTrackController!.dispose();
      } catch (_) {}
      _audioTrackController = null;
    }
    try {
      chewieController?.dispose();
    } catch (_) {}
    _activePlayers.remove(this);
    _timers.cancelAll();
    _webFullscreenSub?.cancel();
    // Restore system UI if still in fullscreen when controller is disposed
    if (isFullScreen.value) {
      isFullScreen.value = false;
      if (kIsWeb) {
        try {
          if (html.document.fullscreenElement != null) {
            html.document.exitFullscreen();
          }
        } catch (_) {}
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      }
    }
    focusNode.dispose();
    try {
      videoPlayerController.removeListener(_onVpcUpdate);
    } catch (_) {}
    abr.onClose();
    if (Get.isRegistered<TowerPlayerController>(tag: tag)) {
      Get.delete<TowerPlayerController>(tag: tag);
    }
    super.onClose();
  }

  // ── Controller sync ──────────────────────────────────────

  void sync(VideoPlayerController vpc) {
    if (videoPlayerController == vpc) return;
    try {
      videoPlayerController.removeListener(_onVpcUpdate);
    } catch (_) {}
    videoPlayerController = vpc;
    _rxValue.value = vpc.value;
    videoPlayerController.addListener(_onVpcUpdate);
    abr.attachVideoController(videoPlayerController);
    _initChewieController();
    _preRollPlayed = false;
    _midRollPlayed = false;
    _sponsorMidRollPlayed = false;
  }

  void _syncTracksWithVideoController() {
    try {
      if (!Get.isRegistered<VideoController>(tag: tag)) return;
      final vc = Get.find<VideoController>(tag: tag);

      if (vc.availableSubtitles.isNotEmpty && subtitleTracks.isEmpty) {
        subtitleTracks.assignAll(
          vc.availableSubtitles.map((t) => SubtitleTrack(
            label: t.label,
            langCode: t.langCode,
            url: t.url,
            isDefault: t.isDefault,
          )).toList(),
        );

        SubtitleTrack? bestTrack;
        if (Get.isRegistered<UserLanguagesService>()) {
          final service = UserLanguagesService.to;

          // 1. Try Primary Language
          bestTrack = subtitleTracks.firstWhereOrNull(
            (t) => service.isLanguageMatch(
              t.label,
              t.langCode,
              service.primaryLanguage.value,
            ),
          );

          // 2. Try Secondary Languages
          if (bestTrack == null) {
            for (final lang in service.secondaryLanguages) {
              bestTrack = subtitleTracks.firstWhereOrNull(
                (t) => service.isLanguageMatch(t.label, t.langCode, lang),
              );
              if (bestTrack != null) break;
            }
          }

          // 3. Try Known Languages
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
          // Fallback to manually configured global settings if user languages did not match
          final prefLang = TowerPlayerController.globalActiveSubLang;
          final match = subtitleTracks.firstWhereOrNull(
            (t) => t.label == prefLang,
          );
          if (match != null) {
            setSubtitles(enabled: true, track: match);
          } else if (subtitleTracks.isNotEmpty) {
            setSubtitles(enabled: true, track: subtitleTracks.first);
          }
        }
      }

      if (vc.availableAudioTracks.isNotEmpty && audioTracks.isEmpty) {
        audioTracks.assignAll(
          vc.availableAudioTracks.map((t) => AudioTrack(
            label: t.label,
            langCode: t.langCode,
            type: t.type,
            url: t.url,
          )).toList(),
        );

        AudioTrack? bestAudio;
        if (Get.isRegistered<UserLanguagesService>()) {
          final service = UserLanguagesService.to;

          // 1. Try Primary Language
          bestAudio = audioTracks.firstWhereOrNull(
            (t) => service.isLanguageMatch(
              t.label,
              t.langCode,
              service.primaryLanguage.value,
            ),
          );

          // 2. Try Secondary Languages
          if (bestAudio == null) {
            for (final lang in service.secondaryLanguages) {
              bestAudio = audioTracks.firstWhereOrNull(
                (t) => service.isLanguageMatch(t.label, t.langCode, lang),
              );
              if (bestAudio != null) break;
            }
          }

          // 3. Try Known Languages
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
    } catch (_) {}
  }

  // ─── Controls visibility ─────────────────────────────────

  void startHideTimer() {
    _timers.set('hide', Duration(milliseconds: PT.kControlsHideMs.toInt()), () {
      if (vv.isPlaying &&
          !settingsOpen.value &&
          !isDragging.value &&
          !showCommentsPopup.value &&
          !showTranscriptPopup.value) {
        controlsVisible.value = false;
      }
    });
  }

  /// YouTube behaviour: single tap = toggle controls on Mobile, Play/Pause on Desktop.
  void onTap(bool isDesktop) {
    focusNode.requestFocus();
    if (settingsOpen.value) {
      closeSettings();
      return;
    }
    if (kIsWeb && isDesktop) {
      togglePlayPause();
    } else {
      if (controlsVisible.value) {
        _timers.cancel('hide');
        controlsVisible.value = false;
      } else {
        controlsVisible.value = true;
        startHideTimer();
      }
    }
  }

  void onInteraction() {
    if (!controlsVisible.value) controlsVisible.value = true;
    // Avoid timer churn during active drag (~60 restarts/sec)
    if (!isDragging.value) startHideTimer();
  }

  // Store double-tap X for left/right detection
  void onDoubleTapDown(double x) => _doubleTapX = x;

  // Called AFTER disambiguation — single tap will NOT fire when this fires
  // YouTube: double-tap seek only works when controls are HIDDEN
  void onDoubleTap(double playerWidth) {
    if (controlsVisible.value) return;
    final half = playerWidth / 2;
    if (_doubleTapX < half) {
      doubleTapLeft();
    } else {
      doubleTapRight();
    }
  }

  // ─── Playback ────────────────────────────────────────────

  Future<void> togglePlayPause() async {
    try {
      if (vv.isPlaying) {
        await videoPlayerController.pause();
        await _audioTrackController?.pause();
        _stopWatchTimer();
        _trackAnalytics(
          PlayerEvent('pause', data: {'position': vv.position.inSeconds}),
        );
      } else {
        if (vv.position >= vv.duration) {
          await videoPlayerController.seekTo(Duration.zero);
          await _audioTrackController?.seekTo(Duration.zero);
        }
        pauseAllActivePlayers(except: this);
        await videoPlayerController.play();
        await _audioTrackController?.play();
        _startWatchTimer();
        _trackAnalytics(
          PlayerEvent('play', data: {'position': vv.position.inSeconds}),
        );
      }
      onInteraction();
    } catch (e) {
      debugPrint('[TowerPlayer] Play/pause error: $e');
    }
  }

  Future<void> seekTo(Duration pos) async {
    try {
      _hasEnded = false; // Reset ended guard on seek
      await videoPlayerController.seekTo(pos);
      await _audioTrackController?.seekTo(pos);
      if (isAudioOnly.value) _audioService?.syncPosition(pos);
      onInteraction();
    } catch (e) {
      debugPrint('[TowerPlayer] Seek error: $e');
    }
  }

  Future<void> seekRelative(int seconds) async {
    final newPos = Duration(
      seconds: (vv.position.inSeconds + seconds).clamp(
        0,
        vv.duration.inSeconds,
      ),
    );
    await seekTo(newPos);
    showToast(seconds > 0 ? '+${seconds}s' : '${seconds}s');
  }

  void playNext() {
    _trackAnalytics(PlayerEvent('next'));
    if (!Get.isRegistered<VideoController>(tag: tag)) return;
    final vc = Get.find<VideoController>(tag: tag);

    if (vc.playlistVideos.isNotEmpty &&
        vc.currentPlaylistIndex.value < vc.playlistVideos.length - 1) {
      _navigateToVideo(
        vc.playlistVideos[vc.currentPlaylistIndex.value + 1],
        vc,
      );
      return;
    }
    if (vc.recommendedVideos.isNotEmpty) {
      final idx = vc.recommendedVideos.indexWhere((v) => v.id == vc.video.id);
      Video? next;
      if (idx >= 0 && idx < vc.recommendedVideos.length - 1) {
        next = vc.recommendedVideos[idx + 1];
      } else if (idx == -1) {
        next = vc.recommendedVideos.first;
      }
      if (next != null && next.id != vc.video.id) {
        _navigateToVideo(next, vc);
      }
    }
  }

  void playPrevious() {
    _trackAnalytics(PlayerEvent('previous'));
    if (!Get.isRegistered<VideoController>(tag: tag)) return;
    final vc = Get.find<VideoController>(tag: tag);

    if (vc.playlistVideos.isNotEmpty && vc.currentPlaylistIndex.value > 0) {
      _navigateToVideo(
        vc.playlistVideos[vc.currentPlaylistIndex.value - 1],
        vc,
      );
      return;
    }
    if (vc.recommendedVideos.isNotEmpty) {
      final idx = vc.recommendedVideos.indexWhere((v) => v.id == vc.video.id);
      Video? prev;
      if (idx > 0) {
        prev = vc.recommendedVideos[idx - 1];
      } else if (idx == -1) {
        prev = vc.recommendedVideos.first;
      }
      if (prev != null && prev.id != vc.video.id) {
        _navigateToVideo(prev, vc);
      }
    }
  }

  void _navigateToVideo(Video video, VideoController vc) {
    // Navigation lock — prevent concurrent switches that cause stuck state
    if (isNavigatingToVideo.value) return;
    isNavigatingToVideo.value = true;
    videoPlayerController.pause();
    Get.offNamed(
      '/watch?v=${video.id}',
      arguments: {
        'video': video,
        'playlist': vc.currentPlaylist.value,
        'heroTag': 'video_${video.id}_${DateTime.now().millisecondsSinceEpoch}',
      },
      preventDuplicates: false,
    );
    // Reset lock after short delay (route transition)
    Future.delayed(const Duration(milliseconds: 500), () {
      isNavigatingToVideo.value = false;
    });
  }

  void _onTrackEnded() {
    _trackAnalytics(PlayerEvent('ended'));
    if (isLooping.value) return; // Looping is handled by VideoPlayerController
    if (isAutoplay.value) playNext();
  }

  // ─── Volume ──────────────────────────────────────────────

  void setVolume(double vol) {
    volume.value = vol.clamp(0.0, 1.0);
    isMuted.value = vol == 0;
    if (_audioTrackController != null) {
      videoPlayerController.setVolume(0.0);
      _audioTrackController!.setVolume(isMuted.value ? 0.0 : volume.value);
    } else {
      videoPlayerController.setVolume(isMuted.value ? 0.0 : volume.value);
    }
    if (isAudioOnly.value) _audioService?.setVolume(volume.value);
    onInteraction();
  }

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

  void setSpeed(double speed) {
    videoPlayerController.setPlaybackSpeed(speed);
    _audioTrackController?.setPlaybackSpeed(speed);
    playbackSpeed.value = speed;
    TowerPlayerController.globalPlaybackSpeed = speed; // Persist speed
    activePanel.value = '';
    _trackAnalytics(PlayerEvent('speed_change', data: {'speed': speed}));
  }

  // ─── Quality ─────────────────────────────────────────────

  String get currentQualityLabel => abr.isAutoMode.value
      ? 'Auto · ${abr.currentTier.label}'
      : abr.currentTier.label;

  void selectQuality(int tierIndex) {
    if (tierIndex < 0 || tierIndex >= abr.resolutionLadder.length) return;
    abr.setManualTier(tierIndex);
    TowerPlayerController.globalQualityPreference =
        abr.resolutionLadder[tierIndex].label;
    activePanel.value = '';
    closeSettings();
    _trackAnalytics(
      PlayerEvent(
        'quality_change',
        data: {'quality': abr.resolutionLadder[tierIndex].label},
      ),
    );
  }

  void selectAutoQuality() {
    abr.enableAutoMode();
    TowerPlayerController.globalQualityPreference = 'Auto';
    activePanel.value = '';
    closeSettings();
  }

  // ─── Audio Only ──────────────────────────────────────────

  Future<void> toggleAudioOnly({
    String? videoUrl,
    String? title,
    String? artworkUrl,
  }) async {
    if (isAudioOnly.value) {
      _audioService?.deactivate();
      isAudioOnly.value = false;
      TowerPlayerController.globalAudioOnly = false;
      await videoPlayerController.play();
      _trackAnalytics(PlayerEvent('audio_only_off'));
    } else {
      final pos = vv.position;
      await videoPlayerController.pause();
      final targetUrl = videoUrl ?? videoPlayerController.dataSource;
      if (kIsWeb) {
        String? finalTitle = title, finalArtwork = artworkUrl;
        try {
          if (Get.isRegistered<VideoController>(tag: tag)) {
            final vc = Get.find<VideoController>(tag: tag);
            finalTitle ??= vc.video.title;
            finalArtwork ??= vc.video.thumbnailUrl;
          }
        } catch (_) {}
        await _audioService?.activateAudioOnly(
          videoUrl: targetUrl,
          title: finalTitle ?? 'Streaming Audio',
          artworkUrl: finalArtwork ?? '',
          startPosition: pos,
        );
      }
      isAudioOnly.value = true;
      TowerPlayerController.globalAudioOnly = true;
      _trackAnalytics(PlayerEvent('audio_only_on'));
    }
  }

  // ─── Subtitles ───────────────────────────────────────────

  void setSubtitles({required bool enabled, SubtitleTrack? track}) {
    subtitlesEnabled.value = enabled;
    if (!enabled) {
      activeSubLang.value = 'Off';
    } else if (track != null) {
      activeSubLang.value = track.label;
      fetchAndParseSubtitles(track.url);
    }
    TowerPlayerController.globalSubtitlesEnabled = enabled;
    TowerPlayerController.globalActiveSubLang = activeSubLang.value;
    _trackAnalytics(
      PlayerEvent('subtitle_change', data: {'lang': activeSubLang.value}),
    );
  }

  Future<void> fetchAndParseSubtitles(String url) async {
    if (url.isEmpty) return;
    try {
      final resolvedUrl = StorageUtils.getFastDownloadUrl(url);
      final response = await http.get(Uri.parse(resolvedUrl));
      if (response.statusCode == 200) {
        String content = utf8.decode(response.bodyBytes, allowMalformed: true);
        if (content.startsWith('\uFEFF')) content = content.substring(1);
        subtitleSegments.assignAll(_parseSRT(content));
      }
    } catch (e) {
      debugPrint('[TowerPlayer] Subtitle error: $e');
      subtitleSegments.clear();
    }
  }

  List<SubtitleSegment> _parseSRT(String content) {
    final List<SubtitleSegment> segs = [];
    String normalized = content.replaceAll('\r\n', '\n').trim();
    if (normalized.startsWith('WEBVTT')) {
      normalized = normalized
          .replaceFirst(RegExp(r'^WEBVTT[^\n]*\n*'), '')
          .trim();
    }
    for (final block in normalized.split('\n\n')) {
      final lines = block.trim().split('\n');
      if (lines.length < 2) continue;
      String timeLine = '';
      int textStart = 0;
      if (lines[0].contains('-->')) {
        timeLine = lines[0];
        textStart = 1;
      } else if (lines.length >= 2 && lines[1].contains('-->')) {
        timeLine = lines[1];
        textStart = 2;
      } else {
        continue;
      }
      final times = timeLine.split(' --> ');
      if (times.length != 2) continue;
      if (lines.length <= textStart) continue;
      final text = lines.sublist(textStart).join('\n').trim();
      if (text.isNotEmpty) {
        segs.add(
          SubtitleSegment(
            start: _parseSRTTime(times[0]),
            end: _parseSRTTime(times[1]),
            text: text,
          ),
        );
      }
    }
    return segs;
  }

  Duration _parseSRTTime(String t) {
    final parts = t.trim().replaceAll(',', '.').split(':');
    if (parts.length != 3) return Duration.zero;
    final sParts = parts[2].split('.');
    return Duration(
      hours: int.parse(parts[0]),
      minutes: int.parse(parts[1]),
      seconds: int.parse(sParts[0]),
      milliseconds: sParts.length > 1 ? int.parse(sParts[1]) : 0,
    );
  }

  // ─── Audio language ──────────────────────────────────────

  void setAudioLanguage(AudioTrack track) {
    activeAudioLang.value = track.label;
    activePanel.value = '';
    closeSettings();
    try {
      if (Get.isRegistered<VideoController>(tag: tag)) {
        final vc = Get.find<VideoController>(tag: tag);

        // 1. Dispose old audio track controller if exists
        if (_audioTrackController != null) {
          try {
            _audioTrackController!.dispose();
          } catch (_) {}
          _audioTrackController = null;
        }

        // 2. Handle type-specific switching
        if (track.type == 'Audio' && track.url != null && track.url!.isNotEmpty) {
          // Switch main player back to original video resolution if it's currently on a dubbed video
          if (vc.currentResolution.value?.url != vc.availableResolutions.first.url) {
            vc.setResolution(vc.availableResolutions.first, isManual: true);
          }
          
          // Mute main video player
          videoPlayerController.setVolume(0.0);

          // Initialize secondary audio player
          _audioTrackController = VideoPlayerController.networkUrl(Uri.parse(track.url!));
          _audioTrackController!.initialize().then((_) {
            if (_audioTrackController == null) return;
            
            // Sync initial settings
            _audioTrackController!.setVolume(isMuted.value ? 0.0 : volume.value);
            _audioTrackController!.setPlaybackSpeed(videoPlayerController.value.playbackSpeed);
            _audioTrackController!.seekTo(videoPlayerController.value.position);
            
            if (videoPlayerController.value.isPlaying) {
              _audioTrackController!.play();
            }
          });
        } else if (track.type == 'Video' && track.url != null && track.url!.isNotEmpty) {
          // Unmute main video player
          videoPlayerController.setVolume(isMuted.value ? 0.0 : volume.value);

          final curr = vc.currentResolution.value;
          vc.setResolution(
            VideoResolutionV2(
              label: '${curr?.label ?? 'Auto'} (Dubbed)',
              url: track.url!,
              width: curr?.width ?? 0,
              height: curr?.height ?? 0,
              bitrate: curr?.bitrate ?? 0,
            ),
            isManual: true,
          );
        } else {
          // 'Original' or fallback
          // Unmute main video player
          videoPlayerController.setVolume(isMuted.value ? 0.0 : volume.value);
          if (vc.availableResolutions.isNotEmpty) {
            vc.setResolution(vc.availableResolutions.first, isManual: true);
          }
        }
      }
    } catch (e) {
      debugPrint('[TowerPlayer] Audio lang switch error: $e');
    }
    _trackAnalytics(PlayerEvent('audio_lang', data: {'lang': track.langCode}));
  }

  // ─── Double tap seek ─────────────────────────────────────

  void doubleTapLeft() {
    seekRelative(-10);
    showDoubleTapLeft.value = true;
    _timers.set(
      'dtLeft',
      Duration(milliseconds: PT.kDoubleTapRippleMs.toInt()),
      () => showDoubleTapLeft.value = false,
    );
  }

  void doubleTapRight() {
    seekRelative(10);
    showDoubleTapRight.value = true;
    _timers.set(
      'dtRight',
      Duration(milliseconds: PT.kDoubleTapRippleMs.toInt()),
      () => showDoubleTapRight.value = false,
    );
  }

  // ─── Seek preview ────────────────────────────────────────

  void updateSeekPreview(double fraction, double xPixel, Duration total) {
    seekPreviewPos.value = Duration(
      milliseconds: (total.inMilliseconds * fraction).toInt(),
    );
    seekPreviewX.value = xPixel;
    seekPreviewVis.value = true;
  }

  void hideSeekPreview() => seekPreviewVis.value = false;

  // ─── Settings ────────────────────────────────────────────

  void openSettings() {
    settingsOpen.value = true;
    activePanel.value = '';
    controlsVisible.value = true;
    _timers.cancel('hide');
  }

  void closeSettings() {
    settingsOpen.value = false;
    activePanel.value = '';
    startHideTimer();
  }

  // ─── Fullscreen ──────────────────────────────────────────

  void toggleFullscreen() async {
    focusNode.requestFocus();
    try {
      final vc = videoController;
      final outerChewie = vc?.chewieController;
      if (outerChewie != null) {
        outerChewie.toggleFullScreen();
      } else {
        chewieController?.toggleFullScreen();
      }
    } catch (e) {
      debugPrint('[TowerPlayer] Fullscreen toggle error: $e');
    }
  }

  void _setupChewieListeners() {
    // 1. Setup internal ChewieController listener
    try {
      chewieController?.removeListener(_onInternalChewieChanged);
      chewieController?.addListener(_onInternalChewieChanged);
    } catch (_) {}

    // 2. Setup outer ChewieController listener
    try {
      final vc = videoController;
      if (vc != null && vc.chewieController != null) {
        vc.chewieController!.removeListener(_onOuterChewieChanged);
        vc.chewieController!.addListener(_onOuterChewieChanged);
        isFullScreen.value = vc.chewieController!.isFullScreen;
        vc.isFullScreen.value = vc.chewieController!.isFullScreen;
      } else {
        if (chewieController != null) {
          isFullScreen.value = chewieController!.isFullScreen;
        }
      }
    } catch (_) {}
  }

  void _onInternalChewieChanged() {
    if (chewieController == null) return;
    final isFs = chewieController!.isFullScreen;
    if (isFullScreen.value != isFs) {
      isFullScreen.value = isFs;
      try {
        final vc = videoController;
        if (vc != null) {
          vc.isFullScreen.value = isFs;
        }
      } catch (_) {}
      onInteraction();
      _trackAnalytics(PlayerEvent(isFs ? 'fullscreen_enter' : 'fullscreen_exit'));
    }
  }

  void _onOuterChewieChanged() {
    final vc = videoController;
    if (vc != null && vc.chewieController != null) {
      final isFs = vc.chewieController!.isFullScreen;
      if (isFullScreen.value != isFs) {
        isFullScreen.value = isFs;
        vc.isFullScreen.value = isFs;
        onInteraction();
        _trackAnalytics(PlayerEvent(isFs ? 'fullscreen_enter' : 'fullscreen_exit'));
      }
    }
  }

  // ─── PiP ─────────────────────────────────────────────────

  void togglePiP() {
    if (!kIsWeb) return;
    try {
      final video = html.document.querySelector('video') as html.VideoElement?;
      if (video == null) return;
      final docJs = js.JsObject.fromBrowserObject(html.document);
      if (docJs['pictureInPictureElement'] == null) {
        js.JsObject.fromBrowserObject(
          video,
        ).callMethod('requestPictureInPicture', []);
        isPiP.value = true;
      } else {
        docJs.callMethod('exitPictureInPicture', []);
        isPiP.value = false;
      }
    } catch (e) {
      debugPrint('[TowerPlayer] PiP error: $e');
    }
  }

  // ─── Keyboard shortcuts ───────────────────────────────────
  // Full YouTube keyboard standard

  void handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;

    if (isShowingAd.value) {
      if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
        togglePlayPauseAd();
      } else if (key == LogicalKeyboardKey.keyF) {
        toggleFullscreen();
      } else if (key == LogicalKeyboardKey.keyM) {
        toggleMuteAd();
      } else if (key == LogicalKeyboardKey.escape) {
        if (isFullScreen.value) toggleFullscreen();
      }
      return;
    }

    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      togglePlayPause();
    } else if (key == LogicalKeyboardKey.keyJ) {
      // YouTube: J = −10 s
      seekRelative(-10);
    } else if (key == LogicalKeyboardKey.keyL) {
      // YouTube: L = +10 s
      seekRelative(10);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      seekRelative(5);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      seekRelative(-5);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setVolume(min(1.0, volume.value + 0.1));
      showToast('Volume ${(volume.value * 100).round()}%');
    } else if (key == LogicalKeyboardKey.arrowDown) {
      setVolume(max(0.0, volume.value - 0.1));
      showToast('Volume ${(volume.value * 100).round()}%');
    } else if (key == LogicalKeyboardKey.keyF) {
      toggleFullscreen();
    } else if (key == LogicalKeyboardKey.keyM) {
      toggleMute();
    } else if (key == LogicalKeyboardKey.keyN) {
      playNext();
    } else if (key == LogicalKeyboardKey.keyP) {
      playPrevious();
    } else if (key == LogicalKeyboardKey.keyI) {
      togglePiP();
    } else if (key == LogicalKeyboardKey.escape) {
      if (isFullScreen.value) toggleFullscreen();
    } else if (key == LogicalKeyboardKey.slash) {
      if (HardwareKeyboard.instance.isShiftPressed) showShortcutsDialog();
    } else if (key == LogicalKeyboardKey.comma) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _adjustSpeedRelative(-0.25);
      } else {
        // YouTube: , = previous frame (approximate via -1/30 s)
        seekRelative(-1);
      }
    } else if (key == LogicalKeyboardKey.period) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _adjustSpeedRelative(0.25);
      } else {
        // YouTube: . = next frame
        seekRelative(1);
      }
    } else {
      // Handle digit keys 0-9 to seek to 0%-90% of duration
      final digitMap = {
        LogicalKeyboardKey.digit0: 0.0,
        LogicalKeyboardKey.digit1: 0.1,
        LogicalKeyboardKey.digit2: 0.2,
        LogicalKeyboardKey.digit3: 0.3,
        LogicalKeyboardKey.digit4: 0.4,
        LogicalKeyboardKey.digit5: 0.5,
        LogicalKeyboardKey.digit6: 0.6,
        LogicalKeyboardKey.digit7: 0.7,
        LogicalKeyboardKey.digit8: 0.8,
        LogicalKeyboardKey.digit9: 0.9,
        LogicalKeyboardKey.numpad0: 0.0,
        LogicalKeyboardKey.numpad1: 0.1,
        LogicalKeyboardKey.numpad2: 0.2,
        LogicalKeyboardKey.numpad3: 0.3,
        LogicalKeyboardKey.numpad4: 0.4,
        LogicalKeyboardKey.numpad5: 0.5,
        LogicalKeyboardKey.numpad6: 0.6,
        LogicalKeyboardKey.numpad7: 0.7,
        LogicalKeyboardKey.numpad8: 0.8,
        LogicalKeyboardKey.numpad9: 0.9,
      };
      if (digitMap.containsKey(key)) {
        final fraction = digitMap[key]!;
        final dur = vv.duration;
        if (dur > Duration.zero) {
          seekTo(dur * fraction);
          showToast('Seek to ${(fraction * 100).round()}%');
        }
      }
    }
  }

  void _adjustSpeedRelative(double delta) {
    const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    double current = playbackSpeed.value;
    int index = speeds.indexOf(current);
    if (index == -1) {
      double minDiff = double.infinity;
      int closestIdx = 3; // 1.0
      for (int i = 0; i < speeds.length; i++) {
        final diff = (speeds[i] - current).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closestIdx = i;
        }
      }
      index = closestIdx;
    }
    int newIndex = (index + (delta > 0 ? 1 : -1)).clamp(0, speeds.length - 1);
    setSpeed(speeds[newIndex]);
    showToast('Speed: ${speeds[newIndex]}×');
  }

  // ─── Long press 2× ───────────────────────────────────────

  void startLongPressSpeedUp() {
    if (isLongPressSpeedUp.value) return;
    _preLongPressSpeed = playbackSpeed.value;
    videoPlayerController.setPlaybackSpeed(2.0);
    playbackSpeed.value = 2.0;
    isLongPressSpeedUp.value = true;
  }

  void endLongPressSpeedUp() {
    if (!isLongPressSpeedUp.value) return;
    videoPlayerController.setPlaybackSpeed(_preLongPressSpeed);
    playbackSpeed.value = _preLongPressSpeed;
    isLongPressSpeedUp.value = false;
  }

  // ─── Sleep timer ─────────────────────────────────────────

  void setSleepTimer(Duration duration) {
    cancelSleepTimer();
    if (duration == Duration.zero) return;
    isSleepTimerActive.value = true;
    sleepTimerRemainingSeconds.value = duration.inSeconds;
    _timers.setPeriodic('sleep', const Duration(seconds: 1), (t) {
      if (sleepTimerRemainingSeconds.value <= 1) {
        cancelSleepTimer();
        _triggerSleepPause();
      } else {
        sleepTimerRemainingSeconds.value--;
      }
    });
    showToast('Sleep timer: ${duration.inMinutes} min');
  }

  void cancelSleepTimer() {
    _timers.cancel('sleep');
    isSleepTimerActive.value = false;
    sleepTimerRemainingSeconds.value = 0;
  }

  Future<void> _triggerSleepPause() async {
    final origVol = volume.value;
    for (int i = 10; i >= 0; i--) {
      setVolume(origVol * (i / 10));
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await videoPlayerController.pause();
    setVolume(origVol);
    showToast('Sleep timer paused playback');
  }

  // ─── Swipe gestures (Fullscreen) ─────────────────────────

  void onVerticalDragStart(DragStartDetails d, Size size) {
    // Start position not needed — swipe direction determined by velocity in onVerticalDragEnd
  }

  void onVerticalDragUpdate(DragUpdateDetails d, Size size) {
    // Wait for drag end to determine swipe direction
  }

  void onVerticalDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    if (velocity < -500) {
      // Swipe UP -> Enter fullscreen
      if (!isFullScreen.value) toggleFullscreen();
    } else if (velocity > 500) {
      // Swipe DOWN -> Exit fullscreen
      if (isFullScreen.value) toggleFullscreen();
    }
  }

  // ─── Shortcuts dialog ────────────────────────────────────

  void showShortcutsDialog() {
    Get.dialog(
      const KeyboardShortcutsDialog(),
      barrierColor: Colors.black.withValues(alpha: 0.8),
    );
  }

  // ─── Toast ───────────────────────────────────────────────

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
        } catch (e) {
          debugPrint('[TowerPlayer] Retry failed: $e');
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

  // ─── Loop ────────────────────────────────────────────────

  void toggleLoop() {
    isLooping.value = !isLooping.value;
    videoPlayerController.setLooping(isLooping.value);
  }

  // ─── Language request dialog ─────────────────────────────

  void showRequestDialog(BuildContext context, String type) {
    if (!Get.isRegistered<VideoController>(tag: tag)) return;
    final vc = Get.find<VideoController>(tag: tag);
    if (!vc.isAuthenticated) {
      showToast('Please login to request languages');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => LanguageRequestDialog(
        type: type,
        onRequested: (lang) async {
          final ok = await vc.requestLanguage(lang, type);
          showToast(
            ok ? 'Request submitted for $lang' : 'Failed to submit request',
          );
        },
      ),
    );
  }

  Future<void> _startAd({required bool isPreRoll}) async {
    // Check for custom advertiser skippable campaigns first
    final List<AdItem> activeVideoAds = [];
    if (Get.isRegistered<AdService>()) {
      activeVideoAds.addAll(AdService.to.getSkippableVideoAds());
    }

    if (activeVideoAds.isEmpty) {
      return;
    }

    await videoPlayerController.pause();
    _stopWatchTimer();

    final random = Random();
    final selectedAd = activeVideoAds[random.nextInt(activeVideoAds.length)];

    String? resolvedUrl;
    if (selectedAd.resolutions != null && selectedAd.resolutions!.isNotEmpty) {
      final List<Map<String, dynamic>> resList =
          List<Map<String, dynamic>>.from(selectedAd.resolutions!);

      // Select resolution based on global quality preference if set and not Auto
      final pref = TowerPlayerController.globalQualityPreference;
      Map<String, dynamic>? selectedResolution;

      if (pref != null && pref != 'Auto') {
        final cleanPref = pref.toLowerCase();
        for (var res in resList) {
          final label = (res['label'] as String? ?? '').toLowerCase();
          if (label == cleanPref ||
              label.contains(cleanPref) ||
              cleanPref.contains(label)) {
            selectedResolution = res;
            break;
          }
        }
      }

      // If Auto or no direct match, pick optimal/highest resolution <= 720p
      if (selectedResolution == null) {
        resList.sort(
          (a, b) =>
              (b['height'] as int? ?? 0).compareTo(a['height'] as int? ?? 0),
        );
        selectedResolution = resList.firstWhere(
          (res) => (res['height'] as int? ?? 0) <= 720,
          orElse: () => resList.first,
        );
      }

      if (selectedResolution['url'] != null) {
        resolvedUrl = selectedResolution['url'] as String;
        debugPrint(
          '[TowerPlayerController] ✅ Playing resolved ad URL directly from campaign document (${selectedResolution['label']}): $resolvedUrl',
        );
      }
    }

    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      debugPrint(
        '[TowerPlayerController] ⚠️ Ad has no resolved resolutions in ad_campaigns. Skipping ad and resuming video.',
      );
      _finishAd();
      return;
    }

    final ad = MockAd(
      videoUrl: resolvedUrl,
      title: selectedAd.title,
      description: selectedAd.description,
      clickUrl: selectedAd.ctaTarget,
      skippable: selectedAd.isSkippableAd,
      duration: const Duration(seconds: 15),
    );

    currentAd.value = ad;
    isShowingAd.value = true;
    adCanSkip.value = false;
    skipCountdown.value = ad.skippable ? 5 : 0;
    adTimeRemaining.value = ad.duration.inSeconds;

    final apc = VideoPlayerController.networkUrl(Uri.parse(ad.videoUrl));
    adPlayerController = apc;

    try {
      await apc.initialize();
      apc.addListener(_onAdVpcUpdate);
      await apc.play();
      update();
    } catch (e) {
      debugPrint(
        '[TowerPlayer] Ad initialization failed: $e. Skipping ad and resuming video.',
      );
      _finishAd();
    }
  }

  Future<void> _startSponsorAd(
    AdItem sponsorAd, {
    required bool isPreRoll,
  }) async {
    await videoPlayerController.pause();
    _stopWatchTimer();

    // The first ad (pre-roll) plays videoUrl (non-skippable)
    // The second ad (mid-roll) plays midrollVideoUrl (skippable, 5s countdown)
    String? resolvedUrl = isPreRoll
        ? sponsorAd.videoUrl
        : sponsorAd.midrollVideoUrl;

    // Fallbacks if one is not defined
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      resolvedUrl =
          sponsorAd.videoUrl ??
          'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';
    }

    final ad = MockAd(
      videoUrl: resolvedUrl,
      title: sponsorAd.title,
      description: sponsorAd.description,
      clickUrl: sponsorAd.ctaTarget,
      skippable: !isPreRoll, // pre-roll is non-skippable, mid-roll is skippable
      duration: const Duration(seconds: 15),
    );

    currentAd.value = ad;
    isShowingAd.value = true;
    adCanSkip.value = false;
    skipCountdown.value = ad.skippable ? 5 : 0;
    adTimeRemaining.value = ad.duration.inSeconds;

    final apc = VideoPlayerController.networkUrl(Uri.parse(ad.videoUrl));
    adPlayerController = apc;

    try {
      await apc.initialize();
      apc.addListener(_onAdVpcUpdate);
      await apc.play();
      update();
    } catch (e) {
      debugPrint(
        '[TowerPlayer] Sponsor Ad initialization failed: $e. Skipping ad.',
      );
      _finishAd();
    }
  }

  void _onAdVpcUpdate() {
    if (adPlayerController == null) return;
    final val = adPlayerController!.value;

    if (val.hasError) {
      debugPrint('[TowerPlayer] Ad playback failed. Skipping ad.');
      _finishAd();
      return;
    }

    final pos = val.position;
    final dur = val.duration;

    adTimeRemaining.value = max(0, dur.inSeconds - pos.inSeconds);

    if (currentAd.value?.skippable ?? false) {
      final elapsed = pos.inSeconds;
      if (elapsed >= 5) {
        adCanSkip.value = true;
        skipCountdown.value = 0;
      } else {
        adCanSkip.value = false;
        skipCountdown.value = 5 - elapsed;
      }
    } else {
      adCanSkip.value = false;
      skipCountdown.value = 0;
    }

    if (pos >= dur && dur > Duration.zero) {
      _finishAd();
    }
  }

  void skipAd() {
    if (adCanSkip.value) {
      _finishAd();
    }
  }

  void _finishAd() {
    isShowingAd.value = false;
    adPlayerController?.removeListener(_onAdVpcUpdate);
    adPlayerController?.pause();
    adPlayerController?.dispose();
    adPlayerController = null;
    currentAd.value = null;

    videoPlayerController.play();
    _startWatchTimer();
  }

  void togglePlayPauseAd() {
    if (adPlayerController == null) return;
    if (adPlayerController!.value.isPlaying) {
      adPlayerController!.pause();
    } else {
      adPlayerController!.play();
    }
  }

  void toggleMuteAd() {
    if (adPlayerController == null) return;
    if (adPlayerController!.value.volume > 0) {
      adPlayerController!.setVolume(0);
    } else {
      adPlayerController!.setVolume(volume.value);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN PLAYER WIDGET
// ─────────────────────────────────────────────────────────────────────────────
