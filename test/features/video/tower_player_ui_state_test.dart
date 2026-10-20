import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_mixins/tower_player_ui_state_mixin.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_overlay_manager.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

class TestUIStateController extends GetxController with TowerPlayerUIStateMixin {
  @override
  final TimerBag timers = TimerBag();

  final RxBool isPlaying = true.obs;
  final RxBool isScrubbing = false.obs;

  @override
  final TowerPlayerOverlayManager overlayManager = TowerPlayerOverlayManager();

  @override
  bool get isPlayingValue => isPlaying.value;

  @override
  bool get isScrubbingValue => isScrubbing.value;

  @override
  void hideSeekPreview() {}

  @override
  void onClose() {
    timers.cancelAll();
    overlayManager.dispose();
    super.onClose();
  }
}

void main() {
  group('TowerPlayerUIStateMixin State Invariant Tests', () {
    late TestUIStateController controller;

    setUp(() {
      controller = TestUIStateController();
    });

    tearDown(() {
      controller.onClose();
    });

    test('Initial state: controls are visible and shouldLockControls is false during active playback', () {
      expect(controller.controlsVisible.value, isTrue);
      expect(controller.shouldLockControls, isFalse);
    });

    test('Paused playback locks controls visible indefinitely', () {
      controller.isPlaying.value = false;
      expect(controller.shouldLockControls, isTrue);

      controller.startHideTimer(const Duration(milliseconds: 50));
      expect(controller.controlsVisible.value, isTrue);
    });

    test('Active scrubbing strictly locks controls visible and prevents auto-hide', () {
      controller.isPlaying.value = true;
      controller.isScrubbing.value = true;

      expect(controller.shouldLockControls, isTrue);

      controller.startHideTimer(const Duration(milliseconds: 50));
      expect(controller.controlsVisible.value, isTrue);
    });

    test('Active blocking overlay (Settings or Truth Report) locks controls visible', () {
      controller.isPlaying.value = true;
      controller.isScrubbing.value = false;

      // 1. Open Truth Report
      controller.overlayManager.open(TowerPlayerOverlay.truthReport);
      expect(controller.shouldLockControls, isTrue);

      controller.startHideTimer(const Duration(milliseconds: 50));
      expect(controller.controlsVisible.value, isTrue);

      // 2. Close overlay -> shouldLockControls becomes false
      controller.overlayManager.close();
      expect(controller.shouldLockControls, isFalse);
    });

    test('User interaction reveals controls and resets auto-hide timer', () {
      controller.controlsVisible.value = false;
      expect(controller.controlsVisible.value, isFalse);

      controller.onInteraction();
      expect(controller.controlsVisible.value, isTrue);
    });

    test('Timer triggers hide only when controls are not locked', () async {
      controller.isPlaying.value = true;
      controller.isScrubbing.value = false;
      controller.overlayManager.close();

      controller.startHideTimer(const Duration(milliseconds: 40));
      expect(controller.controlsVisible.value, isTrue);

      await Future.delayed(const Duration(milliseconds: 70));
      expect(controller.controlsVisible.value, isFalse);
    });

    test('Releasing scrub allows auto-hide countdown to proceed', () async {
      controller.isPlaying.value = true;
      controller.isScrubbing.value = true;

      // In scrub mode: hide cannot occur
      controller.startHideTimer(const Duration(milliseconds: 40));
      await Future.delayed(const Duration(milliseconds: 60));
      expect(controller.controlsVisible.value, isTrue);

      // Release scrub
      controller.isScrubbing.value = false;
      controller.startHideTimer(const Duration(milliseconds: 40));
      await Future.delayed(const Duration(milliseconds: 70));
      expect(controller.controlsVisible.value, isFalse);
    });
  });
}
