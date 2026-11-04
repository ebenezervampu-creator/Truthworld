import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_localization.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/fact_check/fact_check_models_helper.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_helpers.dart';

void main() {
  group('ClaimVerdictLocalization', () {
    test('localizes canonical verdict badge labels across multiple languages', () {
      expect(
        ClaimVerdictLocalization.localizeLabel(
          ClaimVerdictType.verifiedTrue,
          'VERIFIED TRUE',
          'es',
        ),
        'VERIFICADO VERDADERO',
      );

      expect(
        ClaimVerdictLocalization.localizeLabel(
          ClaimVerdictType.verifiedTrue,
          'VERIFIED TRUE',
          'hi',
        ),
        'सत्यापित सत्य',
      );

      expect(
        ClaimVerdictLocalization.localizeLabel(
          ClaimVerdictType.falseClaim,
          'FALSE CLAIM',
          'fr',
        ),
        'ALLÉGATION FAUSSE',
      );

      expect(
        ClaimVerdictLocalization.localizeLabel(
          ClaimVerdictType.misleading,
          'MISLEADING',
          'de',
        ),
        'IRREFÜHREND',
      );

      expect(
        ClaimVerdictLocalization.localizeLabel(
          ClaimVerdictType.disputed,
          'DISPUTED',
          'ja',
        ),
        '異論あり',
      );

      expect(
        ClaimVerdictLocalization.localizeLabel(
          ClaimVerdictType.contextual,
          'CONTEXT NEEDED',
          'te',
        ),
        'సందర్భం అవసరం',
      );
    });

    test('localizes category badges including extended categories', () {
      expect(ClaimVerdictLocalization.localizeCategory('Verified', 'es'), 'Verificado');
      expect(ClaimVerdictLocalization.localizeCategory('Verified', 'hi'), 'सत्यापित');
      expect(ClaimVerdictLocalization.localizeCategory('Caution', 'fr'), 'Attention');
      expect(ClaimVerdictLocalization.localizeCategory('False', 'de'), 'Falsch');
      expect(ClaimVerdictLocalization.localizeCategory('Mostly Verified', 'es'), 'Mayormente Verificado');
      expect(ClaimVerdictLocalization.localizeCategory('Mostly Verified', 'hi'), 'अधिकांशतः सत्यापित');
      expect(ClaimVerdictLocalization.localizeCategory('Partially Verified', 'es'), 'Parcialmente Verificado');
      expect(ClaimVerdictLocalization.localizeCategory('Partially Verified', 'hi'), 'आंशिक रूप से सत्यापित');
      expect(ClaimVerdictLocalization.localizeCategory('Misleading', 'es'), 'Engañoso');
      expect(ClaimVerdictLocalization.localizeCategory('Misleading', 'hi'), 'भ्रामक');
      expect(ClaimVerdictLocalization.localizeCategory('Needs Context', 'es'), 'Requiere Contexto');
      expect(ClaimVerdictLocalization.localizeCategory('Needs Context', 'hi'), 'संदर्भ आवश्यक');
      expect(ClaimVerdictLocalization.localizeCategory('Disputed', 'es'), 'Disputado');
      expect(ClaimVerdictLocalization.localizeCategory('Disputed', 'hi'), 'विवादित');
      expect(ClaimVerdictLocalization.localizeCategory('Opinion', 'es'), 'Opinión');
      expect(ClaimVerdictLocalization.localizeCategory('Opinion', 'hi'), 'राय');
    });

    test('localizes standard takeaways for epistemic verdicts', () {
      final info = ClaimVerdictHelper.resolveVerdictString('true');
      expect(
        info.localizedTakeaway('es'),
        '¡Completamente verdadero! Registros confiables y pruebas del mundo real lo confirman.',
      );
      expect(
        info.localizedTakeaway('hi'),
        'यह पूरी तरह से सच है! विश्वसनीय रिकॉर्ड और वास्तविक दुनिया के सबूत इसकी पुष्टि करते हैं।',
      );

      final falseInfo = ClaimVerdictHelper.resolveVerdictString('false');
      expect(
        falseInfo.localizedTakeaway('es'),
        'Esto es falso. Los hechos reales y los registros oficiales demuestran lo contrario.',
      );
    });

    test('ClaimResult supports localized text and verdict label', () {
      final claim = ClaimResult(
        text: 'The earth has one moon.',
        verdict: 'verified_true',
        localizedTexts: {
          'es': 'La Tierra tiene una luna.',
          'hi': 'पृथ्वी का एक चंद्रमा है।',
        },
      );

      expect(claim.localizedText('es'), 'La Tierra tiene una luna.');
      expect(claim.localizedText('hi'), 'पृथ्वी का एक चंद्रमा है।');
      expect(claim.localizedText('fr'), 'The earth has one moon.'); // fallback
      expect(claim.localizedVerdictLabel('es'), 'VERIFICADO VERDADERO');
      expect(claim.localizedVerdictLabel('hi'), 'सत्यापित सत्य');
    });

    test('ClaimResult fromMap and toMap preserve localizedTexts', () {
      final map = {
        'text': 'Water boils at 100C at sea level.',
        'verdict': 'verified_true',
        'translations': {
          'es': 'El agua hierve a 100°C al nivel del mar.',
          'de': 'Wasser kocht bei 100°C auf Meereshöhe.',
        },
      };

      final claim = ClaimResult.fromMap(map);
      expect(claim.localizedText('es'), 'El agua hierve a 100°C al nivel del mar.');
      expect(claim.localizedText('de'), 'Wasser kocht bei 100°C auf Meereshöhe.');

      final outputMap = claim.toMap();
      expect(outputMap['localizedTexts'], isNotNull);
      expect(outputMap['localizedTexts']['es'], 'El agua hierve a 100°C al nivel del mar.');
    });

    test('VideoChapter supports localized titles and fallback', () {
      final chapter = VideoChapter(
        title: 'Introduction to Solar Panels',
        startTime: Duration.zero,
        localizedTitles: {
          'es': 'Introducción a los paneles solares',
          'hi': 'सौर पैनलों का परिचय',
        },
      );

      expect(chapter.localizedTitle('es'), 'Introducción a los paneles solares');
      expect(chapter.localizedTitle('hi'), 'सौर पैनलों का परिचय');
      expect(chapter.localizedTitle('fr'), 'Introduction to Solar Panels'); // fallback
    });

    test('VideoChapter fromMap parses translations and localizedTitles', () {
      final map = {
        'title': 'Chapter 1: The Discovery',
        'startTimeMs': 30000,
        'translations': {
          'es': 'Capítulo 1: El Descubrimiento',
          'ja': '第1章：発見',
        },
      };

      final chapter = VideoChapter.fromMap(map);
      expect(chapter.localizedTitle('es'), 'Capítulo 1: El Descubrimiento');
      expect(chapter.localizedTitle('ja'), '第1章：発見');
      expect(chapter.localizedTitle('en'), 'Chapter 1: The Discovery');
      expect(chapter.toMap()['localizedTitles']['es'], 'Capítulo 1: El Descubrimiento');
    });

    test('resolveRealClaimDetails leverages cached translations and localized fallback', () {
      Get.reset();
      final langService = Get.put(UserLanguagesService());
      langService.setPrimaryLanguage('es');

      // Case 1: Claim with cached translations
      final claimWithTranslation = {
        'claim': 'India launched 4G in 2012.',
        'verdict': 'false',
        'translations': {
          'es': {
            'claim': 'India lanzó el 4G en 2012.',
            'response': 'India en realidad desplegó el 4G a gran escala con Jio a finales de 2016.',
          },
        },
      };

      final resolved = resolveRealClaimDetails(claimWithTranslation, 0, []);
      expect(resolved.cleanText, 'India lanzó el 4G en 2012.');
      expect(resolved.response, 'India en realidad desplegó el 4G a gran escala con Jio a finales de 2016.');

      // Case 2: Claim without custom reasoning falls back to localized verdict takeaway
      final claimWithoutResponse = {
        'claim': 'Generic unverified assertion.',
        'verdict': 'verified_true',
      };

      final resolvedFallback = resolveRealClaimDetails(claimWithoutResponse, 0, []);
      expect(
        resolvedFallback.response,
        '¡Completamente verdadero! Registros confiables y pruebas del mundo real lo confirman.',
      );

      // Same check with VideoAnalysisHelpers
      final analysisResolved = VideoAnalysisHelpers.resolveRealClaimDetails(
        claimWithoutResponse,
        0,
        [],
      );
      expect(
        analysisResolved.response,
        '¡Completamente verdadero! Registros confiables y pruebas del mundo real lo confirman.',
      );
    });
  });
}
