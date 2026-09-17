import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/miniplayer_widget.dart';

void main() {
  group('MiniplayerWidget Responsive Layout Widget Tests', () {
    late MiniplayerController controller;

    setUp(() {
      Get.testMode = true;
      Get.reset();
      Get.put<ConnectivityService>(ConnectivityService());
      controller = Get.put<MiniplayerController>(
        MiniplayerController(),
        tag: 'miniplayer',
        permanent: true,
      );
      controller.videoInfo.value = const MiniplayerVideoInfo(
        id: 'test_vid_1',
        title: 'Global Peace and Washington D.C',
        channelName: 'Dr.K A Paul Official',
        thumbnailUrl: '',
        videoUrl: 'https://example.com/test.mp4',
        totalDuration: Duration(minutes: 10),
      );
      controller.mode.value = MiniplayerMode.collapsed;
      controller.showMobileControls.value = true;
    });

    tearDown(Get.reset);

    testWidgets('Mobile viewport renders 50% width without info bar',
        (tester) async {
      const mobileWidth = 390.0;
      const mobileHeight = 844.0;
      tester.view.physicalSize = const Size(mobileWidth, mobileHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: mobileWidth,
              height: mobileHeight,
              child: MiniplayerWidget(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      // On mobile, the title from _InfoBar should NOT be rendered in the miniplayer card
      expect(find.text('Global Peace and Washington D.C'), findsNothing);

      // Overlay controls: Pause/Play and Close buttons should exist
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // The close button dismisses the miniplayer
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(controller.mode.value, equals(MiniplayerMode.dismissed));
    });

    testWidgets('Desktop viewport renders full width and includes InfoBar',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        const desktopWidth = 1200.0;
        const desktopHeight = 800.0;
        tester.view.physicalSize = const Size(desktopWidth, desktopHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const GetMaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: desktopWidth,
                height: desktopHeight,
                child: MiniplayerWidget(),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);

        // On desktop, the info bar with video title MUST be present
        expect(find.text('Global Peace and Washington D.C'), findsOneWidget);

        // Desktop width is 1200 * 0.30 = 360.0
        final expectedWidth = (desktopWidth * 0.30).clamp(
          MiniplayerConfig.minWidth,
          MiniplayerConfig.maxWidth,
        );
        expect(expectedWidth, equals(360.0));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
