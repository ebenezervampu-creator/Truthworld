import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player/video_player.dart';

/// Base state class holding all reactive observables and state references
/// for the miniplayer controller.
abstract class MiniplayerStateBase extends BaseController
    with GetTickerProviderStateMixin {
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

  /// Whether subtitles are enabled in the miniplayer.
  final RxBool subtitlesEnabled = false.obs;

  /// Parsed subtitle segments.
  final RxList<SubtitleSegment> subtitleSegments = <SubtitleSegment>[].obs;

  /// Current active subtitle text.
  final RxString currentSubtitle = ''.obs;

  /// Whether the player is currently buffering.
  final RxBool isBuffering = false.obs;

  /// Free-form drag offset of the collapsed miniplayer card.
  ///
  /// `null` means: dock to bottom-right (default). When the user drags the
  /// card, this becomes the explicit top-left position in viewport pixels.
  final Rxn<Offset> dragOffset = Rxn<Offset>();

  /// Whether the pointer is currently hovering the miniplayer (web/desktop).
  /// Used to fade controls in/out smoothly.
  final RxBool isHovering = false.obs;

  /// Whether mobile touch controls are currently visible on top of the video frame.
  final RxBool showMobileControls = false.obs;

  /// Whether miniplayer audio is currently muted.
  final RxBool isMuted = false.obs;

  /// Whether the video is currently rendered in system Picture-in-Picture mode.
  final RxBool isPiP = false.obs;

  /// Live aspect ratio of the loaded video.
  double get currentAspectRatio {
    final vpc = internalVpc;
    if (vpc != null && vpc.value.aspectRatio > 0) {
      return vpc.value.aspectRatio;
    }
    return MiniplayerConfig.videoAspectRatio;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INTERNAL NON-REACTIVE STATE
  // ═══════════════════════════════════════════════════════════════════════════

  VideoPlayerController? internalVpc;
  String? currentPlayingUrl;
  Timer? positionTimer;
  Timer? hideControlsTimer;
  Timer? transitionTimer;
  bool isControllerClosed = false;
  StreamSubscription? connectivitySubscription;

  int recoveryAttempts = 0;
  static const int maxRecoveryAttempts = 2;
  Timer? recoveryDebounceTimer;

  // ── Public read-only accessors ──
  VideoPlayerController? get videoPlayerController => internalVpc;
  bool get isVisible => mode.value != MiniplayerMode.dismissed;

  /// Check if the miniplayer is in a healthy state.
  bool get isHealthy =>
      !isControllerClosed &&
      error.value.isEmpty &&
      (mode.value == MiniplayerMode.dismissed || internalVpc != null);

  /// Clear any existing error state.
  @override
  void clearError() {
    error.value = '';
  }

  /// Cancels any active connectivity stream subscription.
  void cancelConnectivitySubscription() {
    connectivitySubscription?.cancel();
    connectivitySubscription = null;
  }

  /// Format a duration into HH:mm:ss or mm:ss display string.
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

  /// Filter out expected/benign browser interruptions from failing hard.
  bool isIgnorablePlaybackError(String? msg) {
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

  // Abstract contracts implemented across mixins
  void dismiss();
  void expand();
  void collapse();
  Future<void> attemptRecovery();
  Future<void> showWithVideo(
    Video video, {
    Duration? resumeFromPosition,
    String? overrideUrl,
  });
}
