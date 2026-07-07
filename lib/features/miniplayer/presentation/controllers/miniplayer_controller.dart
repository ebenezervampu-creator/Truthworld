import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';

/// Production-grade miniplayer controller.
///
/// Design principles:
///  1. **Granular Rx variables** — each observable holds the smallest possible
///     unit of state. Widgets only rebuild when the exact field they depend on
///     changes (no monolithic `Rx<BigState>` triggering global rebuilds).
///  2. **Single listener cleanup** — video position listener is tracked and
///     removed before attaching a new one to prevent memory leaks.
///  3. **Throttled position updates** — position is sampled at ~4 Hz via a
///     periodic timer instead of every vsync frame (~60 Hz) to reduce reactive
///     overhead without visible UX impact.
///  4. **Safe disposal** — every async gap checks `_isClosed` before touching
///     state to avoid "controller already disposed" errors.
class MiniplayerController extends GetxController
    with GetTickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON ACCESSOR
  // ═══════════════════════════════════════════════════════════════════════════

  static MiniplayerController get to {
    try {
      return Get.find<MiniplayerController>(tag: 'miniplayer');
    } catch (e) {
      // If not registered, register it on the fly (failsafe)
      debugPrint('MiniplayerController.to: Controller not found, registering failsafe.');
      return Get.put<MiniplayerController>(
        MiniplayerController(),
        tag: 'miniplayer',
        permanent: true,
      );
    }
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

  // ═══════════════════════════════════════════════════════════════════════════
  // NON-REACTIVE STATE
  // ═══════════════════════════════════════════════════════════════════════════

  VideoPlayerController? _vpc;
  ChewieController? _chewie;
  Timer? _positionTimer;
  bool _isClosed = false;
  StreamSubscription? _connectivitySubscription;

  // ── Public read-only accessors ──
  VideoPlayerController? get videoPlayerController => _vpc;
  ChewieController? get chewieController => _chewie;
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
    _connectivitySubscription = Get.find<ConnectivityService>()
        .onConnectivityChanged
        .listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected && error.value.isNotEmpty) {
        debugPrint('[MiniplayerController] 🌐 Internet restored. Attempting recovery...');
        attemptRecovery();
      }
    });
  }

  @override
  void onClose() {
    _isClosed = true;
    _stopPositionTimer();
    _connectivitySubscription?.cancel();
    _disposeVideoControllers();
    super.onClose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CORE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

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

    String url = overrideUrl ?? video.videoUrl;
    if (url.isEmpty) {
      error.value = 'Video URL is empty';
      return;
    }

    // If same video is already loaded, just ensure visibility
    if (videoInfo.value?.id == video.id && _vpc != null) {
      mode.value = MiniplayerMode.collapsed;
      _vpc!.play();
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
    currentPosition.value = Duration.zero;
    totalDuration.value = video.durationValue;

    try {
      VideoPlayerController? handoffVpc = VideoPlaybackHandoff.retrieveController(video.id);
      final VideoPlayerController vpc;
      final bool wasHandoff = handoffVpc != null;

      if (wasHandoff) {
        debugPrint('[MiniplayerController] Found active handoff controller for: ${video.id}');
        vpc = handoffVpc;
        await vpc.setLooping(false); // Disable looping which was enabled for hover previews
        await vpc.setVolume(1.0); // Reset volume to unmute
      } else {
        // Resolve gs:// URLs if needed
        if (url.startsWith('gs://')) {
          try {
            url = await FirebaseStorage.instance.refFromURL(url).getDownloadURL();
          } catch (_) {
            // If import fails or resolution fails, let it fall through to networkUrl to fail naturally
          }
        }
        vpc = VideoPlayerController.networkUrl(Uri.parse(url));
        await vpc.initialize();
      }

      if (_isClosed) {
        vpc.dispose();
        return;
      }

      _vpc = vpc;
      _chewie = ChewieController(
        videoPlayerController: vpc,
        autoPlay: true,
        looping: false,
        showControls: false, // We render our own controls in the widget
        aspectRatio: vpc.value.aspectRatio,
        errorBuilder: (_, msg) => _errorWidget(msg),
      );

      totalDuration.value = vpc.value.duration;
      isBuffering.value = false;
      isVideoReady.value = true;

      // Seek to resume position if provided
      if (resumeFromPosition != null &&
          resumeFromPosition > Duration.zero &&
          resumeFromPosition < vpc.value.duration) {
        await vpc.seekTo(resumeFromPosition);
      }

      _startPositionTimer();
    } catch (e) {
      if (_isClosed) return;
      final errorMsg = e.toString();
      if (errorMsg.contains('MEDIA_ERR_SRC_NOT_SUPPORTED') ||
          errorMsg.contains('Format error')) {
        error.value = 'Video format not supported by browser. Please use H.264 encoded videos.';
      } else {
        error.value = 'Failed to load video: $e';
      }
      isBuffering.value = false;
      isVideoReady.value = false;
      debugPrint('[MiniplayerController] Init error: $e');
    }
  }

  /// Dismiss the miniplayer and clean up all resources.
  void dismiss() {
    if (_isClosed) return;
    _disposeVideoControllers();
    mode.value = MiniplayerMode.dismissed;
    videoInfo.value = null;
    isPlaying.value = false;
    isVideoReady.value = false;
    currentPosition.value = Duration.zero;
    totalDuration.value = Duration.zero;
    error.value = '';
    dragProgress.value = 0.0;
    dragOffset.value = null;
    isHovering.value = false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PLAYBACK CONTROLS
  // ═══════════════════════════════════════════════════════════════════════════

  void togglePlayPause() {
    final vpc = _vpc;
    if (vpc == null) return;
    vpc.value.isPlaying ? vpc.pause() : vpc.play();
  }

  void seekForward({int seconds = 10}) {
    final vpc = _vpc;
    if (vpc == null) return;
    final target = vpc.value.position + Duration(seconds: seconds);
    vpc.seekTo(target > vpc.value.duration ? vpc.value.duration : target);
  }

  void seekBackward({int seconds = 10}) {
    final vpc = _vpc;
    if (vpc == null) return;
    final target = vpc.value.position - Duration(seconds: seconds);
    vpc.seekTo(target < Duration.zero ? Duration.zero : target);
  }

  void seekTo(Duration position) {
    _vpc?.seekTo(position);
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
    final newProgress =
        (dragProgress.value - delta / screenHeight).clamp(0.0, 1.0);
    dragProgress.value = newProgress;
  }

  void onDragEnd() {
    if (mode.value != MiniplayerMode.dragging) return;
    
    // If dragging down from collapsed state past dismiss threshold, dismiss
    if (dragProgress.value < 0.15 && mode.value == MiniplayerMode.dragging) {
      // Check if we were collapsed and dragged down
      final previousMode = mode.value;
      if (previousMode == MiniplayerMode.dragging && dragProgress.value < MiniplayerConfig.dismissThreshold) {
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
    final current = dragOffset.value ?? _defaultDockOffset(cardSize, screenSize);
    final maxX = (screenSize.width - cardSize.width).clamp(0.0, double.infinity);
    final maxY = (screenSize.height - cardSize.height).clamp(0.0, double.infinity);
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
    final maxX = (screenSize.width - cardSize.width).clamp(0.0, double.infinity);
    final maxY = (screenSize.height - cardSize.height).clamp(0.0, double.infinity);
    return Offset(
      stored.dx.clamp(0.0, maxX),
      stored.dy.clamp(0.0, maxY),
    );
  }

  Offset _defaultDockOffset(Size cardSize, Size screenSize) {
    final inset = MiniplayerConfig.dockInset;
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
    final pos = currentPosition.value;

    mode.value = MiniplayerMode.transitioning;

    // Register active controller for handoff BEFORE navigating
    if (_vpc != null) {
      VideoPlaybackHandoff.registerActiveController(video.id, _vpc!);
      // Set to null so dismiss() / _disposeVideoControllers() won't dispose it!
      _vpc = null;
    }

    // Navigate first, then dismiss so the miniplayer doesn't flash
    Get.toNamed('/watch?v=${video.id}', arguments: {
      'video': video,
      'resumePosition': pos.inMilliseconds,
    });

    // Short delay to let the navigation start before disposing
    Future.delayed(const Duration(milliseconds: 100), dismiss);
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

      final val = vpc.value;
      isPlaying.value = val.isPlaying;
      currentPosition.value = val.position;
      isBuffering.value = val.isBuffering;

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
    _chewie?.dispose();
    _chewie = null;
    _vpc?.dispose();
    _vpc = null;
  }

  Widget _errorWidget(String msg) {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Icon(Icons.error_outline, color: Colors.white54, size: 32),
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

    debugPrint('[MiniplayerController] 🔄 Attempting recovery from ${currentPos.inSeconds}s...');

    error.value = '';
    isBuffering.value = true;

    try {
      await showWithVideo(
        currentVideo.value!,
        resumeFromPosition: currentPos,
      );

      if (wasPlaying) {
        _vpc?.play();
      }
    } catch (e) {
      debugPrint('[MiniplayerController] ❌ Recovery failed: $e');
      error.value = 'Failed to resume playback';
    } finally {
      isBuffering.value = false;
    }
  }

  /// Clear any existing error state.
  void clearError() {
    error.value = '';
  }

  /// Check if the miniplayer is in a healthy state.
  bool get isHealthy => 
      !_isClosed && 
      error.value.isEmpty && 
      (mode.value == MiniplayerMode.dismissed || _vpc != null);
}






