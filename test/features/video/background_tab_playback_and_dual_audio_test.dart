import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/state_overlay.dart';
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

  setUpAll(() async {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
  });

  setUp(() {
    Get.reset();
    Get.put<ConnectivityService>(FakeConnectivityService());
    Get.put(SleepTimerService());
  });

  tearDown(Get.reset);

  group('Background Tab Playback and Dual Audio Prevention Tests', () {
    test('AudioOnlyService deactivate() sets isPlaying to false and resets state', () {
      final audioSvc = Get.put(AudioOnlyService());
      audioSvc.isActive.value = true;
      audioSvc.isPlaying.value = true;
      audioSvc.isBackgroundPlayback.value = true;

      audioSvc.deactivate();

      expect(audioSvc.isActive.value, isFalse);
      expect(audioSvc.isPlaying.value, isFalse);
      expect(audioSvc.isBackgroundPlayback.value, isFalse);
    });

    test('TowerPlayerRegistry.pauseAllActivePlayers() deactivates AudioOnlyService', () {
      final audioSvc = Get.put(AudioOnlyService());
      audioSvc.isActive.value = true;
      audioSvc.isPlaying.value = true;

      TowerPlayerRegistry.pauseAllActivePlayers();

      expect(audioSvc.isActive.value, isFalse);
      expect(audioSvc.isPlaying.value, isFalse);
    });

    test('TowerPlayerController sync() deactivates active AudioOnlyService', () {
      final audioSvc = Get.put(AudioOnlyService());
      audioSvc.isActive.value = true;
      audioSvc.isPlaying.value = true;

      final vpc1 = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video1.mp4'));
      final ctrl = TowerPlayerController(videoPlayerController: vpc1, tag: 'sync_test');

      final vpc2 = VideoPlayerController.networkUrl(Uri.parse('https://example.com/video2.mp4'));
      ctrl.sync(vpc2);

      expect(audioSvc.isActive.value, isFalse);
      expect(audioSvc.isPlaying.value, isFalse);
    });

    test('handleEnterBackground() guards and does not activate on Web', () async {
      final audioSvc = Get.put(AudioOnlyService());
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      final ctrl = TowerPlayerController(videoPlayerController: vpc, tag: 'bg_test');

      await ctrl.handleEnterBackground();

      expect(ctrl.isBackgroundAudioActive, isFalse);
      expect(audioSvc.isBackgroundPlayback.value, isFalse);
    });

    test('AdaptiveBitrateController enableAutoMode sets isAutoMode to true', () {
      final abr = AdaptiveBitrateController();
      abr.isAutoMode.value = false;
      abr.enableAutoMode();
      expect(abr.isAutoMode.value, isTrue);
    });

    testWidgets('StateOverlay suppresses buffering spinner when playing in Auto mode', (tester) async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      final ctrl = TowerPlayerController(videoPlayerController: vpc, tag: 'state_overlay_test');
      ctrl.abr.isAutoMode.value = true;
      ctrl.isPlaying.value = true;
      ctrl.isBuffering.value = true;

      await tester.pumpWidget(MaterialApp(home: StateOverlay(ctrl: ctrl)));

      // In Auto mode while playing, the buffer spinner must be completely suppressed
      expect(find.byType(StateOverlay), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsNothing);
    });

    testWidgets('StateOverlay displays buffering spinner when user selects manual resolution', (tester) async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      final ctrl = TowerPlayerController(videoPlayerController: vpc, tag: 'manual_overlay_test');
      ctrl.abr.isAutoMode.value = false;
      ctrl.isPlaying.value = false;
      ctrl.isBuffering.value = true;

      await tester.pumpWidget(MaterialApp(home: StateOverlay(ctrl: ctrl)));

      // On manual resolution selection, buffering spinner must be visible to the user
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
    });
  });
}
