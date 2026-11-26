import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/components/miniplayer_components.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/miniplayer_overlay_manager.dart';
import 'package:truthworld/features/video/presentation/services/video_playback_queue_service.dart';

void main() {
  group('Miniplayer Modular Components Tests', () {
    late MiniplayerController controller;

    setUp(() {
      Get.testMode = true;
      Get.reset();
      Get.put<ConnectivityService>(ConnectivityService());
      Get.put<VideoPlaybackQueueService>(VideoPlaybackQueueService());
      controller = Get.put<MiniplayerController>(
        MiniplayerController(),
        tag: 'miniplayer',
        permanent: true,
      );
      controller.videoInfo.value = const MiniplayerVideoInfo(
        id: 'test_vid_modular',
        title: 'TruthWorld Modular Architecture Review',
        channelName: 'TruthWorld Dev Team',
        thumbnailUrl: '',
        videoUrl: 'https://example.com/test.mp4',
        totalDuration: Duration(minutes: 15),
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

    testWidgets('MiniplayerOverlayIconButton renders icon, tooltip, and responds to tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestApp(
          MiniplayerOverlayIconButton(
            icon: Icons.fullscreen,
            tooltip: 'Fullscreen Mode',
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('MiniplayerExpandButton renders Expand label and hotkey I pill', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          MiniplayerExpandButton(controller: controller),
        ),
      );

      expect(find.text('Expand'), findsOneWidget);
      expect(find.text('I'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_full_rounded), findsOneWidget);
    });

    testWidgets('MiniplayerCenterPlayButton displays play and pause icons according to isPlaying state', (tester) async {
      controller.isPlaying.value = false;

      await tester.pumpWidget(
        createTestApp(
          MiniplayerCenterPlayButton(controller: controller),
        ),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      controller.isPlaying.value = true;
      await tester.pump();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('MiniplayerMobileControls renders top-left play/pause, top-right close, and bottom-right expand', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SizedBox(
            width: 300,
            height: 200,
            child: MiniplayerMobileControls(controller: controller),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.open_in_full_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(controller.mode.value, equals(MiniplayerMode.dismissed));
    });

    testWidgets('MiniplayerDesktopControls renders expand, CC, close, and center play', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SizedBox(
            width: 400,
            height: 240,
            child: MiniplayerDesktopControls(controller: controller),
          ),
        ),
      );

      expect(find.text('Expand'), findsOneWidget);
      expect(find.byIcon(Icons.subtitles_outlined), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Reactively show enabled subtitles icon
      controller.subtitlesEnabled.value = true;
      await tester.pump();

      expect(find.byIcon(Icons.subtitles_rounded), findsOneWidget);
    });

    testWidgets('MiniplayerVideoProgressBar renders progress bar and handles tap seek', (tester) async {
      controller.totalDuration.value = const Duration(minutes: 10);
      controller.currentPosition.value = const Duration(minutes: 5);

      await tester.pumpWidget(
        createTestApp(
          SizedBox(
            width: 400,
            height: 20,
            child: MiniplayerVideoProgressBar(controller: controller),
          ),
        ),
      );

      expect(find.byType(MiniplayerVideoProgressBar), findsOneWidget);

      // Tap midway
      await tester.tapAt(const Offset(200, 10));
      await tester.pump();

      expect(controller.currentPosition.value.inMinutes, equals(5));
    });

    testWidgets('MiniplayerTitleAndMeta renders title and channel with duration', (tester) async {
      controller.currentPosition.value = const Duration(minutes: 1, seconds: 30);
      controller.totalDuration.value = const Duration(minutes: 15);

      await tester.pumpWidget(
        createTestApp(
          MiniplayerTitleAndMeta(controller: controller),
        ),
      );

      expect(find.text('TruthWorld Modular Architecture Review'), findsOneWidget);
      expect(
        find.textContaining('TruthWorld Dev Team'),
        findsOneWidget,
      );
      expect(
        find.textContaining('01:30 / 15:00'),
        findsOneWidget,
      );
    });

    testWidgets('MiniplayerInfoBar renders title, play/pause, close, and expand buttons', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          MiniplayerInfoBar(
            controller: controller,
            cardSize: const Size(400, 260),
            screenSize: const Size(1200, 800),
          ),
        ),
      );

      expect(find.text('TruthWorld Modular Architecture Review'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.open_in_full_rounded), findsOneWidget);
    });

    testWidgets('MiniplayerExpandedTopBar renders minimize, CC, and close buttons', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          MiniplayerExpandedTopBar(controller: controller),
        ),
      );

      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      expect(find.byIcon(Icons.subtitles_outlined), findsOneWidget);
      expect(find.byIcon(Icons.open_in_full_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap minimize -> collapses mode
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pump();

      expect(controller.mode.value, equals(MiniplayerMode.collapsed));
    });

    testWidgets('MiniplayerExpandedDetails renders scrubber, Back Video, Center Play, Next Video, and meta', (tester) async {
      controller.isAutoplay.value = true;
      VideoPlaybackQueueService.to.clearSession();

      await tester.pumpWidget(
        createTestApp(
          MiniplayerExpandedDetails(controller: controller),
        ),
      );

      expect(find.byType(Slider), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.text('TruthWorld Modular Architecture Review'), findsOneWidget);
      expect(find.text('TruthWorld Dev Team'), findsOneWidget);

      // On first video, Back Video is wrapped with Opacity 0.0 and IgnorePointer
      final backOpacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byIcon(Icons.skip_previous_rounded),
          matching: find.byType(Opacity),
        ).first,
      );
      expect(backOpacity.opacity, equals(0.0));

      // When autoplay is OFF, Back Video and Next Video are hidden
      controller.isAutoplay.value = false;
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsNothing);
      expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
    });

    testWidgets('MiniplayerCenterControlsRow renders center play with back and next controls when autoplay ON', (tester) async {
      controller.isAutoplay.value = true;
      VideoPlaybackQueueService.to.clearSession();

      await tester.pumpWidget(
        createTestApp(
          MiniplayerCenterControlsRow(controller: controller),
        ),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);

      // When autoplay is OFF, only center play button is shown
      controller.isAutoplay.value = false;
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsNothing);
      expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
    });

    testWidgets('MiniplayerOverlayManager provides internal Overlay ensuring Tooltips render cleanly without error', (tester) async {
      controller.mode.value = MiniplayerMode.collapsed;

      // Mount MiniplayerOverlayManager WITHOUT a MaterialApp, Navigator, or external Overlay
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData(size: Size(390, 844)),
            child: Material(
              child: MiniplayerOverlayManager(),
            ),
          ),
        ),
      );

      expect(find.byType(MiniplayerOverlayManager), findsOneWidget);
      expect(find.byType(Overlay), findsOneWidget);
      expect(find.byType(Tooltip), findsWidgets);
    });
  });
}
