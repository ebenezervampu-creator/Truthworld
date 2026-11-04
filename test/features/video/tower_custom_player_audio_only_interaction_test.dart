import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_top_bar.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_only_overlay.dart';
import 'package:truthworld/features/video/presentation/views/player/tower_custom_player.dart';
import 'package:truthworld/features/video/presentation/widgets/audio_themes_bottom_sheet.dart';
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

  group('TowerCustomPlayer Audio-Only & Fullscreen Interaction Tests', () {
    testWidgets(
      '1. In audio-only mode, tapping the player wakes up controls and does not get absorbed by audio stage',
      (tester) async {
        final vpc = VideoPlayerController.networkUrl(
          Uri.parse('https://example.com/audio_test.mp4'),
        );
        await vpc.initialize();

        final tpc = Get.put(
          TowerPlayerController(videoPlayerController: vpc, tag: 'audio_tap_test'),
          tag: 'audio_tap_test',
        );

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 450,
                child: TowerCustomPlayer(
                  videoPlayerController: vpc,
                  tag: 'audio_tap_test',
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Switch to Audio-Only mode
        await tpc.setAudioOnly(true);
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(AudioOnlyOverlay), findsOneWidget);

        // Hide controls
        tpc.controlsVisible.value = false;
        await tester.pump(const Duration(milliseconds: 300));
        expect(tpc.controlsVisible.value, isFalse);

        // Tap the player viewport
        await tester.tap(find.byType(TowerCustomPlayer));
        await tester.pump(const Duration(milliseconds: 300));

        // Controls must wake up!
        expect(tpc.controlsVisible.value, isTrue);

        // Clean teardown
        await tester.pumpWidget(const SizedBox());
        Get.delete<TowerPlayerController>(tag: 'audio_tap_test', force: true);
        vpc.dispose();
      },
    );

    testWidgets(
      '2. In fullscreen audio-only mode, tapping wakes controls and AudioThemeSwitcherPill opens audio theme panel',
      (tester) async {
        final vpc = VideoPlayerController.networkUrl(
          Uri.parse('https://example.com/audio_fs_test.mp4'),
        );
        await vpc.initialize();

        final tpc = Get.put(
          TowerPlayerController(videoPlayerController: vpc, tag: 'audio_fs_test'),
          tag: 'audio_fs_test',
        );

        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1280,
                height: 720,
                child: TowerCustomPlayer(
                  videoPlayerController: vpc,
                  tag: 'audio_fs_test',
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Switch to fullscreen audio-only mode
        tpc.isFullScreen.value = true;
        await tpc.setAudioOnly(true);
        tpc.controlsVisible.value = true;
        await tester.pump(const Duration(milliseconds: 300));

        // PlayerTopBar and AudioThemeSwitcherPill must be rendered
        expect(find.byType(PlayerTopBar), findsOneWidget);
        expect(find.byType(AudioThemeSwitcherPill), findsOneWidget);

        // Test tapping theme switcher pill opens AudioThemesBottomSheet popup
        await tester.tap(find.byType(AudioThemeSwitcherPill));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(AudioThemesBottomSheet), findsOneWidget);

        // Verify selecting a theme in the popup updates globalAudioTheme
        final targetTile = find.text('Classic Vinyl Turntable');
        expect(targetTile, findsOneWidget);
        await tester.ensureVisible(targetTile);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(targetTile);
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          TowerPlayerPreferences.globalAudioTheme.value,
          equals(AudioPlayerTheme.retroVinyl),
        );

        // Dismiss popup
        final closeBtn = find.byIcon(Icons.close);
        if (closeBtn.evaluate().isNotEmpty) {
          await tester.tap(closeBtn);
          await tester.pump(const Duration(milliseconds: 300));
        }

        // When controls hide in fullscreen, tapping reveals them again
        tpc.settingsOpen.value = false;
        tpc.controlsVisible.value = false;
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byType(TowerCustomPlayer));
        await tester.pump(const Duration(milliseconds: 300));

        expect(tpc.controlsVisible.value, isTrue);

        // Clean teardown
        await tester.pumpWidget(const SizedBox());
        Get.delete<TowerPlayerController>(tag: 'audio_fs_test', force: true);
        vpc.dispose();
      },
    );
  });
}
