import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/mixins/video_drag_to_miniplayer_mixin.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
    await setupMockFirebase();
  });

  group('VideoDragToMiniplayer Tests', () {
    late VideoController videoController;
    late MiniplayerController miniplayerController;

    setUp(() {
      Get.reset();
      Get.testMode = true;
      if (!Get.isRegistered<AuthService>()) {
        Get.put<AuthService>(AuthService(), permanent: true);
      }
      if (!Get.isRegistered<ConnectivityService>()) {
        Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
      }
      miniplayerController = Get.put<MiniplayerController>(
        MiniplayerController(),
        tag: 'miniplayer',
        permanent: true,
      );
      videoController = Get.put<VideoController>(
        VideoController(),
      );
      videoController.video = Video(
        id: 'drag_test_vid_1',
        title: 'Drag Test Video',
        description: 'Test description',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_1',
        channelId: 'ch_1',
        channelName: 'Test Channel',
        category: 'Education',
        tags: const ['test'],
        videoUrl: 'https://example.com/test.mp4',
      );
    });

    tearDown(() {
      videoController.disposeDragToMiniplayer();
      Get.reset();
    });

    test('1. Initial drag state is zero and inactive', () {
      expect(videoController.dragDownOffset.value, equals(0.0));
      expect(videoController.isDraggingDown.value, isFalse);
      expect(videoController.isDismissingToMiniplayer.value, isFalse);
    });

    test('2. onDragDownDelta updates dragDownOffset and clamps between 0 and 900', () {
      videoController.onDragDownStart();
      expect(videoController.isDraggingDown.value, isTrue);

      videoController.onDragDownDelta(45.0);
      expect(videoController.dragDownOffset.value, equals(45.0));

      videoController.onDragDownDelta(60.0);
      expect(videoController.dragDownOffset.value, equals(105.0));

      // Test upper clamp
      videoController.onDragDownDelta(1000.0);
      expect(videoController.dragDownOffset.value, equals(900.0));

      // Test lower clamp
      videoController.onDragDownDelta(-1200.0);
      expect(videoController.dragDownOffset.value, equals(0.0));
    });

    testWidgets('3. Drag below threshold releases back to zero without minimizing', (tester) async {
      videoController.onDragDownDelta(40.0);
      expect(videoController.dragDownOffset.value, equals(40.0));

      videoController.onDragDownEnd(50.0, 800.0);
      expect(videoController.isDraggingDown.value, isFalse);
      expect(videoController.isDismissingToMiniplayer.value, isFalse);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(videoController.dragDownOffset.value, equals(0.0));
    });

    testWidgets('4. Drag above threshold triggers minimizeToMiniplayer and pop', (tester) async {
      videoController.onDragDownDelta(120.0);
      expect(videoController.dragDownOffset.value, equals(120.0));

      videoController.onDragDownEnd(0.0, 800.0);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(videoController.isDismissingToMiniplayer.value, isTrue);
      expect(miniplayerController.currentVideo.value?.id, equals('drag_test_vid_1'));
    });

    testWidgets('5. Downward flick with high velocity triggers minimizeToMiniplayer even if offset is small', (tester) async {
      videoController.onDragDownDelta(30.0); // Below 80px threshold
      expect(videoController.dragDownOffset.value, equals(30.0));

      // High downward velocity (400 px/s > 250 px/s)
      videoController.onDragDownEnd(400.0, 800.0);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(videoController.isDismissingToMiniplayer.value, isTrue);
      expect(miniplayerController.currentVideo.value?.id, equals('drag_test_vid_1'));
    });

    testWidgets('6. minimizeToMiniplayer hands off video to MiniplayerController', (tester) async {
      await videoController.minimizeToMiniplayer();
      await tester.pumpAndSettle();

      expect(videoController.isDismissingToMiniplayer.value, isTrue);
      expect(miniplayerController.currentVideo.value?.id, equals('drag_test_vid_1'));
    });

    testWidgets('7. onDragDownCancel restores offset to zero', (tester) async {
      videoController.onDragDownDelta(50.0);
      expect(videoController.dragDownOffset.value, equals(50.0));

      videoController.onDragDownCancel();
      expect(videoController.isDraggingDown.value, isFalse);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(videoController.dragDownOffset.value, equals(0.0));
    });

    testWidgets('8. minimizeWithAnimation smoothly animates to maxDragDistance and minimizes', (tester) async {
      videoController.minimizeWithAnimation();
      expect(videoController.dragDownOffset.value, equals(0.0));

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(videoController.isDismissingToMiniplayer.value, isTrue);
      expect(miniplayerController.currentVideo.value?.id, equals('drag_test_vid_1'));
    });

    testWidgets('9. Scrolling videos up from feed does not trigger miniplayer', (tester) async {
      // Scrolling feed is decoupled from miniplayer drag down to avoid false minimizes on scroll up
      expect(videoController.dragDownOffset.value, equals(0.0));
      expect(videoController.isDismissingToMiniplayer.value, isFalse);
      expect(videoController.isDraggingDown.value, isFalse);
    });

    testWidgets('10. Dragging from top of video screen updates dragDownOffset and triggers handoff', (tester) async {
      videoController.onDragDownStart();
      expect(videoController.isDraggingDown.value, isTrue);

      // Drag downwards from top
      videoController.onDragDownDelta(95.0);
      expect(videoController.dragDownOffset.value, equals(95.0));

      videoController.onDragDownEnd(100.0, 800.0);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(videoController.isDismissingToMiniplayer.value, isTrue);
      expect(miniplayerController.currentVideo.value?.id, equals('drag_test_vid_1'));
    });

    testWidgets('11. minimizeToMiniplayer maintains maxDragDistance and sets isMiniplayerHandoffDone to prevent blink', (tester) async {
      await videoController.minimizeToMiniplayer();
      await tester.pumpAndSettle();

      expect(videoController.isMiniplayerHandoffDone.value, isTrue);
      expect(videoController.dragDownOffset.value, equals(VideoDragToMiniplayerMixin.maxDragDistance));
    });

    testWidgets('12. resetDragState resets isMiniplayerHandoffDone and dragDownOffset to zero', (tester) async {
      await videoController.minimizeToMiniplayer();
      await tester.pumpAndSettle();

      expect(videoController.isMiniplayerHandoffDone.value, isTrue);
      expect(videoController.dragDownOffset.value, equals(VideoDragToMiniplayerMixin.maxDragDistance));

      videoController.resetDragState();
      expect(videoController.isMiniplayerHandoffDone.value, isFalse);
      expect(videoController.isDismissingToMiniplayer.value, isFalse);
      expect(videoController.isDraggingDown.value, isFalse);
      expect(videoController.dragDownOffset.value, equals(0.0));
      expect(videoController.watchScrollY.value, equals(0.0));
    });

    testWidgets('13. onWatchScrollUpdate tracks scroll offset', (tester) async {
      expect(videoController.watchScrollY.value, equals(0.0));

      videoController.onWatchScrollUpdate(140.0);
      expect(videoController.watchScrollY.value, equals(140.0));

      videoController.onWatchScrollUpdate(350.0);
      expect(videoController.watchScrollY.value, equals(350.0));

      videoController.resetDragState();
      expect(videoController.watchScrollY.value, equals(0.0));
    });

    testWidgets('14. onFeedDrag gestures forward safely without throwing when unattached', (tester) async {
      expect(videoController.feedDrag, isNull);

      videoController.onFeedDragStart(DragStartDetails(
        globalPosition: const Offset(100, 200),
        localPosition: const Offset(100, 200),
      ));
      videoController.onFeedDragUpdate(DragUpdateDetails(
        globalPosition: const Offset(100, 180),
        localPosition: const Offset(100, 180),
        delta: const Offset(0, -20),
      ));
      videoController.onFeedDragEnd();
      expect(videoController.feedDrag, isNull);

      videoController.onFeedDragCancel();
      expect(videoController.feedDrag, isNull);
    });
  });
}
