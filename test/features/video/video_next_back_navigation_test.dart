import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:truthworld/features/video/presentation/services/video_playback_queue_service.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_center_row.dart';
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

Video createTestVideo(String id, String title) {
  return Video(
    id: id,
    title: title,
    description: 'Description for $title',
    thumbnailUrl: 'https://example.com/$id.jpg',
    ownerId: 'owner_1',
    channelId: 'chan_1',
    channelName: 'Truth Channel',
    category: 'General',
    tags: const ['news'],
    views: 100,
    createdAt: DateTime(2026),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  });

  group('VideoPlaybackQueueService Unit Tests', () {
    late VideoPlaybackQueueService queueService;
    final v1 = createTestVideo('v1', 'First Video');
    final v2 = createTestVideo('v2', 'Second Video');
    final v3 = createTestVideo('v3', 'Third Video');

    setUp(() {
      Get.reset();
      queueService = Get.put(VideoPlaybackQueueService(), permanent: true);
    });

    test('1. First video has no back videos', () {
      expect(queueService.hasPreviousVideo, isFalse);
      queueService.onVideoLoaded(v1);
      // Still the first video, no back video
      expect(queueService.hasPreviousVideo, isFalse);
      expect(queueService.previousVideo, isNull);
    });

    test('2. Advancing to next video makes previous video available', () {
      queueService.onVideoLoaded(v1);
      expect(queueService.hasPreviousVideo, isFalse);

      queueService.pushCurrentForNext(v2);
      queueService.onVideoLoaded(v2);

      // On v2, previous video should be v1
      expect(queueService.hasPreviousVideo, isTrue);
      expect(queueService.previousVideo?.id, equals('v1'));

      // Advance again to v3
      queueService.pushCurrentForNext(v3);
      queueService.onVideoLoaded(v3);

      expect(queueService.hasPreviousVideo, isTrue);
      expect(queueService.previousVideo?.id, equals('v2'));
    });

    test('3. Navigating back returns previous video and stops at first video', () {
      queueService.onVideoLoaded(v1);
      queueService.pushCurrentForNext(v2);
      queueService.onVideoLoaded(v2);
      queueService.pushCurrentForNext(v3);
      queueService.onVideoLoaded(v3);

      // On v3, pop previous -> returns v2
      final prev1 = queueService.popPreviousVideo();
      expect(prev1?.id, equals('v2'));
      queueService.onVideoLoaded(prev1!);
      expect(queueService.hasPreviousVideo, isTrue);
      expect(queueService.hasForwardVideo, isTrue);
      expect(queueService.nextForwardVideo?.id, equals('v3'));

      // On v2, pop previous -> returns v1
      final prev2 = queueService.popPreviousVideo();
      expect(prev2?.id, equals('v1'));
      queueService.onVideoLoaded(prev2!);

      // Now on v1 (the first video): NO BACK VIDEOS!
      expect(queueService.hasPreviousVideo, isFalse);
      expect(queueService.previousVideo, isNull);
      expect(queueService.popPreviousVideo(), isNull);
    });

    test('4. Opening an external video clears session to act as first video', () {
      queueService.onVideoLoaded(v1);
      queueService.pushCurrentForNext(v2);
      queueService.onVideoLoaded(v2);
      expect(queueService.hasPreviousVideo, isTrue);

      // External tap on v3 (not internal navigation)
      final externalVid = createTestVideo('v_ext', 'External Tap Video');
      queueService.onVideoLoaded(externalVid);

      // New session started, so no back videos
      expect(queueService.hasPreviousVideo, isFalse);
      expect(queueService.previousStack, isEmpty);
    });
  });

  group('TowerPlayerNavigationMixin Autoplay Requirement Tests', () {
    test('hasPreviousVideo and hasNextVideo return false when isAutoplay is off', () {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      final ctrl = TowerPlayerController(videoPlayerController: vpc);
      final queueService = VideoPlaybackQueueService.to;

      final v1 = createTestVideo('v1', 'First Video');
      final v2 = createTestVideo('v2', 'Second Video');
      queueService.onVideoLoaded(v1);
      queueService.pushCurrentForNext(v2);
      queueService.onVideoLoaded(v2);

      // Queue has a previous video
      expect(queueService.hasPreviousVideo, isTrue);

      // When autoplay is ON: hasPreviousVideo is true
      ctrl.isAutoplay.value = true;
      expect(ctrl.hasPreviousVideo, isTrue);
      expect(ctrl.hasNextVideo, isTrue);

      // When autoplay is OFF: feature must not work!
      ctrl.isAutoplay.value = false;
      expect(ctrl.hasPreviousVideo, isFalse);
      expect(ctrl.hasNextVideo, isFalse);
    });

    test('playNext and playPrevious do not execute when isAutoplay is false', () {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      final ctrl = TowerPlayerController(videoPlayerController: vpc);

      ctrl.isAutoplay.value = false;
      // Should early return and not throw or change navigation state
      ctrl.playNext();
      expect(ctrl.isNavigatingToVideo.value, isFalse);

      ctrl.playPrevious();
      expect(ctrl.isNavigatingToVideo.value, isFalse);
    });
  });

  group('CenterRow Widget Tests', () {
    testWidgets('Replaces 10s buttons with Next and Back buttons', (tester) async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      final ctrl = TowerPlayerController(videoPlayerController: vpc);
      ctrl.isAutoplay.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CenterRow(ctrl: ctrl, maxControlsWidth: 800),
          ),
        ),
      );

      // 10-second buttons must NOT exist anywhere in CenterRow
      expect(find.byIcon(Icons.replay_10_rounded), findsNothing);
      expect(find.byIcon(Icons.forward_10_rounded), findsNothing);

      // Next video button is present
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    });

    testWidgets('First video shows back video button with disabled opacity', (tester) async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      final ctrl = TowerPlayerController(videoPlayerController: vpc);
      ctrl.isAutoplay.value = true;

      // Ensure queue is empty (first video)
      VideoPlaybackQueueService.to.clearSession();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CenterRow(ctrl: ctrl, maxControlsWidth: 800),
          ),
        ),
      );

      // Back video button opacity is 0.4 (visible but disabled) on first video
      final prevFinder = find.byWidgetPredicate(
        (w) => w is Opacity && w.opacity == 0.4,
      );
      expect(prevFinder, findsWidgets);

      // Next video button has opacity 1.0 (visible)
      final nextFinder = find.byWidgetPredicate(
        (w) => w is Opacity && w.opacity == 1.0,
      );
      expect(nextFinder, findsWidgets);
    });

    testWidgets('When autoplay is off, neither back nor next buttons are shown', (tester) async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/test.mp4'));
      final ctrl = TowerPlayerController(videoPlayerController: vpc);
      ctrl.isAutoplay.value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CenterRow(ctrl: ctrl, maxControlsWidth: 800),
          ),
        ),
      );

      // Neither back nor next buttons are shown
      expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
      expect(find.byIcon(Icons.skip_next_rounded), findsNothing);
      expect(find.byIcon(Icons.replay_10_rounded), findsNothing);
      expect(find.byIcon(Icons.forward_10_rounded), findsNothing);
    });
  });
}
