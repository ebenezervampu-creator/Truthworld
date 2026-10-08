import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/player_controls.dart';
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

  setUp(() {
    Get.reset();
    Get.put<ConnectivityService>(FakeConnectivityService());
    Get.put(SleepTimerService());

    vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
    ctrl = TowerPlayerController(videoPlayerController: vpc, tag: 'test_player_ctrl');
  });

  tearDown(() {
    ctrl.timers.cancelAll();
    ctrl.cancelPendingTap();
    TowerPlayerRegistry.unregister(ctrl);
    Get.reset();
  });

  group('Player Controls Button Widgets', () {
    testWidgets('IconBtn triggers onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconBtn(
              icon: Icons.play_arrow,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      await tester.tap(find.byType(IconBtn));
      expect(tapped, isTrue);
    });

    testWidgets('CenterBtn renders with primary styling and triggers onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CenterBtn(
              icon: Icons.pause,
              isPrimary: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.pause), findsOneWidget);
      await tester.tap(find.byType(CenterBtn));
      expect(tapped, isTrue);

      // Verify that idle decoration is NOT transparent (high-contrast frosted backing disc)
      final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, isNot(Colors.transparent));
      expect(decoration.shape, equals(BoxShape.circle));
      expect(decoration.border, isNotNull);
      expect(decoration.boxShadow, isNotEmpty);
    });

    testWidgets('CenterBtn includes icon text shadows for white background contrast', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CenterBtn(
              icon: Icons.forward_10_rounded,
            ),
          ),
        ),
      );

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.forward_10_rounded));
      expect(iconWidget.shadows, isNotNull);
      expect(iconWidget.shadows, isNotEmpty);
    });

    testWidgets('PremiumButton displays label and icon and responds to tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PremiumButton(
              label: 'Upgrade Now',
              icon: Icons.star,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Upgrade Now'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
      await tester.tap(find.byType(PremiumButton));
      expect(tapped, isTrue);
    });

    testWidgets('MobileAutoplaySwitch toggles on tap', (tester) async {
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return MobileAutoplaySwitch(
                  value: value,
                  onChanged: (newVal) => setState(() => value = newVal),
                );
              },
            ),
          ),
        ),
      );

      expect(value, isFalse);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      await tester.tap(find.byType(MobileAutoplaySwitch));
      await tester.pumpAndSettle();

      expect(value, isTrue);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });
  });

  group('Player Badges Widgets', () {
    testWidgets('AbrBadge displays AUTO and tier height label', (tester) async {
      ctrl.abr.resolutionLadder = [
        const ResolutionTier(
          label: '1080p',
          url: 'https://example.com/1080p.mp4',
          height: 1080,
          bitrate: 5000,
          minBandwidth: 4000,
        ),
      ];
      ctrl.abr.currentTierIndex.value = 0;
      ctrl.abr.isAutoMode.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AbrBadge(ctrl: ctrl),
          ),
        ),
      );

      expect(find.text('AUTO·1080p'), findsOneWidget);

      ctrl.abr.isAutoMode.value = false;
      await tester.pump();
      expect(find.text('1080p'), findsOneWidget);
    });
  });

  group('Player Volume and Time Widgets', () {
    testWidgets('VolumeControl renders mute button and responds to toggle', (tester) async {
      ctrl.volume.value = 0.8;
      ctrl.isMuted.value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VolumeControl(ctrl: ctrl),
          ),
        ),
      );

      expect(find.byType(VolumeControl), findsOneWidget);
      expect(find.byType(IconBtn), findsOneWidget);

      await tester.tap(find.byType(IconBtn));
      expect(ctrl.isMuted.value, isTrue);

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('TimeDisplay formats position and duration correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimeDisplay(ctrl: ctrl),
          ),
        ),
      );

      expect(find.byType(TimeDisplay), findsOneWidget);
      expect(find.text('00:00 / 00:00'), findsOneWidget);
    });
  });

  group('Player CenterRow & BottomBar Widgets', () {
    testWidgets('CenterRow displays play/pause and skip buttons and reflects state', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        ctrl.isPlaying.value = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CenterRow(ctrl: ctrl, maxControlsWidth: 800),
            ),
          ),
        );

        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
        expect(find.byIcon(Icons.forward_10_rounded), findsOneWidget);

        // Reactively changes icon when isPlaying becomes true
        ctrl.isPlaying.value = true;
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

        await tester.pump(const Duration(seconds: 4));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('CenterRow adapts button sizes responsively for desktop and mobile', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        // Desktop (>= 600)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CenterRow(ctrl: ctrl, maxControlsWidth: 1024),
            ),
          ),
        );

        final desktopButtons = tester.widgetList<CenterBtn>(find.byType(CenterBtn)).toList();
        expect(desktopButtons.length, equals(3));
        // Replay (skip), Play/Pause, Forward (skip)
        expect(desktopButtons[0].buttonDiameter, equals(52.0));
        expect(desktopButtons[0].size, equals(28.0));
        expect(desktopButtons[1].buttonDiameter, equals(72.0));
        expect(desktopButtons[1].size, equals(36.0));
        expect(desktopButtons[2].buttonDiameter, equals(52.0));
        expect(desktopButtons[2].size, equals(28.0));

        // Mobile (< 600)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CenterRow(ctrl: ctrl, maxControlsWidth: 400),
            ),
          ),
        );

        final mobileButtons = tester.widgetList<CenterBtn>(find.byType(CenterBtn)).toList();
        expect(mobileButtons.length, equals(3));
        expect(mobileButtons[0].buttonDiameter, equals(48.0));
        expect(mobileButtons[0].size, equals(24.0));
        expect(mobileButtons[1].buttonDiameter, equals(64.0));
        expect(mobileButtons[1].size, equals(32.0));
        expect(mobileButtons[2].buttonDiameter, equals(48.0));
        expect(mobileButtons[2].size, equals(24.0));

        await tester.pump(const Duration(seconds: 4));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('MainControls smoke test renders correctly in non-fullscreen', (tester) async {
      ctrl.isFullScreen.value = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 450,
              child: MainControls(ctrl: ctrl, playerWidth: 800),
            ),
          ),
        ),
      );

      expect(find.byType(MainControls), findsOneWidget);
      expect(find.byType(CenterRow), findsOneWidget);
      expect(find.byType(PlayerBottomBar), findsOneWidget);
    });

    testWidgets('ControlRow and MainControls do not overflow on narrow mobile screens (352px)', (tester) async {
      ctrl.isFullScreen.value = false;
      ctrl.isPlaying.value = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 352,
                height: 200,
                child: MainControls(ctrl: ctrl, playerWidth: 352),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ControlRow), findsOneWidget);
    });

    testWidgets('ControlRow does not overflow even on ultra-compact 320px screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: ControlRow(
                  ctrl: ctrl,
                  isNarrow: true,
                  isMedium: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ControlRow), findsOneWidget);
    });
  });
}
