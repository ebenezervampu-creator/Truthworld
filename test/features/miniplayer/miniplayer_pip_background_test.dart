import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/pip_service.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/components/miniplayer_components.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';

import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('PipService & Miniplayer Background / PiP Tests', () {
    late MiniplayerController controller;
    late PipService pipService;

    setUp(() {
      Get.testMode = true;
      Get.reset();
      Get.put<ConnectivityService>(ConnectivityService());
      pipService = Get.put<PipService>(PipService(), permanent: true);
      controller = Get.put<MiniplayerController>(
        MiniplayerController(),
        tag: 'miniplayer',
        permanent: true,
      );
      controller.videoInfo.value = const MiniplayerVideoInfo(
        id: 'test_vid_pip',
        title: 'Background Playback & PiP Architecture',
        channelName: 'TruthWorld Dev Team',
        thumbnailUrl: '',
        videoUrl: 'https://example.com/test.mp4',
        totalDuration: Duration(minutes: 10),
      );
      controller.mode.value = MiniplayerMode.collapsed;
    });

    tearDown(Get.reset);

    Widget createTestApp(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: child,
        ),
      );
    }

    test('PipService initializes with expected defaults', () {
      expect(pipService.isPiP.value, isFalse);
      expect(pipService.isAutoPipEnabled.value, isFalse);
      expect(pipService.currentAspectRatio.value, closeTo(16.0 / 9.0, 0.01));
    });

    test('PipService clamps aspect ratio to Android PiP bounds [0.418, 2.39]', () {
      pipService.updateAutoPip(enabled: true, aspectRatio: 0.1);
      expect(pipService.currentAspectRatio.value, closeTo(0.418, 0.001));

      pipService.updateAutoPip(enabled: true, aspectRatio: 4.5);
      expect(pipService.currentAspectRatio.value, closeTo(2.39, 0.001));

      pipService.updateAutoPip(enabled: true, aspectRatio: 1.777);
      expect(pipService.currentAspectRatio.value, closeTo(1.777, 0.001));
    });

    test('PipService setPipMode notifies MiniplayerController', () {
      controller.showMobileControls.value = true;
      expect(controller.isPiP.value, isFalse);

      pipService.setPipMode(true);
      expect(pipService.isPiP.value, isTrue);
      expect(controller.isPiP.value, isTrue);
      expect(controller.showMobileControls.value, isFalse);

      pipService.setPipMode(false);
      expect(pipService.isPiP.value, isFalse);
      expect(controller.isPiP.value, isFalse);
    });

    test('MiniplayerController handleEnterBackgroundState respects PiP mode', () {
      controller.isPlaying.value = true;
      controller.isPiP.value = true;

      // In PiP mode, entering background should keep playing
      controller.handleEnterBackgroundState();
      expect(controller.isPlaying.value, isTrue);
    });

    test('MiniplayerController handleEnterBackgroundState pauses when not in PiP and mode is Off', () {
      final settings = Get.put<UserSettingsController>(
        UserSettingsController(),
        permanent: true,
      );
      settings.updatePlayback(settings.playback.value.copyWith(
        backgroundPlaybackMode: 'Off',
      ));

      controller.isPlaying.value = true;
      controller.isPiP.value = false;
      pipService.isPiP.value = false;

      controller.handleEnterBackgroundState();
      // Should stop playing because user selected Off and device is not in PiP
      expect(controller.isPlaying.value, isFalse);
    });

    test('MiniplayerController handleEnterBackgroundState continues audio when mode is Always On (screen off like Spotify)', () {
      final settings = Get.put<UserSettingsController>(
        UserSettingsController(),
        permanent: true,
      );
      settings.updatePlayback(settings.playback.value.copyWith(
        backgroundPlaybackMode: 'Always On',
      ));

      controller.isPlaying.value = true;
      controller.isPiP.value = false;
      pipService.isPiP.value = false;

      controller.handleEnterBackgroundState();
      // Should continue playing audio with screen turned off
      expect(controller.isPlaying.value, isTrue);
    });

    testWidgets('MiniplayerMobileControls renders Picture-in-Picture button and triggers enterPip', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SizedBox(
            width: 240,
            height: 135,
            child: MiniplayerMobileControls(controller: controller),
          ),
        ),
      );

      final pipButtonFinder = find.byIcon(Icons.picture_in_picture_alt_rounded);
      expect(pipButtonFinder, findsOneWidget);

      await tester.tap(pipButtonFinder);
      await tester.pump();
      // Should not throw and invoke channel
    });

    testWidgets('MiniplayerDesktopControls renders Picture-in-Picture button', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SizedBox(
            width: 400,
            height: 225,
            child: MiniplayerDesktopControls(controller: controller),
          ),
        ),
      );

      final pipButtonFinder = find.byIcon(Icons.picture_in_picture_alt_rounded);
      expect(pipButtonFinder, findsOneWidget);
    });

    testWidgets('PipDedicatedView renders cleanly in PiP mode without layout overflow', (tester) async {
      pipService.isPiP.value = true;
      controller.subtitlesEnabled.value = true;
      controller.currentSubtitle.value = 'TruthWorld verified content';

      await tester.pumpWidget(
        createTestApp(
          const SizedBox(
            width: 320,
            height: 180,
            child: PipDedicatedView(),
          ),
        ),
      );

      // Should display cleanly without errors
      expect(find.byType(PipDedicatedView), findsOneWidget);
    });
  });
}
