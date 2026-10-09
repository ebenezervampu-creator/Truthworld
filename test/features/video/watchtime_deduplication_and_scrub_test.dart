import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/core/utils/watch_time_formatter.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_analytics_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
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
  Stream<VideoEvent> videoEventsFor(int textureId) => const Stream.empty();
  @override
  Widget buildView(int textureId) => const SizedBox();
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

class TestMainController extends MainController {
  final List<Map<String, dynamic>> trackedEvents = [];

  @override
  // ignore: must_call_super
  void onInit() {
    // Pure unit test harness: bypass live Firestore streams and AppStateController
  }

  @override
  Future<bool> trackWatchEvent({
    required String videoId,
    required String eventType,
    required int position,
    required int duration,
    String? channelId,
    int? watchTimeSecondsDelta,
    bool isSubscriber = false,
    bool isNotSubscriber = false,
    String trafficSource = 'direct',
    String? viewerHash,
    String? dedupKey,
  }) async {
    trackedEvents.add({
      'videoId': videoId,
      'eventType': eventType,
      'position': position,
      'duration': duration,
      'watchTimeSecondsDelta': watchTimeSecondsDelta,
      'isSubscriber': isSubscriber,
      'isNotSubscriber': isNotSubscriber,
      'trafficSource': trafficSource,
      'viewerHash': viewerHash,
      'dedupKey': dedupKey,
    });
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
    await setupMockFirebase();
  });

  late TestMainController mockMainCtrl;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    try {
      GetStorage().erase();
    } catch (_) {}
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
    if (!Get.isRegistered<WatchHistoryService>()) {
      Get.put<WatchHistoryService>(WatchHistoryService(), permanent: true);
    }
    mockMainCtrl = Get.put<MainController>(TestMainController(), permanent: true) as TestMainController;
  });

  tearDown(Get.reset);

  group('Transparent Watchtime & Deduplication Suite', () {
    final sampleVideo = Video.fromMap({
      'title': 'Transparent Watchtime Video',
      'channelId': 'chan_tw_001',
      'channelName': 'TruthWorld Transparency',
      'videoUrl': 'https://cdn.truthworld.in/video/vid_truth_100/master.mp4',
      'duration': 100,
      'viewCount': 10,
    }, 'vid_truth_100');

    test('1. WatchHistoryService accurately manages isVideoFullyWatched status', () {
      final watchHistory = WatchHistoryService.to;
      const testVid = 'vid_history_check';

      // Initially not watched
      expect(watchHistory.isVideoFullyWatched(testVid), isFalse);

      // Save intermediate progress (e.g. 45% watched)
      watchHistory.saveLocalPosition(testVid, 45, 45.0);
      expect(watchHistory.isVideoFullyWatched(testVid), isFalse);

      // Save near-completion progress (92% watched)
      watchHistory.saveLocalPosition(testVid, 92, 92.0);
      expect(watchHistory.isVideoFullyWatched(testVid), isTrue);

      // Explicitly mark fully watched
      const testVid2 = 'vid_history_check_2';
      expect(watchHistory.isVideoFullyWatched(testVid2), isFalse);
      watchHistory.markVideoFullyWatched(testVid2);
      expect(watchHistory.isVideoFullyWatched(testVid2), isTrue);
    });

    test('2. VideoAnalyticsController does NOT trigger milestones or qualified views when dragging slider to end', () {
      final analyticsCtrl = Get.put(VideoAnalyticsController());
      const testVid = 'vid_scrub_test';
      const durationSeconds = 120.0;

      // Simulated scenario: user opened video and immediately scrubbed to 119s / 120s
      // watchTimeSeconds is 0 (or negligible, e.g. 1 second of actual playback)
      expect(analyticsCtrl.watchTimeSeconds, equals(0));

      analyticsCtrl.trackPlaybackPosition(testVid, 119.0, durationSeconds);

      // Verify that qualified view is NOT counted
      expect(analyticsCtrl.hasCountedQualifiedView, isFalse);

      // Verify that milestones (25%, 50%, 75%, 100%) did NOT fire based on playhead position
      expect(analyticsCtrl.firedMilestones, isEmpty);

      // Now simulate true genuine playback: 35 seconds of real elapsed watch time
      analyticsCtrl.testWatchTimeSeconds = 35;
      analyticsCtrl.trackPlaybackPosition(testVid, 35.0, durationSeconds);

      // 35s >= 30s threshold -> qualified view is now legitimately counted!
      expect(analyticsCtrl.hasCountedQualifiedView, isTrue);

      // actualWatchPct = (35 / 120 * 100) = 29.16% >= 25% threshold -> milestone 25 fires
      expect(analyticsCtrl.firedMilestones.contains('${testVid}_25'), isTrue);
      // But 50%, 75%, 100% must NOT fire yet
      expect(analyticsCtrl.firedMilestones.contains('${testVid}_50'), isFalse);
      expect(analyticsCtrl.firedMilestones.contains('${testVid}_75'), isFalse);
      expect(analyticsCtrl.firedMilestones.contains('${testVid}_100'), isFalse);
    });

    test('3. Repeat view deduplication: already watched video suppresses watch pings and deltas', () async {
      final controller = VideoController();
      controller.video = sampleVideo;

      // Mark this video as already fully watched by this user
      WatchHistoryService.to.markVideoFullyWatched(sampleVideo.id);

      // Verify isAlreadyWatchedVideo resolves to true
      expect(controller.isAlreadyWatchedVideo, isTrue);

      // Flush remaining watch time should exit early and NEVER emit a ping
      controller.flushRemainingWatchTime();
      expect(mockMainCtrl.trackedEvents.where((e) => e['eventType'] == 'watch_ping'), isEmpty);

      // Direct pingWatchEvent must be rejected
      await controller.pingWatchEvent('watch_ping', 50, 100, 20);
      expect(mockMainCtrl.trackedEvents.where((e) => e['eventType'] == 'watch_ping'), isEmpty);

      // Milestone event must send delta = 0 for already watched video
      await controller.fireMilestoneEvent('milestone_50', 50, 100);
      final milestoneEvents = mockMainCtrl.trackedEvents.where((e) => e['eventType'] == 'milestone_50').toList();
      expect(milestoneEvents, isNotEmpty);
      expect(milestoneEvents.first['watchTimeSecondsDelta'], equals(0));
    });

    test('4. Dragging to end in handleVideoCompletion does NOT mark video as completed without true watch time', () {
      final scrubVideo = Video.fromMap({
        'title': 'Scrub Drag Video',
        'channelId': 'chan_tw_002',
        'channelName': 'TruthWorld Transparency',
        'videoUrl': 'https://cdn.truthworld.in/video/vid_truth_scrub_4/master.mp4',
        'duration': 100,
        'viewCount': 5,
      }, 'vid_truth_scrub_4');

      final controller = VideoController();
      controller.video = scrubVideo;

      expect(controller.isAlreadyWatched, isFalse);
      expect(WatchHistoryService.to.isVideoFullyWatched(scrubVideo.id), isFalse);

      // Simulate player state where playhead reached end (100s / 100s)
      const endValue = VideoPlayerValue(
        duration: Duration(seconds: 100),
        position: Duration(seconds: 100),
        isPlaying: true,
      );

      // But the user only spent 0 seconds watching (dragged slider across)
      expect(controller.watchStopwatch.elapsed.inSeconds, equals(0));

      controller.handleVideoCompletion(endValue);

      // Transparent rule: Must NOT be marked as already watched because actual elapsed watch time < 85%
      expect(controller.isAlreadyWatched, isFalse);
      expect(WatchHistoryService.to.isVideoFullyWatched(scrubVideo.id), isFalse);
    });

    test('5. Single user viewing multiple sessions cannot exceed video duration watch time (328s / 5m 28s)', () async {
      final videoUnder6Min = Video.fromMap({
        'title': 'Mahonathuda song by Raj prakash paul worship conference',
        'channelId': 'chan_raj_001',
        'channelName': 'Raj Prakash Paul',
        'videoUrl': 'https://cdn.truthworld.in/video/vid_mahonathuda_328/master.mp4',
        'duration': '05:28',
        'durationSeconds': 328,
        'viewCount': 1,
      }, 'vid_mahonathuda_328');

      expect(videoUnder6Min.durationSeconds, equals(328));

      // Session 1: User watches 200 seconds (first session)
      final session1Ctrl = VideoController();
      session1Ctrl.video = videoUnder6Min;

      await session1Ctrl.pingWatchEvent('watch_ping', 200, 328, 200);

      expect(WatchHistoryService.to.getCumulativeWatchSeconds('vid_mahonathuda_328'), equals(200));
      expect(mockMainCtrl.trackedEvents.last['watchTimeSecondsDelta'], equals(200));

      // Session 2: User watches another 200 seconds in a separate playback session
      final session2Ctrl = VideoController();
      session2Ctrl.video = videoUnder6Min;

      // Only remaining 128 seconds allowed (328 - 200) before reaching duration ceiling!
      await session2Ctrl.pingWatchEvent('watch_ping', 200, 328, 200);

      expect(WatchHistoryService.to.getCumulativeWatchSeconds('vid_mahonathuda_328'), equals(328));
      // Delta MUST be clamped to 128s, NEVER 200s!
      expect(mockMainCtrl.trackedEvents.last['watchTimeSecondsDelta'], equals(128));

      // Video is now fully watched!
      expect(WatchHistoryService.to.isVideoFullyWatched('vid_mahonathuda_328', totalDuration: 328), isTrue);

      // Session 3: User tries to watch yet again
      final session3Ctrl = VideoController();
      session3Ctrl.video = videoUnder6Min;
      expect(session3Ctrl.isAlreadyWatchedVideo, isTrue);

      final eventCountBefore = mockMainCtrl.trackedEvents.length;
      await session3Ctrl.pingWatchEvent('watch_ping', 100, 328, 100);
      // No ping event emitted!
      expect(mockMainCtrl.trackedEvents.length, equals(eventCountBefore));
    });

    test('6. Video parser & UI metrics self-heal corrupted watch times beyond duration ceiling', () {
      // 1 view, duration 05:28 (328s), but corrupted totalWatchTimeSeconds in Firestore is 428s (7 mins)
      final parsed = Video.fromMap({
        'title': 'Corrupted Watchtime Video',
        'duration': '05:28',
        'durationSeconds': 328,
        'viewCount': 1,
        'totalWatchTimeSeconds': 428,
      }, 'vid_corrupted');

      // Epistemic ceiling clamps totalWatchTimeSeconds to 328s (5 mins), NEVER 428s (7 mins)
      expect(parsed.totalWatchTimeSeconds, equals(328));
      expect(WatchTimeFormatter.format(parsed.totalWatchTimeSeconds), equals('5 mins'));
    });
  });
}
