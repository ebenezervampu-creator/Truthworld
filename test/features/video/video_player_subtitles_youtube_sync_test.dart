import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_transcript_controller.dart';
import 'package:truthworld/features/video/presentation/services/sleep_timer_service.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  Duration currentPosition = Duration.zero;

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
  Future<void> seekTo(int textureId, Duration position) async {
    currentPosition = position;
  }
  @override
  Future<Duration> getPosition(int textureId) async => currentPosition;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlayerPlatform fakePlatform;

  setUpAll(() async {
    fakePlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    Get.put<ConnectivityService>(FakeConnectivityService());
    Get.put(SleepTimerService());
  });

  tearDown(() {
    Get.reset();
  });

  group('YouTube-Parity Subtitle & Transcription Video Player Synchronization Tests', () {
    const sampleVideoId = 'sample_video_youtube_sync';

    final sampleSegments = [
      const SubtitleSegment(
        start: Duration(seconds: 1),
        end: Duration(seconds: 4),
        text: "Welcome to TruthWorld's fact checking network.",
      ),
      const SubtitleSegment(
        start: Duration(seconds: 4, milliseconds: 100),
        end: Duration(seconds: 7),
        text: 'Today we inspect the claims made in this speech.',
      ),
      const SubtitleSegment(
        start: Duration(seconds: 8),
        end: Duration(seconds: 12),
        text: 'The empirical data conclusively demonstrates accuracy.',
      ),
      const SubtitleSegment(
        start: Duration(seconds: 15),
        end: Duration(seconds: 20),
        text: 'Every citizen deserves transparent verification.',
      ),
    ];

    test('1. Playing video updates subtitles and transcription line with frame-perfect sync', () {
      final vpc = VideoPlayerController.networkUrl(
        Uri.parse('https://cdn.example.org/videos/sample.mp4'),
      );
      vpc.value = vpc.value.copyWith(
        isInitialized: true,
        duration: const Duration(seconds: 30),
      );

      final playerCtrl = TowerPlayerController(
        videoPlayerController: vpc,
        tag: sampleVideoId,
      );
      Get.put(playerCtrl, tag: sampleVideoId);

      final transcriptCtrl = VideoTranscriptController();
      transcriptCtrl.transcriptSegments.assignAll(sampleSegments);
      playerCtrl.subtitleSegments.assignAll(sampleSegments);

      // Turn on subtitles
      playerCtrl.setSubtitles(enabled: true);
      expect(playerCtrl.subtitlesEnabled.value, isTrue);

      // Position: 00:02 -> inside Segment 0
      playerCtrl.syncActiveSubtitle(overridePos: const Duration(seconds: 2));
      expect(
        playerCtrl.currentSubtitle.value,
        equals("Welcome to TruthWorld's fact checking network."),
      );
      expect(playerCtrl.activeSubtitleSegment.value, equals(sampleSegments[0]));

      transcriptCtrl.syncToCurrentPosition(const Duration(seconds: 2));
      expect(transcriptCtrl.activeSegmentIndex.value, equals(0));

      // Advance position: 00:05 -> inside Segment 1
      playerCtrl.syncActiveSubtitle(overridePos: const Duration(seconds: 5));
      expect(
        playerCtrl.currentSubtitle.value,
        equals('Today we inspect the claims made in this speech.'),
      );
      expect(playerCtrl.activeSubtitleSegment.value, equals(sampleSegments[1]));

      transcriptCtrl.syncToCurrentPosition(const Duration(seconds: 5));
      expect(transcriptCtrl.activeSegmentIndex.value, equals(1));

      // Clean up
      playerCtrl.onClose();
    });

    test('2. Instantaneous seeking (seekTo) updates subtitle cue and transcript line immediately with zero lag', () async {
      final vpc = VideoPlayerController.networkUrl(
        Uri.parse('https://cdn.example.org/videos/sample.mp4'),
      );
      vpc.value = vpc.value.copyWith(
        isInitialized: true,
        duration: const Duration(seconds: 30),
      );

      final playerCtrl = TowerPlayerController(
        videoPlayerController: vpc,
        tag: sampleVideoId,
      );
      Get.put(playerCtrl, tag: sampleVideoId);

      final transcriptCtrl = VideoTranscriptController();
      transcriptCtrl.transcriptSegments.assignAll(sampleSegments);
      playerCtrl.subtitleSegments.assignAll(sampleSegments);
      playerCtrl.setSubtitles(enabled: true);

      // Seek to 00:16 (Segment 3)
      await playerCtrl.seekTo(const Duration(seconds: 16));

      expect(
        playerCtrl.currentSubtitle.value,
        equals('Every citizen deserves transparent verification.'),
      );
      expect(playerCtrl.activeSubtitleSegment.value, equals(sampleSegments[3]));

      transcriptCtrl.syncToCurrentPosition(const Duration(seconds: 16));
      expect(transcriptCtrl.activeSegmentIndex.value, equals(3));

      playerCtrl.onClose();
    });

    test('3. Timeline scrubbing (onScrubUpdate) updates subtitle overlay dynamically while dragging', () {
      final vpc = VideoPlayerController.networkUrl(
        Uri.parse('https://cdn.example.org/videos/sample.mp4'),
      );
      // Video duration = 30 seconds
      vpc.value = vpc.value.copyWith(
        isInitialized: true,
        duration: const Duration(seconds: 30),
      );

      final playerCtrl = TowerPlayerController(
        videoPlayerController: vpc,
        tag: sampleVideoId,
      );
      Get.put(playerCtrl, tag: sampleVideoId);

      playerCtrl.subtitleSegments.assignAll(sampleSegments);
      playerCtrl.setSubtitles(enabled: true);

      // User drags scrub bar to 30% of 30s = 9.0s (Segment 2: "The empirical data...")
      playerCtrl.onScrubUpdate(0.30, const Duration(seconds: 30));

      expect(playerCtrl.scrubPosition.value.inSeconds, equals(9));
      expect(
        playerCtrl.currentSubtitle.value,
        equals('The empirical data conclusively demonstrates accuracy.'),
      );
      expect(playerCtrl.activeSubtitleSegment.value, equals(sampleSegments[2]));

      // User scrubs further to 55% of 30s = 16.5s (Segment 3)
      playerCtrl.onScrubUpdate(0.55, const Duration(seconds: 30));
      expect(
        playerCtrl.currentSubtitle.value,
        equals('Every citizen deserves transparent verification.'),
      );

      playerCtrl.onClose();
    });

    test('4. CC Button toggle enables captions from available transcripts when tracks are not predefined', () {
      final vpc = VideoPlayerController.networkUrl(
        Uri.parse('https://cdn.example.org/videos/sample.mp4'),
      );
      final playerCtrl = TowerPlayerController(
        videoPlayerController: vpc,
        tag: sampleVideoId,
      );
      Get.put(playerCtrl, tag: sampleVideoId);

      // Initially no external subtitleTracks loaded, but transcript segments exist
      expect(playerCtrl.subtitleTracks.isEmpty, isTrue);
      playerCtrl.subtitleSegments.assignAll(sampleSegments);

      // Tapping CC Button
      playerCtrl.setSubtitles(enabled: true);
      expect(playerCtrl.subtitlesEnabled.value, isTrue);
      expect(playerCtrl.activeSubLang.value, equals('Auto'));

      // Subtitle syncs immediately
      playerCtrl.syncActiveSubtitle(overridePos: const Duration(seconds: 10));
      expect(
        playerCtrl.currentSubtitle.value,
        equals('The empirical data conclusively demonstrates accuracy.'),
      );

      // Toggling CC Off
      playerCtrl.setSubtitles(enabled: false);
      expect(playerCtrl.subtitlesEnabled.value, isFalse);
      expect(playerCtrl.activeSubLang.value, equals('Off'));
      expect(playerCtrl.currentSubtitle.value, isEmpty);
      expect(playerCtrl.activeSubtitleSegment.value, isNull);

      playerCtrl.onClose();
    });

    test('5. Overlay transcript user scroll and auto-scroll resumption (YouTube-parity)', () {
      final vpc = VideoPlayerController.networkUrl(
        Uri.parse('https://cdn.example.org/videos/sample.mp4'),
      );
      final playerCtrl = TowerPlayerController(
        videoPlayerController: vpc,
        tag: sampleVideoId,
      );
      Get.put(playerCtrl, tag: sampleVideoId);

      expect(playerCtrl.isOverlayTranscriptAutoScroll.value, isTrue);

      // User scrolls transcript to read ahead
      playerCtrl.onOverlayTranscriptUserScrolled();
      expect(playerCtrl.isOverlayTranscriptAutoScroll.value, isFalse);

      // User taps any segment or explicitly resumes
      playerCtrl.resumeOverlayTranscriptAutoScroll();
      expect(playerCtrl.isOverlayTranscriptAutoScroll.value, isTrue);

      playerCtrl.onClose();
    });

    test('6. Telugu subtitles playback and audio clock anticipation sync', () {
      final vpc = VideoPlayerController.networkUrl(
        Uri.parse('https://cdn.example.org/videos/jio_ipo_telugu.mp4'),
      );
      vpc.value = vpc.value.copyWith(
        isInitialized: true,
        duration: const Duration(seconds: 30),
      );

      final playerCtrl = TowerPlayerController(
        videoPlayerController: vpc,
        tag: 'jio_ipo_telugu',
      );
      Get.put(playerCtrl, tag: 'jio_ipo_telugu');

      const teluguSegments = [
        SubtitleSegment(
          start: Duration(seconds: 10, milliseconds: 200),
          end: Duration(seconds: 13, milliseconds: 800),
          text: 'వివరాలు ఆ రికార్డు స్థాయి నెంబర్ల',
        ),
        SubtitleSegment(
          start: Duration(seconds: 14, milliseconds: 200),
          end: Duration(seconds: 18, milliseconds: 500),
          text: 'ఈ తేదీలను ఒక్కసారి గమనిస్తే బిడ్డింగ్',
        ),
        SubtitleSegment(
          start: Duration(seconds: 19),
          end: Duration(seconds: 23, milliseconds: 400),
          text: 'అక్షరాల కేవలం కొద్ది రోజుల వ్యవధిలోనే',
        ),
      ];

      playerCtrl.subtitleSegments.assignAll(teluguSegments);
      playerCtrl.setSubtitles(enabled: true, track: const SubtitleTrack(label: 'Telugu', langCode: 'te', url: 'https://cdn.example.org/subtitles/te.srt'));
      expect(playerCtrl.subtitlesEnabled.value, isTrue);
      expect(playerCtrl.activeSubLang.value, equals('Telugu'));

      // Real-time playback position check with audio lead anticipation
      fakePlatform.currentPosition = const Duration(seconds: 11);
      vpc.value = vpc.value.copyWith(position: const Duration(seconds: 11));
      playerCtrl.syncActiveSubtitle();
      expect(playerCtrl.currentSubtitle.value, equals('వివరాలు ఆ రికార్డు స్థాయి నెంబర్ల'));

      // Advance to second cue
      fakePlatform.currentPosition = const Duration(seconds: 15);
      vpc.value = vpc.value.copyWith(position: const Duration(seconds: 15));
      playerCtrl.syncActiveSubtitle();
      expect(playerCtrl.currentSubtitle.value, equals('ఈ తేదీలను ఒక్కసారి గమనిస్తే బిడ్డింగ్'));

      playerCtrl.onClose();
    });
  });
}
