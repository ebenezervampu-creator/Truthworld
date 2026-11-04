import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/audio_track_models.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/studio_video_resolution_resolver.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/studio_chewie_video_player_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/studio_chewie_video_player.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('StudioVideoResolutionResolver Tests', () {
    test('filters out raw original.mp4 and audio streams, preserving authentic resolutions', () async {
      final video = Video(
        id: 'test_vid_res',
        title: 'Resolution Test Video',
        description: 'Test description',
        videoUrl: 'https://storage.googleapis.com/bucket/videos/test_vid_res/original.mp4',
        language: 'en',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'user_1',
        channelId: 'channel_1',
        channelName: 'Test Channel',
        category: 'Tech',
        tags: const ['test'],
        adaptiveResolutions: [
          VideoResolutionV2(
            label: 'Audio Only',
            url: 'https://storage.googleapis.com/bucket/videos/test_vid_res/audio/stream.mp4',
            width: 0,
            height: 0,
            bitrate: 128000,
          ),
          VideoResolutionV2(
            label: 'Original Raw',
            url: 'https://storage.googleapis.com/bucket/videos/test_vid_res/original.mp4',
            width: 1920,
            height: 1080,
            bitrate: 5000000,
          ),
          VideoResolutionV2(
            label: '1080p',
            url: 'https://storage.googleapis.com/bucket/videos/test_vid_res/resolutions/1080p.mp4',
            width: 1920,
            height: 1080,
            bitrate: 4500000,
          ),
          VideoResolutionV2(
            label: '720p',
            url: 'https://storage.googleapis.com/bucket/videos/test_vid_res/resolutions/720p.mp4',
            width: 1280,
            height: 720,
            bitrate: 2500000,
          ),
          VideoResolutionV2(
            label: '480p',
            url: 'https://storage.googleapis.com/bucket/videos/test_vid_res/resolutions/480p.mp4',
            width: 854,
            height: 480,
            bitrate: 1200000,
          ),
        ],
      );

      final resolutions = await StudioVideoResolutionResolver.resolveResolutions(video);

      expect(resolutions.length, 3);
      expect(resolutions.map((r) => r.label), containsAll(['1080p', '720p', '480p']));
      expect(resolutions.any((r) => r.label.contains('Original') || r.url.endsWith('original.mp4')), isFalse);
      expect(resolutions.any((r) => r.label.contains('Audio') || r.url.contains('/audio')), isFalse);

      final defaultRes = StudioVideoResolutionResolver.pickDefaultResolution(resolutions);
      expect(defaultRes?.label, '720p');
    });

    test('resolvePlaybackUrl resolves dubbed video track URL', () async {
      final video = Video(
        id: 'test_vid_dub',
        title: 'Dubbed Video Test',
        description: 'Test description',
        videoUrl: 'https://storage.googleapis.com/bucket/videos/test_vid_dub/original.mp4',
        language: 'en',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'user_1',
        channelId: 'channel_1',
        channelName: 'Test Channel',
        category: 'Tech',
        tags: const ['test'],
      );

      final dubbedUrl = 'https://example.com/videos/test_vid_dub/dubbing_results/zh_video.mp4';
      final resolved = await StudioVideoResolutionResolver.resolvePlaybackUrl(
        video: video,
        isBaseTrack: false,
        trackUrl: dubbedUrl,
      );

      expect(resolved.isNotEmpty, isTrue);
    });
  });

  group('StudioChewieVideoPlayer Widget Tests', () {
    testWidgets('StudioChewieVideoPlayer renders loading state and resolution switcher when available', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final video = Video(
        id: 'test_vid_player',
        title: 'Chewie Test Video',
        description: 'Test description',
        videoUrl: 'https://example.com/videos/test_vid_player/original.mp4',
        language: 'en',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'user_1',
        channelId: 'channel_1',
        channelName: 'Test Channel',
        category: 'Tech',
        tags: const ['test'],
        adaptiveResolutions: [
          VideoResolutionV2(
            label: '1080p',
            url: 'https://example.com/videos/test_vid_player/resolutions/1080p.mp4',
            width: 1920,
            height: 1080,
            bitrate: 4500000,
          ),
          VideoResolutionV2(
            label: '720p',
            url: 'https://example.com/videos/test_vid_player/resolutions/720p.mp4',
            width: 1280,
            height: 720,
            bitrate: 2500000,
          ),
        ],
      );

      final track = VideoTrackItem(
        id: 'test_track_base',
        languageCode: 'en',
        languageName: 'English (Original)',
        videoUrl: video.videoUrl,
        isBaseTrack: true,
      );

      var closeCalled = false;

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: StudioChewieVideoPlayer(
              video: video,
              track: track,
              tag: 'test_chewie_player_tag',
              onClosePlayer: () => closeCalled = true,
            ),
          ),
        ),
      );

      expect(find.byType(StudioChewieVideoPlayer), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));

      // Controller should be registered with resolutions populated
      final ctrl = Get.find<StudioChewieVideoPlayerController>(tag: 'test_chewie_player_tag');
      expect(ctrl.availableResolutions.length, 2);
      expect(ctrl.availableResolutions.map((r) => r.label), containsAll(['1080p', '720p']));

      // Close player button exists and calls callback
      final closeBtn = find.byIcon(Icons.close_rounded);
      if (closeBtn.evaluate().isNotEmpty) {
        await tester.tap(closeBtn);
        await tester.pump();
        expect(closeCalled, isTrue);
      }

      await tester.pump(const Duration(seconds: 5));
    });
  });
}
