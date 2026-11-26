import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/constants/ai_languages.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_language.dart';

void main() {
  group('DubbingLanguage supported lists', () {
    test('availableSourceLanguages only contains supported source languages', () {
      final sources = DubbingLanguage.availableSourceLanguages;
      expect(sources, isNotEmpty);
      expect(
        sources.map((l) => l.code).toSet(),
        equals(kDubbingLaunchSourceCodes),
      );
      expect(sources.every((l) => l.isAvailableAsSource), isTrue);
    });

    test('availableTargetLanguages only contains supported output languages', () {
      final targets = DubbingLanguage.availableTargetLanguages;
      expect(targets, isNotEmpty);
      expect(
        targets.map((l) => l.code).toSet(),
        equals(kDubbingLaunchTargetCodes),
      );
      expect(targets.every((l) => l.isAvailableAsTarget), isTrue);
    });

    test('source32Languages contains all 32 AssemblyAI Universal 3.7 Pro languages with only English live', () {
      const expected32Codes = {
        'af', 'ar', 'yue', 'ca', 'da', 'nl', 'en', 'et', 'fi', 'fr', 'gl', 'de',
        'he', 'hi', 'it', 'ja', 'ko', 'zh', 'mr', 'no', 'nn', 'fa', 'pt', 'ro',
        'ru', 'es', 'sv', 'tr', 'ur', 'vi', 'xh', 'zu',
      };
      const sources = DubbingLanguage.source32Languages;
      expect(sources.length, 32);
      expect(sources.map((l) => l.code).toSet(), equals(expected32Codes));
      expect(sources.where((l) => l.isAvailableAsSource).map((l) => l.code).toList(), ['en']);
      expect(sources.any((l) => l.isNotPlannedAsSource), isFalse);
    });

    test('supportedLanguages has 80 languages starting with 5 live then 75 remaining from global and Indic', () {
      const targets = DubbingLanguage.supportedLanguages;
      expect(targets.length, 80);
      expect(
        targets.take(5).map((l) => l.code).toList(),
        ['te', 'hi', 'mr', 'ta', 'ml'],
      );
      expect(targets.take(5).every((l) => l.isAvailableAsTarget), isTrue);
      expect(targets.skip(5).length, 75);
      expect(targets.skip(5).any((l) => l.isAvailableAsTarget), isFalse);
      expect(targets[5].code, 'en');
    });
  });
}
