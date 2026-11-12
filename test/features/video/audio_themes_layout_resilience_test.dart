import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/audio_themes_barrel.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
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
          duration: const Duration(seconds: 180),
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

  late TowerPlayerController playerCtrl;
  late AudioAnalysisService analysisService;

  final dummyVideo = Video(
    id: 'test_video_1',
    title: 'Test Audio Experience with a Long Title to Verify Ellipsis',
    description: 'Description',
    videoUrl: 'https://cdn.truthworld.app/video.mp4',
    thumbnailUrl: '',
    ownerId: 'owner_1',
    category: 'Music',
    tags: const ['music'],
    duration: 180,
    views: 1200,
    likes: 85,
    dislikeCount: 2,
    channelId: 'channel_1',
    channelName: 'TruthWorld Acoustic Studio',
    createdAt: DateTime.now(),
  );

  setUpAll(() async {
    VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/audio.mp4'));
    playerCtrl = TowerPlayerController(videoPlayerController: vpc, tag: 'resilience_test');
    Get.put<TowerPlayerController>(playerCtrl, tag: 'resilience_test');
    analysisService = AudioAnalysisService(playerCtrl: playerCtrl);
  });

  tearDown(() {
    analysisService.onClose();
    Get.reset();
  });

  group('Next-Gen 5 Audio Themes Layout Resilience & Constraints Guard', () {
    testWidgets('FluidAuraTheme renders without RenderFlex overflow in compact 16:9 player bounds', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 202, // 16:9 on compact screen where legacy theme overflowed by 57px
              child: FluidAuraTheme(
                ctrl: playerCtrl,
                analysisService: analysisService,
                video: dummyVideo,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(FluidAuraTheme), findsOneWidget);
    });

    testWidgets('All 5 Next-Gen Audio Themes render cleanly in bounded player viewport with ZERO overflow', (tester) async {
      playerCtrl.subtitleSegments.assignAll([
        const SubtitleSegment(
          start: Duration(seconds: 0),
          end: Duration(seconds: 5),
          text: 'Truth in sound, verified evidence for listeners.',
        ),
        const SubtitleSegment(
          start: Duration(seconds: 5),
          end: Duration(seconds: 10),
          text: 'Next line with fluid transcript progression.',
        ),
      ]);
      playerCtrl.activeSubtitleSegment.value = playerCtrl.subtitleSegments.first;

      final themes = <Widget>[
        FluidAuraTheme(ctrl: playerCtrl, analysisService: analysisService, video: dummyVideo),
        KineticSyllableTheme(ctrl: playerCtrl, analysisService: analysisService, video: dummyVideo),
        AudiophileSpectralTheme(ctrl: playerCtrl, analysisService: analysisService, video: dummyVideo),
        ObsidianMinimalistTheme(ctrl: playerCtrl, analysisService: analysisService, video: dummyVideo),
        TruthPulseHologramTheme(ctrl: playerCtrl, analysisService: analysisService, video: dummyVideo),
      ];

      for (final theme in themes) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 202, // Standard 16:9 compact bounds
                child: theme,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull, reason: '${theme.runtimeType} threw an overflow exception');
      }
    });

    testWidgets('Themes adapt across portrait, landscape, and split-screen constraints', (tester) async {
      final viewports = [
        const Size(360, 202), // 16:9 compact mobile
        const Size(360, 640), // Fullscreen mobile portrait
        const Size(800, 360), // Fullscreen landscape
        const Size(320, 160), // Ultra-compact split screen
      ];

      for (final size in viewports) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: size.width,
                height: size.height,
                child: ObsidianMinimalistTheme(
                  ctrl: playerCtrl,
                  analysisService: analysisService,
                  video: dummyVideo,
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: 'ObsidianMinimalistTheme failed on $size');
      }
    });

    testWidgets('AnimatedSwitcher with StackFit.expand passes finite constraints to theme stage', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 202,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      fit: StackFit.expand,
                      children: [
                        ...previousChildren,
                        ?currentChild,
                      ],
                    ),
                    child: KeyedSubtree(
                      key: const ValueKey('fluidAura'),
                      child: FluidAuraTheme(
                        ctrl: playerCtrl,
                        analysisService: analysisService,
                        video: dummyVideo,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(FluidAuraTheme), findsOneWidget);
    });
  });
}
