import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/double_tap_ripple.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/player_toast.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/seek_preview_tooltip.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

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
  Stream<VideoEvent> videoEventsFor(int textureId) => const Stream.empty();
  @override
  Widget buildView(int textureId) => const SizedBox();
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

class _FakeConnectivityService extends GetxService
    implements ConnectivityService {
  @override
  ConnectivityResult get connectionStatus => ConnectivityResult.wifi;
  @override
  bool get isConnected => true;
  @override
  bool get isWifi => true;
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
  @override
  Stream<ConnectivityResult> get onConnectivityRestored => const Stream.empty();
  @override
  Future<ConnectivityService> init() async => this;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (methodCall) async => '.',
        );
    await GetStorage.init();
    Get.put<ConnectivityService>(_FakeConnectivityService());
    Get.put<SleepTimerService>(SleepTimerService());
  });

  tearDownAll(Get.reset);

  group('Player Overlays ParentData & Layout Guard Tests', () {
    testWidgets(
      'DoubleTapRipple renders without ParentDataWidget exception when wrapped in Stack -> Positioned -> IgnorePointer',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 450,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      bottom: 0,
                      width: 800 * 0.45,
                      child: IgnorePointer(
                        child: DoubleTapRipple(isLeft: true),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      width: 800 * 0.45,
                      child: IgnorePointer(
                        child: DoubleTapRipple(isLeft: false, seconds: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Verify widgets mounted cleanly without exception
        expect(tester.takeException(), isNull);
        expect(find.byType(DoubleTapRipple), findsNWidgets(2));
        expect(find.text('10 seconds'), findsOneWidget);
        expect(find.text('20 seconds'), findsOneWidget);
      },
    );

    testWidgets(
      'SeekPreviewTooltip renders without ParentDataWidget exception when wrapped in Stack -> Positioned -> IgnorePointer',
      (tester) async {
        final vpc = VideoPlayerController.networkUrl(
          Uri.parse('https://example.com/test.mp4'),
        );
        final ctrl = Get.put(
          TowerPlayerController(
            videoPlayerController: vpc,
            tag: 'parent_data_test_seek',
          ),
          tag: 'parent_data_test_seek',
        );

        // Seed duration and seek position
        ctrl.seekPreviewPos.value = const Duration(seconds: 45);
        ctrl.seekPreviewVis.value = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 450,
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 100,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: SeekPreviewTooltip(ctrl: ctrl),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(SeekPreviewTooltip), findsOneWidget);

        Get.delete<TowerPlayerController>(tag: 'parent_data_test_seek');
      },
    );

    testWidgets(
      'PlayerToast renders cleanly without ParentDataWidget exception when wrapped in Positioned.fill',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 450,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: PlayerToast(message: 'Quality set to 1080p'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Quality set to 1080p'), findsOneWidget);
      },
    );
  });
}
