/// Fraud / bot detection signals attached to each watch event.
/// Cloud Function evaluates these server-side and flags suspicious events.
class FraudSignals {
  const FraudSignals({
    this.viewsFromSameIP24h = 0,
    this.bounceLoopCount = 0,
    this.sessionVelocity = 0,
    this.impossibleGeoJump = false,
    this.suspiciousCompletion = false,
    this.fingerprintMismatch = false,
    this.fraudScore = 0,
    this.isFlagged = false,
  });

  factory FraudSignals.fromMap(Map<String, dynamic> map) => FraudSignals(
    viewsFromSameIP24h: (map['viewsFromSameIP24h'] as num?)?.toInt() ?? 0,
    bounceLoopCount: (map['bounceLoopCount'] as num?)?.toInt() ?? 0,
    sessionVelocity: (map['sessionVelocity'] as num?)?.toDouble() ?? 0,
    impossibleGeoJump: map['impossibleGeoJump'] as bool? ?? false,
    suspiciousCompletion: map['suspiciousCompletion'] as bool? ?? false,
    fingerprintMismatch: map['fingerprintMismatch'] as bool? ?? false,
    fraudScore: (map['fraudScore'] as num?)?.toDouble() ?? 0,
    isFlagged: map['isFlagged'] as bool? ?? false,
  );

  final int viewsFromSameIP24h; // Total views from this IP in 24h
  final int bounceLoopCount; // Rapid start→exit cycles from same user
  final double sessionVelocity; // Events per minute (> 10 = suspicious)
  final bool impossibleGeoJump; // City changed faster than physically possible
  final bool suspiciousCompletion; // 100% completion in < 30% of duration
  final bool fingerprintMismatch; // Device fingerprint doesn't match prior session
  final double fraudScore; // 0.0-1.0, calculated server-side
  final bool isFlagged;

  /// Is this event suspicious? (fraud score > 0.5 or explicit flag)
  bool get isSuspicious => fraudScore > 0.5 || isFlagged;

  Map<String, dynamic> toMap() => {
    'viewsFromSameIP24h': viewsFromSameIP24h,
    'bounceLoopCount': bounceLoopCount,
    'sessionVelocity': sessionVelocity,
    'impossibleGeoJump': impossibleGeoJump,
    'suspiciousCompletion': suspiciousCompletion,
    'fingerprintMismatch': fingerprintMismatch,
    'fraudScore': fraudScore,
    'isFlagged': isFlagged,
  };

  static const clean = FraudSignals();
}

/// A returning viewer is defined as:
/// "A unique user who watched at least 1 other video on the SAME CHANNEL
///  within the past 28 days, with each session having >= 20s qualified watch."
///
/// This is evaluated SERVER-SIDE by checking:
///   watch_events_raw WHERE channelId == X AND userId == Y
///   AND eventType == 'qualified_view' AND watchedAt > now - 28d
///   AND videoId != currentVideoId
///   LIMIT 1
///
/// If a match exists → isReturningViewer = true
class ReturningViewerDefinition {
  static const int lookbackDays = 28;
  static const int minQualifiedSeconds = 20;
  static const String requiredEventType = 'qualified_view';

  /// Description for dashboard tooltip
  static const String tooltip =
      'Viewers who watched another video on this channel '
      'in the last 28 days (with 20s+ watch time each).';
}
