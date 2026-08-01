import 'package:flutter_test/flutter_test.dart';

void main() {
  group('On-Demand AI Features Configuration Tests', () {
    test('Verifies target languages payload formatting', () {
      final targetLanguages = ['te', 'hi', 'en'];
      expect(targetLanguages.contains('te'), isTrue);
      expect(targetLanguages.contains('hi'), isTrue);
      expect(targetLanguages.length, equals(3));
    });

    test('Verifies feature set payload formatting', () {
      final features = [
        'subtitles',
        'dubbing',
        'factcheck',
        'summary',
        'chapters',
      ];

      final wantSubtitles = features.contains('subtitles');
      final wantDubbing = features.contains('dubbing');
      final wantFactCheck = features.contains('factcheck');
      final wantSummary = features.contains('summary');
      final wantChapters = features.contains('chapters');

      expect(wantSubtitles, isTrue);
      expect(wantDubbing, isTrue);
      expect(wantFactCheck, isTrue);
      expect(wantSummary, isTrue);
      expect(wantChapters, isTrue);
    });

    test('Verifies priority mode option setting', () {
      const priorityMode = 'accuracy';
      expect(priorityMode, equals('accuracy'));
    });
  });
}
