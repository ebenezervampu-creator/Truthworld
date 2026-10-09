import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/video_transcript_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoTranscriptController Loading & Infinite Loop Guard Tests', () {
    late VideoTranscriptController controller;

    setUp(() {
      controller = VideoTranscriptController();
    });

    tearDown(() {
      controller.onClose();
    });

    test('initial state has hasAttemptedTranscriptFetch as false and empty segments', () {
      expect(controller.hasAttemptedTranscriptFetch.value, isFalse);
      expect(controller.isLoadingTranscript.value, isFalse);
      expect(controller.transcriptSegments, isEmpty);
    });

    test('resetForVideo resets hasAttemptedTranscriptFetch and segments on new videoId', () {
      controller.currentVideoId = 'vid_old';
      controller.hasAttemptedTranscriptFetch.value = true;
      controller.transcriptSegments.add(
        const SubtitleSegment(
          start: Duration.zero,
          end: Duration(seconds: 5),
          text: 'Worship conference segment',
        ),
      );

      controller.resetForVideo('vid_new');

      expect(controller.currentVideoId, equals('vid_new'));
      expect(controller.hasAttemptedTranscriptFetch.value, isFalse);
      expect(controller.transcriptSegments, isEmpty);
    });

    test('resetForVideo preserves state if called with identical videoId', () {
      controller.currentVideoId = 'vid_same';
      controller.hasAttemptedTranscriptFetch.value = true;
      controller.transcriptSegments.add(
        const SubtitleSegment(
          start: Duration.zero,
          end: Duration(seconds: 5),
          text: 'Preserved segment',
        ),
      );

      controller.resetForVideo('vid_same');

      expect(controller.currentVideoId, equals('vid_same'));
      expect(controller.hasAttemptedTranscriptFetch.value, isTrue);
      expect(controller.transcriptSegments.length, equals(1));
    });

    test('findSegmentIndexForPosition locates correct segment index accurately', () {
      controller.transcriptSegments.assignAll([
        const SubtitleSegment(start: Duration.zero, end: Duration(seconds: 10), text: 'Line 1'),
        const SubtitleSegment(start: Duration(seconds: 12), end: Duration(seconds: 20), text: 'Line 2'),
        const SubtitleSegment(start: Duration(seconds: 25), end: Duration(seconds: 35), text: 'Line 3'),
      ]);

      // Exact match inside Line 1
      expect(controller.findSegmentIndexForPosition(const Duration(seconds: 5)), equals(0));
      // In gap between Line 1 and Line 2 -> nearest prior line is Line 1 (idx 0)
      expect(controller.findSegmentIndexForPosition(const Duration(seconds: 11)), equals(0));
      // Exact match inside Line 2
      expect(controller.findSegmentIndexForPosition(const Duration(seconds: 15)), equals(1));
      // In gap between Line 2 and Line 3 -> nearest prior line is Line 2 (idx 1)
      expect(controller.findSegmentIndexForPosition(const Duration(seconds: 22)), equals(1));
      // Inside Line 3
      expect(controller.findSegmentIndexForPosition(const Duration(seconds: 30)), equals(2));
    });
  });
}
