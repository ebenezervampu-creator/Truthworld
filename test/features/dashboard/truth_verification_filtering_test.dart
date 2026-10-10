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
}
