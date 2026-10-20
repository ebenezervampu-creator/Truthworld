import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/truthworld_player_timeline.dart';
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
  Stream<VideoEvent> videoEventsFor(int textureId) => Stream.value(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(minutes: 10),
          size: const Size(1920, 1080),
        ),
      );
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

  late TowerPlayerController ctrl;
  late VideoPlayerController vpc;

  setUpAll(() async {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
  });

  setUp(() async {
    Get.reset();
    Get.put<ConnectivityService>(FakeConnectivityService());
    Get.put(SleepTimerService());

    vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
    await vpc.initialize();
    ctrl = TowerPlayerController(videoPlayerController: vpc, tag: 'precision_test_ctrl');
  });

  tearDown(() {
    ctrl.timers.cancelAll();
    ctrl.cancelPendingTap();
    TowerPlayerRegistry.unregister(ctrl);
    Get.reset();
  });

  group('Vertical-Drag Precision Scrubbing Tests', () {
    const totalDuration = Duration(minutes: 10);

    test('Initial scrub state has 1.0x rate and precision mode disabled', () {
      expect(ctrl.scrubRate.value, equals(1.0));
      expect(ctrl.isPrecisionScrubbing.value, isFalse);
      expect(ctrl.precisionScrubLabel.value, isEmpty);
    });

    test('Normal horizontal drag maintains 1.0x scrub rate', () {
      ctrl.onScrubStart(0.2, totalDuration, startX: 200.0);
      expect(ctrl.isScrubbing.value, isTrue);

      ctrl.onScrubUpdate(
        0.3,
        totalDuration,
        currentX: 300.0,
        upwardDisplacement: 10.0,
        barWidth: 1000.0,
      );

      expect(ctrl.scrubRate.value, equals(1.0));
      expect(ctrl.isPrecisionScrubbing.value, isFalse);
      expect(ctrl.precisionScrubLabel.value, isEmpty);
    });

    test('Dragging upward >= 35px engages 0.5x fine scrubbing rate', () {
      ctrl.onScrubStart(0.2, totalDuration, startX: 200.0);

      ctrl.onScrubUpdate(
        0.3,
        totalDuration,
        currentX: 300.0,
        upwardDisplacement: 45.0,
        barWidth: 1000.0,
      );

      expect(ctrl.scrubRate.value, equals(0.5));
      expect(ctrl.isPrecisionScrubbing.value, isTrue);
      expect(ctrl.precisionScrubLabel.value, equals('Fine Scrubbing (0.5×)'));
    });

    test('Dragging upward >= 75px engages 0.25x ultra-fine scrubbing rate', () {
      ctrl.onScrubStart(0.2, totalDuration, startX: 200.0);

      ctrl.onScrubUpdate(
        0.4,
        totalDuration,
        currentX: 400.0,
        upwardDisplacement: 90.0,
        barWidth: 1000.0,
      );

      expect(ctrl.scrubRate.value, equals(0.25));
      expect(ctrl.isPrecisionScrubbing.value, isTrue);
      expect(ctrl.precisionScrubLabel.value, equals('Ultra-Fine Scrubbing (0.25×)'));
    });

    test('Dragging back down returns sensitivity to 1.0x', () {
      ctrl.onScrubStart(0.2, totalDuration, startX: 200.0);

      // Drag up
      ctrl.onScrubUpdate(
        0.4,
        totalDuration,
        currentX: 400.0,
        upwardDisplacement: 80.0,
        barWidth: 1000.0,
      );
      expect(ctrl.scrubRate.value, equals(0.25));

      // Drag back down
      ctrl.onScrubUpdate(
        0.4,
        totalDuration,
        currentX: 400.0,
        upwardDisplacement: 10.0,
        barWidth: 1000.0,
      );
      expect(ctrl.scrubRate.value, equals(1.0));
      expect(ctrl.isPrecisionScrubbing.value, isFalse);
    });

    test('onScrubEnd resets precision state and rate back to 1.0x', () {
      ctrl.onScrubStart(0.2, totalDuration, startX: 200.0);
      ctrl.onScrubUpdate(
        0.4,
        totalDuration,
        currentX: 400.0,
        upwardDisplacement: 90.0,
        barWidth: 1000.0,
      );
      expect(ctrl.isPrecisionScrubbing.value, isTrue);

      ctrl.onScrubEnd();
      expect(ctrl.isScrubbing.value, isFalse);
      expect(ctrl.scrubRate.value, equals(1.0));
      expect(ctrl.isPrecisionScrubbing.value, isFalse);
      expect(ctrl.precisionScrubLabel.value, isEmpty);
    });

    test('Scrub update with chapters and claims safely evaluates without exception', () {
      ctrl.onScrubStart(0.1, totalDuration, startX: 100.0);

      final testChapters = [
        VideoChapter(title: 'Intro', startTime: Duration.zero),
        VideoChapter(title: 'Chapter 1', startTime: const Duration(minutes: 2)),
      ];
      final testClaims = <ClaimResult>[
        ClaimResult(
          text: 'Verified Arctic Temp',
          verdict: 'verified',
          start: 120.0,
        ),
      ];

      expect(
        () => ctrl.onScrubUpdate(
          0.25,
          totalDuration,
          currentX: 250.0,
          upwardDisplacement: 40.0,
          barWidth: 1000.0,
          chapters: testChapters,
          claims: testClaims,
        ),
        returnsNormally,
      );
    });
  });

  group('Power-User Keyboard Shortcuts & Theater Mode Tests', () {
    test('Toggle theater mode updates reactive state and toast', () {
      expect(ctrl.isTheaterMode.value, isFalse);

      ctrl.toggleTheaterMode();
      expect(ctrl.isTheaterMode.value, isTrue);

      ctrl.toggleTheaterMode();
      expect(ctrl.isTheaterMode.value, isFalse);
    });

    test('Keyboard key T toggles theater mode', () {
      expect(ctrl.isTheaterMode.value, isFalse);

      ctrl.handleKey(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyT,
          logicalKey: LogicalKeyboardKey.keyT,
          timeStamp: Duration.zero,
        ),
      );

      expect(ctrl.isTheaterMode.value, isTrue);
    });

    test('Keyboard comma and period step 33ms frame-by-frame when paused', () {
      ctrl.isPlaying.value = false;

      // Press comma (step back 1 frame)
      ctrl.handleKey(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.comma,
          logicalKey: LogicalKeyboardKey.comma,
          timeStamp: Duration.zero,
        ),
      );
      expect(ctrl.toastMessage.value, equals('Frame -1'));

      // Press period (step forward 1 frame)
      ctrl.handleKey(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.period,
          logicalKey: LogicalKeyboardKey.period,
          timeStamp: Duration.zero,
        ),
      );
      expect(ctrl.toastMessage.value, equals('Frame +1'));
    });
  });

  group('Subtitle Timing Sync Offset Tests', () {
    test('Adjusting subtitle offset advances and delays timing reactively', () {
      expect(ctrl.subtitleOffsetMs.value, equals(0));

      ctrl.adjustSubtitleOffset(100);
      expect(ctrl.subtitleOffsetMs.value, equals(100));

      ctrl.adjustSubtitleOffset(150);
      expect(ctrl.subtitleOffsetMs.value, equals(250));

      ctrl.adjustSubtitleOffset(-100);
      expect(ctrl.subtitleOffsetMs.value, equals(150));

      ctrl.resetSubtitleOffset();
      expect(ctrl.subtitleOffsetMs.value, equals(0));
    });
  });

  group('TruthWorldPlayerTimeline Floating HUD Tests', () {
    testWidgets('Renders precision scrubbing HUD when precision mode is active', (tester) async {
      ctrl.isScrubbing.value = true;
      ctrl.isPrecisionScrubbing.value = true;
      ctrl.precisionScrubLabel.value = 'Fine Scrubbing (0.5×)';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: TruthWorldPlayerTimeline(ctrl: ctrl),
            ),
          ),
        ),
      );

      expect(find.text('Fine Scrubbing (0.5×)'), findsOneWidget);
      expect(find.text('Drag down to return to 1.0×'), findsOneWidget);
    });
  });

  group('Chapter and Seek Preview Tooltip Dismissal Tests', () {
    const totalDuration = Duration(minutes: 10);

    test('onScrubEnd hides seek preview and hover state when chapter scrub concludes', () {
      ctrl.onScrubStart(0.3, totalDuration, startX: 300.0);
      ctrl.updateSeekPreview(0.3, 300.0, totalDuration);
      ctrl.updateTimelineHover(0.3, 300.0, totalDuration);

      expect(ctrl.seekPreviewVis.value, isTrue);
      expect(ctrl.isTimelineHovered.value, isTrue);

      ctrl.onScrubEnd();

      expect(ctrl.seekPreviewVis.value, isFalse);
      expect(ctrl.isTimelineHovered.value, isFalse);
      expect(ctrl.isScrubbing.value, isFalse);
    });

    test('onScrubCancel hides seek preview and hover state', () {
      ctrl.onScrubStart(0.4, totalDuration, startX: 400.0);
      ctrl.updateSeekPreview(0.4, 400.0, totalDuration);
      ctrl.updateTimelineHover(0.4, 400.0, totalDuration);

      expect(ctrl.seekPreviewVis.value, isTrue);
      expect(ctrl.isTimelineHovered.value, isTrue);

      ctrl.onScrubCancel();

      expect(ctrl.seekPreviewVis.value, isFalse);
      expect(ctrl.isTimelineHovered.value, isFalse);
      expect(ctrl.isScrubbing.value, isFalse);
    });

    test('seekTo automatically dismisses seek preview tooltip', () async {
      ctrl.seekPreviewVis.value = true;
      expect(ctrl.seekPreviewVis.value, isTrue);

      await ctrl.seekTo(const Duration(minutes: 2, seconds: 47));

      expect(ctrl.seekPreviewVis.value, isFalse);
    });

    testWidgets('TruthWorldPlayerTimeline gesture completion dismisses seek preview', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 50,
              child: TruthWorldPlayerTimeline(ctrl: ctrl),
            ),
          ),
        ),
      );

      // 1. Drag interaction (Scrubbing chapter)
      final timelineFinder = find.byType(TruthWorldPlayerTimeline);
      final gesture = await tester.startGesture(tester.getCenter(timelineFinder));
      await tester.pump();
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();

      expect(ctrl.isScrubbing.value, isTrue);
      expect(ctrl.seekPreviewVis.value, isTrue);

      // Release finger (Selecting chapter)
      await gesture.up();
      await tester.pump();

      expect(ctrl.isScrubbing.value, isFalse);
      expect(ctrl.seekPreviewVis.value, isFalse);
      expect(ctrl.isTimelineHovered.value, isFalse);

      // 2. Tap interaction (Direct chapter selection)
      ctrl.updateSeekPreview(0.5, 400.0, totalDuration);
      expect(ctrl.seekPreviewVis.value, isTrue);

      await tester.tap(timelineFinder);
      await tester.pump();

      expect(ctrl.seekPreviewVis.value, isFalse);
      expect(ctrl.isTimelineHovered.value, isFalse);
    });
  });
}

