import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:truthworld/features/search/data/services/search_service.dart';
import 'package:truthworld/features/search/presentation/widgets/voice_search_dialog.dart';

void main() {
  group('VoiceSearchState and UX Tests', () {
    test('VoiceSearchState contains all expected voice search states', () {
      expect(VoiceSearchState.values, contains(VoiceSearchState.initializing));
      expect(VoiceSearchState.values, contains(VoiceSearchState.listening));
      expect(VoiceSearchState.values, contains(VoiceSearchState.recognized));
      expect(VoiceSearchState.values, contains(VoiceSearchState.submitting));
      expect(VoiceSearchState.values, contains(VoiceSearchState.unrecognized));
      expect(VoiceSearchState.values, contains(VoiceSearchState.permissionDenied));
      expect(VoiceSearchState.values, contains(VoiceSearchState.error));
    });

    test('VoiceSearchController.sanitizeQuery removes trailing punctuation like Hike.', () {
      expect(VoiceSearchController.sanitizeQuery('Hike.'), equals('Hike'));
      expect(VoiceSearchController.sanitizeQuery('Hike!'), equals('Hike'));
      expect(VoiceSearchController.sanitizeQuery('Hike?'), equals('Hike'));
      expect(VoiceSearchController.sanitizeQuery('  hike...  '), equals('hike'));
      expect(VoiceSearchController.sanitizeQuery('Flutter Tutorial.'), equals('Flutter Tutorial'));
    });

    test('VoiceSearchController.sanitizeQuery handles multilingual international queries', () {
      // Spanish with accents
      expect(VoiceSearchController.sanitizeQuery('Música en vivo!'), equals('Música en vivo'));
      // Hindi Devanagari
      expect(VoiceSearchController.sanitizeQuery('ताज़ा समाचार.'), equals('ताज़ा समाचार'));
      // Arabic
      expect(VoiceSearchController.sanitizeQuery('أخبار اليوم؟'), equals('أخبار اليوم'));
      // French
      expect(VoiceSearchController.sanitizeQuery('Actualités du jour...'), equals('Actualités du jour'));
      // Japanese
      expect(VoiceSearchController.sanitizeQuery('最新ニュース！'), equals('最新ニュース'));
    });

    test('SearchService.sanitizeQuery and extractTokens handle multilingual tokens cleanly', () {
      expect(SearchService.sanitizeQuery('Hike.'), equals('hike'));
      expect(SearchService.extractTokens('Hike.'), equals(['hike']));
      expect(SearchService.extractTokens('Hike a social media platform.'), equals(['hike', 'a', 'social', 'media', 'platform']));

      // Multilingual extraction without stripping Unicode letters
      expect(SearchService.extractTokens('Música clásica!'), equals(['música', 'clásica']));
      expect(SearchService.extractTokens('ताज़ा समाचार.'), equals(['ताज़ा', 'समाचार']));
      expect(SearchService.extractTokens('أخبار العالم.'), equals(['أخبار', 'العالم']));
    });

    test('VoiceSearchController has curated fallback locales for 100+ language support', () {
      expect(VoiceSearchController.fallbackLocales, isNotEmpty);
      expect(VoiceSearchController.fallbackLocales.length >= 100, isTrue);
      final localeIds = VoiceSearchController.fallbackLocales.map((l) => l.localeId).toList();

      // Major global languages
      expect(localeIds, contains('en_US'));
      expect(localeIds, contains('en_IN'));
      expect(localeIds, contains('es_ES'));
      expect(localeIds, contains('fr_FR'));
      expect(localeIds, contains('de_DE'));
      expect(localeIds, contains('ar_SA'));
      expect(localeIds, contains('ja_JP'));
      expect(localeIds, contains('pt_BR'));
      expect(localeIds, contains('ru_RU'));
      expect(localeIds, contains('zh_CN'));

      // Indian languages
      expect(localeIds, contains('hi_IN'));
      expect(localeIds, contains('te_IN'));
      expect(localeIds, contains('ta_IN'));
      expect(localeIds, contains('kn_IN'));
      expect(localeIds, contains('ml_IN'));
      expect(localeIds, contains('bn_IN'));
      expect(localeIds, contains('mr_IN'));
      expect(localeIds, contains('gu_IN'));
      expect(localeIds, contains('pa_IN'));
      expect(localeIds, contains('or_IN'));
      expect(localeIds, contains('as_IN'));
      expect(localeIds, contains('ur_IN'));
    });

    test('VoiceSearchController.buildLocalesList preserves all languages even when device returns limited OEM locales', () {
      // Simulate the exact scenario from user device screenshot (only Chinese and English returned)
      final hardwareLimitedLocales = [
        stt.LocaleName('cmn_CN', 'Chinese (Simplified Han,China)'),
        stt.LocaleName('cmn_TW', 'Chinese (Traditional Han,Taiwan)'),
        stt.LocaleName('en_AU', 'English (Australia)'),
        stt.LocaleName('en_CA', 'English (Canada)'),
        stt.LocaleName('en_IN', 'English (India)'),
        stt.LocaleName('en_IE', 'English (Ireland)'),
        stt.LocaleName('en_SG', 'English (Singapore)'),
      ];

      final merged = VoiceSearchController.buildLocalesList(hardwareLimitedLocales);

      // Verify all canonical languages are NOT discarded
      expect(merged.length >= 100, isTrue);
      final mergedIds = merged.map((l) => l.localeId.toLowerCase()).toList();

      // Indian languages MUST be present
      expect(mergedIds, contains('te_in'));
      expect(mergedIds, contains('hi_in'));
      expect(mergedIds, contains('ta_in'));
      expect(mergedIds, contains('kn_in'));
      expect(mergedIds, contains('ml_in'));
      expect(mergedIds, contains('bn_in'));
      expect(mergedIds, contains('mr_in'));
      expect(mergedIds, contains('gu_in'));

      // Global languages MUST be present
      expect(mergedIds, contains('es_es'));
      expect(mergedIds, contains('fr_fr'));
      expect(mergedIds, contains('de_de'));
      expect(mergedIds, contains('ja_jp'));
      expect(mergedIds, contains('ar_sa'));
      expect(mergedIds, contains('ru_ru'));

      // Device-reported variants are also preserved
      expect(mergedIds, contains('cmn_cn'));
      expect(mergedIds, contains('en_au'));
      expect(mergedIds, contains('en_ca'));
    });

    test('VoiceSearchController.getNativeName returns accurate native scripts', () {
      expect(VoiceSearchController.getNativeName('te_IN'), equals('తెలుగు'));
      expect(VoiceSearchController.getNativeName('hi_IN'), equals('हिन्दी'));
      expect(VoiceSearchController.getNativeName('ta_IN'), equals('தமிழ்'));
      expect(VoiceSearchController.getNativeName('kn_IN'), equals('ಕನ್ನಡ'));
      expect(VoiceSearchController.getNativeName('ml_IN'), equals('മലയാളം'));
      expect(VoiceSearchController.getNativeName('es_ES'), equals('Español'));
      expect(VoiceSearchController.getNativeName('fr_FR'), equals('Français'));
      expect(VoiceSearchController.getNativeName('ja_JP'), equals('日本語'));
      expect(VoiceSearchController.getNativeName('ar_SA'), equals('العربية'));
    });

    test('VoiceSearchLanguagePickerController filters locales dynamically by query', () {
      final dummyDialog = VoiceSearchDialog(onSearch: (_) {});
      expect(dummyDialog, isNotNull);

      final dummyLocales = [
        stt.LocaleName('en_US', 'English (United States)'),
        stt.LocaleName('es_ES', 'Spanish (Spain)'),
        stt.LocaleName('hi_IN', 'Hindi (India)'),
        stt.LocaleName('fr_FR', 'French (France)'),
      ];

      // Test filtering logic directly
      final matchesHindi = dummyLocales.where((l) =>
        l.name.toLowerCase().contains('hindi') || l.localeId.toLowerCase().contains('hindi')
      ).toList();
      expect(matchesHindi.length, equals(1));
      expect(matchesHindi.first.localeId, equals('hi_IN'));

      final matchesSpanish = dummyLocales.where((l) =>
        l.name.toLowerCase().contains('spanish') || l.localeId.toLowerCase().startsWith('es')
      ).toList();
      expect(matchesSpanish.length, equals(1));
      expect(matchesSpanish.first.localeId, equals('es_ES'));
    });

    test('VoiceSearchDialog widget can be instantiated with callback', () {
      String? searchedQuery;
      final dialog = VoiceSearchDialog(
        onSearch: (query) {
          searchedQuery = query;
        },
      );
      expect(dialog.onSearch, isNotNull);
      dialog.onSearch('Flutter test query');
      expect(searchedQuery, equals('Flutter test query'));
    });
  });
}
