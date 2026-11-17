import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/pip_service.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';

/// Global registry managing active TowerPlayerController instances and picture-in-picture coordination.
class TowerPlayerRegistry {
  static final List<TowerPlayerController> _activePlayers = [];
  static final Set<String> _disposedTags = <String>{};

  /// Read-only snapshot of currently active players
  static List<TowerPlayerController> get activePlayers =>
      List.unmodifiable(_activePlayers);

  /// Mark a tag as having had its TowerPlayerController disposed
  static void markDisposed(String tag) {
    if (tag.isNotEmpty) {
      _disposedTags.add(tag);
    }
  }

  /// Whether a player tag was recently disposed
  static bool isDisposed(String tag) => _disposedTags.contains(tag);

  /// Clear the disposed state for a player tag
  static void clearDisposed(String tag) {
    _disposedTags.remove(tag);
  }

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
    if (tag != null && tag.isNotEmpty && _activePlayers.isNotEmpty) {
      final match = _activePlayers.firstWhereOrNull((p) => p.tag == tag);
      if (match != null) return match;
    }
    if (Get.isRegistered<TowerPlayerController>()) {
      return Get.find<TowerPlayerController>();
    }
    if (_activePlayers.isNotEmpty) {
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
      if (p != except) {
        try {
          if (p.audioTrackController != null && p.audioTrackController!.value.isPlaying) {
            p.audioTrackController!.pause();
          }
        } catch (_) {}
      }
    }
    if (Get.isRegistered<AudioOnlyService>()) {
      try {
        final audioSvc = Get.find<AudioOnlyService>();
        if (audioSvc.isActive.value || audioSvc.isPlaying.value) {
          audioSvc.deactivateBackgroundPlayback();
        }
      } catch (_) {}
    }
    // Pause any active miniplayer instance to prevent dual-playback bleed
    try {
      if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer')) {
        final mini = Get.find<MiniplayerController>(tag: 'miniplayer');
        if (mini.isPlaying.value || (mini.internalVpc?.value.isPlaying ?? false)) {
          mini.internalVpc?.pause();
          mini.isPlaying.value = false;
        }
      } else if (Get.isRegistered<MiniplayerController>()) {
        final mini = Get.find<MiniplayerController>();
        if (mini.isPlaying.value || (mini.internalVpc?.value.isPlaying ?? false)) {
          mini.internalVpc?.pause();
          mini.isPlaying.value = false;
        }
      }
    } catch (_) {}
  }

  /// Initialize native PiP method channel listener via PipService
  static void initPipChannel() {
    PipService.to;
  }

  /// Tear down native PiP method channel handler
  static void disposePipChannel() {
    // Preserve global PipService handler across handoffs
  }
}
