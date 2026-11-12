import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/fact_check_data_parser.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_helpers.dart';
import 'package:truthworld/theme/app_theme.dart';

void main() {
  group('FactCheckDataParser', () {
    test('parses empty or null data to ParsedFactCheckData.empty', () {
      final parsedNull = FactCheckDataParser.parse(null);
      expect(parsedNull.isEmpty, isTrue);
      expect(parsedNull.claims, isEmpty);
      expect(parsedNull.sources, isEmpty);

      final parsedEmpty = FactCheckDataParser.parse({});
      expect(parsedEmpty.isEmpty, isTrue);
    });

    test('resolves fact checked state when isVideoFactChecked is true', () {
      final parsed = FactCheckDataParser.parse(
        null,
        isVideoFactChecked: true,
      );
      expect(parsed.isEmpty, isFalse);
      expect(parsed.isVideoFactChecked, isTrue);
      expect(parsed.analysisState, 'VERIFIED');
    });

    test('resolves confidence values and tiers', () {
      final p1 = FactCheckDataParser.parse({'confidence': 88});
      expect(p1.confidenceVal, 0.88);

      final p2 = FactCheckDataParser.parse({'confidence': 0.75});
      expect(p2.confidenceVal, 0.75);

      final p3 = FactCheckDataParser.parse({'confidenceTier': 'High'});
      expect(p3.confidenceVal, 0.9);

      final p4 = FactCheckDataParser.parse({'confidenceTier': 'Medium'});
      expect(p4.confidenceVal, 0.6);

      final p5 = FactCheckDataParser.parse({'confidenceTier': 'Low'});
      expect(p5.confidenceVal, 0.4);
    });

    test('counts claims accurately and sets urgency flags', () {
      final data = {
        'claims': [
          {'claim': 'Earth orbits Sun', 'verdict': 'verified_true'},
          {'claim': 'Moon is cheese', 'verdict': 'false_claim'},
          {'claim': 'Martians live underground', 'verdict': 'unverified'},
        ],
      };

      final parsed = FactCheckDataParser.parse(data);
      expect(parsed.claims.length, 3);
      expect(parsed.claimResults.length, 3);
      expect(parsed.verifiedCount, 1);
      expect(parsed.falseCount, 1);
      expect(parsed.cautionCount, 1);
      expect(parsed.isDisputed, isTrue); // falseCount >= verifiedCount
      expect(parsed.needsUrgency, isTrue);
      expect(parsed.urgencyColor, AppColors.error);
    });

    test('parses rich sources and converts strings and maps to UISource', () {
      final data = {
        'sources': [
          'https://reuters.com/news',
          {
            'title': 'AP News Report',
            'url': 'https://apnews.com/article/123',
            'domain': 'apnews.com',
            'trustLevel': 'High',
          },
        ],
      };

      final parsed = FactCheckDataParser.parse(data);
      expect(parsed.sources.length, 2);
      expect(parsed.parsedSources.length, 2);
      expect(parsed.parsedSources[0].url, 'https://reuters.com/news');
      expect(parsed.parsedSources[1].title, 'AP News Report');
      expect(parsed.parsedSources[1].domain, 'apnews.com');
    });

    test('falls back to UIReport when raw map is empty', () {
      final report = UIReport(
        summary: UISummary(
          rating: 4.5,
          label: 'HIGH INTEGRITY',
          confidence: 'high',
          analysisState: 'VERIFIED',
        ),
        quickVerdict: 'Verified',
        narrative: 'Strong corroboration found across all major citations.',
        riskNote: 'Minimal risk',
        positiveDrivers: [],
        negativeDrivers: [],
        sources: [
          UISource(
            title: 'Nature Journal',
            trustLevel: 'High',
            type: 'Primary',
            url: 'https://nature.com/articles/s41586',
          ),
        ],
        conclusion: 'Trustworthy',
        keyClaims: [
          ClaimResult(
            text: 'Key scientific breakthrough corroborated.',
            verdict: 'verified_true',
          ),
        ],
      );

      final parsed = FactCheckDataParser.parse({}, fallbackReport: report);
      expect(parsed.trustLabel, 'HIGH INTEGRITY');
      expect(parsed.viewerNote, 'Strong corroboration found across all major citations.');
      expect(parsed.verifiedCount, 1);
      expect(parsed.parsedSources.length, 1);
    });

    test('parses provisional fast triage data correctly', () {
      final data = {
        'provisionalScore': 84.0,
        'isProvisional': true,
        'provisionalViewerNote': 'Fast triage: Core claims verified with OCR tickers.',
        'provisionalClaims': [
          {'text': 'Inflation dropped 1.2%', 'verdict': 'verified_true'},
        ],
      };

      final parsed = FactCheckDataParser.parse(data);
      expect(parsed.isProvisional, isTrue);
      expect(parsed.viewerNote, 'Fast triage: Core claims verified with OCR tickers.');
      expect(parsed.claims.length, 1);
      expect(parsed.verifiedCount, 1);
    });

    test('extracts claims from keyClaims and aggregates claim sources into parsedSources', () {
      final data = {
        'keyClaims': [
          {
            'text': 'India GDP grew 7.2% in 2023',
            'verdict': 'verified_true',
            'verdictBasis': ['Confirmed by Ministry of Statistics and World Bank records.'],
            'effectiveSources': [
              {
                'title': 'World Bank Report',
                'url': 'https://worldbank.org/india-gdp',
                'trustLevel': 'High',
              },
            ],
          },
          {
            'claim': 'Sun rises in the west',
            'verdict': 'false_claim',
            'whyWrong': 'Contradicted by basic astronomical facts.',
            'sources': [
              {
                'title': 'NASA Astronomy Reference',
                'url': 'https://nasa.gov/sun-orbit',
                'trustLevel': 'High',
              },
            ],
          },
        ],
      };

      final parsed = FactCheckDataParser.parse(data);
      expect(parsed.claims.length, 2);
      expect(parsed.claimResults.length, 2);
      expect(parsed.verifiedCount, 1);
      expect(parsed.falseCount, 1);

      // Verify AI reasoning was extracted
      expect(parsed.claims[0]['response'], contains('Ministry of Statistics'));
      expect(parsed.claims[1]['response'], contains('astronomical facts'));

      // Verify sources were aggregated at top level from claims because data['sources'] was empty
      expect(parsed.sources.length, 2);
      expect(parsed.parsedSources.length, 2);
      expect(parsed.parsedSources[0].title, 'World Bank Report');
      expect(parsed.parsedSources[0].url, 'https://worldbank.org/india-gdp');
      expect(parsed.parsedSources[1].title, 'NASA Astronomy Reference');
      expect(parsed.parsedSources[1].url, 'https://nasa.gov/sun-orbit');
    });

    test('resolveRealClaimDetails properly resolves clean text, AI reasoning, and tapable sources', () {
      final claim = {
        'text': '??  Electric vehicle adoption doubled in 2023',
        'verdict': 'verified_true',
        'verdictBasis': [
          'Verified through official vehicle registration portal and industry reports.',
        ],
        'effectiveSources': [
          {
            'title': 'Ministry of Road Transport',
            'url': 'https://morth.nic.in/ev-stats',
            'trustLevel': 'High',
          },
        ],
      };

      final resolved = VideoAnalysisHelpers.resolveRealClaimDetails(claim, 0, []);
      expect(resolved.cleanText, 'Electric vehicle adoption doubled in 2023');
      expect(resolved.response, contains('official vehicle registration'));
      expect(resolved.sources.length, 1);
      expect(resolved.sources[0]['title'], 'Ministry of Road Transport');
      expect(resolved.sources[0]['url'], 'https://morth.nic.in/ev-stats');
    });

    test('parses factCheckTier and resolves helper getters correctly', () {
      // Default standard
      final defaultParsed = FactCheckDataParser.parse({});
      expect(defaultParsed.factCheckTier, 'standard');
      expect(defaultParsed.isStandardTier, isTrue);
      expect(defaultParsed.isShortOverview, isFalse);
      expect(defaultParsed.isFullGround, isFalse);
      expect(defaultParsed.tierBadgeLabel, 'VERIFIED FACT-CHECK');

      // Short tier
      final shortParsed = FactCheckDataParser.parse({'factCheckTier': 'short'});
      expect(shortParsed.factCheckTier, 'short');
      expect(shortParsed.isShortOverview, isTrue);
      expect(shortParsed.isStandardTier, isFalse);
      expect(shortParsed.isFullGround, isFalse);
      expect(shortParsed.tierBadgeLabel, 'SHORT FACT-CHECK • OVERVIEW');

      // Full Ground tier
      final fullGroundParsed = FactCheckDataParser.parse({'factCheckTier': 'full_ground'});
      expect(fullGroundParsed.factCheckTier, 'full_ground');
      expect(fullGroundParsed.isFullGround, isTrue);
      expect(fullGroundParsed.isStandardTier, isFalse);
      expect(fullGroundParsed.isShortOverview, isFalse);
      expect(fullGroundParsed.tierBadgeLabel, 'FULL GROUND FACT-CHECK • ALL CLAIMS VERIFIED');

      // Nested in aiFeatures
      final nestedParsed = FactCheckDataParser.parse({
        'aiFeatures': {'factCheckTier': 'short'},
      });
      expect(nestedParsed.factCheckTier, 'short');
      expect(nestedParsed.isShortOverview, isTrue);
    });

    test('parses conclusion with sources from map and string formats', () {
      // 1. Structured conclusion map with dedicated sources
      final structuredData = {
        'conclusion': {
          'label': 'Supported',
          'text': 'The video findings are rigorously supported by independent peer reviews.',
          'confidence': 0.94,
          'sources': [
            {
              'title': 'Nature Journal of Climate Science',
              'url': 'https://nature.com/articles/s41558',
              'domain': 'nature.com',
              'trustLevel': 'High',
              'type': 'Primary',
            },
            {
              'title': 'NOAA Global Climate Report',
              'url': 'https://noaa.gov/climate/2024',
              'domain': 'noaa.gov',
              'trustLevel': 'High',
              'type': 'Primary',
            },
          ],
        },
      };

      final parsedStructured = FactCheckDataParser.parse(structuredData);
      expect(parsedStructured.conclusion, 'The video findings are rigorously supported by independent peer reviews.');
      expect(parsedStructured.conclusionSources.length, 2);
      expect(parsedStructured.conclusionSources[0].title, 'Nature Journal of Climate Science');
      expect(parsedStructured.conclusionSources[0].domain, 'nature.com');
      expect(parsedStructured.conclusionSources[1].title, 'NOAA Global Climate Report');
      expect(parsedStructured.conclusionSources[1].domain, 'noaa.gov');

      // 2. String conclusion with explicit conclusionSources
      final stringData = {
        'conclusion': 'Empirical verification completed across global databases.',
        'conclusionSources': [
          {
            'title': 'World Health Organization',
            'url': 'https://who.int/report',
            'domain': 'who.int',
            'trustLevel': 'High',
          },
        ],
      };

      final parsedString = FactCheckDataParser.parse(stringData);
      expect(parsedString.conclusion, 'Empirical verification completed across global databases.');
      expect(parsedString.conclusionSources.length, 1);
      expect(parsedString.conclusionSources[0].title, 'World Health Organization');
      expect(parsedString.conclusionSources[0].domain, 'who.int');
    });
  });
}
