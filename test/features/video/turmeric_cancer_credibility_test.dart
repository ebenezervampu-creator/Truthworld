import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/theme/app_theme.dart';

void main() {
  group('TruthWorld Credibility System: Turmeric Cancer Cure Verification', () {
    const claimText = 'Drinking turmeric water cures cancer.';

    test('1. Resolves verdict as False Claim with error color and false indicator', () {
      final info = ClaimVerdictHelper.resolveVerdictString('false_claim');
      expect(info.type, ClaimVerdictType.falseClaim);
      expect(info.label, 'FALSE CLAIM');
      expect(info.color, AppColors.error);
      expect(info.isFalse, isTrue);
      expect(info.isVerified, isFalse);
    });

    test('2. ClaimResult maps medical false claim with high severity and authoritative oncology sources', () {
      final claimMap = {
        'claimId': 'claim_health_turmeric_01',
        'claim': claimText,
        'status': 'false_claim',
        'severity': 'high',
        'severityLabel': 'Factually false',
        'reasoning':
            'Contradicted by medical and oncological consensus. While curcumin has demonstrated in-vitro anti-inflammatory activity, zero clinical trial evidence exists that drinking turmeric water cures cancer in humans.',
        'sources': [
          {
            'title': 'Cancer Research UK - Turmeric and Cancer',
            'url':
                'https://www.cancerresearchuk.org/about-cancer/treatment/complementary-alternative-therapies/individual-therapies/turmeric',
            'domain': 'cancerresearchuk.org',
            'tier': 'A',
          },
          {
            'title': 'National Cancer Institute (NCI) - Curcumin Research Overview',
            'url': 'https://www.cancer.gov/about-cancer/treatment/cam/hp/curcumin-pdq',
            'domain': 'cancer.gov',
            'tier': 'A',
          }
        ],
      };

      final claim = ClaimResult.fromMap(claimMap);

      expect(claim.text, claimText);
      expect(claim.verdict, 'false_claim');
      expect(claim.effectiveSources.length, 2);
      expect(claim.effectiveSources[0].title, contains('Cancer Research UK'));
      expect(claim.effectiveSources[0].domain, 'cancerresearchuk.org');
      expect(claim.effectiveSources[1].domain, 'cancer.gov');
    });

    test('3. ClaimLedgerSummary enforces High Severity, Priority Viewer Notice, and Review Request', () {
      final ledgerMap = {
        'totalClaimsChecked': 1,
        'confirmedCount': 0,
        'disputedCount': 0,
        'unprovenCount': 0,
        'falseCount': 1,
        'contextualCount': 0,
        'highestSeverityVerdict': 'false_claim',
        'verdictHeadline': '0 Confirmed • 0 Disputed • 1 False',
        'priorityNotice': 'Notice: 1 claim(s) contradicted by documented evidence.',
        'verifiableRatio': 0.0,
      };

      final ledger = ClaimLedgerSummary.fromMap(ledgerMap);

      // Expected: False
      expect(ledger.falseCount, 1);
      expect(ledger.confirmedCount, 0);

      // Expected: High severity
      expect(ledger.highestSeverityVerdict, 'false_claim');
      expect(ledger.hasHighSeverityIssues, isTrue);

      // Expected: Prominent viewer warning
      expect(ledger.priorityNotice, 'Notice: 1 claim(s) contradicted by documented evidence.');
      expect(ledger.verdictHeadline, '0 Confirmed • 0 Disputed • 1 False');
    });

    test('4. UIReport model triggers human review flag and disputed content warning', () {
      final reportMap = {
        'analysisState': 'VERIFIED',
        'trustScore': 0.0,
        'trustLabel': 'Not Scored',
        'keyClaims': [
          {
            'text': claimText,
            'status': 'false_claim',
            'severity': 'high',
          }
        ],
        'viewerNote':
            'Warning: This content asserts that drinking turmeric water cures cancer, which is contradicted by oncological consensus. Delaying or substituting standard medical treatment with unproven home remedies can cause fatal health outcomes.',
        'highestSeverityVerdict': 'false_claim',
        'priorityNotice': 'Notice: 1 claim(s) contradicted by documented evidence.',
        'reviewRequestEnabled': true,
        'claimLedger': {
          'totalClaimsChecked': 1,
          'confirmedCount': 0,
          'disputedCount': 0,
          'unprovenCount': 0,
          'falseCount': 1,
          'contextualCount': 0,
          'highestSeverityVerdict': 'false_claim',
          'priorityNotice': 'Notice: 1 claim(s) contradicted by documented evidence.',
        }
      };

      final report = UIReport.fromMap(reportMap);

      expect(report.claimLedger?.falseCount, 1);
      expect(report.claimLedger?.highestSeverityVerdict, 'false_claim');
      expect(report.claimLedger?.priorityNotice, contains('contradicted by documented evidence'));
      expect(report.narrative, contains('Warning'));
      expect(report.narrative, contains('oncological consensus'));
      expect(report.reviewRequestEnabled, isTrue);
    });
  });
}
