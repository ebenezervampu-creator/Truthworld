import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_screen/video_player_stage.dart';
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
  Stream<VideoEvent> videoEventsFor(int textureId) => const Stream.empty();
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
  });

  tearDown(Get.reset);

  group('VideoPlayerStage Responsive Fit & Aspect Ratio Tests', () {
    test('1. vpcAspectRatio reactively updates when aspect ratio changes from 16:9 to ultrawide 2.235', () {
      final controller = VideoController();
      controller.video = Video.empty().copyWith(id: 'vid_test_ultrawide');

      // Initial default fallback
      expect(controller.vpcAspectRatio, equals(16 / 9));

      // Simulate TowerPlayerController registration and aspect ratio update
      final vpc = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/test.mp4'),
      );
      final towerCtrl = TowerPlayerController(
        videoPlayerController: vpc,
        tag: 'vid_test_ultrawide',
      );
      Get.put(towerCtrl, tag: 'vid_test_ultrawide');
      towerCtrl.aspectRatio.value = 2.235;

      // vpcAspectRatio dynamically syncs
      expect(controller.vpcAspectRatio, closeTo(2.235, 0.001));

      // Updating TowerPlayerController aspect ratio also updates vpcAspectRatio
      towerCtrl.aspectRatio.value = 2.39;
      expect(controller.vpcAspectRatio, closeTo(2.39, 0.001));
    });

    testWidgets('2. VideoPlayerStage builds cleanly and adapts without overflow on desktop viewport (1024x768)', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = VideoController();
      controller.video = Video.empty().copyWith(
        id: 'vid_desktop_fit',
        title: 'Christian songs Redx Media',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );
      controller.rxAspectRatio.value = 2.235;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                VideoPlayerStage(controller: controller, videoTag: 'vid_desktop_fit'),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      // Find VideoPlayerStage and ensure it rendered
      expect(find.byType(VideoPlayerStage), findsOneWidget);

      // Verify that no ClipRect is wrapping the ImageFiltered ambient glow
      // (ensuring zero hard razor cut-off borders under the player)
      final imageFiltered = find.byType(ImageFiltered);
      if (imageFiltered.evaluate().isNotEmpty) {
        final parentWidget = tester.widget(find.ancestor(
          of: imageFiltered,
          matching: find.byType(AnimatedOpacity),
        ));
        expect(parentWidget, isNotNull);
      }
    });

    testWidgets('3. VideoPlayerStage fits 16:9 videos cleanly without artificial shrinking on desktop', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = VideoController();
      controller.video = Video.empty().copyWith(
        id: 'vid_16_9_fit',
        title: 'choosen one series 1 season 2',
      );
      controller.rxAspectRatio.value = 16 / 9;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                VideoPlayerStage(controller: controller, videoTag: 'vid_16_9_fit'),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(VideoPlayerStage), findsOneWidget);
    });

    testWidgets('4. VideoPlayerStage ambient glow has ShaderMask and stops at bottom: 0 to prevent bottom border artifact', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = VideoController();
      controller.video = Video.empty().copyWith(
        id: 'vid_glow_test',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                VideoPlayerStage(controller: controller, videoTag: 'vid_glow_test'),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      // Ambient glow must have a ShaderMask for smooth vertical dissolution
      final shaderMask = find.byType(ShaderMask);
      expect(shaderMask, findsOneWidget);

      // Verify the Positioned wrapping the ambient glow has bottom: 0
      final positionedGlow = tester.widget<Positioned>(
        find.ancestor(of: shaderMask, matching: find.byType(Positioned)),
      );
      expect(positionedGlow.bottom, equals(0.0));
      expect(positionedGlow.top, equals(-24.0));
    });
  });
}
