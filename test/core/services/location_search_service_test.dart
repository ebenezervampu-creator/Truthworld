import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:truthworld/core/services/location_search_service.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/location_autocomplete_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationSuggestion Model Tests', () {
    test('Country formatting has clean displayName and subtitle', () {
      const country = LocationSuggestion(
        name: 'United States',
        country: 'United States',
        type: LocationType.country,
        countryCode: 'US',
      );
      expect(country.displayName, 'United States');
      expect(country.subtitle, 'Country');
      expect(country.type.label, 'Country');
    });

    test('State formatting includes country in displayName', () {
      const state = LocationSuggestion(
        name: 'California',
        state: 'California',
        country: 'United States',
        type: LocationType.state,
        countryCode: 'US',
      );
      expect(state.displayName, 'California, United States');
      expect(state.subtitle, 'State / Region in United States');
      expect(state.type.label, 'State / Region');
    });

    test('City formatting includes state and country when available', () {
      const cityWithState = LocationSuggestion(
        name: 'London',
        state: 'England',
        country: 'United Kingdom',
        type: LocationType.city,
        countryCode: 'GB',
      );
      expect(cityWithState.displayName, 'London, England, United Kingdom');
      expect(cityWithState.subtitle, 'City in England, United Kingdom');
      expect(cityWithState.type.label, 'City');

      const cityWithoutState = LocationSuggestion(
        name: 'Singapore',
        country: 'Singapore',
        type: LocationType.city,
        countryCode: 'SG',
      );
      expect(cityWithoutState.displayName, 'Singapore, Singapore');
      expect(cityWithoutState.subtitle, 'City in Singapore');
    });

    test('Equality and hashCode are case-insensitive on displayName', () {
      const s1 = LocationSuggestion(
        name: 'Tokyo',
        state: 'Tokyo',
        country: 'Japan',
        type: LocationType.city,
      );
      const s2 = LocationSuggestion(
        name: 'tokyo',
        state: 'tokyo',
        country: 'japan',
        type: LocationType.city,
      );
      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
    });
  });

  group('LocationSearchService Canonical Search', () {
    late LocationSearchService service;

    setUp(() {
      service = LocationSearchService();
    });

    test('Returns instant canonical country matches', () async {
      final results = await service.searchLocations('India');
      expect(results.isNotEmpty, isTrue);
      expect(
        results.any((loc) =>
            loc.name == 'India' && loc.type == LocationType.country),
        isTrue,
      );
    });

    test('Returns instant canonical state matches', () async {
      final results = await service.searchLocations('California');
      expect(results.isNotEmpty, isTrue);
      expect(
        results.any((loc) =>
            loc.name == 'California' && loc.type == LocationType.state),
        isTrue,
      );
    });

    test('Returns instant canonical city matches', () async {
      final results = await service.searchLocations('Bengaluru');
      expect(results.isNotEmpty, isTrue);
      expect(
        results.any((loc) =>
            loc.name == 'Bengaluru' && loc.type == LocationType.city),
        isTrue,
      );
    });

    test('Handles short query (1 character) without error', () async {
      final results = await service.searchLocations('U');
      expect(results.isNotEmpty, isTrue);
    });

    test('Handles empty query gracefully', () async {
      final results = await service.searchLocations('   ');
      expect(results.isEmpty, isTrue);
    });

    test('Parses live Photon geocoding API responses correctly', () async {
      final mockClient = MockClient((request) async {
        final mockResponse = {
          'features': [
            {
              'properties': {
                'name': 'Kyoto',
                'state': 'Kyoto Prefecture',
                'country': 'Japan',
                'countrycode': 'JP',
                'type': 'city',
                'osm_value': 'city',
              },
            },
          ],
        };
        return http.Response(
          jsonEncode(mockResponse),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final results = await service.searchLocations(
        'Kyoto',
        httpClient: mockClient,
      );
      expect(results.isNotEmpty, isTrue);
      final kyoto = results.firstWhere((r) => r.name == 'Kyoto');
      expect(kyoto.country, 'Japan');
      expect(kyoto.state, 'Kyoto Prefecture');
      expect(kyoto.type, LocationType.city);
    });
  });

  group('LocationAutocompleteController Unit Tests', () {
    late LocationSearchService service;
    late LocationAutocompleteController controller;

    setUp(() {
      service = LocationSearchService();
      controller = LocationAutocompleteController(locationService: service);
    });

    tearDown(() {
      controller.dispose();
    });

    test('onQueryChanged updates searchQuery and opens dropdown', () async {
      controller.onQueryChanged('Ger');
      expect(controller.searchQuery.value, 'Ger');
      expect(controller.isOpen.value, isTrue);

      // Wait microtask for instant canonical matches
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.suggestions.isNotEmpty, isTrue);
      expect(
        controller.suggestions.any((s) => s.name.contains('Germany')),
        isTrue,
      );
    });

    test('Empty query resets controller state', () {
      controller.onQueryChanged('Paris');
      expect(controller.isOpen.value, isTrue);

      controller.onQueryChanged('   ');
      expect(controller.isOpen.value, isFalse);
      expect(controller.suggestions.isEmpty, isTrue);
    });

    test('selectSuggestion adds location to list and clears search', () {
      final selectedList = <String>[].obs;
      final textController = TextEditingController(text: 'Tokyo');

      const suggestion = LocationSuggestion(
        name: 'Tokyo',
        state: 'Tokyo',
        country: 'Japan',
        type: LocationType.city,
      );

      controller.selectSuggestion(
        suggestion,
        selectedList,
        textController,
      );

      expect(selectedList.contains('Tokyo, Japan'), isTrue);
      expect(textController.text.isEmpty, isTrue);
      expect(controller.isOpen.value, isFalse);
      expect(controller.searchQuery.value.isEmpty, isTrue);
    });

    test('selectSuggestion avoids duplicate locations', () {
      final selectedList = <String>['Tokyo, Japan'].obs;
      final textController = TextEditingController();

      const suggestion = LocationSuggestion(
        name: 'Tokyo',
        state: 'Tokyo',
        country: 'Japan',
        type: LocationType.city,
      );

      controller.selectSuggestion(
        suggestion,
        selectedList,
        textController,
      );

      expect(selectedList.length, 1);
    });

    test('addCustomLocation adds valid trimmed custom location', () {
      final selectedList = <String>[].obs;
      final textController = TextEditingController(text: 'Zurich');

      controller.addCustomLocation('Zurich', selectedList, textController);

      expect(selectedList.contains('Zurich'), isTrue);
      expect(textController.text.isEmpty, isTrue);
      expect(controller.isOpen.value, isFalse);
    });
  });
}
