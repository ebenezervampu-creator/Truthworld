import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/location_search_service.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';

/// GetX controller managing reactive state and live suggestions for location targeting.
class LocationAutocompleteController extends GetxController {
  LocationAutocompleteController({LocationSearchService? locationService})
      : _locationService = locationService ?? LocationSearchService.to;

  final LocationSearchService _locationService;

  final RxString searchQuery = ''.obs;
  final RxList<LocationSuggestion> suggestions = <LocationSuggestion>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isOpen = false.obs;
  final RxBool isFocused = false.obs;

  Timer? _debounceTimer;

  /// Triggered whenever the user types into the location search input.
  void onQueryChanged(String query) {
    final trimmed = query.trim();
    searchQuery.value = query;

    if (trimmed.isEmpty) {
      _debounceTimer?.cancel();
      suggestions.clear();
      isOpen.value = false;
      isLoading.value = false;
      return;
    }

    isOpen.value = true;

    // 1. Instant local canonical matches (0ms response for instant typing feedback)
    _locationService.searchLocations(trimmed, limit: 8).then((instantMatches) {
      // Only apply if the query hasn't changed in the microtask
      if (searchQuery.value.trim() == trimmed) {
        suggestions.assignAll(instantMatches);
      }
    });

    // 2. Debounced live authoritative geocoding (OpenStreetMap / Photon)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 280), () async {
      if (searchQuery.value.trim() != trimmed) return;

      isLoading.value = true;
      try {
        final liveMatches = await _locationService.searchLocations(trimmed);
        if (searchQuery.value.trim() == trimmed) {
          suggestions.assignAll(liveMatches);
        }
      } finally {
        if (searchQuery.value.trim() == trimmed) {
          isLoading.value = false;
        }
      }
    });
  }

  /// Select a structured location suggestion and add it to the campaign's target locations.
  void selectSuggestion(
    LocationSuggestion suggestion,
    RxList<String> selectedLocations,
    TextEditingController textController,
  ) {
    final locName = suggestion.displayName;

    final locVal = ContentValidator.validate(
      locName,
      fieldName: 'Location',
    );
    if (!locVal.isValid) {
      AppSnackbar.warning(locVal.message);
      return;
    }

    if (selectedLocations.contains(locName)) {
      AppSnackbar.info('"$locName" is already in your targeted locations.');
    } else {
      selectedLocations.add(locName);
    }

    clearSearch(textController);
  }

  /// Add a custom location typed directly by the user.
  void addCustomLocation(
    String rawText,
    RxList<String> selectedLocations,
    TextEditingController textController,
  ) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return;

    final locVal = ContentValidator.validate(
      trimmed,
      fieldName: 'Location',
    );
    if (!locVal.isValid) {
      AppSnackbar.warning(locVal.message);
      return;
    }

    if (selectedLocations.contains(trimmed)) {
      AppSnackbar.info('"$trimmed" is already in your targeted locations.');
    } else {
      selectedLocations.add(trimmed);
    }

    clearSearch(textController);
  }

  /// Clear the search input and close the dropdown.
  void clearSearch(TextEditingController textController) {
    textController.clear();
    searchQuery.value = '';
    suggestions.clear();
    isOpen.value = false;
    isLoading.value = false;
    _debounceTimer?.cancel();
  }

  /// Close the suggestion dropdown.
  void closeDropdown() {
    isOpen.value = false;
  }

  /// Open the dropdown if suggestions or query exist.
  void openDropdown() {
    if (searchQuery.value.trim().isNotEmpty && suggestions.isNotEmpty) {
      isOpen.value = true;
    }
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    super.onClose();
  }
}
