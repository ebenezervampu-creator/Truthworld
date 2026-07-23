// ============================================================
// player_lock_controller.dart
// Dedicated Controller for Touch Lock Screen State & Unlock Pill
// ============================================================

import 'dart:async';
import 'package:get/get.dart';

enum UnlockPillState {
  hidden,
  visible,
}

/// Controller managing screen lock state and floating unlock hint pill
class PlayerLockController extends GetxController {
  final RxBool isLocked = false.obs;
  final Rx<UnlockPillState> pillState = UnlockPillState.hidden.obs;
  Timer? _pillHideTimer;

  void lock() {
    isLocked.value = true;
    showUnlockHint();
  }

  void unlock() {
    isLocked.value = false;
    pillState.value = UnlockPillState.hidden;
    _pillHideTimer?.cancel();
  }

  void toggleLock() {
    if (isLocked.value) {
      unlock();
    } else {
      lock();
    }
  }

  /// Show YouTube-style floating unlock pill for 3 seconds
  void showUnlockHint() {
    if (!isLocked.value) return;
    pillState.value = UnlockPillState.visible;
    _pillHideTimer?.cancel();
    _pillHideTimer = Timer(const Duration(seconds: 3), () {
      pillState.value = UnlockPillState.hidden;
    });
  }

  @override
  void onClose() {
    _pillHideTimer?.cancel();
    super.onClose();
  }
}
