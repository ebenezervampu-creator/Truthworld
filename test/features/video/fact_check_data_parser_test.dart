import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/fact_check_data_parser.dart';
import 'package:truthworld/theme/app_theme.dart';

void main() {
  group('FactCheckDataParser', () {
    test('parses empty or null data to ParsedFactCheckData.empty', () {
      final parsedNull = FactCheckDataParser.parse(null);
      expect(parsedNull.isEmpty, isTrue);
      expect(parsedNull.trustScore, isNull);
      expect(parsedNull.claims, isEmpty);
      expect(parsedNull.sources, isEmpty);

      final parsedEmpty = FactCheckDataParser.parse({});
      expect(parsedEmpty.isEmpty, isTrue);
    });

    test('resolves fallback trust score correctly', () {
      final parsed = FactCheckDataParser.parse(
        null,
        fallbackTrustScore: 4.2,
        isVideoFactChecked: true,
      );
      expect(parsed.isEmpty, isFalse);
      expect(parsed.trustScore, 4.2);
      expect(parsed.normalizedScore, 84.0);
      expect(parsed.analysisState, 'VERIFIED');
      expect(parsed.scoreAvailable, isTrue);
    });

    test('resolves trustScore field variants and computes normalized score', () {
      final p1 = FactCheckDataParser.parse({'trustScore': 92});
      expect(p1.trustScore, 92.0);
      expect(p1.normalizedScore, 92.0);

      final p2 = FactCheckDataParser.parse({'trustIndex': 3.5});
      expect(p2.trustScore, 3.5);
      expect(p2.normalizedScore, 70.0);

      final p3 = FactCheckDataParser.parse({'videoRating': 4.8});
      expect(p3.trustScore, 4.8);
      expect(p3.normalizedScore, 96.0);
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
        'trustScore': 65,
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
      expect(parsed.trustScore, 4.5);
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
      expect(parsed.trustScore, 84.0);
      expect(parsed.viewerNote, 'Fast triage: Core claims verified with OCR tickers.');
      expect(parsed.claims.length, 1);
      expect(parsed.verifiedCount, 1);
    });
  });
}
