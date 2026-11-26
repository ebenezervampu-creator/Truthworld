import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    try {
      final box = GetStorage();
      box.erase();
    } catch (_) {}
  });

  tearDown(() {
    Get.reset();
  });

  group('YouTube Playback Parity - Completed Video & Resume Logic', () {
    test('1. Fully watched video returns resume position 0 (starts from beginning)', () {
      final service = WatchHistoryService();
      const videoId = 'vid_completed_1';
      const totalDur = 300; // 5 minutes

      // Simulate video completed: user watched to 298s (99.3%)
      service.markVideoFullyWatched(videoId);

      expect(service.isVideoFullyWatched(videoId, totalDuration: totalDur), isTrue);
      expect(service.getProgress(videoId), equals(100.0));
      // YouTube parity: Completed video must ALWAYS resume from 0 (start over)
      expect(service.getLastPosition(videoId, totalDuration: totalDur), equals(0));
      expect(service.getResumePosition(videoId, totalDuration: totalDur), equals(0));
    });

    test('2. Near-end watch progress (within last 10s or >=90%) returns resume position 0', () {
      final service = WatchHistoryService();
      const videoId = 'vid_near_end_2';
      const totalDur = 200; // 200 seconds

      // Save position at 195s (within last 10s of 200s video)
      service.saveLocalPosition(videoId, 195, 97.5, totalDuration: totalDur);

      // Visual progress bar should reflect completion / near-end
      expect(service.getProgress(videoId), equals(100.0));
      // Resume playback position must be 0 to prevent instant completion on re-tap
      expect(service.getLastPosition(videoId, totalDuration: totalDur), equals(0));
    });

    test('3. Near-start watch progress (< 5s) returns resume position 0 (no micro-resume)', () {
      final service = WatchHistoryService();
      const videoId = 'vid_near_start_3';
      const totalDur = 300;

      // Save position at 3s (micro-progress)
      service.saveLocalPosition(videoId, 3, 1.0, totalDuration: totalDur);

      expect(service.getLastPosition(videoId, totalDuration: totalDur), equals(0));
    });

    test('4. Mid-video watch progress (e.g. 50%) returns exact position for resume', () {
      final service = WatchHistoryService();
      const videoId = 'vid_mid_4';
      const totalDur = 300;

      // Save position at 150s (50%)
      service.saveLocalPosition(videoId, 150, 50.0, totalDuration: totalDur);

      expect(service.getProgress(videoId), equals(50.0));
      expect(service.getLastPosition(videoId, totalDuration: totalDur), equals(150));
      expect(service.getResumePosition(videoId, totalDuration: totalDur), equals(150));
    });

    test('5. resetResumePosition resets playback position to 0 while keeping 100% progress', () {
      final service = WatchHistoryService();
      const videoId = 'vid_reset_5';
      const totalDur = 180;

      service.saveLocalPosition(videoId, 90, 50.0, totalDuration: totalDur);
      expect(service.getLastPosition(videoId, totalDuration: totalDur), equals(90));

      // User completes video or clicks 'Start Over'
      service.markVideoFullyWatched(videoId);
      service.resetResumePosition(videoId);

      expect(service.getLastPosition(videoId, totalDuration: totalDur), equals(0));
      expect(service.getProgress(videoId), equals(100.0));
    });

    test('6. VideoPlaybackHandoff clearResumePosition cleanly removes registered position', () {
      const videoId = 'vid_handoff_6';
      VideoPlaybackHandoff.registerResumePosition(videoId, const Duration(seconds: 140));
      expect(VideoPlaybackHandoff.peekPosition(videoId), equals(const Duration(seconds: 140)));

      VideoPlaybackHandoff.clearResumePosition(videoId);
      expect(VideoPlaybackHandoff.peekPosition(videoId), isNull);
    });
  });
}
