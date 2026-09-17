import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/presentation/controllers/mixins/mixins.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  group('VideoController Modular Architecture Tests', () {
    final sampleVideo = Video.fromMap({
      'title': 'Modular Video Testing',
      'channelId': 'chan_abc',
      'channelName': 'TruthWorld Engineering',
      'videoUrl': 'https://cdn.truthworld.com/video/vid_test_123/master.mp4',
      'hlsUrl': 'https://cdn.truthworld.com/video/vid_test_123/master.m3u8',
      'thumbnailUrl': 'https://cdn.truthworld.com/thumbs/vid_test_123.jpg',
      'likeCount': 42,
      'dislikeCount': 2,
      'viewCount': 1500,
      'chapters': [
        {'title': 'Intro', 'startTime': 0},
        {'title': 'Body', 'startTime': 30},
        {'title': 'Conclusion', 'startTime': 90},
      ],
    }, 'vid_test_123');

    test('1. VideoController implements all 10 domain mixins cleanly', () {
      final controller = VideoController();

      expect(controller, isA<VideoHydrationFlowMixin>());
      expect(controller, isA<VideoEngagementActionsMixin>());
      expect(controller, isA<VideoPlaybackFlowMixin>());
      expect(controller, isA<VideoPlaybackEngineMixin>());
      expect(controller, isA<VideoAnalyticsTrackingMixin>());
      expect(controller, isA<VideoErrorRecoveryMixin>());
      expect(controller, isA<VideoFactCheckMixin>());
      expect(controller, isA<VideoOfflineDownloadMixin>());
      expect(controller, isA<VideoPlaylistNavigationMixin>());
      expect(controller, isA<VideoTrackManagementMixin>());
    });

    test('2. VideoEngagementActionsMixin computes chapters and handles active clips', () {
      final controller = VideoController();
      controller.video = sampleVideo;

      // Check chapters
      final chapters = controller.getDisplayChapters();
      expect(chapters.length, equals(3));
      expect(chapters.first.title, equals('Intro'));
      expect(chapters.last.title, equals('Conclusion'));

      // Check clip management
      expect(controller.activeClip.value, isNull);
      final clip = VideoClip(
        id: 'clip_001',
        videoId: sampleVideo.id,
        userId: 'user_xyz',
        title: 'Highlight Clip',
        startTime: 15.0,
        endTime: 45.0,
        thumbnailUrl: '',
        videoTitle: 'Modular Video Testing',
        channelName: 'TruthWorld Engineering',
        createdAt: DateTime.now(),
      );

      controller.applyClipIfPresent({'clip': clip});
      expect(controller.activeClip.value, equals(clip));

      controller.clearActiveClip();
      expect(controller.activeClip.value, isNull);
    });

    test('3. VideoPlaybackFlowMixin calculates aspect ratios and resolves target URLs', () async {
      final controller = VideoController();
      controller.video = sampleVideo;

      // Default aspect ratio fallback
      expect(controller.vpcAspectRatio, equals(16 / 9));

      // Resolve URL with overrideUrl
      final overrideResolved = await controller.resolvePlaybackTargetUrl(
        overrideUrl: 'https://example.com/custom.mp4',
      );
      expect(overrideResolved, equals('https://example.com/custom.mp4'));

      // Resolve URL with sample video
      final resolved = await controller.resolvePlaybackTargetUrl();
      expect(resolved, isNotNull);
      expect(resolved, isNotEmpty);
    });

    test('4. VideoHydrationFlowMixin manages channel streams and initializes clean states', () {
      final controller = VideoController();
      controller.video = sampleVideo;

      final stream1 = controller.getChannelStream('chan_abc');
      final stream2 = controller.getChannelStream('chan_abc');
      expect(identical(stream1, stream2), isTrue); // Caching verification

      expect(controller.rxIsLoading.value, isTrue);
      expect(controller.videoError.value, isFalse);
      expect(controller.rxErrorMessage.value, isEmpty);
    });

    test('5. VideoController lifecycle and safe disposal', () {
      final controller = VideoController();
      controller.video = sampleVideo;

      expect(controller.isVpcInitialized, isFalse);
      expect(controller.isVpcPlaying, isFalse);

      // Safe teardown does not throw
      expect(controller.disposePlayer, returnsNormally);
    });
  });
}
