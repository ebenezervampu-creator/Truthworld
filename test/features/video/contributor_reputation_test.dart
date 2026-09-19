import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/contributor_reputation.dart';

void main() {
  group('ContributorReputation', () {
    test('fromMap/toMap round-trip', () {
      final date = DateTime.utc(2023);
      final original = ContributorReputation(
        userId: 'user123',
        disputesSubmitted: 10,
        disputesAccepted: 8,
        disputesRejected: 2,
        sourcesSubmitted: 5,
        sourcesVerified: 4,
        sourcesRejected: 1,
        lastActivity: date,
      );

      final map = original.toMap();
      final reconstructed = ContributorReputation.fromMap(map);

      expect(reconstructed.userId, original.userId);
      expect(reconstructed.disputesSubmitted, original.disputesSubmitted);
      expect(reconstructed.disputesAccepted, original.disputesAccepted);
      expect(reconstructed.disputesRejected, original.disputesRejected);
      expect(reconstructed.sourcesSubmitted, original.sourcesSubmitted);
      expect(reconstructed.sourcesVerified, original.sourcesVerified);
      expect(reconstructed.sourcesRejected, original.sourcesRejected);
      expect(reconstructed.lastActivity, original.lastActivity);
    });

    test('reputationScore computation and tier - not enough data', () {
      final rep = ContributorReputation(
        userId: 'user1',
        disputesSubmitted: 1,
        sourcesSubmitted: 1,
      );

      expect(rep.hasEnoughData, false);
      expect(rep.reputationScore, 0.0);
      expect(rep.tier, 'Unverified');
      expect(rep.isTrusted, false);
    });

    test('reputationScore computation - all accepted/verified', () {
      final rep = ContributorReputation(
        userId: 'user1',
        disputesSubmitted: 5,
        disputesAccepted: 5,
        sourcesSubmitted: 5,
        sourcesVerified: 5,
      );

      expect(rep.hasEnoughData, true);
      expect(rep.reputationScore, 100.0);
      expect(rep.tier, 'Trusted Contributor');
      expect(rep.isTrusted, true);
      expect(rep.disputeAcceptanceRate, 1.0);
      expect(rep.sourceVerificationRate, 1.0);
    });

    test('reputationScore computation - all rejected', () {
      final rep = ContributorReputation(
        userId: 'user1',
        disputesSubmitted: 5,
        sourcesSubmitted: 5,
      );

      expect(rep.hasEnoughData, true);
      expect(rep.reputationScore, 0.0);
      expect(rep.tier, 'Unverified');
      expect(rep.isTrusted, false);
      expect(rep.disputeAcceptanceRate, 0.0);
      expect(rep.sourceVerificationRate, 0.0);
    });

    test('reputationScore computation - partial', () {
      final rep = ContributorReputation(
        userId: 'user1',
        disputesSubmitted: 10,
        disputesAccepted: 5, // 50% = 25 points
        sourcesSubmitted: 10,
        sourcesVerified: 8, // 80% = 40 points
      );

      expect(rep.hasEnoughData, true);
      expect(rep.reputationScore, 65.0); // 25 + 40 = 65
      expect(rep.tier, 'Active Contributor');
      expect(rep.isTrusted, false);
      expect(rep.disputeAcceptanceRate, 0.5);
      expect(rep.sourceVerificationRate, 0.8);
    });

    test('tier computation - various scores', () {
      expect(
        ContributorReputation(userId: 'u', disputesSubmitted: 5, disputesAccepted: 5, sourcesSubmitted: 5, sourcesVerified: 5).tier,
        'Trusted Contributor', // 100
      );
      expect(
        ContributorReputation(userId: 'u', disputesSubmitted: 5, disputesAccepted: 4, sourcesSubmitted: 5, sourcesVerified: 4).tier,
        'Trusted Contributor', // 80
      );
      expect(
        ContributorReputation(userId: 'u', disputesSubmitted: 10, disputesAccepted: 5, sourcesSubmitted: 10, sourcesVerified: 5).tier,
        'Active Contributor', // 50
      );
      expect(
        ContributorReputation(userId: 'u', disputesSubmitted: 10, disputesAccepted: 2, sourcesSubmitted: 10, sourcesVerified: 2).tier,
        'New Contributor', // 20
      );
      expect(
        ContributorReputation(userId: 'u', disputesSubmitted: 10, disputesAccepted: 1, sourcesSubmitted: 10, sourcesVerified: 1).tier,
        'Unverified', // 10
      );
    });
  });
}
