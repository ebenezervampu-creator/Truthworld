/// Date range presets for analytics filtering
enum AnalyticsDateRange {
  last7Days('7 days', 7),
  last28Days('28 days', 28),
  last90Days('90 days', 90),
  last365Days('1 year', 365),
  allTime('All time', 0),
  custom('Custom', -1);

  final String label;
  final int days;

  const AnalyticsDateRange(this.label, this.days);

  /// Calculates the start and end dates based on the enum preset.
  ({DateTime start, DateTime end}) calculateRange({
    DateTime? customStart,
    DateTime? customEnd,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    DateTime startDate;
    var endDate = now;

    if (this == AnalyticsDateRange.custom &&
        customStart != null &&
        customEnd != null) {
      startDate = customStart;
      endDate = customEnd;
    } else if (this == AnalyticsDateRange.allTime) {
      startDate = DateTime(2020); // Platform start
    } else {
      startDate = now.subtract(Duration(days: days));
    }
    return (start: startDate, end: endDate);
  }
}
