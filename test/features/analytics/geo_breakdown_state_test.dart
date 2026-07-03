import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/presentation/widgets/geo_breakdown_state.dart';

void main() {
  group('GeoBreakdownState', () {
    test(
      'sorts regions by count descending and splits states from countries',
      () {
        final regions = [
          const GeoRegionModel(
            regionKey: 'Delhi',
            count: 4,
            isIndianState: true,
          ),
          const GeoRegionModel(
            regionKey: 'United States',
            count: 20,
            isIndianState: false,
          ),
          const GeoRegionModel(
            regionKey: 'Maharashtra',
            count: 15,
            isIndianState: true,
          ),
          const GeoRegionModel(
            regionKey: 'Canada',
            count: 9,
            isIndianState: false,
          ),
        ];

        final state = GeoBreakdownState.fromRegions(regions);

        expect(state.totalCount, 48);
        expect(state.indianStates.map((r) => r.regionKey).toList(), [
          'Maharashtra',
          'Delhi',
        ]);
        expect(state.countries.map((r) => r.regionKey).toList(), [
          'United States',
          'Canada',
        ]);
        expect(state.indianStates.first.count, 15);
        expect(state.countries.first.count, 20);
      },
    );

    test('returns empty sections for an empty region list', () {
      final state = GeoBreakdownState.fromRegions(const []);

      expect(state.totalCount, 0);
      expect(state.indianStates, isEmpty);
      expect(state.countries, isEmpty);
      expect(state.hasData, isFalse);
    });
  });
}
