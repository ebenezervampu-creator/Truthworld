import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/bridging_consensus_engine.dart';
import 'package:truthworld/theme/app_colors.dart';

void main() {
  group('BridgingConsensusEngine', () {
    test('returns pending when no ratings provided', () {
      final res = BridgingConsensusEngine.evaluate('dispute_1', []);
      expect(res.status, DisputeConsensusStatus.pendingRatings);
      expect(res.bridgingScore, 0.0);
      expect(res.totalRatings, 0);
      expect(res.isBrigadeSuspected, isFalse);
    });

    test('achieves consensus when ratings bridge across opposing clusters', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final ratings = [
        // Left cluster raters find it helpful
        ContributorDisputeRating(
          ratingId: 'r1',
          contributorId: 'u1',
          isHelpful: true,
          contributorPolarity: -0.8,
          contributorReputationTier: 'Trusted',
          timestamp: now - 300000,
        ),
        ContributorDisputeRating(
          ratingId: 'r2',
          contributorId: 'u2',
          isHelpful: true,
          contributorPolarity: -0.5,
          contributorReputationTier: 'Active',
          timestamp: now - 240000,
        ),
        // Right cluster raters ALSO find it helpful
        ContributorDisputeRating(
          ratingId: 'r3',
          contributorId: 'u3',
          isHelpful: true,
          contributorPolarity: 0.7,
          contributorReputationTier: 'Trusted',
          timestamp: now - 180000,
        ),
        ContributorDisputeRating(
          ratingId: 'r4',
          contributorId: 'u4',
          isHelpful: true,
          contributorPolarity: 0.6,
          contributorReputationTier: 'Active',
          timestamp: now - 120000,
        ),
        // Center rater finds it helpful
        ContributorDisputeRating(
          ratingId: 'r5',
          contributorId: 'u5',
          isHelpful: true,
          contributorPolarity: 0.0,
          contributorReputationTier: 'Active',
          timestamp: now - 60000,
        ),
      ];

      final res = BridgingConsensusEngine.evaluate('dispute_cross', ratings);
      expect(res.status, DisputeConsensusStatus.consensusAchieved);
      expect(res.isConsensusAchieved, isTrue);
      expect(res.bridgingScore, greaterThanOrEqualTo(0.60));
      expect(res.statusColor, AppColors.success);
      expect(res.statusLabel, 'Consensus Corroborated');
    });

    test('rejects as polarized when opposing clusters disagree', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final ratings = [
        // Left cluster says helpful
        ContributorDisputeRating(
          ratingId: 'r1',
          contributorId: 'u1',
          isHelpful: true,
          contributorPolarity: -0.7,
          contributorReputationTier: 'Trusted',
          timestamp: now - 300000,
        ),
        ContributorDisputeRating(
          ratingId: 'r2',
          contributorId: 'u2',
          isHelpful: true,
          contributorPolarity: -0.6,
          contributorReputationTier: 'Active',
          timestamp: now - 240000,
        ),
        // Right cluster says NOT helpful
        ContributorDisputeRating(
          ratingId: 'r3',
          contributorId: 'u3',
          isHelpful: false,
          contributorPolarity: 0.8,
          contributorReputationTier: 'Trusted',
          timestamp: now - 180000,
        ),
        ContributorDisputeRating(
          ratingId: 'r4',
          contributorId: 'u4',
          isHelpful: false,
          contributorPolarity: 0.7,
          contributorReputationTier: 'Active',
          timestamp: now - 120000,
        ),
        // Center says NOT helpful
        ContributorDisputeRating(
          ratingId: 'r5',
          contributorId: 'u5',
          isHelpful: false,
          contributorPolarity: 0.05,
          contributorReputationTier: 'Active',
          timestamp: now - 60000,
        ),
      ];

      final res = BridgingConsensusEngine.evaluate('dispute_polarized', ratings);
      expect(res.status, DisputeConsensusStatus.rejectedPolarized);
      expect(res.isPolarized, isTrue);
      expect(res.bridgingScore, lessThan(0.35));
      expect(res.statusColor, AppColors.warning);
      expect(res.statusLabel, 'Split Without Consensus');
    });

    test('detects temporal velocity burst from unilateral faction and quarantines', () {
      final base = DateTime.now().millisecondsSinceEpoch;
      // 5 ratings within 10 seconds, all with high positive polarity
      final burstRatings = List.generate(
        5,
        (i) => ContributorDisputeRating(
          ratingId: 'burst_$i',
          contributorId: 'user_$i',
          isHelpful: true,
          contributorPolarity: 0.85, // unilateral faction
          contributorReputationTier: 'New',
          timestamp: base + (i * 2000), // 2s apart
        ),
      );

      final res = BridgingConsensusEngine.evaluate('dispute_brigade', burstRatings);
      expect(res.isBrigadeSuspected, isTrue);
      expect(res.status, DisputeConsensusStatus.brigadeFlagged);
      expect(res.statusColor, AppColors.error);
      expect(res.statusLabel, 'Coordinated Activity Detected');
    });

    test('round-trips ContributorDisputeRating serialization', () {
      const rating = ContributorDisputeRating(
        ratingId: 'r_test',
        contributorId: 'u_test',
        isHelpful: true,
        ratingReason: 'Verified with official government archive',
        contributorPolarity: -0.45,
        contributorReputationTier: 'Trusted',
        timestamp: 1710000000000,
      );

      final map = rating.toMap();
      final reconstructed = ContributorDisputeRating.fromMap(map);

      expect(reconstructed.ratingId, rating.ratingId);
      expect(reconstructed.contributorId, rating.contributorId);
      expect(reconstructed.isHelpful, rating.isHelpful);
      expect(reconstructed.ratingReason, rating.ratingReason);
      expect(reconstructed.contributorPolarity, rating.contributorPolarity);
      expect(reconstructed.contributorReputationTier, rating.contributorReputationTier);
      expect(reconstructed.timestamp, rating.timestamp);
    });
  });
}
