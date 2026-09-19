import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer/miniplayer_barrel.dart';

export 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer/miniplayer_barrel.dart';

/// Production-grade miniplayer controller coordinating playback, gestures,
/// subtitle sync, and full-screen handoffs.
class MiniplayerController extends MiniplayerStateBase
    with
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
    _setupConnectivityListener();
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
  void onClose() {
    isControllerClosed = true;
    recoveryDebounceTimer?.cancel();
    stopPositionTimer();
    hideControlsTimer?.cancel();
    transitionTimer?.cancel();
    cancelConnectivitySubscription();
    disposeVideoControllers();
    super.onClose();
  }
}
