import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';

/// Global registry managing active TowerPlayerController instances and picture-in-picture coordination.
class TowerPlayerRegistry {
  static final List<TowerPlayerController> _activePlayers = [];

  /// Read-only snapshot of currently active players
  static List<TowerPlayerController> get activePlayers =>
      List.unmodifiable(_activePlayers);

  static const MethodChannel _pipChannel = MethodChannel(
    'com.example.truthworld/pip',
  );

  static void Function(BuildContext context, TowerPlayerController ctrl)?
      showMobileSettingsCallback;

  /// Register an active player instance
  static void register(TowerPlayerController player) {
    if (!_activePlayers.contains(player)) {
      _activePlayers.add(player);
    }
  }

  /// Unregister an active player instance
  static void unregister(TowerPlayerController player) {
    _activePlayers.remove(player);
  }

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

  /// Pause all active players except the specified instance
  static void pauseAllActivePlayers({TowerPlayerController? except}) {
    for (final p in _activePlayers) {
      if (p != except && (p.vv.isPlaying || p.isPlaying.value)) {
        try {
          p.videoPlayerController.pause();
        } catch (_) {}
        p.isPlaying.value = false;
      }
    }
  }

  /// Initialize native PiP method channel listener
  static void initPipChannel() {
    if (kIsWeb) return;
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

  /// Tear down native PiP method channel handler
  static void disposePipChannel() {
    if (!kIsWeb) {
      _pipChannel.setMethodCallHandler(null);
    }
  }
}
