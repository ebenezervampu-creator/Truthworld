import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/video_transcript_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    Get.testMode = true;
  });

  tearDown(Get.reset);

  group('VideoTranscriptController Exact Position & Sync Tests', () {
    late VideoTranscriptController transcriptCtrl;

    final sampleSegments = [
      const SubtitleSegment(
        start: Duration(seconds: 3),
        end: Duration(seconds: 5),
        text: 'You see the Parthian foot',
      ),
      const SubtitleSegment(
        start: Duration(seconds: 5),
        end: Duration(seconds: 7),
        text: 'races last night?',
      ),
      const SubtitleSegment(
        start: Duration(seconds: 7),
        end: Duration(seconds: 12),
        text: 'Darius ran like a gazelle.',
      ),
      const SubtitleSegment(
        start: Duration(minutes: 2, seconds: 25),
        end: Duration(minutes: 2, seconds: 29),
        text: 'No Jew lives as good',
      ),
      const SubtitleSegment(
        start: Duration(minutes: 2, seconds: 35),
        end: Duration(minutes: 2, seconds: 40),
        text: 'Later line in chosen video',
      ),
    ];

    setUp(() {
      transcriptCtrl = VideoTranscriptController();
      transcriptCtrl.transcriptSegments.assignAll(sampleSegments);
    });

    test('findSegmentIndexForPosition returns exact segment when playing inside bounds', () {
      // 02:27 falls squarely inside [02:25, 02:29] ("No Jew lives as good")
      const currentPos = Duration(minutes: 2, seconds: 27);
      final idx = transcriptCtrl.findSegmentIndexForPosition(currentPos);
      expect(idx, equals(3));
      expect(transcriptCtrl.transcriptSegments[idx].text, equals('No Jew lives as good'));
    });

    test('findSegmentIndexForPosition returns preceding spoken segment during pause/speech gap', () {
      // 02:31 is between [02:25 - 02:29] and [02:35 - 02:40]
      const currentPos = Duration(minutes: 2, seconds: 31);
      final idx = transcriptCtrl.findSegmentIndexForPosition(currentPos);
      // It should still point to the segment that was just spoken (index 3), NOT 0
      expect(idx, equals(3));
      expect(transcriptCtrl.transcriptSegments[idx].text, equals('No Jew lives as good'));
    });

    test('findSegmentIndexForPosition handles beginning of video before first segment', () {
      const currentPos = Duration(seconds: 1);
      final idx = transcriptCtrl.findSegmentIndexForPosition(currentPos);
      expect(idx, equals(0));
      expect(transcriptCtrl.transcriptSegments[idx].text, equals('You see the Parthian foot'));
    });

    test('findSegmentIndexForPosition handles playback beyond last segment', () {
      const currentPos = Duration(minutes: 3, seconds: 10);
      final idx = transcriptCtrl.findSegmentIndexForPosition(currentPos);
      expect(idx, equals(4));
      expect(transcriptCtrl.transcriptSegments[idx].text, equals('Later line in chosen video'));
    });

    test('syncToCurrentPosition updates activeSegmentIndex to exact playing line', () {
      expect(transcriptCtrl.activeSegmentIndex.value, equals(-1));

      // Video playing at 02:27
      const currentPos = Duration(minutes: 2, seconds: 27);
      transcriptCtrl.syncToCurrentPosition(currentPos);

      expect(transcriptCtrl.activeSegmentIndex.value, equals(3));
      expect(
        transcriptCtrl.transcriptSegments[transcriptCtrl.activeSegmentIndex.value].text,
        equals('No Jew lives as good'),
      );
    });

    test('updateActiveSegment with null cue keeps active index using currentPos (speech pause)', () {
      // Set to 02:27
      transcriptCtrl.updateActiveSegment(
        null,
        currentPos: const Duration(minutes: 2, seconds: 27),
      );
      expect(transcriptCtrl.activeSegmentIndex.value, equals(3));

      // If speech pauses (seg == null) at 02:28, active index is NOT cleared to -1
      transcriptCtrl.updateActiveSegment(
        null,
        currentPos: const Duration(minutes: 2, seconds: 28),
      );
      expect(transcriptCtrl.activeSegmentIndex.value, equals(3));
    });

    test('resetForVideo prevents showing old/random video transcript when switching videos', () {
      transcriptCtrl.currentVideoId = 'chosen_ep1';
      expect(transcriptCtrl.transcriptSegments.isNotEmpty, isTrue);

      // New video arrives
      transcriptCtrl.resetForVideo('new_different_video');
      expect(transcriptCtrl.transcriptSegments.isEmpty, isTrue);
      expect(transcriptCtrl.activeSegmentIndex.value, equals(-1));
      expect(transcriptCtrl.isTranscriptVisible.value, isFalse);
    });

    test('resetForVideo retains state when video ID is unchanged', () {
      transcriptCtrl.currentVideoId = 'chosen_ep1';
      transcriptCtrl.activeSegmentIndex.value = 3;
      transcriptCtrl.isTranscriptVisible.value = true;

      transcriptCtrl.resetForVideo('chosen_ep1');
      expect(transcriptCtrl.transcriptSegments.length, equals(5));
      expect(transcriptCtrl.activeSegmentIndex.value, equals(3));
      expect(transcriptCtrl.isTranscriptVisible.value, isTrue);
    });

    test('getSegmentKey returns stable GlobalKey for given index', () {
      final key0 = transcriptCtrl.getSegmentKey(0);
      final key0Again = transcriptCtrl.getSegmentKey(0);
      final key1 = transcriptCtrl.getSegmentKey(1);

      expect(key0, equals(key0Again));
      expect(key0, isNot(equals(key1)));
    });

    test('onUserScrolled pauses auto-scroll and resumes after timeout or resumeAutoScroll', () {
      expect(transcriptCtrl.autoScrollEnabled.value, isTrue);

      transcriptCtrl.onUserScrolled();
      expect(transcriptCtrl.autoScrollEnabled.value, isFalse);

      transcriptCtrl.resumeAutoScroll();
      expect(transcriptCtrl.autoScrollEnabled.value, isTrue);
    });
  });
}
