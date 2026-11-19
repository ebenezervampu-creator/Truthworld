import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/fact_check_data_parser.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_helpers.dart';

void main() {
  group('10 Critical Claims Sample Video Verification', () {
    final sampleTenCriticalClaimsJson = {
      'analysisState': 'VERIFIED',
      'scoreAvailable': false,
      'trustLabel': 'Not Scored',
      'summary':
          'Multi-disciplinary fact check of 10 critical claims across governance, epidemiology, banking, and physics.',
      'conclusion': {
        'label': 'Review Complete',
        'text': '6 verified, 2 refuted, 1 disputed out of 10 critical claims.',
        'confidence': 0.95,
      },
      'claims': [
        {
          'claimId': 'critical_01',
          'claim':
              'The Election Commission of India mandates VVPAT paper audit trails for electronic voting machines.',
          'verdict': 'VERIFIED TRUE',
          'status': 'verified_true',
          'sourceStatus': 'complete',
          'sources': [
            {
              'title': 'Election Commission of India: VVPAT Overview',
              'url': 'https://eci.gov.in/vvpat-overview/',
              'domain': 'eci.gov.in',
              'publisher': 'Election Commission of India',
              'snippet': 'VVPAT slips enable physical verification of votes cast on EVMs.',
            },
            {
              'title': 'Supreme Court of India: VVPAT Audit Verification Mandate',
              'url': 'https://sci.gov.in/judgments/vvpat-verification/',
              'domain': 'sci.gov.in',
              'publisher': 'Supreme Court of India',
              'snippet': 'Supreme Court upholds VVPAT paper slip auditing protocol for electoral integrity.',
            },
            {
              'title': 'PIB: EVM and VVPAT Verification Protocols',
              'url': 'https://pib.gov.in/PressReleasePage.aspx?PRID=1711200',
              'domain': 'pib.gov.in',
              'publisher': 'Press Information Bureau',
              'snippet': 'Official notification on mandatory multi-stage VVPAT verification.',
            },
          ],
        },
        {
          'claimId': 'critical_02',
          'claim':
              'Measles is an airborne viral disease preventable with two doses of the MMR vaccine.',
          'verdict': 'VERIFIED TRUE',
          'status': 'verified_true',
          'sourceStatus': 'complete',
          'sources': [
            {
              'title': 'World Health Organization: Measles Fact Sheet',
              'url': 'https://www.who.int/news-room/fact-sheets/detail/measles',
              'domain': 'who.int',
              'publisher': 'WHO',
              'snippet': 'Two doses of measles vaccine provide approximately 97% protection.',
            },
            {
              'title': 'CDC: Measles Vaccination Recommendations & Efficacy',
              'url': 'https://www.cdc.gov/measles/vaccination.html',
              'domain': 'cdc.gov',
              'publisher': 'CDC',
              'snippet': 'Two doses of MMR vaccine are 97% effective at preventing measles.',
            },
          ],
        },
        {
          'claimId': 'critical_03',
          'claim':
              'Drinking industrial sodium chlorite bleach cures cancer and replaces emergency medical care.',
          'verdict': 'FALSE CLAIM',
          'status': 'false_claim',
          'severity': 'extreme',
          'sourceStatus': 'complete',
          'sources': [
            {
              'title': 'FDA Consumer Update: Danger - Do Not Drink MMS',
              'url':
                  'https://www.fda.gov/consumers/consumer-updates/danger-dont-drink-miracle-mineral-solution-mms',
              'domain': 'fda.gov',
              'publisher': 'US FDA',
              'snippet': 'FDA warns consumers not to drink sodium chlorite products marketed as medical cures.',
            },
            {
              'title': 'FTC: Joint FTC/FDA Action on Fraudulent Bleach Products',
              'url': 'https://www.ftc.gov/news-events/news/press-releases/2020/05/ftc-fda-warn-seller-miracle-mineral-solution',
              'domain': 'ftc.gov',
              'publisher': 'FTC',
              'snippet': 'Enforcement actions against false medical claims for sodium chlorite.',
            },
          ],
        },
        {
          'claimId': 'critical_04',
          'claim':
              'The Reserve Bank of India regulates monetary policy and sets the policy repo rate.',
          'verdict': 'VERIFIED TRUE',
          'status': 'verified_true',
          'sourceStatus': 'complete',
          'sources': [
            {
              'title': 'Reserve Bank of India: Monetary Policy Framework',
              'url': 'https://rbi.org.in/scripts/FS_Overview.aspx?fn=2752',
              'domain': 'rbi.org.in',
              'publisher': 'Reserve Bank of India',
              'snippet': 'The RBI manages monetary policy through the policy repo rate.',
            }
          ],
        },
        {
          'claimId': 'critical_05',
          'claim':
              'The BRAVHO algorithm is a Bayesian risk-limiting audit method designed for auditing elections.',
          'verdict': 'MOSTLY TRUE',
          'status': 'mostly_true',
          'sourceStatus': 'complete',
          'sources': [
            {
              'title': 'BRAVHO: Bayesian Risk-Limiting Audits for Complex Elections - ArXiv',
              'url': 'https://arxiv.org/abs/2105.12345',
              'domain': 'arxiv.org',
              'publisher': 'ArXiv',
              'snippet': 'Statistical ballot comparison guarantees for complex elections.',
            }
          ],
        },
        {
          'claimId': 'critical_06',
          'claim':
              'The central bank declared total bankruptcy today and all consumer deposits are permanently lost.',
          'verdict': 'FALSE CLAIM',
          'status': 'false_claim',
          'severity': 'extreme',
          'sourceStatus': 'complete',
          'sources': [
            {
              'title': 'PIB Fact Check: Debunking Rumors of Central Bank Collapse',
              'url': 'https://pib.gov.in/PressReleasePage.aspx?PRID=1800000',
              'domain': 'pib.gov.in',
              'publisher': 'Press Information Bureau',
              'snippet': 'Official fact check debunking rumors of central bank insolvency.',
            },
            {
              'title': 'Reserve Bank of India: Press Release on Financial Solvency',
              'url': 'https://rbi.org.in/scripts/BS_PressReleaseDisplay.aspx?prid=54000',
              'domain': 'rbi.org.in',
              'publisher': 'Reserve Bank of India',
              'snippet': 'RBI clarifies Indian banking system remains sound, stable and well-capitalized.',
            },
          ],
        },
        {
          'claimId': 'critical_07',
          'claim':
              'Atmospheric carbon dioxide concentrations have surpassed 420 ppm at Mauna Loa.',
          'verdict': 'VERIFIED TRUE',
          'status': 'verified_true',
          'sourceStatus': 'complete',
          'sources': [
            {
              'title': 'NOAA: Trends in Atmospheric Carbon Dioxide',
              'url': 'https://gml.noaa.gov/ccgg/trends/',
              'domain': 'noaa.gov',
              'publisher': 'NOAA',
              'snippet': 'Direct atmospheric measurements confirm baseline CO2 concentrations.',
            }
          ],
        },
        {
          'claimId': 'critical_08',
          'claim':
              'Article 21 of the Constitution of India guarantees the protection of life and personal liberty.',
          'verdict': 'VERIFIED TRUE',
          'status': 'verified_true',
          'sourceStatus': 'complete',
          'sources': [
            {
              'title': 'Supreme Court of India: Constitution of India Article 21',
              'url': 'https://sci.gov.in/constitution/article-21',
              'domain': 'sci.gov.in',
              'publisher': 'Supreme Court of India',
              'snippet': 'Fundamental protection of life and personal liberty.',
            },
            {
              'title': 'Ministry of Law and Justice: Constitution of India Official Text',
              'url': 'https://legislative.gov.in/constitution-of-india/',
              'domain': 'legislative.gov.in',
              'publisher': 'Ministry of Law and Justice',
              'snippet': 'Official statutory repository for the Constitution of India.',
            },
          ],
        },
        {
          'claimId': 'critical_09',
          'claim':
              'Clinical antibiotics target bacterial cell wall synthesis and do not cure viral influenza.',
          'verdict': 'VERIFIED TRUE',
          'status': 'verified_true',
          'sourceStatus': 'complete',
          'sources': [
            {
              'title': 'CDC: Antibiotic Prescribing and Use',
              'url': 'https://www.cdc.gov/antibiotic-use/about/index.html',
              'domain': 'cdc.gov',
              'publisher': 'CDC',
              'snippet': 'Antibiotics do not treat viral infections like influenza.',
            },
            {
              'title': 'WHO: Antimicrobial Resistance Fact Sheet',
              'url': 'https://www.who.int/news-room/fact-sheets/detail/antimicrobial-resistance',
              'domain': 'who.int',
              'publisher': 'WHO',
              'snippet': 'Antibiotics are medicines used to prevent and treat bacterial infections.',
            },
          ],
        },
        {
          'claimId': 'critical_10',
          'claim':
              'A breaking laboratory preprint claims room-temperature ambient pressure superconductivity.',
          'verdict': 'DISPUTED',
          'status': 'disputed',
          'sourceStatus': 'complete',
          'sources': [
            {
              'title': 'Nature News: Superconductivity Replication Challenges',
              'url': 'https://www.nature.com/articles/d41586-023-02401-2',
              'domain': 'nature.com',
              'publisher': 'Nature',
              'snippet': 'Replication efforts ongoing for ambient superconductor preprint.',
            }
          ],
        },
      ],
      'claimLedger': {
        'totalClaimsChecked': 10,
        'confirmedCount': 6,
        'disputedCount': 1,
        'unprovenCount': 0,
        'falseCount': 2,
        'contextualCount': 1,
        'highestSeverityVerdict': 'false_claim',
      },
    };

    test('1. FactCheckDataParser extracts and aggregates all 10 claims and distinct sources', () {
      final parsed = FactCheckDataParser.parse(sampleTenCriticalClaimsJson);

      expect(parsed.claims.length, equals(10));
      expect(parsed.sources.length, equals(17));

      final domains = parsed.sources.map((s) => s['domain']).toSet();
      expect(domains.contains('eci.gov.in'), isTrue);
      expect(domains.contains('who.int'), isTrue);
      expect(domains.contains('fda.gov'), isTrue);
      expect(domains.contains('ftc.gov'), isTrue);
      expect(domains.contains('rbi.org.in'), isTrue);
      expect(domains.contains('arxiv.org'), isTrue);
      expect(domains.contains('pib.gov.in'), isTrue);
      expect(domains.contains('noaa.gov'), isTrue);
      expect(domains.contains('sci.gov.in'), isTrue);
      expect(domains.contains('cdc.gov'), isTrue);
      expect(domains.contains('legislative.gov.in'), isTrue);
      expect(domains.contains('nature.com'), isTrue);
    });

    test('2. VideoMediaCredibility aggregates claim sources when top-level sources is empty', () {
      final cred = VideoMediaCredibility.fromMap(sampleTenCriticalClaimsJson);

      expect(cred.claims.length, equals(10));
      expect(cred.sources.length, equals(17));

      for (var i = 0; i < 10; i++) {
        final claim = cred.claims[i];
        expect(claim['claim'], isNotNull);
        final sources = claim['sources'] as List?;
        expect(sources, isNotNull);
        expect(sources!.isNotEmpty, isTrue);
        expect(sources.first['url'].toString().startsWith('https://'), isTrue);
      }
    });

    test('3. VideoAnalysisHelpers resolves tapable sources for each of the 10 critical claims', () {
      final rawClaims = sampleTenCriticalClaimsJson['claims'] as List;

      for (var i = 0; i < rawClaims.length; i++) {
        final claim = rawClaims[i] as Map<String, dynamic>;
        final resolved = VideoAnalysisHelpers.resolveRealClaimDetails(claim, i, []);

        expect(resolved.cleanText.isNotEmpty, isTrue);
        expect(resolved.sources.isNotEmpty, isTrue);
        final src = resolved.sources.first;
        expect(src['url'], isNotNull);
        expect(src['url'].toString().startsWith('https://'), isTrue);
        expect(src['domain'], isNotNull);
      }
    });
  });
}
