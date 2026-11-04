import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/adaptive_bitrate_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/quality_panel.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import '../../test_helpers/mock_firebase.dart';

class _FakeQualityPlayerPlatform extends VideoPlayerPlatform {
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
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return Stream.value(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 60),
        size: const Size(640, 360),
      ),
    );
  }
  @override
  Widget buildView(int textureId) => const SizedBox();
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    VideoPlayerPlatform.instance = _FakeQualityPlayerPlatform();
    await setupMockFirebase();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
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
    if (!Get.isRegistered<AudioOnlyService>()) {
      Get.put<AudioOnlyService>(AudioOnlyService(), permanent: true);
    }
    AuthService.to.isPremiumUser.value = false;
    AuthService.to.premiumPlanId.value = null;
  });

  tearDown(Get.reset);

  group('VideoResolutionV2 Real Resolutions & Ceiling Tests', () {
    test('ensureCompleteLadder for 360p video strictly caps ladder at 360p', () {
      final existing360 = [
        VideoResolutionV2(
          label: '360p',
          url: 'https://example.com/360.mp4',
          width: 640,
          height: 360,
          bitrate: 800000,
        ),
      ];

      final ladder = VideoResolutionV2.ensureCompleteLadder(
        existing360,
        fallbackUrl: 'https://example.com/fallback.mp4',
      );

      final labels = ladder.map((r) => r.label).toList();
      final heights = ladder.map((r) => r.height).toList();

      expect(labels, contains('360p'));
      expect(labels, contains('240p'));
      expect(labels, contains('144p'));
      expect(labels, isNot(contains('480p')));
      expect(labels, isNot(contains('720p')));
      expect(labels, isNot(contains('1080p')));
      expect(labels, isNot(contains('1040p')));

      for (final h in heights) {
        expect(h, lessThanOrEqualTo(360));
      }
    });

    test('ensureCompleteLadder for 720p video does NOT upscale to 1080p', () {
      final existing720 = [
        VideoResolutionV2(
          label: '720p',
          url: 'https://example.com/720.mp4',
          width: 1280,
          height: 720,
          bitrate: 2500000,
        ),
      ];

      final ladder = VideoResolutionV2.ensureCompleteLadder(
        existing720,
        fallbackUrl: 'https://example.com/fallback.mp4',
      );

      final labels = ladder.map((r) => r.label).toList();
      expect(labels, contains('720p'));
      expect(labels, contains('480p'));
      expect(labels, contains('360p'));
      expect(labels, contains('240p'));
      expect(labels, contains('144p'));
      expect(labels, isNot(contains('1080p')));
      expect(labels, isNot(contains('1040p')));
    });

    test('ensureCompleteLadder for empty list returns empty without inventing fake tiers', () {
      final ladder = VideoResolutionV2.ensureCompleteLadder(
        [],
        fallbackUrl: 'https://example.com/fallback.mp4',
      );

      expect(ladder, isEmpty);
    });

    test('ResolutionTier.defaultLadder does not contain fictitious 1040p tier', () {
      final tiers = ResolutionTier.defaultLadder;
      final labels = tiers.map((t) => t.label).toList();

      expect(labels, isNot(contains('1040p')));
      expect(labels, contains('1080p'));
    });
  });

  group('QualityPanel UI Display Tests', () {
    testWidgets('QualityPanel for 360p video only renders 360p, 240p, 144p (no 1080p/720p/480p/1040p)', (tester) async {
      const videoId = 'test_360p_video';
      final video = Video.empty().copyWith(
        id: videoId,
        title: 'Munnar Kerala',
        videoUrl: 'https://example.com/360.mp4',
      );

      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/360.mp4'));
      await vpc.initialize();

      final vc = Get.put(VideoController(tag: videoId), tag: videoId);
      vc.video = video;
      vc.videoPlayerController = vpc;

      // Populate availableResolutions with authentic 360p completed transcode variants
      vc.availableResolutions.assignAll([
        VideoResolutionV2(label: '360p', url: 'https://example.com/360.mp4', width: 640, height: 360, bitrate: 800000),
        VideoResolutionV2(label: '240p', url: 'https://example.com/240.mp4', width: 426, height: 240, bitrate: 400000),
        VideoResolutionV2(label: '144p', url: 'https://example.com/144.mp4', width: 256, height: 144, bitrate: 200000),
      ]);
      vc.currentResolution.value = vc.availableResolutions.first;

      final tpc = Get.put(TowerPlayerController(videoPlayerController: vpc, tag: videoId), tag: videoId);

      // Pump QualityPanel
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: QualityPanel(ctrl: tpc),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify "Video Quality" header
      expect(find.text('Video Quality'), findsOneWidget);

      // Verify Auto and Audio only are present
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('Audio only'), findsOneWidget);

      // Verify authentic 360p, 240p, 144p are shown
      expect(find.text('360p'), findsWidgets);
      expect(find.text('240p'), findsOneWidget);
      expect(find.text('144p'), findsOneWidget);

      // Verify fictitious / higher resolutions are ABSOLUTELY NOT shown
      expect(find.text('1080p'), findsNothing);
      expect(find.text('720p'), findsNothing);
      expect(find.text('480p'), findsNothing);
      expect(find.text('1040p'), findsNothing);
      expect(find.text('Full HD'), findsNothing);
      expect(find.text('HD'), findsNothing);

      // Clean teardown
      await tester.pumpWidget(const SizedBox());
      tpc.abr.dispose();
      Get.delete<TowerPlayerController>(tag: videoId, force: true);
      Get.delete<VideoController>(tag: videoId, force: true);
      vpc.dispose();
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('QualityPanel rejects synthetic tiers exceeding native ceiling', (tester) async {
      const videoId = 'test_synthetic_rejection_video';
      final video = Video.empty().copyWith(
        id: videoId,
        title: 'Munnar Kerala',
        videoUrl: 'https://example.com/360.mp4',
      );

      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/360.mp4'));
      await vpc.initialize();

      final vc = Get.put(VideoController(tag: videoId), tag: videoId);
      vc.video = video;
      vc.videoPlayerController = vpc;

      // Even if legacy synthetic items were somehow in availableResolutions:
      vc.availableResolutions.assignAll([
        VideoResolutionV2(label: '1080p', url: 'https://example.com/360.mp4', width: 1920, height: 1080, bitrate: 4500000, isSynthetic: true),
        VideoResolutionV2(label: '720p', url: 'https://example.com/360.mp4', width: 1280, height: 720, bitrate: 2500000, isSynthetic: true),
        VideoResolutionV2(label: '480p', url: 'https://example.com/360.mp4', width: 854, height: 480, bitrate: 1200000, isSynthetic: true),
        VideoResolutionV2(label: '360p', url: 'https://example.com/360.mp4', width: 640, height: 360, bitrate: 800000, isSynthetic: false),
        VideoResolutionV2(label: '240p', url: 'https://example.com/240.mp4', width: 426, height: 240, bitrate: 400000, isSynthetic: false),
        VideoResolutionV2(label: '144p', url: 'https://example.com/144.mp4', width: 256, height: 144, bitrate: 200000, isSynthetic: false),
      ]);
      vc.currentResolution.value = vc.availableResolutions[3]; // 360p

      final tpc = Get.put(TowerPlayerController(videoPlayerController: vpc, tag: videoId), tag: videoId);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: QualityPanel(ctrl: tpc),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Synthetic 1080p, 720p, 480p must be strictly filtered out
      expect(find.text('1080p'), findsNothing);
      expect(find.text('720p'), findsNothing);
      expect(find.text('480p'), findsNothing);

      // Only real 360p, 240p, 144p remain
      expect(find.text('360p'), findsWidgets);
      expect(find.text('240p'), findsOneWidget);
      expect(find.text('144p'), findsOneWidget);

      // Clean teardown
      await tester.pumpWidget(const SizedBox());
      tpc.abr.dispose();
      Get.delete<TowerPlayerController>(tag: videoId, force: true);
      Get.delete<VideoController>(tag: videoId, force: true);
      vpc.dispose();
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
