/// Aggregated credibility score for a channel, computed from all fact-checked videos.
class ChannelTrustScore {
  final double averageTrustScore;      // 0-100
  final int totalVideosAnalyzed;
  final int totalClaimsVerified;
  final int totalClaimsFalse;
  final int totalClaimsUnconfirmed;
  final double verificationRate;       // % of claims verified (0.0-1.0)
  final String trackRecordLabel;       // computed from verificationRate
  final DateTime? lastUpdated;

  ChannelTrustScore({
    required this.averageTrustScore,
    required this.totalVideosAnalyzed,
    required this.totalClaimsVerified,
    required this.totalClaimsFalse,
    required this.totalClaimsUnconfirmed,
    required this.verificationRate,
    this.lastUpdated,
  }) : trackRecordLabel = _computeLabel(totalVideosAnalyzed, verificationRate);

  static String _computeLabel(int videosAnalyzed, double verificationRate) {
    if (videosAnalyzed < 3) return 'Not Enough Data';
    if (verificationRate > 0.85) return 'Highly Reliable';
    if (verificationRate >= 0.50) return 'Mixed Record';
    return 'Low Reliability';
  }

  factory ChannelTrustScore.fromMap(Map<String, dynamic> map) {
    return ChannelTrustScore(
      averageTrustScore: (map['averageTrustScore'] ?? 0.0).toDouble(),
      totalVideosAnalyzed: map['totalVideosAnalyzed'] ?? 0,
      totalClaimsVerified: map['totalClaimsVerified'] ?? 0,
      totalClaimsFalse: map['totalClaimsFalse'] ?? 0,
      totalClaimsUnconfirmed: map['totalClaimsUnconfirmed'] ?? 0,
      verificationRate: (map['verificationRate'] ?? 0.0).toDouble(),
      lastUpdated: map['lastUpdated'] != null ? DateTime.parse(map['lastUpdated']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'averageTrustScore': averageTrustScore,
      'totalVideosAnalyzed': totalVideosAnalyzed,
      'totalClaimsVerified': totalClaimsVerified,
      'totalClaimsFalse': totalClaimsFalse,
      'totalClaimsUnconfirmed': totalClaimsUnconfirmed,
      'verificationRate': verificationRate,
      'trackRecordLabel': trackRecordLabel,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }
}
