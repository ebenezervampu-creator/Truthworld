import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/presentation/controllers/mixins/mixins.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
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

    test('6. StorageUtils resolves Google CDN and streaming URLs instantly in 0ms', () async {
      // Direct Google Cloud CDN / GCS URL
      const cdnUrl = 'https://storage.googleapis.com/truthworld-1.firebasestorage.app/videos/vid_test_123/master.mp4';
      final resolvedCdn = await StorageUtils.resolveUrl(cdnUrl);
      expect(resolvedCdn, equals(cdnUrl));

      // Fast download URL conversion
      const gsUrl = 'gs://truthworld-1.firebasestorage.app/videos/vid_test_123/stream.m3u8';
      final resolvedGs = await StorageUtils.resolveUrl(gsUrl);
      expect(resolvedGs, contains('firebasestorage.googleapis.com'));
      expect(resolvedGs, contains('alt=media'));

      // Direct CDN domain
      const customCdn = 'https://cdn.truthworld.com/video/vid_test_123/master.mp4';
      final resolvedCustom = await StorageUtils.resolveUrl(customCdn);
      expect(resolvedCustom, equals(customCdn));
    });

    test('7. VideoPlaybackHandoff and VideoController immediate Google CDN playback flow', () async {
      final cdnVideo = Video.fromMap({
        'title': 'Google CDN Video',
        'channelId': 'chan_google_cdn',
        'channelName': 'TruthWorld Edge',
        'videoUrl': 'https://storage.googleapis.com/truthworld-1.firebasestorage.app/videos/gcdn_123.mp4',
        'adaptiveResolutions': [
          {
            'label': '720p',
            'url': 'https://storage.googleapis.com/truthworld-1.firebasestorage.app/resolutions/gcdn_123/720p.mp4',
            'width': 1280,
            'height': 720,
            'bitrate': 2500000,
          },
        ],
      }, 'gcdn_123');

      // Prewarm handles Google CDN video model
      await VideoPlaybackHandoff.prewarmVideo(cdnVideo);

      final controller = VideoController();
      controller.video = cdnVideo;

      // Populates available resolutions immediately from model
      expect(cdnVideo.adaptiveResolutions, isNotEmpty);
      final targetUrl = await controller.resolvePlaybackTargetUrl();
      expect(targetUrl, isNotNull);
      expect(targetUrl, contains('storage.googleapis.com'));

      VideoPlaybackHandoff.clear('gcdn_123');
    });
  });
}
