import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_lifecycle_helper.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_registry.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/tower_custom_player.dart';
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

  group('TowerCustomPlayer Route Pop & Focus Resilience Tests', () {
    testWidgets('1. TowerCustomPlayer cleanly returns SizedBox.shrink when tag is marked disposed in TowerPlayerRegistry',
        (tester) async {
      const testTag = 'disposed_video_tag_1';
      TowerPlayerRegistry.markDisposed(testTag);
      expect(TowerPlayerRegistry.isDisposed(testTag), isTrue);

      final vpc = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/stream.mp4'),
      );
      await vpc.initialize();

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: TowerCustomPlayer(
              videoPlayerController: vpc,
              tag: testTag,
            ),
          ),
        ),
      );

      // Verify that no TowerPlayerController was registered or resurrected for the disposed tag
      expect(Get.isRegistered<TowerPlayerController>(tag: testTag), isFalse);
      expect(find.byType(KeyboardListener), findsNothing);

      TowerPlayerRegistry.clearDisposed(testTag);
      await vpc.dispose();
    });

    testWidgets('2. TowerCustomPlayer cleanly collapses to SizedBox.shrink when controller.isClosed is true',
        (tester) async {
      const testTag = 'closed_video_tag_2';
      final vpc = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/stream.mp4'),
      );
      await vpc.initialize();

      final ctrl = Get.put(
        TowerPlayerController(videoPlayerController: vpc, tag: testTag),
        tag: testTag,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: TowerCustomPlayer(
              videoPlayerController: vpc,
              tag: testTag,
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially active and mounted
      expect(find.byType(KeyboardListener), findsOneWidget);

      // Close the controller directly (simulating route teardown)
      ctrl.onClose();
      expect(ctrl.isClosed, isTrue);

      // Re-pump widget tree (simulating layout/frame during route pop)
      await tester.pump();

      // KeyboardListener and child overlays must cleanly unmount without throwing assertion errors
      expect(tester.takeException(), isNull);

      await vpc.dispose();
    });

    test('3. TowerPlayerLifecycleHelper.disposeControllers safely unfocuses and disposes focusNode', () {
      final fn = FocusNode();
      expect(fn.hasFocus, isFalse);

      final vpc = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/stream.mp4'),
      );

      TowerPlayerLifecycleHelper.disposeControllers(
        adPlayerController: null,
        audioTrackController: null,
        videoPlayerController: vpc,
        webFullscreenSub: null,
        errorDebounceTimer: null,
        singleTapTimer: null,
        autoplayTimer: null,
        focusNode: fn,
        isFullScreen: false,
        onAdVpcUpdate: () {},
        onVpcUpdate: () {},
      );

      expect(fn.canRequestFocus, isFalse);
    });

    testWidgets('4. Popping a route containing TowerCustomPlayer unmounts cleanly without _FocusInheritedScope error',
        (tester) async {
      const testTag = 'pop_route_tag_4';
      final vpc = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/stream.mp4'),
      );
      await vpc.initialize();

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          body: TowerCustomPlayer(
                            videoPlayerController: vpc,
                            tag: testTag,
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Player'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap to push route
      await tester.tap(find.text('Open Player'));
      await tester.pumpAndSettle();

      expect(Get.isRegistered<TowerPlayerController>(tag: testTag), isTrue);

      // Pop route back to home
      Navigator.of(tester.element(find.byType(TowerCustomPlayer))).pop();
      Get.delete<TowerPlayerController>(tag: testTag, force: true);

      // Pump through the pop transition animation
      await tester.pumpAndSettle();

      // Zero framework assertion errors caught
      expect(tester.takeException(), isNull);
      expect(find.text('Open Player'), findsOneWidget);

      await vpc.dispose();
    });
  });
}
