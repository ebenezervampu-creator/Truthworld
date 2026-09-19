/// Tracks a user's fact-checking contribution quality and reputation.
/// Used to weight community disputes and source submissions.
class ContributorReputation {
  final String userId;
  final int disputesSubmitted;
  final int disputesAccepted;      // accepted by editorial review
  final int disputesRejected;
  final int sourcesSubmitted;
  final int sourcesVerified;       // verified as legitimate
  final int sourcesRejected;
  final DateTime? lastActivity;

  ContributorReputation({
    required this.userId,
    this.disputesSubmitted = 0,
    this.disputesAccepted = 0,
    this.disputesRejected = 0,
    this.sourcesSubmitted = 0,
    this.sourcesVerified = 0,
    this.sourcesRejected = 0,
    this.lastActivity,
  });

  factory ContributorReputation.fromMap(Map<String, dynamic> map) {
    return ContributorReputation(
      userId: map['userId'] as String,
      disputesSubmitted: map['disputesSubmitted'] as int? ?? 0,
      disputesAccepted: map['disputesAccepted'] as int? ?? 0,
      disputesRejected: map['disputesRejected'] as int? ?? 0,
      sourcesSubmitted: map['sourcesSubmitted'] as int? ?? 0,
      sourcesVerified: map['sourcesVerified'] as int? ?? 0,
      sourcesRejected: map['sourcesRejected'] as int? ?? 0,
      lastActivity: map['lastActivity'] != null ? DateTime.parse(map['lastActivity'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'disputesSubmitted': disputesSubmitted,
      'disputesAccepted': disputesAccepted,
      'disputesRejected': disputesRejected,
      'sourcesSubmitted': sourcesSubmitted,
      'sourcesVerified': sourcesVerified,
      'sourcesRejected': sourcesRejected,
      if (lastActivity != null) 'lastActivity': lastActivity!.toIso8601String(),
    };
  }

  double get reputationScore {
    if (!hasEnoughData) return 0.0;

    var disputeScore = 0.0;
    if (disputesSubmitted > 0) {
      disputeScore = (disputesAccepted / disputesSubmitted) * 50;
    }

    var sourceScore = 0.0;
    if (sourcesSubmitted > 0) {
      sourceScore = (sourcesVerified / sourcesSubmitted) * 50;
    }

    final totalScore = disputeScore + sourceScore;
    return totalScore.clamp(0.0, 100.0);
  }

  String get tier {
    final score = reputationScore;
    if (score >= 80) return 'Trusted Contributor';
    if (score >= 50) return 'Active Contributor';
    if (score >= 20) return 'New Contributor';
    return 'Unverified';
  }

  bool get isTrusted => reputationScore >= 80;
  
  bool get hasEnoughData => (disputesSubmitted + sourcesSubmitted) >= 3;
  
  double get disputeAcceptanceRate {
    if (disputesSubmitted == 0) return 0.0;
    return disputesAccepted / disputesSubmitted;
  }
  
  double get sourceVerificationRate {
    if (sourcesSubmitted == 0) return 0.0;
    return sourcesVerified / sourcesSubmitted;
  }
}
