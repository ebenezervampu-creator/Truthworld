import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
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
  Widget buildView(int textureId) => const SizedBox();
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
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
  });

  tearDown(Get.reset);

  group('ChewieController Lifecycle and Disposal Resilience Tests', () {
    test('1. setupChewieListeners does not throw when outer or internal ChewieController is disposed', () async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
      await vpc.initialize();

      final towerCtrl = TowerPlayerController(
        videoPlayerController: vpc,
        tag: 'test_chewie_tag',
      );

      // Create a ChewieController and then immediately dispose it
      final disposedChewie = TowerPlayerChewieConfigurator.create(
        videoPlayerController: vpc,
        isLooping: false,
      );
      disposedChewie.dispose();

      // Assign the disposed controller to simulate dangling pointer
      towerCtrl.chewieController = disposedChewie;

      // setupChewieListeners should safely execute with zero assertions or errors
      expect(() => towerCtrl.setupChewieListeners(), returnsNormally);

      // Clean up
      TowerPlayerRegistry.unregister(towerCtrl);
      await vpc.dispose();
    });

    test('2. TowerPlayerController.sync safely handles resolution swaps without throwing on disposed controllers', () async {
      final vpc1 = VideoPlayerController.networkUrl(Uri.parse('https://example.com/1080p.mp4'));
      final vpc2 = VideoPlayerController.networkUrl(Uri.parse('https://example.com/720p.mp4'));
      await vpc1.initialize();
      await vpc2.initialize();

      final towerCtrl = TowerPlayerController(
        videoPlayerController: vpc1,
        tag: 'test_resolution_swap_tag',
      );

      // Verify initial controller
      expect(towerCtrl.videoPlayerController, equals(vpc1));
      final oldChewie = towerCtrl.chewieController;

      // Simulate resolution swap sync
      expect(() => towerCtrl.sync(vpc2), returnsNormally);

      // Old Chewie should be disposed or replaced safely
      expect(towerCtrl.videoPlayerController, equals(vpc2));
      expect(towerCtrl.chewieController, isNot(equals(oldChewie)));

      // Call setupChewieListeners again to ensure zero crashes
      expect(() => towerCtrl.setupChewieListeners(), returnsNormally);

      TowerPlayerRegistry.unregister(towerCtrl);
      await vpc1.dispose();
      await vpc2.dispose();
    });

    test('3. TowerPlayerController.onClose safely cleans up without throwing even if controllers are disposed', () async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
      await vpc.initialize();

      final towerCtrl = TowerPlayerController(
        videoPlayerController: vpc,
        tag: 'test_onclose_tag',
      );

      // Explicitly dispose underlying ChewieController first to test robustness
      towerCtrl.chewieController?.dispose();

      // onClose must run completely and safely
      expect(() => towerCtrl.onClose(), returnsNormally);

      TowerPlayerRegistry.unregister(towerCtrl);
      await vpc.dispose();
    });

    test('4. VideoPlayerSettingsSheet loop setting queries videoPlayerController safely', () async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
      await vpc.initialize();

      final videoCtrl = VideoController();
      videoCtrl.videoPlayerController = vpc;
      videoCtrl.chewieController = null; // No ChewieController attached

      // vpc loop is false initially
      expect(videoCtrl.videoPlayerController?.value.isLooping ?? false, isFalse);

      await vpc.setLooping(true);
      expect(videoCtrl.videoPlayerController?.value.isLooping ?? false, isTrue);

      await vpc.dispose();
    });
  });
}
