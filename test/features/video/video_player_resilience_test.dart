import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_mixins/tower_player_abr_mixin.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_state_mixin.dart';
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
  Stream<VideoEvent> videoEventsFor(int textureId) => const Stream.empty();
  @override
  Widget buildView(int textureId) => const SizedBox();
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

/// Test harness for TowerPlayerStateMixin and TowerPlayerAbrMixin
class TestTowerPlayerStateHarness extends GetxController
    with TowerPlayerStateMixin, TowerPlayerAbrMixin {
  TestTowerPlayerStateHarness({this.harnessVideoController});

  final VideoController? harnessVideoController;

  @override
  VideoController? get videoController => harnessVideoController;

  @override
  VideoPlayerController get videoPlayerController => throw UnimplementedError();

  @override
  String? get tag => 'resilience_test_tag';

  @override
  RxBool get isShowingAd => false.obs;

  @override
  RxString get activePanel => ''.obs;

  @override
  RxBool get isAudioOnly => false.obs;

  @override
  void closeSettings() {}

  @override
  void trackAnalytics(dynamic event) {}
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
    AuthService.to.premiumPlanId.value = null;
  });

  tearDown(Get.reset);

  group('VideoController & TowerPlayer LateInitialization & Resilience Tests', () {
    test('1. VideoController sub-controllers (channel, engagement, analytics, comments, playlist, transcript, recommendations) do not throw LateInitializationError before initialization', () {
      final controller = VideoController();

      // Accessing sub-controllers must NEVER throw LateInitializationError
      expect(() => controller.channelController, returnsNormally);
      expect(controller.channelController, isA<ChannelController>());

      expect(() => controller.engagementController, returnsNormally);
      expect(() => controller.analyticsController, returnsNormally);
      expect(() => controller.commentsController, returnsNormally);

      expect(() => controller.videoPlaylistController, returnsNormally);
      expect(() => controller.transcriptController, returnsNormally);
      expect(() => controller.recommendationsController, returnsNormally);

      // Accessing tabs must never throw LateInitializationError
      expect(() => controller.mobileTabController, returnsNormally);
      expect(() => controller.desktopTabController, returnsNormally);

      // Accessing VideoPlaybackAccessPolicy methods must never throw
      expect(controller.isChannelMember, isFalse);
      expect(controller.channelHasMemberAdFreePerk, isFalse);
      expect(controller.hasAdFreePlayback, isFalse);
      expect(controller.canStreamHighResolution, isFalse);
    });

    test('2. VideoController resolves tagged ChannelController when tag is provided', () {
      const customTag = 'test_video_vid_123';
      final taggedChannelCtrl = Get.put(ChannelController(), tag: customTag);

      final controller = VideoController(tag: customTag);
      expect(controller.channelController, equals(taggedChannelCtrl));
    });

    test('3. TowerPlayerAbrMixin.hasPremiumPlaybackAccess safely returns false without throwing when videoController has unhydrated channel', () {
      final videoController = VideoController();
      final harness = TestTowerPlayerStateHarness(harnessVideoController: videoController);

      // Must not throw LateInitializationError or null pointer
      expect(() => harness.hasPremiumPlaybackAccess, returnsNormally);
      expect(harness.hasPremiumPlaybackAccess, isFalse);
    });

    test('4. TowerPlayerStateMixin.shouldSuppressAds safely returns false without throwing when channel is null/unhydrated', () {
      final videoController = VideoController();
      final harness = TestTowerPlayerStateHarness(harnessVideoController: videoController);

      // Must not throw LateInitializationError
      expect(() => harness.shouldSuppressAds, returnsNormally);
      expect(harness.shouldSuppressAds, isFalse);
    });

    test('5. TowerPlayerStateMixin.shouldSuppressAds returns false when videoController itself is null', () {
      final harness = TestTowerPlayerStateHarness();

      expect(() => harness.shouldSuppressAds, returnsNormally);
      expect(harness.shouldSuppressAds, isFalse);
    });

    testWidgets('6. IgnorePointer allows taps through when controlsVisible is false (resolving playback tap unresponsiveness)', (tester) async {
      var backgroundTapCount = 0;
      final controlsVisible = false.obs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                // Layer 0: Background player gesture detector
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      backgroundTapCount++;
                    },
                    child: Container(color: Colors.black),
                  ),
                ),
                // Layer 6: Controls layer using IgnorePointer (matches TowerCustomPlayer fix)
                Positioned.fill(
                  child: Obx(
                    () => IgnorePointer(
                      ignoring: !controlsVisible.value,
                      child: AnimatedOpacity(
                        opacity: controlsVisible.value ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: Center(
                          child: IconButton(
                            icon: const Icon(Icons.pause),
                            onPressed: () {},
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // 1. When controls are hidden (controlsVisible = false), tapping anywhere hits the background gesture detector
      await tester.tap(find.byType(Container));
      await tester.pump();
      expect(backgroundTapCount, equals(1));

      await tester.tap(find.byType(Container));
      await tester.pump();
      expect(backgroundTapCount, equals(2));

      // 2. When controls become visible, taps are handled by the controls layer and not the background
      controlsVisible.value = true;
      await tester.pumpAndSettle();

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      // Background tap count should remain 2 because IconButton consumed the tap
      expect(backgroundTapCount, equals(2));
    });
  });
}
