import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_helpers.dart';

void main() {
  group('Video Credibility Claims & Real Sources Tests', () {
    test('Cleans leading ? and emoji artifacts from claim text', () {
      final inputClaims = [
        {'claim': '? In 2012, mobile data in India ran on patchy 2G networks.'},
        {'claim': '✅ In 2012, Internet access in India looked very different.'},
        {'claim': '❔ In 2012, a single device was often shared.'},
        {'claim': '❌ Having parents constantly picking up a shared device.'},
        {'claim': '🗣️ Entrepreneur Kaban Bharti Mattel saw this friction point.'},
      ];

      for (var i = 0; i < inputClaims.length; i++) {
        final resolved = VideoAnalysisHelpers.resolveRealClaimDetails(inputClaims[i], i, []);
        expect(resolved.cleanText.startsWith('?'), isFalse);
        expect(resolved.cleanText.startsWith('✅'), isFalse);
        expect(resolved.cleanText.startsWith('❔'), isFalse);
        expect(resolved.cleanText.startsWith('❌'), isFalse);
        expect(resolved.cleanText.startsWith('🗣️'), isFalse);
        expect(resolved.cleanText.isNotEmpty, isTrue);
      }
    });

    test('Resolves authentic responses from claim and verdict', () {
      final r1 = VideoAnalysisHelpers.resolveRealClaimDetails(
        {
          'claim': 'India reached a population of 1.4 billion people.',
          'response': 'Census and UN demographic tracking confirm this figure.',
          'verdict': 'VERIFIED',
        },
        0,
        [],
      );
      expect(r1.response.contains('Census and UN demographic'), isTrue);

      final r2 = VideoAnalysisHelpers.resolveRealClaimDetails(
        {
          'claim': 'This is a personal preference.',
          'verdict': 'OPINION',
        },
        1,
        [],
      );
      expect(r2.response.isNotEmpty, isTrue);
    });

    test('Resolves real, authentic, tapable sources for claims', () {
      final authenticSources = [
        {
          'title': 'TRAI: Telecom Performance Indicators',
          'url': 'https://www.trai.gov.in/release-publication/reports/performance-indicators-reports',
          'domain': 'trai.gov.in',
          'snippet': 'Official TRAI performance indicators.',
        },
        {
          'title': 'IAMAI: Internet in India',
          'url': 'https://www.iamai.in/research',
          'domain': 'iamai.in',
          'snippet': 'IAMAI research on internet penetration.',
        },
      ];

      final r1 = VideoAnalysisHelpers.resolveRealClaimDetails(
        {
          'claim': 'Mobile data metrics in India',
          'sources': authenticSources,
        },
        0,
        [],
      );

      expect(r1.sources.length, equals(2));
      for (final s in r1.sources) {
        expect(s['url'], isNotNull);
        expect(s['url'].toString().startsWith('http'), isTrue);
        expect(s['title'], isNotNull);
        expect(s['snippet'], isNotNull);
      }

      final domains = r1.sources.map((s) => s['domain']).toList();
      expect(domains.contains('trai.gov.in'), isTrue);
      expect(domains.contains('iamai.in'), isTrue);
    });

    test('Preserves explicit backend richSources if present', () {
      final customSources = [
        {
          'title': 'Custom TRAI Paper',
          'url': 'https://trai.gov.in/custom-doc.pdf',
          'domain': 'trai.gov.in',
          'snippet': 'Custom snippet from AI pipeline',
        }
      ];

      final r = VideoAnalysisHelpers.resolveRealClaimDetails(
        {
          'claim': 'Sample claim',
          'response': 'Explicit backend response',
          'richSources': customSources,
        },
        0,
        [],
      );

      expect(r.response, equals('Explicit backend response'));
      expect(r.sources.first['title'], equals('Custom TRAI Paper'));
      expect(r.sources.first['url'], equals('https://trai.gov.in/custom-doc.pdf'));
    });

    test('Faith-based supernatural claim evaluation: Jesus walks on water it is 100% proved', () {
      final claimMap = {
        'claim': 'Jesus walks on water and it is 100% proved',
        'verdict': 'FAITH-BASED CLAIM',
        'claimDomain': 'RELIGIOUS',
        'claimNature': 'SUPERNATURAL_CLAIM',
        'classificationConfidence': 0.98,
        'historicalEvidenceConfidence': 0.15,
        'evidenceDetails': {
          'scriptural': 'VERY_STRONG',
          'historical': 'LIMITED',
          'scientific': 'CONTRADICTED',
        },
        'consensusDetails': {
          'theology': 'HIGH',
          'historical': 'LOW',
          'scientific': 'NONE',
        },
        'verdictBasis': [
          'The account of Jesus walking on water (Matthew 14:22–33, John 6:16–21) is a religious miracle tradition of faith. While scripturally central to Christian theology, it is not an empirically or scientifically proven physical event, so asserting it as 100% proved fact is epistemically inaccurate.'
        ],
        'richSources': [
          {
            'title': 'Gospel of Matthew (Matthew 14:22-33)',
            'sourceType': 'scripture',
            'bookTitle': 'New Testament',
            'chapter': 'Matthew 14',
            'trustLevel': 'High',
            'url': 'https://www.biblegateway.com/passage/?search=Matthew+14%3A22-33',
            'domain': 'biblegateway.com',
          },
          {
            'title': 'Miracles of Jesus - Academic & Theological Consensus',
            'sourceType': 'encyclopedia',
            'domain': 'en.wikipedia.org',
            'url': 'https://en.wikipedia.org/wiki/Jesus_walking_on_water',
          }
        ]
      };

      final claimResult = ClaimResult.fromMap(claimMap);

      expect(claimResult.text, equals('Jesus walks on water and it is 100% proved'));
      expect(claimResult.verdict, equals('FAITH-BASED CLAIM'));
      expect(claimResult.claimDomain, equals('RELIGIOUS'));
      expect(claimResult.claimNature, equals('SUPERNATURAL_CLAIM'));
      expect(claimResult.classificationConfidence, greaterThanOrEqualTo(0.95));
      expect(claimResult.historicalEvidenceConfidence, lessThan(0.3));
      expect(claimResult.evidenceDetails?['scriptural'], equals('VERY_STRONG'));
      expect(claimResult.evidenceDetails?['historical'], equals('LIMITED'));
      expect(claimResult.evidenceDetails?['scientific'], equals('CONTRADICTED'));
      expect(claimResult.consensusDetails?['theology'], equals('HIGH'));
      expect(claimResult.consensusDetails?['scientific'], equals('NONE'));
      expect(claimResult.effectiveSources.length, equals(2));
      expect(claimResult.effectiveSources.first.domain, equals('biblegateway.com'));
      expect(claimResult.effectiveSources.last.domain, equals('en.wikipedia.org'));
    });

    test('Closed-World ClaimResult hides broken URLs on missing status and retains non-clickable academic metadata', () {
      final claimMap = {
        'claimId': 'claim_18',
        'claim': 'Biological aging rate can be influenced by lifestyle habits.',
        'verdict': 'VERIFIED TRUE',
        'sourceStatus': 'missing',
        'verifiedAcademicMetadata': [
          {
            'title': 'Lifestyle factors and biological age markers',
            'authors': ['Smith J', 'Lee K'],
            'journal': 'Nature Aging',
            'year': '2024',
            'doi': '10.1038/s43587-024-0001-x',
          },
        ],
        'richSources': [
          {
            'title': 'Mayo Clinic',
            'url': 'https://www.mayoclinic.org/',
            'domain': 'mayoclinic.org',
          },
        ],
      };

      final claimResult = ClaimResult.fromMap(claimMap);

      expect(claimResult.sourceStatus, equals('missing'));
      expect(claimResult.effectiveSources, isEmpty);
      expect(claimResult.verifiedAcademicMetadata, hasLength(1));
      expect(
        claimResult.verifiedAcademicMetadata!.first['doi'],
        equals('10.1038/s43587-024-0001-x'),
      );

      final resolved = VideoAnalysisHelpers.resolveRealClaimDetails(
        claimMap,
        17,
        [
          {
            'title': 'Aging video global source',
            'url': 'https://www.who.int/news-room/fact-sheets/detail/ageing-and-health',
            'domain': 'who.int',
          },
        ],
      );
      expect(resolved.sources, isEmpty);
    });
  });
}
