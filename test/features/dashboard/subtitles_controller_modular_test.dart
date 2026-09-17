import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  tearDown(Get.reset);

  group('SubtitlesController Modular Components Tests', () {
    test('SubtitleCue model instantiation, copyWith, and properties', () {
      final cue = SubtitleCue(
        id: 'cue_1',
        startTime: '00:00:01.000',
        endTime: '00:00:04.000',
        text: 'Welcome to TruthWorld',
      );

      expect(cue.id, 'cue_1');
      expect(cue.startTime, '00:00:01.000');
      expect(cue.endTime, '00:00:04.000');
      expect(cue.text, 'Welcome to TruthWorld');

      final copied = cue.copyWith(text: 'Updated line text');
      expect(copied.id, 'cue_1');
      expect(copied.startTime, '00:00:01.000');
      expect(copied.text, 'Updated line text');
      expect(copied.toString(), contains('Updated line text'));
    });

    test('Timecode duration formatting and time shifting utilities', () {
      expect(
        SubtitlesController.formatDurationToTimecode(
          const Duration(hours: 1, minutes: 23, seconds: 45, milliseconds: 678),
        ),
        '01:23:45.678',
      );

      expect(
        SubtitlesController.formatDurationToTimecode(
          const Duration(seconds: 5, milliseconds: 12),
        ),
        '00:00:05.012',
      );

      final controller = Get.put(SubtitlesController());
      final shiftedForward = controller.shiftTimeString('00:00:05.000', 2500);
      expect(shiftedForward, '00:00:07.500');

      final shiftedBackward = controller.shiftTimeString('00:00:05.000', -2000);
      expect(shiftedBackward, '00:00:03.000');
    });

    test('Language name resolver maps codes to human readable names', () {
      final controller = Get.put(SubtitlesController());
      expect(controller.getLanguageName('en'), 'English');
      expect(controller.getLanguageName('es'), 'Spanish');
      expect(controller.getLanguageName('ta'), 'Tamil');
      expect(controller.getLanguageName('hi'), 'Hindi');
    });

    test('Cue manipulation: add, duplicate, update, shift, delete and sort', () {
      final controller = Get.put(SubtitlesController());
      controller.currentCues.clear();

      controller.addNewCue();
      expect(controller.currentCues.length, 1);
      expect(controller.hasUnsavedChanges.value, isTrue);

      controller.updateCueText(0, 'First subtitle line');
      expect(controller.currentCues.first.text, 'First subtitle line');

      controller.duplicateCue(0);
      expect(controller.currentCues.length, 2);
      expect(controller.currentCues[1].text, 'First subtitle line');

      // Shift cues
      controller.shiftAllCues(1000);
      expect(controller.currentCues.first.startTime, '00:00:01.000');

      // Replace text
      final replacedCount = controller.replaceTextInCues('First', 'Premier');
      expect(replacedCount, 2);
      expect(controller.currentCues.first.text, contains('Premier'));

      // Sort
      controller.sortCuesChronologically();
      expect(controller.currentCues.length, 2);

      // Delete
      controller.deleteCue(1);
      expect(controller.currentCues.length, 1);

      // Clear all
      controller.clearAllCues();
      expect(controller.currentCues.isEmpty, isTrue);
    });

    test('SRT export compilation formatting matches SubRip spec', () {
      final controller = Get.put(SubtitlesController());
      final cues = [
        SubtitleCue(
          id: '1',
          startTime: '00:00:01.000',
          endTime: '00:00:03.500',
          text: 'Line 1 of subtitles',
        ),
        SubtitleCue(
          id: '2',
          startTime: '00:00:04.000',
          endTime: '00:00:07.250',
          text: 'Line 2 of subtitles',
        ),
      ];

      final srt = controller.compileSrtContent(cues);
      expect(srt, contains('1\n00:00:01,000 --> 00:00:03,500\nLine 1 of subtitles'));
      expect(srt, contains('2\n00:00:04,000 --> 00:00:07,250\nLine 2 of subtitles'));
    });

    test('Cues search filter filters segments by text and timestamp', () {
      final controller = Get.put(SubtitlesController());
      controller.currentCues.value = [
        SubtitleCue(
          id: '1',
          startTime: '00:00:01.000',
          endTime: '00:00:04.000',
          text: 'Introduction to artificial intelligence',
        ),
        SubtitleCue(
          id: '2',
          startTime: '00:00:05.000',
          endTime: '00:00:09.000',
          text: 'Deep learning neural networks',
        ),
      ];

      controller.setCueSearchQuery('intelligence');
      expect(controller.filteredCues.length, 1);
      expect(controller.filteredCues.first.id, '1');

      controller.setCueSearchQuery('00:00:05');
      expect(controller.filteredCues.length, 1);
      expect(controller.filteredCues.first.id, '2');

      controller.setCueSearchQuery('');
      expect(controller.filteredCues.length, 2);
    });
  });
}
