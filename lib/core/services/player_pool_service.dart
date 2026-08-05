import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/config/app_config.dart';
import 'package:video_player/video_player.dart';

/// Bounded video decoder memory pool implementing LRU sliding-window eviction.
/// Holds at most [maxActivePlayers] (default 3: Previous, Current, Next) active instances
/// to prevent hardware video decoder exhaustion and RAM bloat during vertical scrolling.
class PlayerPoolService extends GetxService {
  PlayerPoolService({int? maxActivePlayers})
    : maxActivePlayers =
          maxActivePlayers ?? (AppConfig.instance.defaultPlayerPoolSize);
  static PlayerPoolService get to {
    if (!Get.isRegistered<PlayerPoolService>()) {
      Get.put(PlayerPoolService(), permanent: true);
    }
    return Get.find<PlayerPoolService>();
  }

  final int maxActivePlayers;
  final Map<String, VideoPlayerController> _pool = {};
  final List<String> _lruOrder = [];

  int get activePlayerCount => _pool.length;

  /// Register or acquire an active VideoPlayerController in the memory pool
  void registerPlayer(String id, VideoPlayerController controller) {
    if (_pool.containsKey(id)) {
      _lruOrder.remove(id);
      _lruOrder.add(id);
      return;
    }

    if (_pool.length >= maxActivePlayers) {
      _evictOldest();
    }

    _pool[id] = controller;
    _lruOrder.add(id);
    debugPrint(
      '🎥 [PlayerPool] Registered player: $id (Pool size: ${_pool.length}/$maxActivePlayers)',
    );
  }

  /// Evict the least recently used player outside the sliding active window
  void _evictOldest() {
    if (_lruOrder.isEmpty) return;
    final oldestId = _lruOrder.removeAt(0);
    final oldestController = _pool.remove(oldestId);

    if (oldestController != null) {
      try {
        if (oldestController.value.isInitialized) {
          oldestController.pause();
        }
        oldestController.dispose();
        debugPrint(
          '🗑️ [PlayerPool Evicted] Disposed player decoder for $oldestId',
        );
      } catch (e) {
        debugPrint('🔴 [PlayerPool Eviction Error] $oldestId: $e');
      }
    }
  }

  /// Keep only the specified [activeIds] alive in memory and evict all others
  void updateActiveWindow(List<String> activeIds) {
    final toRemove = _pool.keys.where((id) => !activeIds.contains(id)).toList();
    toRemove.forEach(disposePlayer);
  }

  /// Explicitly remove and dispose a specific player instance
  void disposePlayer(String id) {
    _lruOrder.remove(id);
    final controller = _pool.remove(id);
    if (controller != null) {
      try {
        if (controller.value.isInitialized) {
          controller.pause();
        }
        controller.dispose();
        debugPrint('⚫ [PlayerPool Disposed] Manually disposed player: $id');
      } catch (e) {
        debugPrint('🔴 [PlayerPool Error] Could not dispose $id: $e');
      }
    }
  }

  /// Dispose all active players on service teardown
  @override
  void onClose() {
    for (final controller in _pool.values) {
      try {
        controller.pause();
        controller.dispose();
      } catch (_) {}
    }
    _pool.clear();
    _lruOrder.clear();
    debugPrint('⚫ [PlayerPool Teardown] Cleared all video player instances');
    super.onClose();
  }
}
