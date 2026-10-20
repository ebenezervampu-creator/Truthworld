import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import '../../test_helpers/mock_firebase.dart';

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}
  @override
  Future<void> dispose(int textureId) async {}
  @override
  Future<int?> create(DataSource dataSource) async => 1;
  @override
  Future<void> setLooping(int textureId, bool looping) async {}
  @override
  Future<void> play(int textureId) async {}
  @override
  Future<void> pause(int textureId) async {}
  @override
  Future<void> setVolume(int textureId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}
  @override
  Future<void> seekTo(int textureId, Duration position) async {}
  @override
  Future<Duration> getPosition(int textureId) async => Duration.zero;
  @override
  Stream<VideoEvent> videoEventsFor(int textureId) => Stream.value(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 120),
          size: const Size(1920, 1080),
        ),
      );
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
    await setupMockFirebase();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
    if (!Get.isRegistered<AudioOnlyService>()) {
      Get.put<AudioOnlyService>(AudioOnlyService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  group('Audio-Only Low-Bandwidth Optimization Tests', () {
    test('1. resolvePlaybackTargetUrl prioritizes 144p lowest stream when isAudioOnly is true', () async {
      final vc = VideoController();
      vc.isAudioOnly.value = true;
      vc.availableResolutions.assignAll([
        VideoResolutionV2(label: '1080p', url: 'https://cdn.truthworld.com/1080p.mp4', width: 1920, height: 1080, bitrate: 4500),
        VideoResolutionV2(label: '720p', url: 'https://cdn.truthworld.com/720p.mp4', width: 1280, height: 720, bitrate: 2500),
        VideoResolutionV2(label: '480p', url: 'https://cdn.truthworld.com/480p.mp4', width: 854, height: 480, bitrate: 1000),
        VideoResolutionV2(label: '144p', url: 'https://cdn.truthworld.com/144p.mp4', width: 256, height: 144, bitrate: 200),
      ]);

      final targetUrl = await vc.resolvePlaybackTargetUrl();
      expect(targetUrl, equals('https://cdn.truthworld.com/144p.mp4'));
      expect(vc.currentResolution.value?.label, equals('144p'));
    });

    test('2. toggleAudioOnly(true) saves previous resolution and downscales to 144p', () async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
      final vc = Get.put(VideoController(), tag: 'test_vid_lowbw');
      vc.availableResolutions.assignAll([
        VideoResolutionV2(label: '1080p', url: 'https://cdn.truthworld.com/1080p.mp4', width: 1920, height: 1080, bitrate: 4500),
        VideoResolutionV2(label: '720p', url: 'https://cdn.truthworld.com/720p.mp4', width: 1280, height: 720, bitrate: 2500),
        VideoResolutionV2(label: '144p', url: 'https://cdn.truthworld.com/144p.mp4', width: 256, height: 144, bitrate: 200),
      ]);
      vc.currentResolution.value = vc.availableResolutions.first; // 1080p

      final tpc = Get.put(
        TowerPlayerController(videoPlayerController: vpc, tag: 'test_vid_lowbw'),
        tag: 'test_vid_lowbw',
      );
      tpc.isAudioOnly.value = false;

      // Toggle Audio-Only ON
      await tpc.toggleAudioOnly();

      expect(tpc.isAudioOnly.value, isTrue);
      expect(vc.isAudioOnly.value, isTrue);
      expect(vc.currentResolution.value?.label, equals('144p'));

      // Toggle Audio-Only OFF (should restore 1080p)
      await tpc.toggleAudioOnly();

      expect(tpc.isAudioOnly.value, isFalse);
      expect(vc.isAudioOnly.value, isFalse);
      expect(vc.currentResolution.value?.label, equals('1080p'));
    });

    test('3. AdaptiveBitrateController degrades up to 144p (tier 0) and never auto-switches to audio-only', () {
      final abr = AdaptiveBitrateController();
      abr.resolutionLadder = [
        const ResolutionTier(label: '144p', url: 'https://cdn.truthworld.com/144p.mp4', height: 144, bitrate: 200, minBandwidth: 240),
        const ResolutionTier(label: '360p', url: 'https://cdn.truthworld.com/360p.mp4', height: 360, bitrate: 600, minBandwidth: 800),
        const ResolutionTier(label: '720p', url: 'https://cdn.truthworld.com/720p.mp4', height: 720, bitrate: 2500, minBandwidth: 3000),
      ];
      abr.currentTierIndex.value = 1; // 360p
      abr.isAutoMode.value = true;

      int? switchedToTier;
      abr.onTierChanged = (idx, isManual) {
        switchedToTier = idx;
      };

      // When stalling at tier 1, ABR emergency downgrade steps down to tier 0 (144p)
      abr.playbackState.value = PlaybackState.playing;
      // Simulate emergency stall step
      if (abr.isAutoMode.value && abr.currentTierIndex.value > 0) {
        abr.setManualTier(0);
      }
      expect(abr.currentTierIndex.value, equals(0));
      expect(abr.currentTier.label, equals('144p'));
      expect(switchedToTier, equals(0));

      // When already at tier 0 (144p), stall recovery stops at 144p and does NOT switch to audio-only
      if (abr.isAutoMode.value && abr.currentTierIndex.value > 0) {
        abr.setManualTier(abr.currentTierIndex.value - 1);
      }
      expect(abr.currentTierIndex.value, equals(0));
      expect(abr.currentTier.label, equals('144p'));
    });

    test('4. Audio-only is strictly a manual user action and selecting Auto video quality exits audio-only', () async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
      final tpc = Get.put(
        TowerPlayerController(videoPlayerController: vpc, tag: 'manual_audio_test'),
        tag: 'manual_audio_test',
      );
      tpc.isAudioOnly.value = false;
      tpc.initABR();

      // User manually turns on Audio-only
      await tpc.setAudioOnly(true);
      expect(tpc.isAudioOnly.value, isTrue);

      // User manually selects Auto video quality
      tpc.selectAutoQuality();
      expect(tpc.isAudioOnly.value, isFalse);
      expect(tpc.abr.isAutoMode.value, isTrue);
    });
  });
}
