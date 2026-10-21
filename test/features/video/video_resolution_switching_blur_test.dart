import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import '../../test_helpers/mock_firebase.dart';

class _FakeResolutionPlatform extends VideoPlayerPlatform {
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
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return Stream.value(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 60),
        size: const Size(1920, 1080),
      ),
    );
  }
  @override
  Widget buildView(int textureId) => const SizedBox();
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    VideoPlayerPlatform.instance = _FakeResolutionPlatform();
    await setupMockFirebase();
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
    AuthService.to.isPremiumUser.value = false;
    AuthService.to.premiumPlanId.value = null;
  });

  tearDown(Get.reset);

  group('Video Resolution Switching & 144p Blur Fix Tests', () {
    test('1. AdaptiveBitrateController.setManualTier triggers onTierChanged even when index == currentTierIndex', () {
      final abr = AdaptiveBitrateController();
      abr.resolutionLadder = [
        const ResolutionTier(label: '144p', url: 'https://example.com/v.mp4', height: 144, bitrate: 200, minBandwidth: 240),
        const ResolutionTier(label: '720p', url: 'https://example.com/v.mp4', height: 720, bitrate: 2500, minBandwidth: 3000),
        const ResolutionTier(label: '1080p', url: 'https://example.com/v.mp4', height: 1080, bitrate: 5000, minBandwidth: 6000),
      ];
      abr.currentTierIndex.value = 0; // Already on 0 (144p)

      int? callbackTier;
      bool? callbackIsManual;
      abr.onTierChanged = (idx, isManual) {
        callbackTier = idx;
        callbackIsManual = isManual;
      };

      // Tapping 144p (tier 0) manually must NOT return early; it must trigger callback
      abr.setManualTier(0);

      expect(abr.isAutoMode.value, isFalse);
      expect(callbackTier, equals(0));
      expect(callbackIsManual, isTrue);
    });

    test('2. VideoTrackManagementMixin.setResolution updates currentResolution and toast on shared fallbackUrl', () async {
      const fallbackUrl = 'https://example.com/single_1080p_source.mp4';
      final res1080 = VideoResolutionV2(label: '1080p', url: fallbackUrl, width: 1920, height: 1080, bitrate: 4500000);
      final res144 = VideoResolutionV2(label: '144p', url: fallbackUrl, width: 256, height: 144, bitrate: 200000, isSynthetic: true);

      final vpc = VideoPlayerController.networkUrl(Uri.parse(fallbackUrl));
      await vpc.initialize();

      final vc = Get.put(VideoController(tag: 'res_test_video'), tag: 'res_test_video');
      vc.video = Video.empty().copyWith(id: 'res_test_video');
      vc.videoPlayerController = vpc;
      vc.availableResolutions.assignAll([res1080, res144]);
      vc.currentResolution.value = res1080;

      Get.put(
        TowerPlayerController(videoPlayerController: vpc, tag: 'res_test_video'),
        tag: 'res_test_video',
      );

      expect(vc.currentResolution.value?.label, equals('1080p'));

      // Switch to 144p with shared source URL
      await vc.setResolution(res144);

      // Must update currentResolution reactively to 144p
      expect(vc.currentResolution.value?.label, equals('144p'));
      expect(vc.currentResolution.value?.height, equals(144));
      expect(vc.currentResolution.value?.isSynthetic, isTrue);
    });

    test('3. TowerPlayerAbrMixin.resolutionBlurSigma applies authentic blur for 144p and returns 0 for 720p/1080p', () async {
      const fallbackUrl = 'https://example.com/single_1080p_source.mp4';
      final res1080 = VideoResolutionV2(label: '1080p', url: fallbackUrl, width: 1920, height: 1080, bitrate: 4500000);
      final res720 = VideoResolutionV2(label: '720p', url: fallbackUrl, width: 1280, height: 720, bitrate: 2500000);
      final res480 = VideoResolutionV2(label: '480p', url: fallbackUrl, width: 854, height: 480, bitrate: 1200000, isSynthetic: true);
      final res360 = VideoResolutionV2(label: '360p', url: fallbackUrl, width: 640, height: 360, bitrate: 800000, isSynthetic: true);
      final res240 = VideoResolutionV2(label: '240p', url: fallbackUrl, width: 426, height: 240, bitrate: 400000, isSynthetic: true);
      final res144 = VideoResolutionV2(label: '144p', url: fallbackUrl, width: 256, height: 144, bitrate: 200000, isSynthetic: true);

      final vpc = VideoPlayerController.networkUrl(Uri.parse(fallbackUrl));
      await vpc.initialize();

      final vc = Get.put(VideoController(tag: 'blur_test_video'), tag: 'blur_test_video');
      vc.video = Video.empty().copyWith(id: 'blur_test_video');
      vc.videoPlayerController = vpc;
      vc.availableResolutions.assignAll([res1080, res720, res480, res360, res240, res144]);

      final tpc = Get.put(
        TowerPlayerController(videoPlayerController: vpc, tag: 'blur_test_video'),
        tag: 'blur_test_video',
      );

      // 144p: must return 4.5 sigma blur
      vc.currentResolution.value = res144;
      expect(tpc.resolutionBlurSigma, equals(4.5));

      // 240p: must return 2.5 sigma blur
      vc.currentResolution.value = res240;
      expect(tpc.resolutionBlurSigma, equals(2.5));

      // 360p: must return 1.4 sigma blur
      vc.currentResolution.value = res360;
      expect(tpc.resolutionBlurSigma, equals(1.4));

      // 480p: must return 0.7 sigma blur
      vc.currentResolution.value = res480;
      expect(tpc.resolutionBlurSigma, equals(0.7));

      // 720p: must return 0.0 (no blur)
      vc.currentResolution.value = res720;
      expect(tpc.resolutionBlurSigma, equals(0.0));

      // 1080p: must return 0.0 (no blur)
      vc.currentResolution.value = res1080;
      expect(tpc.resolutionBlurSigma, equals(0.0));

      // Audio-only mode: returns 0.0
      vc.currentResolution.value = res144;
      tpc.isAudioOnly.value = true;
      expect(tpc.resolutionBlurSigma, equals(0.0));
    });

    test('4. TowerPlayerController.sync updates rxVideoPlayerController reactively', () async {
      final vpc1 = VideoPlayerController.networkUrl(Uri.parse('https://example.com/1080p.mp4'));
      final vpc2 = VideoPlayerController.networkUrl(Uri.parse('https://example.com/144p.mp4'));

      final tpc = Get.put(
        TowerPlayerController(videoPlayerController: vpc1, tag: 'sync_test_video'),
        tag: 'sync_test_video',
      );

      expect(tpc.rxVideoPlayerController.value, equals(vpc1));

      tpc.sync(vpc2);

      expect(tpc.videoPlayerController, equals(vpc2));
      expect(tpc.rxVideoPlayerController.value, equals(vpc2));
    });
  });
}
