import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('Subtitles Duplicate Prevention & Language Code Normalization Tests', () {
    test('normalizeLanguageCode normalizes locale codes and language names to canonical ISO codes', () {
      expect(normalizeLanguageCode('en_us'), 'en');
      expect(normalizeLanguageCode('en_US'), 'en');
      expect(normalizeLanguageCode('en-US'), 'en');
      expect(normalizeLanguageCode('en-GB'), 'en');
      expect(normalizeLanguageCode('English'), 'en');
      expect(normalizeLanguageCode('english'), 'en');
      expect(normalizeLanguageCode('ar'), 'ar');
      expect(normalizeLanguageCode('Arabic'), 'ar');
      expect(normalizeLanguageCode('es_ES'), 'es');
      expect(normalizeLanguageCode('es-MX'), 'es');
      expect(normalizeLanguageCode('te'), 'te');
      expect(normalizeLanguageCode('hi'), 'hi');
    });

    test('getLanguageName resolves both canonical codes and locale codes properly', () {
      final controller = Get.put(SubtitlesController());
      // Test plain English name resolution
      expect(controller.getLanguageName('en'), 'English');
      expect(controller.getLanguageName('en_us'), 'English');
      expect(controller.getLanguageName('en_US'), 'English');
      expect(controller.getLanguageName('en-US'), 'English');

      // Test includeNative = true for UI display
      expect(controller.getLanguageName('ar', includeNative: true), 'Arabic (العربية)');
      expect(controller.getLanguageName('es', includeNative: true), 'Spanish (Español)');
    });

    test('Video with en_us language does not produce duplicate English tracks', () {
      final video = Video.empty().copyWith(
        id: 'test_video_1',
        title: 'jesus clips',
        description: 'Test clip',
        language: 'en_us',
        languages: const ['English', 'ar'],
        mediaSubtitles: const {'en': 'https://storage.googleapis.com/test/en.vtt'},
      );

      final controller = Get.put(SubtitlesController());

      // Simulate the logic in SubtitlesListSection:
      final baseLang = normalizeLanguageCode(video.language);
      final orderedLanguages = <String>[];
      orderedLanguages.add(baseLang);

      for (final lang in controller.availableLanguages) {
        final l = normalizeLanguageCode(lang);
        if (!orderedLanguages.contains(l)) {
          orderedLanguages.add(l);
        }
      }

      for (final lang in video.mediaSubtitles.keys) {
        final l = normalizeLanguageCode(lang);
        if (!orderedLanguages.contains(l)) {
          orderedLanguages.add(l);
        }
      }

      for (final lang in video.languages) {
        final code = normalizeLanguageCode(lang);
        if (!orderedLanguages.contains(code)) {
          orderedLanguages.add(code);
        }
      }

      // Assert: Exactly 2 languages ('en' and 'ar'), with NO duplicate English!
      expect(orderedLanguages.length, 2);
      expect(orderedLanguages, ['en', 'ar']);
      expect(orderedLanguages.where((l) => l == 'en' || l == 'en_us').length, 1);

      // Verify that hasSubtitles detects the subtitle under canonical 'en' even if queried by en_us or en
      final subs = video.mediaSubtitles;
      bool checkSubtitles(String langCode) {
        final normCode = normalizeLanguageCode(langCode);
        return (subs.containsKey(langCode) && (subs[langCode]?.isNotEmpty ?? false)) ||
            (subs.containsKey(normCode) && (subs[normCode]?.isNotEmpty ?? false));
      }

      expect(checkSubtitles('en'), isTrue);
      expect(checkSubtitles('en_us'), isTrue);
      expect(checkSubtitles('ar'), isFalse);
    });
  });
}
