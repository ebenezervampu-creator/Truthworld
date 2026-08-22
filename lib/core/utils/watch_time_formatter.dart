class WatchTimeFormatter {
  /// Formats seconds into human-readable watch time.
  ///
  /// Standard mode:
  /// - < 60 mins: "0 mins", "1 min", "59 mins"
  /// - 1.0 - < 2.0 hrs: "1.0 hr"
  /// - ≥ 2.0 hrs: "1.5 hrs", "12.4 hrs"
  /// - ≥ 1K hrs: "1.2K hrs", "1.5M hrs"
  ///
  /// Compact mode:
  /// - < 60 mins: "0m", "1m", "59m"
  /// - ≥ 1 hr: "1.0h", "1.5h", "1.2Kh", "1.5Mh"
  static String format(num seconds, {bool compact = false}) {
    if (seconds <= 0) return compact ? '0m' : '0 mins';

    final s = seconds.toDouble();
    final hours = s / 3600.0;

    // 1. Million+ Hours
    if (hours >= 1000000) {
      final formatted = (hours / 1000000).toStringAsFixed(1);
      return compact ? '${formatted}Mh' : '$formatted M hrs';
    }

    // 2. Thousand+ Hours
    if (hours >= 1000) {
      final formatted = (hours / 1000).toStringAsFixed(1);
      return compact ? '${formatted}Kh' : '$formatted K hrs';
    }

    // 3. Hours (1.0 hr to 999.9 hrs)
    if (hours >= 1.0) {
      final formatted = hours.toStringAsFixed(1);
      if (hours >= 1.0 && hours < 2.0) {
        return compact ? '${formatted}h' : '$formatted hr';
      }
      return compact ? '${formatted}h' : '$formatted hrs';
    }

    // 4. Minutes (< 60 mins)
    final minutes = (s / 60.0).round();
    if (minutes == 1) {
      return compact ? '1m' : '1 min';
    }
    return compact ? '${minutes}m' : '$minutes mins';
  }
}
