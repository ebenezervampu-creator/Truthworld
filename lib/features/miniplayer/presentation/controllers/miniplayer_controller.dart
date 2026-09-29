import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/pip_service.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer/miniplayer_barrel.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';

export 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer/miniplayer_barrel.dart';

/// Production-grade miniplayer controller coordinating playback, gestures,
/// subtitle sync, full-screen handoffs, and background / Picture-in-Picture.
class MiniplayerController extends MiniplayerStateBase
    with
        WidgetsBindingObserver,
        MiniplayerSubtitlesMixin,
        MiniplayerGesturesMixin,
        MiniplayerPlaybackMixin,
        MiniplayerHandoffMixin {
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
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _setupConnectivityListener();
    _setupPipListener();
  }

  void _setupPipListener() {
    isPiP.value = PipService.to.isPiP.value;
    trackSubscription(
      PipService.to.isPiP.listen((pip) {
        isPiP.value = pip;
        if (pip) {
          showMobileControls.value = false;
        }
      }),
    );
  }

  void _setupConnectivityListener() {
    if (!Get.isRegistered<ConnectivityService>()) return;
    connectivitySubscription = trackSubscription(
      Get.find<ConnectivityService>()
          .onConnectivityChanged
          .listen(
            (results) {
              final isConnected =
                  results.any((r) => r != ConnectivityResult.none);
              if (isConnected && error.value.isNotEmpty) {
                debugPrint(
                  '[MiniplayerController] 🌐 Internet restored. Attempting recovery...',
                );
                attemptRecovery();
              }
            },
            onError: (e, stackTrace) => ErrorHandler.log(
              e,
              stackTrace: stackTrace,
              tag: 'MiniplayerController.connectivityListener',
            ),
          ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      handleEnterBackgroundState();
    } else if (state == AppLifecycleState.resumed) {
      handleExitBackgroundState();
    }
  }

  /// Handles app transitioning to background or inactive state.
  void handleEnterBackgroundState() {
    // If currently playing in Picture-in-Picture window, maintain playback
    if (isPiP.value || PipService.to.isPiP.value) {
      return;
    }

    if (Get.isRegistered<UserSettingsController>()) {
      final bgMode =
          UserSettingsController.to.playback.value.backgroundPlaybackMode;
      if (bgMode == 'Off') {
        if (internalVpc != null) {
          try {
            internalVpc!.pause();
          } catch (_) {}
        }
        isPlaying.value = false;
      }
    }
  }

  /// Handles app returning to active foreground state.
  void handleExitBackgroundState() {
    // Synchronize PiP state on resume
    PipService.to.isNativeInPip().then((inPip) {
      if (!isControllerClosed) {
        isPiP.value = inPip;
      }
    });
  }

  @override
  void onClose() {
    isControllerClosed = true;
    WidgetsBinding.instance.removeObserver(this);
    PipService.to.updateAutoPip(enabled: false);
    recoveryDebounceTimer?.cancel();
    stopPositionTimer();
    hideControlsTimer?.cancel();
    transitionTimer?.cancel();
    cancelConnectivitySubscription();
    disposeVideoControllers();
    super.onClose();
  }
}
