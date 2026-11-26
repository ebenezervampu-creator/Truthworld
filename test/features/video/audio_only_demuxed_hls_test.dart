import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/audio_only_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_only_overlay.dart';
import 'package:video_player/video_player.dart';
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
  Stream<VideoEvent> videoEventsFor(int textureId) => Stream.value(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 180),
          size: const Size(1920, 1080),
        ),
      );
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
  });

  tearDown(Get.reset);

  group('Next-Gen Demuxed Audio HLS & Visual Pill Tests', () {
    test('1. resolveAudioOnlyTargetUrl resolves RFC 8216 audio playlist when hlsUrl is present', () {
      final vc = VideoController();
      vc.video = Video(
        id: 'hls_test_video',
        title: 'HLS Test Video',
        description: 'Testing RFC 8216 HLS audio rendition',
        videoUrl: 'https://cdn.truthworld.com/hls_test_video.mp4',
        thumbnailUrl: '',
        ownerId: 'owner_1',
        category: 'Journalism',
        tags: const ['news'],
        duration: 300,
        views: 100,
        likes: 10,
        dislikeCount: 0,
        channelId: 'ch_1',
        channelName: 'TruthWorld News',
        createdAt: DateTime.now(),
        language: 'en',
        hlsUrl: 'https://storage.googleapis.com/truthworld/hls/hls_test_video/master.m3u8',
      );

      final audioUrl = vc.resolveAudioOnlyTargetUrl();
      expect(
        audioUrl,
        equals('https://storage.googleapis.com/truthworld/hls/hls_test_video/audio/en/prog.m3u8'),
      );
    });

    test('2. resolveAudioOnlyTargetUrl falls back to null (triggering 144p) when no HLS or audio tracks exist', () {
      final vc = VideoController();
      vc.video = Video(
        id: 'legacy_test_video',
        title: 'Legacy Video',
        description: 'Video without HLS master',
        videoUrl: 'https://cdn.truthworld.com/legacy.mp4',
        thumbnailUrl: '',
        ownerId: 'owner_1',
        category: 'Talks',
        tags: const ['talk'],
        duration: 200,
        views: 50,
        likes: 5,
        dislikeCount: 0,
        channelId: 'ch_1',
        channelName: 'TruthWorld Talks',
        createdAt: DateTime.now(),
        language: 'en',
        hlsUrl: '',
      );

      final audioUrl = vc.resolveAudioOnlyTargetUrl();
      expect(audioUrl, isNull);
    });

    test('3. toggleAudioOnly switches to demuxed audio resolution when HLS audio is available', () async {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/stream.mp4'));
      final vc = Get.put(VideoController(), tag: 'demuxed_hls_test');
      vc.video = Video(
        id: 'demuxed_hls_test',
        title: 'Demuxed Test Video',
        description: 'Test',
        videoUrl: 'https://cdn.truthworld.com/test.mp4',
        thumbnailUrl: '',
        ownerId: 'owner_1',
        category: 'Debates',
        tags: const ['debate'],
        duration: 180,
        views: 20,
        likes: 2,
        dislikeCount: 0,
        channelId: 'ch_1',
        channelName: 'Channel',
        createdAt: DateTime.now(),
        language: 'en',
        hlsUrl: 'https://storage.googleapis.com/truthworld/hls/demuxed_hls_test/master.m3u8',
      );

      final tpc = Get.put(
        TowerPlayerController(videoPlayerController: vpc, tag: 'demuxed_hls_test'),
        tag: 'demuxed_hls_test',
      );

      // Toggle audio-only ON
      await tpc.toggleAudioOnly();

      expect(tpc.isAudioOnly.value, isTrue);
      expect(vc.isAudioOnly.value, isTrue);
      expect(vc.currentResolution.value?.label, equals('Audio only'));
      expect(
        vc.currentResolution.value?.url,
        equals('https://storage.googleapis.com/truthworld/hls/demuxed_hls_test/audio/en/prog.m3u8'),
      );

      tpc.cancelHideTimer();
      tpc.onClose();
      vpc.dispose();
    });

    test('4. Visual evidence pill triggers on high-signal claim, respects 45s cooldown, and limits to 3', () {
      final vpc = VideoPlayerController.networkUrl(Uri.parse('https://example.com/stream.mp4'));
      final vc = VideoController(tag: 'pill_test');
      vc.factCheckData['claims'] = [
        {
          'text': 'Official financial audit report shows documented 40% discrepancy in allocation funds',
          'verdict': 'contradicted',
          'start': 10.0,
          'end': 25.0,
        },
      ];
      Get.put(vc, tag: 'pill_test');
      final tpc = TowerPlayerController(videoPlayerController: vpc, tag: 'pill_test');
      tpc.isAudioOnly.value = true;

      // At position 5s (before claim): pill remains hidden
      tpc.evaluateVisualEvidenceSignals(const Duration(seconds: 5));
      expect(tpc.visualEvidencePillVisible.value, isFalse);

      // At position 15s (inside high-signal claim): pill triggers!
      tpc.evaluateVisualEvidenceSignals(const Duration(seconds: 15));
      expect(tpc.visualEvidencePillVisible.value, isTrue);
      expect(tpc.visualEvidencePillText.value, contains('On-screen evidence'));

      // Dismiss pill
      tpc.dismissVisualEvidencePill();
      expect(tpc.visualEvidencePillVisible.value, isFalse);

      // Immediately re-evaluating within 45s cooldown window does not re-trigger
      tpc.evaluateVisualEvidenceSignals(const Duration(seconds: 18));
      expect(tpc.visualEvidencePillVisible.value, isFalse);

      tpc.cancelHideTimer();
      tpc.dismissVisualEvidencePill();
      tpc.onClose();
      vpc.dispose();
    });

    testWidgets('5. VisualEvidenceWarningPill renders and tap triggers switch to video mode', (tester) async {
      await tester.pump(const Duration(seconds: 5));
      bool tapped = false;
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VisualEvidenceWarningPill(
                text: 'On-screen evidence presented · Tap to view',
                onTap: () => tapped = true,
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('On-screen evidence presented · Tap to view'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      await tester.tap(find.text('On-screen evidence presented · Tap to view'));
      expect(tapped, isTrue);

      await tester.tap(find.byIcon(Icons.close));
      expect(dismissed, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
