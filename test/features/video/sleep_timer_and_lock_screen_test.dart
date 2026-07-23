// ============================================================
// sleep_timer_and_lock_screen_test.dart
// Automated Unit Tests for SleepTimerService & PlayerLockController
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';
import 'package:truthworld/features/video/presentation/controllers/player_lock_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';

class TestPlaybackSource implements PlaybackSource {
  Duration _pos = Duration.zero;
  final Duration _dur = const Duration(minutes: 10);
  bool _playing = true;
  double volume = 1;
  final ValueNotifier<Duration> _notifier = ValueNotifier(Duration.zero);

  @override
  Duration get position => _pos;

  @override
  Duration get duration => _dur;

  @override
  bool get isPlaying => _playing;

  @override
  ValueListenable<Duration> get positionListenable => _notifier;

  @override
  Future<void> play() async => _playing = true;

  @override
  Future<void> pause() async => _playing = false;

  @override
  Future<void> seek(Duration position) async {
    _pos = position;
    _notifier.value = position;
  }

  @override
  Future<void> setVolume(double vol) async {
    volume = vol;
  }

  @override
  Future<void> dispose() async => _notifier.dispose();
}

void main() {
  group('SleepTimerService & PlayerLockController Tests', () {
    late SleepTimerService sleepService;
    late PlayerLockController lockController;
    late TestPlaybackSource testSource;

    setUp(() {
      sleepService = SleepTimerService();
      lockController = PlayerLockController();
      testSource = TestPlaybackSource();
      sleepService.setActivePlayback(testSource);
    });

    test('1. SleepTimerService starts with duration and computes remaining seconds', () {
      sleepService.startTimer(const Duration(minutes: 15));
      expect(sleepService.isActive, isTrue);
      expect(sleepService.mode.value, equals(SleepTimerMode.duration));
      expect(sleepService.remainingSeconds.value, closeTo(900, 2));
    });

    test('2. Extending sleep timer adds 5 minutes accurately', () {
      sleepService.startTimer(const Duration(minutes: 10));
      expect(sleepService.remainingSeconds.value, closeTo(600, 2));

      sleepService.extendTimer(const Duration(minutes: 5));
      expect(sleepService.remainingSeconds.value, closeTo(900, 2));
    });

    test('3. Timer replacement cancels existing timer without duplication', () {
      sleepService.startTimer(const Duration(minutes: 30));
      expect(sleepService.remainingSeconds.value, closeTo(1800, 2));

      sleepService.startTimer(const Duration(minutes: 10));
      expect(sleepService.remainingSeconds.value, closeTo(600, 2));
    });

    test('4. Expiration pauses active playback and restores volume safely', () async {
      testSource.setVolume(0.8);
      await sleepService.triggerExpiration();

      expect(testSource.isPlaying, isFalse);
      expect(sleepService.isActive, isFalse);
      expect(testSource.volume, equals(1.0));
    });

    test('5. PlayerLockController state machine handles lock, unlock, and pill hints', () {
      expect(lockController.isLocked.value, isFalse);
      expect(lockController.pillState.value, equals(UnlockPillState.hidden));

      lockController.lock();
      expect(lockController.isLocked.value, isTrue);
      expect(lockController.pillState.value, equals(UnlockPillState.visible));

      lockController.unlock();
      expect(lockController.isLocked.value, isFalse);
      expect(lockController.pillState.value, equals(UnlockPillState.hidden));
    });
  });
}
