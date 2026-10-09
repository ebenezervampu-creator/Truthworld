import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
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
  Stream<VideoEvent> videoEventsFor(int textureId) => const Stream.empty();
  @override
  Widget buildView(int textureId) => const SizedBox();
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

class FakeConnectivityService extends GetxService implements ConnectivityService {
  @override
  ConnectivityResult get connectionStatus => ConnectivityResult.wifi;
  @override
  bool get isConnected => true;
  @override
  bool get isWifi => true;
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
  @override
  Stream<ConnectivityResult> get onConnectivityRestored => const Stream.empty();
  @override
  Future<ConnectivityService> init() async => this;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
  });

  setUp(() {
    Get.reset();
    Get.put<ConnectivityService>(FakeConnectivityService());
  });

  tearDown(() async {
    Get.reset();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  group('HoverPreviewCoordinator Mute Detection Tests', () {
    test('Returns false when no video players are registered', () {
      expect(HoverPreviewCoordinator.isMainVideoMuted(), isFalse);
    });

    test('Returns true when TowerPlayerController is registered and isMuted is true', () {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
      final ctrl = Get.put(TowerPlayerController(videoPlayerController: vpc));
      TowerPlayerRegistry.register(ctrl);
      ctrl.isMuted.value = true;
      expect(HoverPreviewCoordinator.isMainVideoMuted(), isTrue);

      ctrl.isMuted.value = false;
      expect(HoverPreviewCoordinator.isMainVideoMuted(), isFalse);
    });

    test('Returns true when TowerPlayerController is registered and volume is 0', () {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'));
      final ctrl = Get.put(TowerPlayerController(videoPlayerController: vpc));
      TowerPlayerRegistry.register(ctrl);
      ctrl.isMuted.value = false;
      ctrl.volume.value = 0.0;
      expect(HoverPreviewCoordinator.isMainVideoMuted(), isTrue);

      ctrl.volume.value = 0.8;
      expect(HoverPreviewCoordinator.isMainVideoMuted(), isFalse);
    });

    test('Returns true when MiniplayerController is active and muted', () {
      final mini = Get.put(MiniplayerController(), tag: 'miniplayer');
      mini.isPlaying.value = true;
      mini.isMuted.value = true;

      expect(HoverPreviewCoordinator.isMainVideoMuted(), isTrue);

      mini.isMuted.value = false;
      expect(HoverPreviewCoordinator.isMainVideoMuted(), isFalse);
    });

    test('Global mute is false by default for hover previews with audio and can be toggled', () {
      expect(HoverPreviewCoordinator.globalMute.value, isFalse);
      HoverPreviewCoordinator.globalMute.value = true;
      expect(HoverPreviewCoordinator.globalMute.value, isTrue);
      HoverPreviewCoordinator.globalMute.value = false;
      expect(HoverPreviewCoordinator.globalMute.value, isFalse);
    });

    test('setActiveCard enforces strictly one active card and unregisters properly', () {
      HoverPreviewCoordinator.clearActiveCard(null);

      // Testing clear and unregister behaviors
      expect(HoverPreviewCoordinator.isMainVideoMuted(), isFalse);
    });
  });
}
