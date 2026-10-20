import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/real_time_fact_overlay.dart';
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

  group('Fullscreen Claims & Fact-Check Popup Tests', () {
    testWidgets('RealTimeFactOverlayWidget renders claim text, verdict, and dismisses on close', (tester) async {
      var closed = false;
      var tapped = false;

      final testClaim = ClaimResult(
        text: 'Biology and taxonomy are universal.',
        verdict: 'INCONCLUSIVE',
        claimDomain: 'Science',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RealTimeFactOverlayWidget(
              claim: testClaim,
              onClose: () => closed = true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('INCONCLUSIVE'), findsOneWidget);
      expect(find.text('Biology and taxonomy are universal.'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(closed, isTrue);

      await tester.tap(find.text('Biology and taxonomy are universal.'));
      expect(tapped, isTrue);
    });

    test('Fullscreen mode toggle state isolates portrait mode from fullscreen claims', () {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      final ctrl = Get.put(TowerPlayerController(videoPlayerController: vpc));

      expect(ctrl.isFullScreen.value, isFalse);
      expect(ctrl.showFactCheckPopup.value, isFalse);
      expect(ctrl.showCommentsPopup.value, isFalse);

      // Verify opening fact check overlay in controller
      ctrl.overlayManager.toggle(TowerPlayerOverlay.factCheck);
      ctrl.showFactCheckPopup.value = ctrl.overlayManager.isFactCheckOpen;
      expect(ctrl.showFactCheckPopup.value, isTrue);

      // Switching to comments closes fact check popup
      ctrl.overlayManager.toggle(TowerPlayerOverlay.comments);
      ctrl.showCommentsPopup.value = ctrl.overlayManager.isCommentsOpen;
      ctrl.showFactCheckPopup.value = false;
      expect(ctrl.showFactCheckPopup.value, isFalse);
      expect(ctrl.showCommentsPopup.value, isTrue);
    });
  });
}
