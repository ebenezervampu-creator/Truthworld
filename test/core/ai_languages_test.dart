import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/constants/ai_languages.dart';

void main() {
  group('AI Languages Registry Verification', () {
    test('contains 135+ total languages across all regions', () {
      expect(kAllAILanguages.length, greaterThanOrEqualTo(135));
    });

    test('covers 70+ ElevenLabs dubbing languages', () {
      expect(kElevenLabsDubbingLanguages.length, greaterThanOrEqualTo(70));
      for (final lang in kElevenLabsDubbingLanguages) {
        expect(lang.supportsDubbing, isTrue, reason: '${lang.name} should support dubbing');
      }
    });

    test('covers all Google Cloud Translation API subtitle languages', () {
      expect(kGoogleCloudTranslationLanguages.length, greaterThanOrEqualTo(135));
      for (final lang in kGoogleCloudTranslationLanguages) {
        expect(lang.supportsSubtitles, isTrue, reason: '${lang.name} should support subtitles');
      }
    });

    test('Indian languages catalog contains all 23 official/constitutional languages', () {
      final indianLangs = kAllAILanguages.where((l) => l.region == 'Indian').toList();
      expect(indianLangs.length, 23);
      final codes = indianLangs.map((l) => l.code).toSet();
      expect(codes.contains('te'), isTrue); // Telugu
      expect(codes.contains('hi'), isTrue); // Hindi
      expect(codes.contains('ta'), isTrue); // Tamil
      expect(codes.contains('kn'), isTrue); // Kannada
      expect(codes.contains('ml'), isTrue); // Malayalam
      expect(codes.contains('bn'), isTrue); // Bengali
      expect(codes.contains('mr'), isTrue); // Marathi
      expect(codes.contains('gu'), isTrue); // Gujarati
      expect(codes.contains('pa'), isTrue); // Punjabi
      expect(codes.contains('or'), isTrue); // Odia
      expect(codes.contains('as'), isTrue); // Assamese
      expect(codes.contains('ur'), isTrue); // Urdu
      expect(codes.contains('ne'), isTrue); // Nepali
      expect(codes.contains('sa'), isTrue); // Sanskrit
    });

    test('helper functions resolve languages and dubbing capability accurately', () {
      expect(isDubbingSupported('te'), isTrue);
      expect(isDubbingSupported('es'), isTrue);
      expect(isDubbingSupported('haw'), isFalse); // Hawaiian: subs only

      expect(isSubtitleSupported('te'), isTrue);
      expect(isSubtitleSupported('haw'), isTrue);
      expect(isSubtitleSupported('chr'), isTrue);

      final telugu = getAILanguageByCode('te');
      expect(telugu?.name, 'Telugu');
      expect(telugu?.native, 'తెలుగు');
      expect(telugu?.supportsDubbing, isTrue);
      expect(telugu?.supportsSubtitles, isTrue);
    });
  });
}
