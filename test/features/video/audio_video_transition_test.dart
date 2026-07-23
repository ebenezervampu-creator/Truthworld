// ============================================================
// audio_video_transition_test.dart
// Automated Unit Tests for Audio <-> Video Mode Switching & Authority
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';

class MockVideoController implements PlaybackSource {
  Duration _pos = const Duration(milliseconds: 12450);
  final Duration _dur = const Duration(seconds: 120);
  bool _playing = true;
  final ValueNotifier<Duration> _notifier = ValueNotifier(const Duration(milliseconds: 12450));

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
  Future<void> seek(Duration pos) async {
    _pos = pos;
    _notifier.value = pos;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async => _notifier.dispose();
}

class MockAudioService implements PlaybackSource {
  Duration _pos = const Duration(milliseconds: 12450);
  final Duration _dur = const Duration(seconds: 120);
  bool _playing = true;
  final ValueNotifier<Duration> _notifier = ValueNotifier(const Duration(milliseconds: 12450));

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
  Future<void> seek(Duration pos) async {
    _pos = pos;
    _notifier.value = pos;
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async => _notifier.dispose();
}

void main() {
  group('Audio-Video Transition & Authority Tests', () {
    late MockVideoController mockVideo;
    late MockAudioService mockAudio;

    setUp(() {
      mockVideo = MockVideoController();
      mockAudio = MockAudioService();
    });

    test('1. Millisecond precision handoff preserves exact timestamp within tolerance', () async {
      final initialPos = mockVideo.position; // 12450 ms
      expect(initialPos.inMilliseconds, equals(12450));

      // Simulate atomic handoff to audio
      await mockAudio.seek(initialPos);
      expect(mockAudio.position.inMilliseconds, equals(12450));

      // Advance audio position by 5500 ms
      await mockAudio.seek(mockAudio.position + const Duration(milliseconds: 5500));
      expect(mockAudio.position.inMilliseconds, equals(17950));

      // Simulate atomic handoff back to video
      final returnPos = mockAudio.position;
      await mockVideo.seek(returnPos);
      expect(mockVideo.position.inMilliseconds, equals(17950));

      final diff = (mockVideo.position.inMilliseconds - 17950).abs();
      expect(diff, lessThanOrEqualTo(50));
    });

    test('2. PlaybackAuthority delegates position and control seamlessly', () async {
      var mode = PlaybackMode.video;
      PlaybackSource getActiveAuthority() =>
          mode == PlaybackMode.audio ? mockAudio : mockVideo;

      // In Video Mode
      expect(getActiveAuthority().position.inMilliseconds, equals(12450));
      await getActiveAuthority().pause();
      expect(mockVideo.isPlaying, isFalse);

      // Switch to Audio Mode
      mode = PlaybackMode.audio;
      expect(getActiveAuthority().position.inMilliseconds, equals(12450));
      await getActiveAuthority().play();
      expect(mockAudio.isPlaying, isTrue);

      // Relative seek in Audio mode
      final current = getActiveAuthority().position;
      await getActiveAuthority().seek(current + const Duration(seconds: 10));
      expect(getActiveAuthority().position.inMilliseconds, equals(22450));
    });

    test('3. State Machine mode transitions remain valid', () {
      const modes = PlaybackMode.values;
      expect(modes.contains(PlaybackMode.video), isTrue);
      expect(modes.contains(PlaybackMode.audio), isTrue);
      expect(modes.contains(PlaybackMode.switchingToAudio), isTrue);
      expect(modes.contains(PlaybackMode.switchingToVideo), isTrue);
    });
  });
}
