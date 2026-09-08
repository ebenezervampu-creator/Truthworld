import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/core/utils/subtitle_parser.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

/// Production-grade miniplayer controller.
class MiniplayerController extends BaseController
    with GetTickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON ACCESSOR
  // ═══════════════════════════════════════════════════════════════════════════

  static MiniplayerController get to {
    if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer')) {
      return Get.find<MiniplayerController>(tag: 'miniplayer');
    }
    if (Get.isRegistered<MiniplayerController>()) {
      return Get.find<MiniplayerController>();
    }
    debugPrint(
      'MiniplayerController.to: Registering default MiniplayerController.',
    );
    return Get.put<MiniplayerController>(
      MiniplayerController(),
      tag: 'miniplayer',
      permanent: true,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REACTIVE STATE — granular, minimal-rebuild design
  // ═══════════════════════════════════════════════════════════════════════════

  /// Current mode of the miniplayer panel.
  final Rx<MiniplayerMode> mode = MiniplayerMode.dismissed.obs;

  /// Video metadata (null when no video loaded).
  final Rxn<MiniplayerVideoInfo> videoInfo = Rxn<MiniplayerVideoInfo>();

  /// Full video object for handoff to full screen.
  final Rxn<Video> currentVideo = Rxn<Video>();

  /// Whether the underlying video is currently playing.
  final RxBool isPlaying = false.obs;

  /// Whether the video player has been successfully initialized.
  final RxBool isVideoReady = false.obs;

  /// Current playback position (updated at ~4 Hz).
  final Rx<Duration> currentPosition = Duration.zero.obs;

  /// Total duration of the loaded video.
  final Rx<Duration> totalDuration = Duration.zero.obs;

  /// Drag progress (0.0 = collapsed, 1.0 = expanded).
  final RxDouble dragProgress = 0.0.obs;

  /// Error message (empty = no error).
  final RxString error = ''.obs;

  /// Whether subtitles are enabled in the miniplayer
  final RxBool subtitlesEnabled = false.obs;

  /// Parsed subtitle segments
  final RxList<SubtitleSegment> subtitleSegments = <SubtitleSegment>[].obs;

  /// Current active subtitle text
  final RxString currentSubtitle = ''.obs;

  /// Whether the player is currently buffering.
  final RxBool isBuffering = false.obs;

  /// Free-form drag offset of the collapsed miniplayer card.
  ///
  /// `null` means: dock to bottom-right (default). When the user drags the
  /// card, this becomes the explicit top-left position in viewport pixels.
  final Rxn<Offset> dragOffset = Rxn<Offset>();

  /// Whether the pointer is currently hovering the miniplayer (web/desktop).
  /// Used to fade controls in/out like YouTube.
  final RxBool isHovering = false.obs;

  /// Whether mobile touch controls are currently visible on top of the video frame.
  final RxBool showMobileControls = false.obs;

  /// Whether miniplayer audio is currently muted.
  final RxBool isMuted = false.obs;

  // ═══════════════════════════════════════════════════════════════════════════
  // NON-REACTIVE STATE
  // ═══════════════════════════════════════════════════════════════════════════

  VideoPlayerController? _vpc;
  Timer? _positionTimer;
  Timer? _hideControlsTimer;
  bool _isClosed = false;
  StreamSubscription? _connectivitySubscription;

  // ── Public read-only accessors ──
  VideoPlayerController? get videoPlayerController => _vpc;
  bool get isVisible => mode.value != MiniplayerMode.dismissed;

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void onInit() {
    super.onInit();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    trackSubscription(
      _connectivitySubscription = Get.find<ConnectivityService>()
          .onConnectivityChanged
          .listen((results) {
            final isConnected = results.any((r) => r != ConnectivityResult.none);
            if (isConnected && error.value.isNotEmpty) {
              debugPrint(
                '[MiniplayerController] 🌐 Internet restored. Attempting recovery...',
              );
              attemptRecovery();
            }
          }),
    );
  }

  @override
  void onClose() {
    _isClosed = true;
    _recoveryDebounceTimer?.cancel();
    _stopPositionTimer();
    _hideControlsTimer?.cancel();
    _connectivitySubscription?.cancel();
    _disposeVideoControllers();
    super.onClose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CORE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<String> _resolvePlayableUrl(Video video, String? overrideUrl) async {
    String? targetUrl;

    if (overrideUrl != null && overrideUrl.isNotEmpty) {
      targetUrl = overrideUrl;
    }

    final validAdaptive = video.adaptiveResolutions.where((r) {
      final u = r.url.trim().toLowerCase();
      final l = r.label.toLowerCase();
      return u.isNotEmpty &&
          !l.contains('audio') &&
          !u.contains('/audio');
    }).toList();

    final nonOriginalAdaptive = validAdaptive.where((r) {
      final u = r.url.toLowerCase();
      return !u.endsWith('original.mp4') && !u.contains('/original/');
    }).toList();

    final preferredAdaptive = nonOriginalAdaptive.isNotEmpty
        ? nonOriginalAdaptive
        : validAdaptive;

    if (targetUrl == null || targetUrl.isEmpty) {
      if (kIsWeb) {
        // On web, avoid .m3u8 HLS if MP4 resolutions are available
        final mp4Res = preferredAdaptive.firstWhereOrNull(
          (r) => !r.url.contains('.m3u8'),
        );
        if (mp4Res != null) {
          targetUrl = mp4Res.url;
        } else if (video.hlsUrl.isNotEmpty &&
            !video.hlsUrl.endsWith('original.mp4') &&
            !video.hlsUrl.contains('/original/')) {
          targetUrl = video.hlsUrl;
        }
      } else {
        // On native, prefer HLS or adaptive resolutions
        if (video.hlsUrl.isNotEmpty &&
            !video.hlsUrl.startsWith('gs://') &&
            !video.hlsUrl.endsWith('original.mp4') &&
            !video.hlsUrl.contains('/original/')) {
          targetUrl = video.hlsUrl;
        } else if (preferredAdaptive.isNotEmpty) {
          targetUrl = preferredAdaptive.first.url;
        }
      }
    }

    // Fallback: Query VideoMediaService for streaming resolutions if model lacks them
    if ((targetUrl == null || targetUrl.isEmpty) && video.id.isNotEmpty) {
      try {
        final streaming = await VideoMediaService().getStreaming(video.id);
        final streamingValid = streaming.adaptiveResolutions.where((r) {
          final u = r.url.trim().toLowerCase();
          final l = r.label.toLowerCase();
          return u.isNotEmpty &&
              !l.contains('audio') &&
              !u.contains('/audio');
        }).toList();

        final streamingNonOriginal = streamingValid.where((r) {
          final u = r.url.toLowerCase();
          return !u.endsWith('original.mp4') && !u.contains('/original/');
        }).toList();

        final preferredStreaming = streamingNonOriginal.isNotEmpty
            ? streamingNonOriginal
            : streamingValid;

        if (streamingValid.isNotEmpty) {
          final mp4Res = kIsWeb
              ? preferredStreaming.firstWhereOrNull((r) => !r.url.contains('.m3u8'))
              : null;
          targetUrl = mp4Res?.url ?? preferredStreaming.first.url;
        } else if (streaming.hlsUrl.isNotEmpty &&
            !streaming.hlsUrl.endsWith('original.mp4') &&
            !streaming.hlsUrl.contains('/original/')) {
          targetUrl = streaming.hlsUrl;
        }
      } catch (_) {}
    }

    // Absolute fallback: check video.videoUrl, video.originalUrl, or video.hlsUrl
    if (targetUrl == null || targetUrl.isEmpty) {
      if (video.videoUrl.isNotEmpty) {
        targetUrl = video.videoUrl;
      } else if (video.originalUrl.isNotEmpty) {
        targetUrl = video.originalUrl;
      } else if (video.hlsUrl.isNotEmpty) {
        targetUrl = video.hlsUrl;
      }
    }

    // Fast-download CDN and authenticated resolution for storage paths
    if (targetUrl != null && targetUrl.isNotEmpty) {
      targetUrl = await StorageUtils.resolveUrl(targetUrl);
    }

    return targetUrl ?? '';
  }

  bool _isIgnorablePlaybackError(String? msg) {
    if (msg == null || msg.trim().isEmpty) return true;
    final lower = msg.toLowerCase();
    return lower.contains('interrupted') ||
        lower.contains('removed from the document') ||
        lower.contains('media was removed') ||
        lower.contains('abort') ||
        lower.contains('notallowederror') ||
        lower.contains('user gesture') ||
        lower.contains('pause()') ||
        lower.contains('new load request') ||
        lower.contains('media_err_aborted');
  }

  int _recoveryAttempts = 0;
  static const int _maxRecoveryAttempts = 2;
  Timer? _recoveryDebounceTimer;

  void _scheduleAutoRecovery() {
    if (_isClosed || currentVideo.value == null) return;
    if (_recoveryAttempts >= _maxRecoveryAttempts) {
      error.value = 'Playback error. Tap to retry.';
      return;
    }
    _recoveryDebounceTimer?.cancel();
    _recoveryDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (!_isClosed && currentVideo.value != null) {
        _recoveryAttempts++;
        attemptRecovery();
      }
    });
  }

  void _vpcListener() {
    final vpc = _vpc;
    if (vpc == null || _isClosed) return;
    try {
      final val = vpc.value;
      isPlaying.value = val.isPlaying;
      currentPosition.value = val.position;
      isBuffering.value = val.isBuffering;
      if (val.duration > Duration.zero) {
        totalDuration.value = val.duration;
      }
      if (val.hasError) {
        final err = val.errorDescription;
        if (_isIgnorablePlaybackError(err)) {
          debugPrint(
            '[MiniplayerController] Ignored benign browser playback interruption: $err',
          );
        } else if (error.value.isEmpty) {
          debugPrint('[MiniplayerController] Playback error detected: $err');
          _scheduleAutoRecovery();
        }
      }
    } catch (_) {}
  }

  /// Load a [video] into the miniplayer and begin playback.
  ///
  /// If [resumeFromPosition] is provided the player will seek after init.
  Future<void> showWithVideo(
    Video video, {
    Duration? resumeFromPosition,
    String? overrideUrl,
  }) async {
    if (_isClosed) return;

    // Reset error state
    error.value = '';
    _recoveryDebounceTimer?.cancel();

    // If same video is already loaded and active, just ensure visibility and play
    if (videoInfo.value?.id == video.id && _vpc != null && isVideoReady.value) {
      mode.value = MiniplayerMode.collapsed;
      try {
        HoverPreviewCoordinator.globalMute.value = true;
        await _vpc!.play();
        isPlaying.value = true;
      } catch (e) {
        if (!_isIgnorablePlaybackError(e.toString())) {
          try {
            await _vpc!.setVolume(0);
            await _vpc!.play();
            isPlaying.value = true;
          } catch (_) {}
        }
      }
      return;
    }

    // Dispose previous
    _disposeVideoControllers();

    // Populate metadata first so the UI shows thumbnail immediately
    videoInfo.value = MiniplayerVideoInfo.fromVideo(video);
    currentVideo.value = video;
    mode.value = MiniplayerMode.collapsed;
    dragProgress.value = 0.0;
    isPlaying.value = false;
    isBuffering.value = true;
    isVideoReady.value = false;
    currentPosition.value = resumeFromPosition ?? Duration.zero;
    totalDuration.value = video.durationValue;

    // Sync and load subtitles if global subtitles are enabled
    subtitlesEnabled.value = TowerPlayerController.globalSubtitlesEnabled;
    if (subtitlesEnabled.value) {
      _loadBestSubtitleTrack();
    } else {
      subtitleSegments.clear();
      currentSubtitle.value = '';
    }

    if (video.status == VideoStatus.rejected ||
        video.visibility == 'rejected' ||
        video.channelStatus == 'rejected') {
      isBuffering.value = false;
      error.value =
          'This video has been removed for violating community guidelines.';
      return;
    }

    try {
      final handoffVpc =
          !kIsWeb ? VideoPlaybackHandoff.retrieveController(video.id) : null;
      final VideoPlayerController vpc;
      final wasHandoff = handoffVpc != null && !handoffVpc.value.hasError;

      if (wasHandoff) {
        debugPrint(
          '[MiniplayerController] Found active handoff controller for: ${video.id}',
        );
        vpc = handoffVpc;
        try {
          await vpc.setLooping(false);
          await vpc.setVolume(1.0);
        } catch (_) {}
      } else {
        if (handoffVpc != null) {
          try {
            handoffVpc.dispose();
          } catch (_) {}
        }
        final targetUrl = await _resolvePlayableUrl(video, overrideUrl);
        if (targetUrl.isEmpty) {
          debugPrint('[MiniplayerController] Video URL is empty');
          error.value = 'Video unavailable';
          isBuffering.value = false;
          return;
        }

        debugPrint('[MiniplayerController] Initializing player for: $targetUrl');
        vpc = VideoPlayerController.networkUrl(
          Uri.parse(targetUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        await vpc.initialize();
      }

      if (_isClosed) {
        vpc.dispose();
        return;
      }

      _vpc = vpc;
      vpc.addListener(_vpcListener);

      totalDuration.value = vpc.value.duration;
      isBuffering.value = false;
      isVideoReady.value = true;

      // Seek to resume position if provided
      if (resumeFromPosition != null &&
          resumeFromPosition > Duration.zero &&
          resumeFromPosition < vpc.value.duration) {
        await vpc.seekTo(resumeFromPosition);
        currentPosition.value = resumeFromPosition;
      }

      // Explicitly start playback so the miniplayer plays when appearing
      HoverPreviewCoordinator.globalMute.value = true;
      try {
        await vpc.play();
        isPlaying.value = true;
      } catch (e) {
        final errorMsg = e.toString();
        debugPrint(
          '[MiniplayerController] Play error, attempting muted autoplay fallback: $errorMsg',
        );
        try {
          await vpc.setVolume(0);
          await vpc.play();
          isPlaying.value = true;
        } catch (e2) {
          debugPrint('[MiniplayerController] Play fallback failed: $e2');
          // If browser blocked playback, leave paused without showing error
          isPlaying.value = false;
        }
      }

      _startPositionTimer();
    } catch (e) {
      if (_isClosed) return;
      final errorMsg = e.toString();
      debugPrint('[MiniplayerController] Init error: $e');

      isBuffering.value = false;
      isVideoReady.value = false;

      if (_isIgnorablePlaybackError(errorMsg)) {
        // Benign error during init / play, do not show error on UI
        return;
      }

      if (errorMsg.contains('MEDIA_ERR_SRC_NOT_SUPPORTED') ||
          errorMsg.contains('Format error')) {
        error.value =
            'Video format not supported. Tap to retry or open in full player.';
      } else {
        _scheduleAutoRecovery();
      }
    }
  }

  /// Dismiss the miniplayer and clean up all resources.
  void dismiss() {
    if (_isClosed) return;
    _recoveryDebounceTimer?.cancel();
    _recoveryAttempts = 0;
    _disposeVideoControllers();
    mode.value = MiniplayerMode.dismissed;
    videoInfo.value = null;
    currentVideo.value = null;
    isPlaying.value = false;
    isVideoReady.value = false;
    currentPosition.value = Duration.zero;
    totalDuration.value = Duration.zero;
    error.value = '';
    dragProgress.value = 0.0;
    dragOffset.value = null;
    isHovering.value = false;
  }

  void toggleSubtitles() {
    final enabled = !subtitlesEnabled.value;
    subtitlesEnabled.value = enabled;
    TowerPlayerController.globalSubtitlesEnabled = enabled;

    if (enabled) {
      _loadBestSubtitleTrack();
    } else {
      subtitleSegments.clear();
      currentSubtitle.value = '';
    }
  }

  Future<void> _loadBestSubtitleTrack() async {
    final video = currentVideo.value;
    if (video == null) return;

    final subs = video.mediaSubtitles;
    if (subs.isEmpty) return;

    // Find the primary/first available subtitle track
    final selectedUrl = subs['en'] ?? subs.values.firstOrNull;
    if (selectedUrl == null) return;

    await fetchAndParseSubtitles(selectedUrl);
  }

  Future<void> fetchAndParseSubtitles(String url) async {
    if (url.isEmpty) return;
    try {
      String? content;
      try {
        final resolvedUrl = StorageUtils.getFastDownloadUrl(url);
        final response = await http.get(Uri.parse(resolvedUrl));
        if (response.statusCode == 200) {
          content = utf8.decode(response.bodyBytes, allowMalformed: true);
        }
      } catch (_) {}

      if (content == null || content.isEmpty) {
        try {
          Uint8List? data;
          if (url.startsWith('gs://') ||
              url.startsWith('https://storage.googleapis.com/') ||
              url.startsWith('https://firebasestorage.googleapis.com/')) {
            data = await FirebaseStorage.instance.refFromURL(url).getData();
          } else if (url.startsWith('subtitles/') || url.startsWith('transcripts/')) {
            data = await FirebaseStorage.instance.ref(url).getData();
          }
          if (data != null && data.isNotEmpty) {
            content = utf8.decode(data, allowMalformed: true);
          }
        } catch (_) {}
      }

      if (content != null && content.isNotEmpty) {
        subtitleSegments.assignAll(SubtitleParser.parse(content));
      }
    } catch (e) {
      debugPrint('[MiniplayerController] Subtitle error: $e');
      subtitleSegments.clear();
    }
  }

  SubtitleSegment? _findSubtitle(Duration pos) {
    return SubtitleParser.findActiveSubtitle(subtitleSegments, pos);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PLAYBACK CONTROLS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> togglePlayPause() async {
    final vpc = _vpc;
    if (vpc == null) return;
    if (vpc.value.isPlaying) {
      await vpc.pause();
      isPlaying.value = false;
    } else {
      HoverPreviewCoordinator.globalMute.value = true;
      try {
        await vpc.play();
        isPlaying.value = true;
      } catch (e) {
        debugPrint('[MiniplayerController] togglePlayPause error: $e');
        try {
          await vpc.setVolume(0);
          await vpc.play();
          isPlaying.value = true;
        } catch (_) {}
      }
    }
  }

  Future<void> seekForward({int seconds = 10}) async {
    final vpc = _vpc;
    if (vpc == null) return;
    final target = vpc.value.position + Duration(seconds: seconds);
    final clamped = target > vpc.value.duration ? vpc.value.duration : target;
    currentPosition.value = clamped;
    await vpc.seekTo(clamped);
  }

  Future<void> seekBackward({int seconds = 10}) async {
    final vpc = _vpc;
    if (vpc == null) return;
    final target = vpc.value.position - Duration(seconds: seconds);
    final clamped = target < Duration.zero ? Duration.zero : target;
    currentPosition.value = clamped;
    await vpc.seekTo(clamped);
  }

  Future<void> seekTo(Duration position) async {
    final vpc = _vpc;
    if (vpc == null) return;
    currentPosition.value = position;
    await vpc.seekTo(position);
  }

  Future<void> seekToRatio(double ratio) async {
    final vpc = _vpc;
    if (vpc == null) return;
    final totalMs = totalDuration.value.inMilliseconds;
    if (totalMs <= 0) return;
    final targetMs = (totalMs * ratio.clamp(0.0, 1.0)).toInt();
    final targetDuration = Duration(milliseconds: targetMs);
    currentPosition.value = targetDuration;
    await vpc.seekTo(targetDuration);
  }

  void toggleMobileControls() {
    showMobileControls.value = !showMobileControls.value;
    _hideControlsTimer?.cancel();
    if (showMobileControls.value) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (!_isClosed) {
          showMobileControls.value = false;
        }
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW STATE TRANSITIONS (expand / collapse / drag)
  // ═══════════════════════════════════════════════════════════════════════════

  void expand() {
    if (mode.value == MiniplayerMode.expanded) return;
    mode.value = MiniplayerMode.expanded;
    dragProgress.value = 1.0;
  }

  void collapse() {
    if (mode.value == MiniplayerMode.collapsed) return;
    mode.value = MiniplayerMode.collapsed;
    dragProgress.value = 0.0;
  }

  void onDragUpdate(double delta, double screenHeight) {
    if (mode.value == MiniplayerMode.dismissed) return;
    mode.value = MiniplayerMode.dragging;
    // Delta is negative when dragging up (expanding)
    final newProgress = (dragProgress.value - delta / screenHeight).clamp(
      0.0,
      1.0,
    );
    dragProgress.value = newProgress;
  }

  void onDragEnd() {
    if (mode.value != MiniplayerMode.dragging) return;

    // If dragging down from collapsed state past dismiss threshold, dismiss
    if (dragProgress.value < 0.15 && mode.value == MiniplayerMode.dragging) {
      // Check if we were collapsed and dragged down
      final previousMode = mode.value;
      if (previousMode == MiniplayerMode.dragging &&
          dragProgress.value < MiniplayerConfig.dismissThreshold) {
        dismiss();
        return;
      }
    }

    // Otherwise, snap to nearest state based on snap threshold
    if (dragProgress.value > MiniplayerConfig.snapThreshold) {
      expand();
    } else {
      collapse();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Free-positioning drag (YouTube-style: card can be moved anywhere)
  // ───────────────────────────────────────────────────────────────────────────

  /// Translate the floating card by [delta] pixels, keeping it on-screen.
  /// [cardSize] is the card's logical size and [screenSize] the viewport.
  void onPanCard(Offset delta, Size cardSize, Size screenSize) {
    if (mode.value != MiniplayerMode.collapsed &&
        mode.value != MiniplayerMode.dragging) {
      return;
    }
    final current =
        dragOffset.value ?? _defaultDockOffset(cardSize, screenSize);
    final maxX = (screenSize.width - cardSize.width).clamp(
      0.0,
      double.infinity,
    );
    final maxY = (screenSize.height - cardSize.height).clamp(
      0.0,
      double.infinity,
    );
    dragOffset.value = Offset(
      (current.dx + delta.dx).clamp(0.0, maxX),
      (current.dy + delta.dy).clamp(0.0, maxY),
    );
  }

  /// Resolve the effective top-left position of the card given the viewport.
  /// Falls back to bottom-right docking when the user hasn't moved it yet.
  Offset effectiveOffset(Size cardSize, Size screenSize) {
    final stored = dragOffset.value;
    if (stored == null) return _defaultDockOffset(cardSize, screenSize);
    final maxX = (screenSize.width - cardSize.width).clamp(
      0.0,
      double.infinity,
    );
    final maxY = (screenSize.height - cardSize.height).clamp(
      0.0,
      double.infinity,
    );
    return Offset(
      stored.dx.clamp(0.0, maxX),
      stored.dy.clamp(0.0, maxY),
    );
  }

  Offset _defaultDockOffset(Size cardSize, Size screenSize) {
    const inset = MiniplayerConfig.dockInset;
    return Offset(
      (screenSize.width - cardSize.width - inset).clamp(0.0, double.infinity),
      (screenSize.height - cardSize.height - inset).clamp(0.0, double.infinity),
    );
  }

  /// Hover state — used to fade overlay controls in and out.
  void setHovering(bool value) {
    if (isHovering.value != value) isHovering.value = value;
  }

  /// Navigate to full video screen and close miniplayer.
  void openFullScreen() {
    final video = currentVideo.value;
    if (video == null) return;

    // Capture the most accurate live position available from hardware or periodic tracker
    var pos = currentPosition.value;
    if (_vpc != null && _vpc!.value.isInitialized && _vpc!.value.position > Duration.zero) {
      pos = _vpc!.value.position;
    }

    mode.value = MiniplayerMode.transitioning;

    // Register active controller & live timestamp for handoff BEFORE navigating
    if (_vpc != null && !kIsWeb) {
      try {
        _vpc!.removeListener(_vpcListener);
      } catch (_) {}
      VideoPlaybackHandoff.registerActiveController(video.id, _vpc!, position: pos);
      // Set to null so dismiss() won't dispose it while handing over!
      _vpc = null;
    } else {
      // On web or when controller is null, ensure exact resume position is registered
      VideoPlaybackHandoff.registerResumePosition(video.id, pos);
    }

    final args = <String, dynamic>{
      'video': video,
      'resumePosition': pos.inMilliseconds,
      'initialPosition': pos,
      'isFromMiniplayer': true,
    };

    final currentRoute = Get.currentRoute.toLowerCase();
    final isCurrentlyOnWatch =
        currentRoute.contains('/watch') && currentRoute.contains(video.id);

    if (!isCurrentlyOnWatch) {
      Get.toNamed(
        '/watch?v=${video.id}',
        arguments: args,
        preventDuplicates: false,
      );
    }

    // Give navigation transition 600ms to complete smoothly before cleaning up transitioning state.
    // VideoScreen's postFrameCallback will also call dismiss() once mounted.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!_isClosed && mode.value == MiniplayerMode.transitioning) {
        dismiss();
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS (formatted time)
  // ═══════════════════════════════════════════════════════════════════════════

  String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Periodic position sampler running at ~4 Hz.
  /// Much cheaper than a per-frame listener on the VideoPlayerController.
  void _startPositionTimer() {
    _stopPositionTimer();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final vpc = _vpc;
      if (vpc == null || _isClosed) return;

      final VideoPlayerValue val;
      try {
        val = vpc.value;
      } catch (_) {
        return;
      }
      isPlaying.value = val.isPlaying;
      currentPosition.value = val.position;
      isBuffering.value = val.isBuffering;

      // Subtitle lookup
      if (subtitlesEnabled.value && subtitleSegments.isNotEmpty) {
        final pos = val.position;
        final seg = _findSubtitle(pos);
        currentSubtitle.value = seg?.text ?? '';
      } else {
        currentSubtitle.value = '';
      }

      // Auto-collapse when complete
      if (val.position >= val.duration &&
          val.duration > Duration.zero &&
          !val.isPlaying) {
        isPlaying.value = false;
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _disposeVideoControllers() {
    _stopPositionTimer();
    if (_vpc != null) {
      try {
        _vpc!.removeListener(_vpcListener);
      } catch (_) {}
      try {
        _vpc!.pause();
      } catch (_) {}
      try {
        _vpc!.dispose();
      } catch (_) {}
      _vpc = null;
    }
  }

  Widget _errorWidget(String msg) {
    return const ColoredBox(
      color: AppColors.bgPage,
      child: Center(
        child: Icon(
          Icons.error_outline,
          color: AppColors.textPrimary,
          size: 32,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ERROR HANDLING & RECOVERY
  // ═══════════════════════════════════════════════════════════════════════════

  /// Attempt to recover from an error state by re-initializing if possible.
  Future<void> attemptRecovery() async {
    if (_isClosed || currentVideo.value == null) return;

    final currentPos = currentPosition.value;
    final wasPlaying = isPlaying.value;

    debugPrint(
      '[MiniplayerController] 🔄 Attempting recovery from ${currentPos.inSeconds}s (attempt $_recoveryAttempts)...',
    );

    error.value = '';
    isBuffering.value = true;

    try {
      await showWithVideo(
        currentVideo.value!,
        resumeFromPosition: currentPos,
      );

      if (wasPlaying && _vpc != null) {
        try {
          await _vpc!.play();
          isPlaying.value = true;
        } catch (_) {
          try {
            await _vpc!.setVolume(0);
            await _vpc!.play();
            isPlaying.value = true;
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[MiniplayerController] ❌ Recovery failed: $e');
      if (_recoveryAttempts >= _maxRecoveryAttempts) {
        error.value = 'Playback error. Tap to retry.';
      }
    } finally {
      isBuffering.value = false;
    }
  }

  /// Clear any existing error state.
  @override
  void clearError() {
    error.value = '';
  }

  /// Check if the miniplayer is in a healthy state.
  bool get isHealthy =>
      !_isClosed &&
      error.value.isEmpty &&
      (mode.value == MiniplayerMode.dismissed || _vpc != null);
}
