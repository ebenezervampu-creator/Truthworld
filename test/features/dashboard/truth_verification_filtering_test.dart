import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification_dashboard_page.dart';

void main() {
  group('TruthVerificationDashboardPage.hasFactChecking', () {
    test('returns true when isFactChecked is explicitly true', () {
      final data = <String, dynamic>{
        'title': 'Investigative Fact Check',
        'isFactChecked': true,
      };
      expect(TruthVerificationDashboardPage.hasFactChecking(data), isTrue);
    });

    test('returns true when aiFeatures has factChecking enabled', () {
      final data = <String, dynamic>{
        'title': 'AI Verification in Progress',
        'aiFeatures': {'factChecking': true},
      };
      expect(TruthVerificationDashboardPage.hasFactChecking(data), isTrue);
    });

    test('returns true when trustScore or credibilityScore is positive', () {
      final dataWithTrustScore = <String, dynamic>{
        'title': 'Scored Video',
        'trustScore': 95.0,
      };
      expect(
        TruthVerificationDashboardPage.hasFactChecking(dataWithTrustScore),
        isTrue,
      );

      final dataWithCredScore = <String, dynamic>{
        'title': 'Credibility Scored Video',
        'credibilityScore': 80.0,
      };
      expect(
        TruthVerificationDashboardPage.hasFactChecking(dataWithCredScore),
        isTrue,
      );
    });

    test('returns true when video has extracted claims', () {
      final data = <String, dynamic>{'title': 'Video with Claims'};
      final dummyClaim = RealExtractedClaim(
        id: 'c1',
        videoId: 'v1',
        videoTitle: 'Video with Claims',
        text: 'Eggs contain 6 grams of protein',
        timestamp: '01:20',
        timestampSeconds: 80.0,
        category: 'Nutrition',
        confidenceScore: 0.95,
        sourceCitation: 'USDA Database',
        tier: ClaimEvidenceTier.verified,
      );
      expect(
        TruthVerificationDashboardPage.hasFactChecking(
          data,
          claims: [dummyClaim],
        ),
        isTrue,
      );
    });

    test('returns true when uiReport contains key claims or summary', () {
      final data = <String, dynamic>{
        'title': 'Report Video',
        'uiReport': {
          'keyClaims': [
            {'text': 'Claim 1', 'verdict': 'verified'},
          ],
        },
      };
      expect(TruthVerificationDashboardPage.hasFactChecking(data), isTrue);
    });

    test('returns true when reverification is requested or disputed', () {
      final reverifyData = <String, dynamic>{
        'title': 'Reverification Video',
        'reverificationRequested': true,
      };
      expect(
        TruthVerificationDashboardPage.hasFactChecking(reverifyData),
        isTrue,
      );

      final disputeData = <String, dynamic>{
        'title': 'Disputed Video',
        'disputeStatus': 'under_review',
      };
      expect(
        TruthVerificationDashboardPage.hasFactChecking(disputeData),
        isTrue,
      );
    });

    test('returns false for routine video without fact-checking enabled', () {
      // Models routine upload such as "Mahonathuda song by Raj prakash paul worship conference"
      final routineData = <String, dynamic>{
        'title': 'Mahonathuda song by Raj prakash paul worship conference',
        'factCheckReviewMode': 'open_to_users',
        'isFactCheckApproved': true,
        'trustScore': 0,
        'claims': <dynamic>[],
        'aiFeatures': {
          'factChecking': false,
          'factCheckTier': 'full_ground',
        },
      };
      expect(
        TruthVerificationDashboardPage.hasFactChecking(
          routineData,
          claims: [],
          trustScore: 0.0,
        ),
        isFalse,
      );
    });

    test('returns false for video where factChecking is disabled even if trustScore is 100', () {
      // Models video such as "Are Eggs Vegetarian or Non-Vegetarian?" where fact-checking was not requested
      final eggsVideoData = <String, dynamic>{
        'title': 'Are Eggs Vegetarian or Non-Vegetarian? 🥚 The Science & Truth Explained',
        'factCheckReviewMode': 'open_to_users',
        'isFactCheckApproved': true,
        'isFactChecked': false,
        'trustScore': 100,
        'claims': <dynamic>[],
        'factCheckUrl': '',
        'aiFeatures': {
          'factChecking': false,
          'factCheckTier': 'full_ground',
        },
      };
      expect(
        TruthVerificationDashboardPage.hasFactChecking(
          eggsVideoData,
          claims: [],
          trustScore: 100.0,
        ),
        isFalse,
      );
    });
  });

  group('VideoFactCheckItem epistemic accuracy & audit structure', () {
    test('correctly handles zero assertions analyzed (opinion/philosophical discourse)', () {
      final item = VideoFactCheckItem(
        id: '014FDF6E-8648-47E0-B83A-D5815DC145A2',
        title: 'If a language can be misinterpreted so easily, how can it be a great language? Isn\'t it useless?',
        thumbnailUrl: '',
        truthScore: 1.0,
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: true,
        claims: [],
        summary: 'Philosophical inquiry on language semantics.',
        domain: 'Linguistics',
        createdAt: DateTime.now(),
      );

      expect(item.hasClaims, isFalse);
      expect(item.factualAccuracyScore, isNull);
      expect(item.factualAccuracyLabel, 'Not Assessed (No empirical assertions)');
      expect(item.verificationState, 'INSUFFICIENT_EVIDENCE');
      expect(
        item.consensusValidationStatus,
        'INSUFFICIENT_EVIDENCE_FOR_FACTUAL_CONSENSUS (Media Provenance Verified)',
      );
      expect(item.isPubliclyVisible, isTrue);
    });

    test('correctly computes factual accuracy when empirical claims are present', () {
      final verifiedClaim = RealExtractedClaim(
        id: 'c1',
        videoId: 'v1',
        videoTitle: 'Test Video',
        text: 'Water boils at 100C at standard atmospheric pressure',
        timestamp: '00:10',
        timestampSeconds: 10.0,
        category: 'Science',
        confidenceScore: 0.99,
        sourceCitation: 'IUPAC Database',
        tier: ClaimEvidenceTier.verified,
      );

      final item = VideoFactCheckItem(
        id: 'v1',
        title: 'Test Video',
        thumbnailUrl: '',
        truthScore: 1.0,
        factCheckReviewMode: 'open_to_users',
        isFactCheckApproved: true,
        claims: [verifiedClaim],
        summary: 'Scientific analysis.',
        domain: 'Physics',
        createdAt: DateTime.now(),
      );

      expect(item.hasClaims, isTrue);
      expect(item.factualAccuracyScore, 1.0);
      expect(item.factualAccuracyLabel, '100%');
      expect(item.verificationState, 'VERIFIED_MULTIMODAL_CONSENSUS');
      expect(item.consensusValidationStatus, 'VERIFIED_MULTIMODAL_CONSENSUS');
    });
  });
}
