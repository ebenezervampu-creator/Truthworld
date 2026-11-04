import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_center_row.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_control_row.dart';
import 'package:video_player/video_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Jio Hotstar More Videos Zone & Gestures Tests', () {
    late TowerPlayerController controller;
    late VideoPlayerController fakeVpc;

    setUp(() {
      Get.reset();
      fakeVpc = VideoPlayerController.networkUrl(
        Uri.parse('https://example.com/test.mp4'),
      );
      controller = TowerPlayerController(videoPlayerController: fakeVpc);
    });

    tearDown(() {
      controller.onClose();
      fakeVpc.dispose();
      Get.reset();
    });

    test('isInMoreVideosZone accurately checks the middle down area', () {
      const size = Size(1000, 600);
      // Center controls are at y = 300, buttons extend to ~330.
      // Middle zone: x between 250 and 750; y >= 330.

      // 1. Left side (brightness zone) -> false
      expect(
        controller.isInMoreVideosZone(const Offset(150, 400), size),
        isFalse,
      );

      // 2. Right side (volume zone) -> false
      expect(
        controller.isInMoreVideosZone(const Offset(850, 400), size),
        isFalse,
      );

      // 3. Top half / Above center controls -> false
      expect(
        controller.isInMoreVideosZone(const Offset(500, 150), size),
        isFalse,
      );

      // 4. Over the center play/pause button -> false
      expect(
        controller.isInMoreVideosZone(const Offset(500, 300), size),
        isFalse,
      );

      // 5. Down of the pause/play and previous/next buttons in the middle -> true
      expect(
        controller.isInMoreVideosZone(const Offset(500, 360), size),
        isTrue,
      );
      expect(
        controller.isInMoreVideosZone(const Offset(400, 450), size),
        isTrue,
      );
      expect(
        controller.isInMoreVideosZone(const Offset(600, 500), size),
        isTrue,
      );

      // 6. Invalid / zero sizes -> false
      expect(
        controller.isInMoreVideosZone(const Offset(500, 400), Size.zero),
        isFalse,
      );
    });

    test('Vertical swipe in fullscreen: opens More Videos ONLY in the middle down zone', () {
      controller.isFullScreen.value = true;
      controller.showMoreVideos.value = false;
      const size = Size(1000, 600);

      // Swipe up on left side (brightness swipe)
      controller.onVerticalDragStart(
        DragStartDetails(localPosition: const Offset(150, 400)),
        size,
      );
      controller.onVerticalDragUpdate(
        DragUpdateDetails(
          globalPosition: const Offset(150, 300),
          localPosition: const Offset(150, 300),
          delta: const Offset(0, -100),
        ),
        size,
      );
      controller.onVerticalDragEnd(
        DragEndDetails(
          velocity: const Velocity(pixelsPerSecond: Offset(0, -600)),
          primaryVelocity: -600,
        ),
      );
      // Must NOT open More Videos
      expect(controller.showMoreVideos.value, isFalse);

      // Swipe up on right side (volume swipe)
      controller.onVerticalDragStart(
        DragStartDetails(localPosition: const Offset(850, 400)),
        size,
      );
      controller.onVerticalDragUpdate(
        DragUpdateDetails(
          globalPosition: const Offset(850, 300),
          localPosition: const Offset(850, 300),
          delta: const Offset(0, -100),
        ),
        size,
      );
      controller.onVerticalDragEnd(
        DragEndDetails(
          velocity: const Velocity(pixelsPerSecond: Offset(0, -600)),
          primaryVelocity: -600,
        ),
      );
      // Must NOT open More Videos
      expect(controller.showMoreVideos.value, isFalse);

      // Swipe up in top half
      controller.onVerticalDragStart(
        DragStartDetails(localPosition: const Offset(500, 150)),
        size,
      );
      controller.onVerticalDragUpdate(
        DragUpdateDetails(
          globalPosition: const Offset(500, 50),
          localPosition: const Offset(500, 50),
          delta: const Offset(0, -100),
        ),
        size,
      );
      controller.onVerticalDragEnd(
        DragEndDetails(
          velocity: const Velocity(pixelsPerSecond: Offset(0, -600)),
          primaryVelocity: -600,
        ),
      );
      // Must NOT open More Videos
      expect(controller.showMoreVideos.value, isFalse);

      // Swipe up strictly in the middle down zone (down of pause/play/next/prev)
      controller.onVerticalDragStart(
        DragStartDetails(localPosition: const Offset(500, 420)),
        size,
      );
      controller.onVerticalDragUpdate(
        DragUpdateDetails(
          globalPosition: const Offset(500, 320),
          localPosition: const Offset(500, 320),
          delta: const Offset(0, -100),
        ),
        size,
      );
      controller.onVerticalDragEnd(
        DragEndDetails(
          velocity: const Velocity(pixelsPerSecond: Offset(0, -600)),
          primaryVelocity: -600,
        ),
      );
      // MUST open More Videos!
      expect(controller.showMoreVideos.value, isTrue);

      // Swipe down when open -> closes More Videos
      controller.onVerticalDragStart(
        DragStartDetails(localPosition: const Offset(500, 300)),
        size,
      );
      controller.onVerticalDragUpdate(
        DragUpdateDetails(
          globalPosition: const Offset(500, 400),
          localPosition: const Offset(500, 400),
          delta: const Offset(0, 100),
        ),
        size,
      );
      controller.onVerticalDragEnd(
        DragEndDetails(
          velocity: const Velocity(pixelsPerSecond: Offset(0, 600)),
          primaryVelocity: 600,
        ),
      );
      expect(controller.showMoreVideos.value, isFalse);
    });

    testWidgets('CenterRow does not render More Videos pill in fullscreen (clean center controls)', (tester) async {
      controller.isFullScreen.value = true;
      controller.showMoreVideos.value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CenterRow(ctrl: controller, maxControlsWidth: 800),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "More videos" pill must NOT be rendered in CenterRow
      expect(find.descendant(of: find.byType(CenterRow), matching: find.text('More videos')), findsNothing);
      expect(find.descendant(of: find.byType(CenterRow), matching: find.byIcon(Icons.keyboard_arrow_up_rounded)), findsNothing);
    });

    testWidgets('ControlRow renders More Videos pill at bottom center after progress bar in fullscreen', (tester) async {
      controller.isFullScreen.value = true;
      controller.showMoreVideos.value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 800,
                child: ControlRow(
                  ctrl: controller,
                  isNarrow: false,
                  isMedium: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that "More videos" pill is present in ControlRow
      expect(find.byType(MoreVideosPill), findsOneWidget);
      expect(find.text('More videos'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);

      // Tap on the pill -> opens More Videos
      await tester.tap(find.text('More videos'));
      await tester.pump();
      expect(controller.showMoreVideos.value, isTrue);

      // When More Videos is open, the pill is hidden
      await tester.pump();
      expect(find.byType(MoreVideosPill), findsNothing);
    });
  });
}
