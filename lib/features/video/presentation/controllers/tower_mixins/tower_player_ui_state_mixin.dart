import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_overlay_manager.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

/// Mixin defining the deterministic UI state and auto-hide state machine.
///
/// Invariant: Controls NEVER auto-hide while:
///   1. The user is actively scrubbing the timeline (`isScrubbing == true`)
///   2. Any blocking modal overlay is open (`overlayManager.hasBlockingOverlay == true`)
///   3. Playback is paused (`isPlaying == false`)
mixin TowerPlayerUIStateMixin on GetxController {
  // ── Visibility Observables ─────────────────────────────────
  final RxBool controlsVisible = true.obs;
  final RxBool topBarVisible = true.obs;
  final RxBool bottomBarVisible = true.obs;
  final RxBool centerControlsVisible = true.obs;

  // ── Contract required from controller / other mixins ──────
  TimerBag get timers;
  bool get isPlayingValue;
  bool get isScrubbingValue;
  TowerPlayerOverlayManager get overlayManager;

  /// Default timeout for controls auto-hide.
  /// 2.2s on desktop, 2.6s on mobile.
  Duration get autoHideDuration {
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return isMobile
        ? const Duration(milliseconds: 2600)
        : const Duration(milliseconds: 2200);
  }

  /// Whether controls should be strictly locked in the visible state.
  bool get shouldLockControls =>
      !isPlayingValue || isScrubbingValue || overlayManager.hasBlockingOverlay;

  /// Starts the auto-hide timer if controls are not locked.
  void startHideTimer([Duration? timeout]) {
    timers.cancel('hide');

    if (shouldLockControls) {
      controlsVisible.value = true;
      return;
    }

    final duration = timeout ?? autoHideDuration;
    timers.set('hide', duration, () {
      if (!shouldLockControls) {
        controlsVisible.value = false;
      }
    });
  }

  /// Explicitly cancels any scheduled auto-hide timer.
  void cancelHideTimer() {
    timers.cancel('hide');
  }

  /// Resets the timer and ensures controls are visible.
  void resetHideTimer([Duration? timeout]) {
    controlsVisible.value = true;
    startHideTimer(timeout);
  }

  /// User interaction trigger (pointer enter, tap, mouse move).
  void onInteraction() {
    controlsVisible.value = true;
    startHideTimer();
  }

  /// Temporarily reveals controls and begins normal auto-hide countdown.
  void showControlsTemporarily() {
    controlsVisible.value = true;
    startHideTimer();
  }
}
