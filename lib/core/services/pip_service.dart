import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/web_platform_utils.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_registry.dart';

/// Core service coordinating system Picture-in-Picture (PiP) and background
/// playback state across mobile, desktop, and web.
class PipService extends GetxService {
  static const MethodChannel _pipChannel = MethodChannel(
    'com.example.truthworld/pip',
  );

  /// Reactive observable tracking whether the application is currently rendered
  /// inside an active Picture-in-Picture window.
  final RxBool isPiP = false.obs;

  /// Whether auto-enter PiP is enabled on home navigation / app minimization.
  final RxBool isAutoPipEnabled = false.obs;

  /// Currently configured aspect ratio (clamped to Android PiP bounds [0.418, 2.39]).
  final RxDouble currentAspectRatio = (16.0 / 9.0).obs;

  static PipService get to {
    if (Get.isRegistered<PipService>()) {
      return Get.find<PipService>();
    }
    return Get.put<PipService>(PipService(), permanent: true);
  }

  @override
  void onInit() {
    super.onInit();
    _initChannel();
  }

  void _initChannel() {
    if (kIsWeb) return;
    _pipChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        final inPip = call.arguments as bool? ?? false;
        setPipMode(inPip);
      }
    });
  }

  /// Update PiP mode status and notify active player controllers.
  void setPipMode(bool inPip) {
    if (isPiP.value == inPip) return;
    isPiP.value = inPip;
    debugPrint('[PipService] 📺 Picture-in-Picture mode changed: $inPip');

    // Notify registered TowerPlayer controllers
    for (final player in TowerPlayerRegistry.activePlayers) {
      player.isPiP.value = inPip;
      if (inPip) {
        player.controlsVisible.value = false;
        player.settingsOpen.value = false;
      }
    }

    // Notify Miniplayer controller if active
    if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer') ||
        Get.isRegistered<MiniplayerController>()) {
      try {
        final miniplayer = MiniplayerController.to;
        miniplayer.isPiP.value = inPip;
        if (inPip) {
          miniplayer.showMobileControls.value = false;
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'PipService.notifyMiniplayer');
      }
    }
  }

  /// Trigger immediate transition into Picture-in-Picture mode.
  Future<bool> enterPip({double? aspectRatio}) async {
    final ratio = (aspectRatio ?? currentAspectRatio.value).clamp(0.418, 2.39);
    currentAspectRatio.value = ratio;

    if (kIsWeb) {
      return _enterPipWeb();
    }

    try {
      await _pipChannel.invokeMethod('enterPip', {
        'aspectRatio': ratio,
      });
      return true;
    } catch (e, s) {
      if (e is! MissingPluginException) {
        ErrorHandler.log(e, stackTrace: s, tag: 'PipService.enterPip');
      }
      return false;
    }
  }

  /// Exit Picture-in-Picture mode if currently active (primarily Web).
  Future<bool> exitPip() async {
    if (kIsWeb) {
      return _exitPipWeb();
    }
    // On native mobile platforms, exiting PiP is triggered by the system UI / expand button
    return true;
  }

  /// Toggle Picture-in-Picture mode.
  Future<bool> togglePip({double? aspectRatio}) async {
    if (isPiP.value) {
      return exitPip();
    }
    return enterPip(aspectRatio: aspectRatio);
  }

  /// Updates system auto-enter PiP settings.
  /// When [enabled] is true and the user navigates Home or switches apps,
  /// the system will automatically transition playback into a floating PiP window.
  void updateAutoPip({required bool enabled, double? aspectRatio}) {
    final ratio = (aspectRatio ?? currentAspectRatio.value).clamp(0.418, 2.39);
    currentAspectRatio.value = ratio;
    isAutoPipEnabled.value = enabled;

    if (kIsWeb) return;

    _pipChannel.invokeMethod('setAutoEnterPip', {
      'enabled': enabled,
      'aspectRatio': ratio,
    }).catchError((dynamic e, StackTrace s) {
      if (e is MissingPluginException) return null;
      ErrorHandler.log(e, stackTrace: s, tag: 'PipService.updateAutoPip');
      return null;
    });
  }

  /// Check whether Picture-in-Picture is supported by the current device OS.
  Future<bool> isPipSupported() async {
    if (kIsWeb) {
      return WebPlatformUtils.isPipSupported();
    }

    try {
      final supported = await _pipChannel.invokeMethod<bool>('isPipSupported');
      return supported ?? false;
    } catch (e, s) {
      if (e is! MissingPluginException) {
        ErrorHandler.log(e, stackTrace: s, tag: 'PipService.isPipSupported');
      }
      return false;
    }
  }

  /// Check whether native platform activity is currently in Picture-in-Picture mode.
  Future<bool> isNativeInPip() async {
    if (kIsWeb) {
      return WebPlatformUtils.isDocumentInPip();
    }

    try {
      final inPip = await _pipChannel.invokeMethod<bool>('isInPip');
      return inPip ?? false;
    } catch (_) {
      return isPiP.value;
    }
  }

  bool _enterPipWeb() {
    final success = WebPlatformUtils.enterPip();
    if (success) {
      isPiP.value = true;
    }
    return success;
  }

  bool _exitPipWeb() {
    final success = WebPlatformUtils.exitPip();
    if (success) {
      isPiP.value = false;
    }
    return success;
  }
}
