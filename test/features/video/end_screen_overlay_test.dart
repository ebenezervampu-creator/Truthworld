import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/end_screen_overlay.dart';
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
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return Stream.value(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(minutes: 5),
        size: const Size(1920, 1080),
      ),
    );
  }

  @override
  Widget buildView(int textureId) => const SizedBox();
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
  });

  tearDown(() {
    Get.reset();
  });

  group('EndScreenOverlay Layout and Constraints Tests', () {
    testWidgets(
      'Compact mode renders AspectRatio thumbnail without unbounded constraints exception',
      (tester) async {
        const videoTag = 'test_end_screen_compact';

        final videoController = VideoController();
        videoController.video = Video.empty().copyWith(
          id: 'current_video_id',
          title: 'Current Playing Video',
        );
        videoController.recommendedVideos.assignAll([
          Video.empty().copyWith(
            id: 'rec_video_1',
            title: 'Recommended Video 1',
            channelName: 'Channel A',
            thumbnailUrl: 'https://example.com/thumb1.jpg',
          ),
          Video.empty().copyWith(
            id: 'rec_video_2',
            title: 'Recommended Video 2',
            channelName: 'Channel B',
            thumbnailUrl: 'https://example.com/thumb2.jpg',
          ),
        ]);
        Get.put<VideoController>(videoController, tag: videoTag);

        final vpc = VideoPlayerController.networkUrl(
          Uri.parse('https://example.com/video.mp4'),
        );
        final towerCtrl = TowerPlayerController(
          videoPlayerController: vpc,
          tag: videoTag,
        );
        Get.put<TowerPlayerController>(towerCtrl, tag: videoTag);

        towerCtrl.showEndScreen.value = true;
        towerCtrl.isEndScreenOverlayHidden.value = false;
        towerCtrl.autoplayCountdown.value =
            0; // Test compact list without banner

        // Render in compact viewport (e.g. 360 x 220 portrait player)
        tester.view.physicalSize = const Size(360, 220);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 220,
                child: EndScreenOverlay(ctrl: towerCtrl),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify no crash / exception occurred during performLayout
        expect(tester.takeException(), isNull);

        // Verify compact layout elements are present
        expect(find.text('Replay'), findsOneWidget);
        expect(find.text('Recommended Video 1'), findsOneWidget);
        expect(find.text('Channel A'), findsOneWidget);

        // Verify AspectRatio widget for thumbnail is laid out with bounded constraints
        final aspectRatioFinder = find.byType(AspectRatio);
        expect(aspectRatioFinder, findsWidgets);

        for (final element in aspectRatioFinder.evaluate()) {
          final renderObject = element.renderObject as RenderBox;
          expect(renderObject.hasSize, isTrue);
          expect(renderObject.size.width, greaterThan(0));
          expect(renderObject.size.height, greaterThan(0));
        }

        // Clean up controller timers before end of test body
        towerCtrl.onClose();
        if (Get.isRegistered<AdaptiveBitrateController>(tag: videoTag)) {
          Get.find<AdaptiveBitrateController>(tag: videoTag).onClose();
        }
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Autoplay countdown banner renders flexibly in compact mode without overflow',
      (tester) async {
        const videoTag = 'test_end_screen_autoplay';

        final videoController = VideoController();
        videoController.video = Video.empty().copyWith(
          id: 'current_video_id',
          title: 'Current Playing Video',
        );
        videoController.recommendedVideos.assignAll([
          Video.empty().copyWith(
            id: 'rec_video_next',
            title: 'Next Upcoming Video With A Really Long Title Here',
            channelName: 'Channel A',
            thumbnailUrl: 'https://example.com/thumb.jpg',
          ),
        ]);
        Get.put<VideoController>(videoController, tag: videoTag);

        final vpc = VideoPlayerController.networkUrl(
          Uri.parse('https://example.com/video.mp4'),
        );
        final towerCtrl = TowerPlayerController(
          videoPlayerController: vpc,
          tag: videoTag,
        );
        Get.put<TowerPlayerController>(towerCtrl, tag: videoTag);

        towerCtrl.showEndScreen.value = true;
        towerCtrl.isEndScreenOverlayHidden.value = false;
        towerCtrl.autoplayCountdown.value = 5;

        // Viewport with standard mobile width
        tester.view.physicalSize = const Size(360, 240);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 240,
                child: EndScreenOverlay(ctrl: towerCtrl),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Up Next: '), findsOneWidget);
        expect(find.text('PLAY NOW'), findsOneWidget);
        expect(find.text('CANCEL'), findsOneWidget);

        towerCtrl.onClose();
        if (Get.isRegistered<AdaptiveBitrateController>(tag: videoTag)) {
          Get.find<AdaptiveBitrateController>(tag: videoTag).onClose();
        }
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Replay button triggers ctrl.replayVideo in compact mode with recommendations',
      (tester) async {
        const videoTag = 'test_end_screen_replay';

        final videoController = VideoController();
        videoController.video = Video.empty().copyWith(
          id: 'curr_vid',
          title: 'Playing Video',
        );
        videoController.recommendedVideos.assignAll([
          Video.empty().copyWith(
            id: 'rec_1',
            title: 'Rec 1',
            channelName: 'Channel 1',
          ),
        ]);
        Get.put<VideoController>(videoController, tag: videoTag);

        final vpc = VideoPlayerController.networkUrl(
          Uri.parse('https://example.com/video.mp4'),
        );
        final towerCtrl = TowerPlayerController(
          videoPlayerController: vpc,
          tag: videoTag,
        );
        Get.put<TowerPlayerController>(towerCtrl, tag: videoTag);

        towerCtrl.showEndScreen.value = true;
        towerCtrl.isEndScreenOverlayHidden.value = false;

        tester.view.physicalSize = const Size(360, 220);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 220,
                child: EndScreenOverlay(ctrl: towerCtrl),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Replay'), findsOneWidget);
        final replayFinder = find.widgetWithIcon(
          IconButton,
          Icons.replay_rounded,
        );
        expect(replayFinder, findsOneWidget);

        await tester.tap(replayFinder);
        await tester.pumpAndSettle();

        // End screen should be dismissed when replayed
        expect(towerCtrl.showEndScreen.value, isFalse);

        towerCtrl.onClose();
        if (Get.isRegistered<AdaptiveBitrateController>(tag: videoTag)) {
          Get.find<AdaptiveBitrateController>(tag: videoTag).onClose();
        }
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Empty recommendations renders center replay FloatingActionButton',
      (tester) async {
        const videoTag = 'test_end_screen_empty';

        final videoController = VideoController();
        videoController.video = Video.empty().copyWith(
          id: 'curr_vid',
          title: 'Playing Video',
        );
        Get.put<VideoController>(videoController, tag: videoTag);

        final vpc = VideoPlayerController.networkUrl(
          Uri.parse('https://example.com/video.mp4'),
        );
        final towerCtrl = TowerPlayerController(
          videoPlayerController: vpc,
          tag: videoTag,
        );
        Get.put<TowerPlayerController>(towerCtrl, tag: videoTag);

        towerCtrl.showEndScreen.value = true;
        towerCtrl.isEndScreenOverlayHidden.value = false;

        tester.view.physicalSize = const Size(360, 220);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 220,
                child: EndScreenOverlay(ctrl: towerCtrl),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fabFinder = find.byType(FloatingActionButton);
        expect(fabFinder, findsOneWidget);

        await tester.tap(fabFinder);
        await tester.pumpAndSettle();

        expect(towerCtrl.showEndScreen.value, isFalse);

        towerCtrl.onClose();
        if (Get.isRegistered<AdaptiveBitrateController>(tag: videoTag)) {
          Get.find<AdaptiveBitrateController>(tag: videoTag).onClose();
        }
        await tester.pumpAndSettle();
      },
    );
  });
}
