import 'package:get/get.dart';
import 'package:truthworld/core/services/logger_service.dart';

/// Defensive service locator wrapper for GetX.
///
/// Prevents unhandled "T not found in GetX" runtime exceptions by offering
/// null-safe lookups, auto-creation fallbacks, and contextual error telemetry.
class SafeGet {
  const SafeGet._();

  /// Safely attempts to retrieve [T]. Returns `null` if not registered.
  static T? findOrNull<T>({String? tag}) {
    if (Get.isRegistered<T>(tag: tag)) {
      try {
        return Get.find<T>(tag: tag);
      } catch (e) {
        LoggerService().warning(
          'SafeGet: Failed to retrieve registered instance of $T: $e',
          tag: 'SafeGet',
        );
        return null;
      }
    }
    return null;
  }

  /// Retrieves [T] if registered. If absent, automatically instantiates it using [create],
  /// registers it in GetX, and returns the instance.
  ///
  /// Guarantees that screens never crash due to a missing route binding.
  static T findOrCreate<T>(
    T Function() create, {
    String? tag,
    bool permanent = false,
  }) {
    final existing = findOrNull<T>(tag: tag);
    if (existing != null) return existing;

    final instance = create();
    Get.put<T>(instance, tag: tag, permanent: permanent);
    return instance;
  }

  /// Safe retriever with fallback value.
  static T? findSafe<T>({String? tag, T? fallback}) {
    try {
      if (Get.isRegistered<T>(tag: tag)) {
        return Get.find<T>(tag: tag);
      }
      return fallback;
    } catch (e) {
      LoggerService().error(
        'SafeGet: Caught unhandled error finding $T: $e',
        tag: 'SafeGet',
      );
      return fallback;
    }
  }

  /// Checks whether an instance of [T] is ready in memory.
  static bool isReady<T>({String? tag}) => Get.isRegistered<T>(tag: tag);
}
