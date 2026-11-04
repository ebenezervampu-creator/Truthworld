import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';

void main() {
  group('ScoringFactors', () {
    test('fromMap and toMap round-trip', () {
      final map = {
        'accuracy': 0.9,
        'evidence': 0.8,
        'consensus': 0.7,
        'consistency': 0.6,
        'integrity': 0.5,
        'expertise': 0.4,
        'freshness': 0.3,
        'safety': 0.2,
      };

      final factors = ScoringFactors.fromMap(map);
      expect(factors.accuracy, 0.9);
      expect(factors.evidence, 0.8);
      expect(factors.consensus, 0.7);
      expect(factors.consistency, 0.6);
      expect(factors.integrity, 0.5);
      expect(factors.expertise, 0.4);
      expect(factors.freshness, 0.3);
      expect(factors.safety, 0.2);

      expect(factors.toMap(), equals(map));
    });

    test('default values when keys missing', () {
      final factors = ScoringFactors.fromMap({});
      expect(factors.accuracy, 0.0);
      expect(factors.evidence, 0.0);
      expect(factors.consensus, 0.0);
      expect(factors.consistency, 0.0);
      expect(factors.integrity, 0.0);
      expect(factors.expertise, 0.0);
      expect(factors.freshness, 0.0);
      expect(factors.safety, 0.0);
    });
  });

  group('ClaimResult', () {
    test('timestamp formats and large values (>100000)', () {
      final formats = [
        {'startMs': 5000, 'endMs': 10000},
        {'startTimeMs': 5000, 'endTimeMs': 10000},
        {'timestampStart': 5.0, 'timestampEnd': 10.0},
        {'startTime': 5, 'endTime': 10},
      ];

      for (final format in formats) {
        final claim = ClaimResult.fromMap(format);
        expect(claim.start, equals(5.0), reason: 'Failed on format $format');
        expect(claim.end, equals(10.0), reason: 'Failed on format $format');
      }

      final largeClaim = ClaimResult.fromMap({'start': 105000, 'end': 110000});
      expect(largeClaim.start, 105.0);
      expect(largeClaim.end, 110.0);
    });

    test('verdict and text field name fallbacks', () {
      final textFallbacks = ['text', 'claim', 'statement', 'cleanText'];
      final verdictFallbacks = ['verdict', 'status', 'verificationStatus'];

      for (final tFallback in textFallbacks) {
        final claim = ClaimResult.fromMap({tFallback: 'My Claim'});
        expect(claim.text, 'My Claim');
      }

      for (final vFallback in verdictFallbacks) {
        final claim = ClaimResult.fromMap({vFallback: 'True'});
        expect(claim.verdict, 'True');
      }
    });

    test('source parsing from List<Map> and List<String>', () {
      final map = {
        'sources': [
          {'title': 'Source 1'},
          'http://example.com/source2',
          'Just a string',
        ]
      };
      final claim = ClaimResult.fromMap(map);
      expect(claim.effectiveSources.length, 3);
      expect(claim.effectiveSources[0].title, 'Source 1');
      expect(claim.effectiveSources[1].url, 'http://example.com/source2');
      expect(claim.effectiveSources[2].title, 'Just a string');
    });

    test('verdictBasis fallbacks vs explicit field', () {
      final map1 = {'verdictBasis': ['Explicit Basis']};
      expect(ClaimResult.fromMap(map1).verdictBasis, ['Explicit Basis']);

      final fallbacks = ['response', 'reasoning', 'whyWrong', 'explanation', 'verificationSummary'];
      for (final fb in fallbacks) {
        final claim = ClaimResult.fromMap({fb: 'Fallback Reason'});
        expect(claim.verdictBasis, ['Fallback Reason']);
      }
    });

    test('isLowRiskTrivia and evidence/consensus list parsing', () {
      final map = {
        'isLowRiskTrivia': true,
        'evidence': [{'type': 'Doc', 'strength': 'High'}],
        'consensus': [{'domain': 'Science', 'level': 'Strong'}],
      };
      final claim = ClaimResult.fromMap(map);
      expect(claim.isLowRiskTrivia, true);
      expect(claim.evidence?.length, 1);
      expect(claim.evidence?.first.type, 'Doc');
      expect(claim.consensus?.length, 1);
      expect(claim.consensus?.first.domain, 'Science');
    });
  });

  group('UISource', () {
    test('URL, domain extraction, and defaults', () {
      final source = UISource.fromMap({
        'url': 'https://example.com/page',
        'citationCount': 5,
        'snippet': 'A snippet',
        'retrievalProvider': 'Google',
      });

      expect(source.url, 'https://example.com/page');
      expect(source.domain, 'example.com'); // extracted from URL
      expect(source.trustLevel, 'Medium');
      expect(source.type, 'Secondary');
      expect(source.citationCount, 5);
      expect(source.snippet, 'A snippet');
      expect(source.retrievalProvider, 'Google');
    });
  });

  group('UIReport', () {
    test('summary and narrative fallbacks, claims/sources parsing', () {
      final map = {
        'trustScore': 0.9,
        'trustLabel': 'Highly Credible',
        'confidence': 'High',
        'analysisState': 'Complete',
        'viewerNote': 'Narrative fallback',
        'claims': [{'text': 'Claim 1'}, 'Claim 2 string'],
        'sources': [{'title': 'Source 1'}, 'Source 2 string'],
      };

      final report = UIReport.fromMap(map);
      expect(report.summary.rating, 0.9);
      expect(report.summary.label, 'Highly Credible');
      expect(report.summary.confidence, 'High');
      expect(report.summary.analysisState, 'Complete');
      expect(report.narrative, 'Narrative fallback');

      expect(report.keyClaims.length, 2);
      expect(report.keyClaims[0].text, 'Claim 1');
      expect(report.keyClaims[1].text, 'Claim 2 string');

      expect(report.sources.length, 2);
      expect(report.sources[0].title, 'Source 1');
      expect(report.sources[1].title, 'Source 2 string');
    });
  });

  group('UISummary', () {
    test('nullable doubles', () {
      final summary = UISummary.fromMap({
        'rating': 4.5,
      });
      expect(summary.rating, 4.5);

      final empty = UISummary.fromMap({});
      expect(empty.rating, null);
    });
  });

  group('HardeningMetadata', () {
    test('parsing nested domain override and booleans', () {
      final map = {
        'truthFloorApplied': true,
        'consensusGateTriggered': true,
        'domainOverride': {
          'triggered': true,
          'penalty': -0.2,
          'riskDelta': 0.1,
        }
      };

      final meta = HardeningMetadata.fromMap(map);
      expect(meta.truthFloorApplied, true);
      expect(meta.consensusGateTriggered, true);
      expect(meta.domainOverride?.triggered, true);
      expect(meta.domainOverride?.penalty, -0.2);
    });
  });

  group('ContextualFlag & Perspective', () {
    test('parsing list of perspectives', () {
      final map = {
        'topic': 'Topic',
        'claimText': 'Claim',
        'aiNote': 'Note',
        'perspectives': [
          {'label': 'P1', 'explanation': 'E1', 'sources': ['S1']},
        ]
      };
      final flag = ContextualFlag.fromMap(map);
      expect(flag.perspectives.length, 1);
      expect(flag.perspectives[0].label, 'P1');
      expect(flag.perspectives[0].sources, ['S1']);
    });
  });

  group('TrustDeduction & FactCheckStats', () {
    test('fromMap with defaults', () {
      final td = TrustDeduction.fromMap({'factor': 'F1'});
      expect(td.points, 0.0);
      expect(td.reason, '');

      final fcs = FactCheckStats.fromMap({'totalClaims': 10});
      expect(fcs.correct, 0);
      expect(fcs.incorrect, 0);
      expect(fcs.unverifiable, 0);
    });
  });
}
