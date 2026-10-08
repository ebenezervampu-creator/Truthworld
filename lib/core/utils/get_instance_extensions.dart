import 'package:get/get.dart';

/// Extensions on [GetInterface] to safely interact with controllers
/// without prematurely triggering lazy factories.
extension GetInstanceExtensions on GetInterface {
  /// Checks whether an instance of [T] has already been instantiated in memory.
  ///
  /// Unlike [isRegistered], this returns `false` if [T] was registered with
  /// [lazyPut] but has not yet been instantiated via [find].
  bool isInstantiated<T>({String? tag}) {
    return GetInstance().isRegistered<T>(tag: tag) &&
        !GetInstance().isPrepared<T>(tag: tag);
  }

  /// Finds and returns the active instance of [T] if and only if it is already
  /// instantiated in memory.
  ///
  /// Returns `null` if [T] is not registered or is registered lazily and has
  /// not yet been instantiated, avoiding unintended eager initialization.
  T? findIfInstantiated<T>({String? tag}) {
    if (isInstantiated<T>(tag: tag)) {
      return Get.find<T>(tag: tag);
    }
    return null;
  }
}
