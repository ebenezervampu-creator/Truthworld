import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card/video_card_controller.dart';

/// 🎯 LRU Eviction Registry for VideoCardController
///
/// Prevents memory bloat and controller accumulation during infinite feed scrolling.
/// Enforces a hard maximum limit on registered [VideoCardController] instances in GetX
/// by automatically evicting the oldest unhovered and inactive controllers.
class VideoCardControllerRegistry {
  VideoCardControllerRegistry._();

  /// Maximum number of active VideoCardControllers kept simultaneously in GetX.
  static const int maxActiveControllers = 40;

  /// Access-ordered list of controller tags (most recently accessed at the end).
  static final List<String> _tagOrder = <String>[];

  @visibleForTesting
  static List<String> get tagOrder => List.unmodifiable(_tagOrder);

  /// Current number of tracked card controller tags.
  static int get activeCount => _tagOrder.length;

  /// Records access to a card controller tag, promoting it to the MRU position
  /// and evicting the oldest inactive controller if capacity is exceeded.
  static void recordAccess(String tag) {
    _tagOrder.remove(tag);
    _tagOrder.add(tag);

    // Evict oldest inactive controllers when exceeding capacity
    while (_tagOrder.length > maxActiveControllers) {
      var evicted = false;
      for (var i = 0; i < _tagOrder.length; i++) {
        final candidateTag = _tagOrder[i];
        if (!Get.isRegistered<VideoCardController>(tag: candidateTag)) {
          _tagOrder.remove(candidateTag);
          evicted = true;
          break;
        }

        final ctrl = Get.find<VideoCardController>(tag: candidateTag);
        if (!ctrl.isHovered && !ctrl.hasActivePlayer) {
          _tagOrder.remove(candidateTag);
          Get.delete<VideoCardController>(tag: candidateTag);
          evicted = true;
          break;
        }
      }

      // If all controllers are currently playing or hovered, break to avoid loop
      if (!evicted) break;
    }
  }

  /// Removes a tag from the registry when explicitly disposed.
  static void unregisterTag(String tag) {
    _tagOrder.remove(tag);
  }

  /// Clears the registry (useful for testing and major navigation resets).
  static void clear() {
    _tagOrder.clear();
  }
}
