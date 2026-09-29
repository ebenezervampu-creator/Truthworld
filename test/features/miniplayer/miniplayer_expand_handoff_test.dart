import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';

void main() {
  group('VideoPlaybackHandoff Position & Handoff Tests', () {
    setUp(() {
      VideoPlaybackHandoff.clear('test-video-1');
      VideoPlaybackHandoff.clear('test-video-2');
    });

    tearDown(() {
      VideoPlaybackHandoff.clear('test-video-1');
      VideoPlaybackHandoff.clear('test-video-2');
    });

    test('registerResumePosition stores position and can be peeked/retrieved', () {
      const videoId = 'test-video-1';
      const position = Duration(seconds: 42);

      expect(VideoPlaybackHandoff.hasActivePosition(videoId), isFalse);
      expect(VideoPlaybackHandoff.peekPosition(videoId), isNull);

      VideoPlaybackHandoff.registerResumePosition(videoId, position);

      expect(VideoPlaybackHandoff.hasActivePosition(videoId), isTrue);
      expect(VideoPlaybackHandoff.peekPosition(videoId), equals(position));
      expect(VideoPlaybackHandoff.isActive(videoId), isFalse);

      final retrieved = VideoPlaybackHandoff.retrievePosition(videoId);
      expect(retrieved, equals(position));

      // After retrieve, active position should be consumed
      expect(VideoPlaybackHandoff.hasActivePosition(videoId), isFalse);
      expect(VideoPlaybackHandoff.retrievePosition(videoId), isNull);
    });

    test('clear removes active position from registry', () {
      const videoId = 'test-video-2';
      const position = Duration(minutes: 3, seconds: 15);

      VideoPlaybackHandoff.registerResumePosition(videoId, position);
      expect(VideoPlaybackHandoff.hasActivePosition(videoId), isTrue);

      VideoPlaybackHandoff.clear(videoId);

      expect(VideoPlaybackHandoff.hasActivePosition(videoId), isFalse);
      expect(VideoPlaybackHandoff.peekPosition(videoId), isNull);
      expect(VideoPlaybackHandoff.retrievePosition(videoId), isNull);
    });

    test('multiple videos have independent resume positions', () {
      const video1 = 'test-video-1';
      const video2 = 'test-video-2';
      const pos1 = Duration(seconds: 10);
      const pos2 = Duration(seconds: 90);

      VideoPlaybackHandoff.registerResumePosition(video1, pos1);
      VideoPlaybackHandoff.registerResumePosition(video2, pos2);

      expect(VideoPlaybackHandoff.peekPosition(video1), equals(pos1));
      expect(VideoPlaybackHandoff.peekPosition(video2), equals(pos2));

      expect(VideoPlaybackHandoff.retrievePosition(video1), equals(pos1));
      expect(VideoPlaybackHandoff.hasActivePosition(video1), isFalse);
      expect(VideoPlaybackHandoff.hasActivePosition(video2), isTrue);
      expect(VideoPlaybackHandoff.retrievePosition(video2), equals(pos2));
    });

    test('registerResumePosition with zero or negative duration is safely ignored', () {
      const videoId = 'test-video-zero';
      VideoPlaybackHandoff.registerResumePosition(videoId, Duration.zero);
      expect(VideoPlaybackHandoff.hasActivePosition(videoId), isFalse);
      expect(VideoPlaybackHandoff.peekPosition(videoId), isNull);

      VideoPlaybackHandoff.registerResumePosition(videoId, const Duration(seconds: -5));
      expect(VideoPlaybackHandoff.hasActivePosition(videoId), isFalse);
      expect(VideoPlaybackHandoff.peekPosition(videoId), isNull);
    });

    testWidgets('openFullScreen registers exact live position in VideoPlaybackHandoff', (tester) async {
      Get.testMode = true;
      Get.reset();
      Get.put<ConnectivityService>(ConnectivityService());
      final controller = Get.put(
        MiniplayerController(),
        tag: 'miniplayer_test',
      );
      final testVideo = Video(
        id: 'handoff_vid_123',
        title: 'Handoff Test',
        description: 'Test',
        thumbnailUrl: '',
        ownerId: 'owner_1',
        channelId: 'chan_1',
        channelName: 'Test Channel',
        category: 'Tech',
        tags: const [],
      );

      controller.currentVideo.value = testVideo;
      controller.currentPosition.value = const Duration(seconds: 77);

      await tester.pumpWidget(
        GetMaterialApp(
          home: const Scaffold(body: SizedBox.shrink()),
          getPages: [
            GetPage(
              name: '/watch',
              page: () => const Scaffold(body: SizedBox.shrink()),
            ),
          ],
        ),
      );

      expect(VideoPlaybackHandoff.hasActivePosition('handoff_vid_123'), isFalse);

      controller.openFullScreen();
      await tester.pump(const Duration(milliseconds: 700));

      expect(VideoPlaybackHandoff.hasActivePosition('handoff_vid_123'), isTrue);
      expect(
        VideoPlaybackHandoff.peekPosition('handoff_vid_123'),
        equals(const Duration(seconds: 77)),
      );

      controller.onClose();
      Get.delete<MiniplayerController>(tag: 'miniplayer_test');
      VideoPlaybackHandoff.clear('handoff_vid_123');
      Get.reset();
    });
  });
}
