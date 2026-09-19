import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/channel/data/models/channel_trust_score.dart';

void main() {
  group('ChannelTrustScore', () {
    test('computes trackRecordLabel based on video count and verification rate', () {
      final notEnough = ChannelTrustScore(
        averageTrustScore: 90,
        totalVideosAnalyzed: 2,
        totalClaimsVerified: 10,
        totalClaimsFalse: 0,
        totalClaimsUnconfirmed: 0,
        verificationRate: 1.0,
      );
      expect(notEnough.trackRecordLabel, 'Not Enough Data');

      final highlyReliable = ChannelTrustScore(
        averageTrustScore: 88,
        totalVideosAnalyzed: 5,
        totalClaimsVerified: 20,
        totalClaimsFalse: 1,
        totalClaimsUnconfirmed: 2,
        verificationRate: 0.87,
      );
      expect(highlyReliable.trackRecordLabel, 'Highly Reliable');

      final mixedRecord = ChannelTrustScore(
        averageTrustScore: 65,
        totalVideosAnalyzed: 10,
        totalClaimsVerified: 12,
        totalClaimsFalse: 6,
        totalClaimsUnconfirmed: 2,
        verificationRate: 0.60,
      );
      expect(mixedRecord.trackRecordLabel, 'Mixed Record');

      final lowReliability = ChannelTrustScore(
        averageTrustScore: 40,
        totalVideosAnalyzed: 8,
        totalClaimsVerified: 3,
        totalClaimsFalse: 10,
        totalClaimsUnconfirmed: 2,
        verificationRate: 0.20,
      );
      expect(lowReliability.trackRecordLabel, 'Low Reliability');
    });

    test('fromMap and toMap round-trip', () {
      final now = DateTime.now();
      final score = ChannelTrustScore(
        averageTrustScore: 82.5,
        totalVideosAnalyzed: 6,
        totalClaimsVerified: 18,
        totalClaimsFalse: 2,
        totalClaimsUnconfirmed: 1,
        verificationRate: 0.857,
        lastUpdated: now,
      );

      final map = score.toMap();
      final reconstructed = ChannelTrustScore.fromMap(map);

      expect(reconstructed.averageTrustScore, score.averageTrustScore);
      expect(reconstructed.totalVideosAnalyzed, score.totalVideosAnalyzed);
      expect(reconstructed.totalClaimsVerified, score.totalClaimsVerified);
      expect(reconstructed.totalClaimsFalse, score.totalClaimsFalse);
      expect(reconstructed.totalClaimsUnconfirmed, score.totalClaimsUnconfirmed);
      expect(reconstructed.verificationRate, score.verificationRate);
      expect(reconstructed.trackRecordLabel, score.trackRecordLabel);
      expect(reconstructed.lastUpdated?.toIso8601String(), now.toIso8601String());
    });
  });
}
