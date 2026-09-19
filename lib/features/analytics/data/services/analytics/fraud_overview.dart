/// Summary model representing fraudulent vs clean view analysis for a video.
class FraudOverview {
  const FraudOverview({
    required this.totalViews,
    required this.flaggedViews,
    required this.cleanViews,
    required this.fraudRate,
  });

  final int totalViews;
  final int flaggedViews;
  final int cleanViews;
  final double fraudRate;

  static const clean = FraudOverview(
    totalViews: 0,
    flaggedViews: 0,
    cleanViews: 0,
    fraudRate: 0,
  );
}
