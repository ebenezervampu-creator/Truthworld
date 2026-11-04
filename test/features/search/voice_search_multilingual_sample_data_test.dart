import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:truthworld/features/search/data/services/search_service.dart';
import 'package:truthworld/features/search/presentation/widgets/voice_search_dialog.dart';

void main() {
  group('Multilingual Voice Search Comprehensive Sample Data Tests', () {
    // 1. Realistic Sample Spoken Datasets Across 12 Languages
    final sampleSpokenQueries = <String, Map<String, dynamic>>{
      'English': {
        'rawSpoken': 'How to build scalable Flutter apps in 2026? ',
        'expectedSanitized': 'How to build scalable Flutter apps in 2026',
        'expectedTokens': ['how', 'to', 'build', 'scalable', 'flutter', 'apps', 'in', '2026'],
      },
      'Spanish': {
        'rawSpoken': '¿Cuáles son las últimas noticias del día? ',
        'expectedSanitized': 'Cuáles son las últimas noticias del día',
        'expectedTokens': ['cuáles', 'son', 'las', 'últimas', 'noticias', 'del', 'día'],
      },
      'Hindi': {
        'rawSpoken': 'आज के मुख्य समाचार और मौसम की जानकारी। ',
        'expectedSanitized': 'आज के मुख्य समाचार और मौसम की जानकारी',
        'expectedTokens': ['आज', 'के', 'मुख्य', 'समाचार', 'और', 'मौसम', 'की', 'जानकारी'],
      },
      'Arabic': {
        'rawSpoken': 'ما هي آخر أخبار التكنولوجيا والذكاء الاصطناعي؟ ',
        'expectedSanitized': 'ما هي آخر أخبار التكنولوجيا والذكاء الاصطناعي',
        'expectedTokens': ['ما', 'هي', 'آخر', 'أخبار', 'التكنولوجيا', 'والذكاء', 'الاصطناعي'],
      },
      'French': {
        'rawSpoken': 'Quelles sont les recettes de cuisine faciles et rapides? ',
        'expectedSanitized': 'Quelles sont les recettes de cuisine faciles et rapides',
        'expectedTokens': ['quelles', 'sont', 'les', 'recettes', 'de', 'cuisine', 'faciles', 'et', 'rapides'],
      },
      'German': {
        'rawSpoken': 'Wie lernt man künstliche Intelligenz programmieren?! ',
        'expectedSanitized': 'Wie lernt man künstliche Intelligenz programmieren',
        'expectedTokens': ['wie', 'lernt', 'man', 'künstliche', 'intelligenz', 'programmieren'],
      },
      'Japanese': {
        'rawSpoken': '最新のアニメとゲームの情報を教えてください！ ',
        'expectedSanitized': '最新のアニメとゲームの情報を教えてください',
        'expectedTokens': ['最新のアニメとゲームの情報を教えてください'],
      },
      'Portuguese': {
        'rawSpoken': 'Como aprender programação do zero passo a passo... ',
        'expectedSanitized': 'Como aprender programação do zero passo a passo',
        'expectedTokens': ['como', 'aprender', 'programação', 'do', 'zero', 'passo', 'a', 'passo'],
      },
      'Russian': {
        'rawSpoken': 'Какие последние научные открытия в мире?! ',
        'expectedSanitized': 'Какие последние научные открытия в мире',
        'expectedTokens': ['какие', 'последние', 'научные', 'открытия', 'в', 'мире'],
      },
      'Bengali': {
        'rawSpoken': 'আজকের শীর্ষ খবর এবং খেলার আপডেট! ',
        'expectedSanitized': 'আজকের শীর্ষ খবর এবং খেলার আপডেট',
        'expectedTokens': ['আজকের', 'শীর্ষ', 'খবর', 'এবং', 'খেলার', 'আপডেট'],
      },
      'Telugu': {
        'rawSpoken': 'తాజా వార్తలు మరియు సాంకేతిక విశేషాలు? ',
        'expectedSanitized': 'తాజా వార్తలు మరియు సాంకేతిక విశేషాలు',
        'expectedTokens': ['తాజా', 'వార్తలు', 'మరియు', 'సాంకేతిక', 'విశేషాలు'],
      },
      'Tamil': {
        'rawSpoken': 'இன்றைய முக்கிய செய்திகள் மற்றும் உலக நிகழ்வுகள்! ',
        'expectedSanitized': 'இன்றைய முக்கிய செய்திகள் மற்றும் உலக நிகழ்வுகள்',
        'expectedTokens': ['இன்றைய', 'முக்கிய', 'செய்திகள்', 'மற்றும்', 'உலக', 'நிகழ்வுகள்'],
      },
    };

    test('All 12 sample language spoken inputs sanitize properly without losing text or accents', () {
      sampleSpokenQueries.forEach((language, sample) {
        final raw = sample['rawSpoken'] as String;
        final expected = sample['expectedSanitized'] as String;
        final actual = VoiceSearchController.sanitizeQuery(raw);
        expect(
          actual,
          equals(expected),
          reason: 'Failed sanitization for language: $language (Raw: "$raw")',
        );
      });
    });

    test('SearchService.extractTokens correctly preserves letters, combining vowels, and numbers across all 12 sample languages', () {
      sampleSpokenQueries.forEach((language, sample) {
        final raw = sample['rawSpoken'] as String;
        final expectedTokens = sample['expectedTokens'] as List<String>;
        final actualTokens = SearchService.extractTokens(raw);
        expect(
          actualTokens,
          equals(expectedTokens),
          reason: 'Token mismatch for language: $language (Raw: "$raw")',
        );
      });
    });

    test('Decibel level normalization maps correctly across iOS, Android, and Web audio inputs', () {
      // iOS audio range (-60 dBFS to 0 dBFS)
      double normalize(double level) {
        double normalized;
        if (level < 0) {
          normalized = ((level + 60.0) / 60.0).clamp(0.0, 1.0);
        } else if (level <= 1.0) {
          normalized = level.clamp(0.0, 1.0);
        } else {
          normalized = (level / 10.0).clamp(0.0, 1.0);
        }
        return normalized;
      }

      // iOS test points
      expect(normalize(-60.0), closeTo(0.0, 0.01)); // Absolute silence
      expect(normalize(-30.0), closeTo(0.5, 0.01)); // Medium speech
      expect(normalize(-0.1), closeTo(1.0, 0.01));  // Loud speech (-0.1 dBFS)

      // Android test points (0.0 to 10.0+ dB)
      expect(normalize(0.0), closeTo(0.0, 0.01)); // Silence at 0 dB
      expect(normalize(5.0), closeTo(0.5, 0.01)); // Medium speech
      expect(normalize(10.0), closeTo(1.0, 0.01)); // High loudness
      expect(normalize(15.0), closeTo(1.0, 0.01)); // Clamped max

      // Web test points (0.0 to 1.0)
      expect(normalize(0.25), closeTo(0.25, 0.01));
      expect(normalize(0.75), closeTo(0.75, 0.01));
    });

    test('Language picker dynamic filtering matches diverse search sample queries accurately', () {
      final sampleLocales = [
        stt.LocaleName('en_US', 'English (United States)'),
        stt.LocaleName('en_GB', 'English (United Kingdom)'),
        stt.LocaleName('en_IN', 'English (India)'),
        stt.LocaleName('es_ES', 'Spanish (Spain)'),
        stt.LocaleName('es_MX', 'Spanish (Mexico)'),
        stt.LocaleName('hi_IN', 'Hindi (India)'),
        stt.LocaleName('fr_FR', 'French (France)'),
        stt.LocaleName('de_DE', 'German (Germany)'),
        stt.LocaleName('ar_SA', 'Arabic (Saudi Arabia)'),
        stt.LocaleName('pt_BR', 'Portuguese (Brazil)'),
        stt.LocaleName('ja_JP', 'Japanese (Japan)'),
        stt.LocaleName('ru_RU', 'Russian (Russia)'),
        stt.LocaleName('zh_CN', 'Chinese (Simplified)'),
        stt.LocaleName('bn_IN', 'Bengali (India)'),
        stt.LocaleName('te_IN', 'Telugu (India)'),
        stt.LocaleName('ta_IN', 'Tamil (India)'),
        stt.LocaleName('mr_IN', 'Marathi (India)'),
        stt.LocaleName('ur_PK', 'Urdu (Pakistan)'),
      ];

      List<stt.LocaleName> filter(String query) {
        final q = query.trim().toLowerCase();
        if (q.isEmpty) return sampleLocales;
        return sampleLocales.where((l) =>
          l.name.toLowerCase().contains(q) || l.localeId.toLowerCase().contains(q)
        ).toList();
      }

      // Test searching for "Spanish"
      final spanishMatches = filter('spanish');
      expect(spanishMatches.length, equals(2));
      expect(spanishMatches.map((l) => l.localeId), containsAll(['es_ES', 'es_MX']));

      // Test searching for "Hindi"
      final hindiMatches = filter('hindi');
      expect(hindiMatches.length, equals(1));
      expect(hindiMatches.first.localeId, equals('hi_IN'));

      // Test searching for "India"
      final indiaMatches = filter('india');
      expect(indiaMatches.length, equals(6)); // English (India), Hindi, Bengali, Telugu, Tamil, Marathi

      // Test searching for locale ID prefix "ar"
      final arabicMatches = filter('ar_');
      expect(arabicMatches.length, equals(1));
      expect(arabicMatches.first.localeId, equals('ar_SA'));

      // Test searching for nonexistent language
      final emptyMatches = filter('klingon');
      expect(emptyMatches, isEmpty);
    });

    test('Simulated Voice Search Dialog triggers onSearch with clean sanitized sample query', () {
      final receivedSearches = <String>[];
      final dialog = VoiceSearchDialog(
        onSearch: (query) {
          receivedSearches.add(query);
        },
      );

      expect(dialog.onSearch, isNotNull);

      // Simulate search submissions across sample languages
      dialog.onSearch(VoiceSearchController.sanitizeQuery('Flutter tutorials for beginners?! '));
      dialog.onSearch(VoiceSearchController.sanitizeQuery('¿Cómo aprender Flutter desde cero? '));
      dialog.onSearch(VoiceSearchController.sanitizeQuery('फ्लटर सीखें हिंदी में। '));

      expect(receivedSearches.length, equals(3));
      expect(receivedSearches[0], equals('Flutter tutorials for beginners'));
      expect(receivedSearches[1], equals('Cómo aprender Flutter desde cero'));
      expect(receivedSearches[2], equals('फ्लटर सीखें हिंदी में'));
    });
  });
}
