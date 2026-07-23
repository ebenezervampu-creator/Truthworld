import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';

/// Immutable UI state for the geographic breakdown widget.
///
/// This keeps the grouping, sorting, and summary calculations in one place so
/// the widget stays presentational and state transitions remain predictable.
class GeoBreakdownState {

  const GeoBreakdownState({
    required this.indianStates,
    required this.countries,
    required this.totalCount,
  });

  factory GeoBreakdownState.fromRegions(List<GeoRegionModel> regions) {
    final sortedRegions = [...regions]
      ..sort((a, b) => b.count.compareTo(a.count));

    final indianStates = sortedRegions
        .where((region) => region.isIndianState)
        .toList(growable: false);
    final countries = sortedRegions
        .where((region) => !region.isIndianState)
        .toList(growable: false);
    final totalCount = sortedRegions.fold<int>(
      0,
      (sum, region) => sum + region.count,
    );

    return GeoBreakdownState(
      indianStates: indianStates,
      countries: countries,
      totalCount: totalCount,
    );
  }
  final List<GeoRegionModel> indianStates;
  final List<GeoRegionModel> countries;
  final int totalCount;

  bool get hasData => totalCount > 0;
}
