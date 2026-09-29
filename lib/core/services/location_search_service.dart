import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/services/location_canonical_data.dart';
import 'package:truthworld/core/services/logger_service.dart';

/// Type of geographic administrative unit.
enum LocationType {
  country,
  state,
  city;

  String get label {
    switch (this) {
      case LocationType.country:
        return 'Country';
      case LocationType.state:
        return 'State / Region';
      case LocationType.city:
        return 'City';
    }
  }
}

/// A structured, validated real-world geographic location suggestion.
class LocationSuggestion {
  const LocationSuggestion({
    required this.name,
    required this.country,
    required this.type,
    this.state,
    this.countryCode,
    String? customDisplayName,
  }) : _customDisplayName = customDisplayName;

  final String name;
  final String? state;
  final String country;
  final LocationType type;
  final String? countryCode;
  final String? _customDisplayName;

  /// User-friendly, canonical representation used for ad targeting.
  String get displayName {
    final custom = _customDisplayName;
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    switch (type) {
      case LocationType.country:
        return country;
      case LocationType.state:
        if (state != null && state!.isNotEmpty && state != country) {
          return '$state, $country';
        }
        return '$name, $country';
      case LocationType.city:
        if (state != null && state!.isNotEmpty && state != name) {
          return '$name, $state, $country';
        }
        return '$name, $country';
    }
  }

  /// Contextual subtitle describing the administrative hierarchy.
  String get subtitle {
    switch (type) {
      case LocationType.country:
        return 'Country';
      case LocationType.state:
        return 'State / Region in $country';
      case LocationType.city:
        if (state != null && state!.isNotEmpty) {
          return 'City in $state, $country';
        }
        return 'City in $country';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationSuggestion &&
          runtimeType == other.runtimeType &&
          displayName.toLowerCase() == other.displayName.toLowerCase();

  @override
  int get hashCode => displayName.toLowerCase().hashCode;

  @override
  String toString() => displayName;
}

/// Production-grade Location Search Service.
///
/// Implements a dual-source strategy adhering to TruthWorld's Zero Mock Data Policy:
/// 1. Instant Canonical Geodata: Pre-indexed authoritative ISO 3166-1 countries,
///    major international states/provinces, and global metropolitan centers for
///    0ms latency typing feedback.
/// 2. Live Authoritative Geocoding: Queries the OpenStreetMap / Photon geocoding
///    service (`photon.komoot.io`) with place-level filtering to resolve any real
///    city, municipality, or region globally.
class LocationSearchService extends GetxService {
  static const String _tag = 'LocationSearchService';

  static LocationSearchService get to {
    if (Get.isRegistered<LocationSearchService>()) {
      return Get.find<LocationSearchService>();
    }
    return Get.put(LocationSearchService(), permanent: true);
  }

  /// In-memory LRU-style cache for live API responses to eliminate redundant requests.
  final Map<String, List<LocationSuggestion>> _queryCache = {};

  /// Search real locations across both instant canonical data and authoritative API.
  Future<List<LocationSuggestion>> searchLocations(
    String rawQuery, {
    int limit = 10,
    http.Client? httpClient,
  }) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return const [];

    final normalizedQuery = query.toLowerCase();

    // 1. Instant local canonical search (0ms)
    final localMatches = _searchCanonical(normalizedQuery);

    // If query is very short (1 char), return local matches immediately
    if (normalizedQuery.length < 2) {
      return localMatches.take(limit).toList();
    }

    // 2. Check query cache
    if (_queryCache.containsKey(normalizedQuery)) {
      return _mergeAndDeduplicate(
        localMatches,
        _queryCache[normalizedQuery]!,
        limit,
      );
    }

    // 3. Live authoritative OpenStreetMap geocoding
    try {
      final liveResults = await _fetchFromPhotonApi(
        query,
        httpClient: httpClient,
      );
      _queryCache[normalizedQuery] = liveResults;

      return _mergeAndDeduplicate(localMatches, liveResults, limit);
    } catch (e) {
      logger.warning('Live geocoding error for "$query": $e', tag: _tag);
      return localMatches.take(limit).toList();
    }
  }

  /// Search local canonical geodata instantly.
  List<LocationSuggestion> _searchCanonical(String lowerQuery) {
    final exact = <LocationSuggestion>[];
    final prefix = <LocationSuggestion>[];
    final contains = <LocationSuggestion>[];

    for (final item in _canonicalLocations) {
      final nameLower = item.name.toLowerCase();
      final displayLower = item.displayName.toLowerCase();

      if (nameLower == lowerQuery || displayLower == lowerQuery) {
        exact.add(item);
      } else if (nameLower.startsWith(lowerQuery) ||
          displayLower.startsWith(lowerQuery)) {
        prefix.add(item);
      } else if (displayLower.contains(lowerQuery)) {
        contains.add(item);
      }
    }

    return [...exact, ...prefix, ...contains];
  }

  /// Query the authoritative Photon OpenStreetMap Geocoding API.
  Future<List<LocationSuggestion>> _fetchFromPhotonApi(
    String query, {
    http.Client? httpClient,
  }) async {
    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse(
      'https://photon.komoot.io/api/?q=$encoded&limit=12&lang=en',
    );

    final client = httpClient ?? http.Client();
    final shouldCloseClient = httpClient == null;

    try {
      final response = await client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'TruthWorld-App/1.0',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) {
        logger.warning(
          'Photon API returned status ${response.statusCode}',
          tag: _tag,
        );
        return const [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? const [];

      final results = <LocationSuggestion>[];

      for (final rawFeature in features) {
        if (rawFeature is! Map<String, dynamic>) continue;
        final props = rawFeature['properties'] as Map<String, dynamic>?;
        if (props == null) continue;

        final name = (props['name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;

        final country = (props['country'] as String?)?.trim() ?? '';
        final state = (props['state'] as String?)?.trim();
        final osmValue = (props['osm_value'] as String?)?.toLowerCase();
        final typeStr = (props['type'] as String?)?.toLowerCase();
        final countryCode = (props['countrycode'] as String?)?.toUpperCase();

        var locType = LocationType.city;
        if (osmValue == 'country' || typeStr == 'country') {
          locType = LocationType.country;
        } else if (osmValue == 'state' ||
            osmValue == 'province' ||
            typeStr == 'state') {
          locType = LocationType.state;
        } else if (osmValue == 'city' ||
            osmValue == 'town' ||
            osmValue == 'municipality' ||
            osmValue == 'village' ||
            typeStr == 'city' ||
            osmValue == 'county' ||
            osmValue == 'district') {
          locType = LocationType.city;
        } else {
          // Skip non-geographic entities (individual buildings, venues, streets, etc.)
          continue;
        }

        final resolvedCountry = country.isNotEmpty
            ? country
            : (locType == LocationType.country ? name : 'Global');

        results.add(
          LocationSuggestion(
            name: name,
            state: state,
            country: resolvedCountry,
            type: locType,
            countryCode: countryCode,
          ),
        );
      }

      return results;
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }

  /// Deduplicate and prioritize local and remote search results.
  List<LocationSuggestion> _mergeAndDeduplicate(
    List<LocationSuggestion> local,
    List<LocationSuggestion> remote,
    int limit,
  ) {
    final seen = <String>{};
    final combined = <LocationSuggestion>[];

    void addUnique(LocationSuggestion s) {
      final key = s.displayName.toLowerCase().trim();
      if (seen.add(key)) {
        combined.add(s);
      }
    }

    local.forEach(addUnique);
    remote.forEach(addUnique);

    return combined.take(limit).toList();
  }

  /// Clear the query cache.
  void clearCache() {
    _queryCache.clear();
  }

  // ===========================================================================
  /// Authoritative canonical geodata backed by location_canonical_data.dart
  static List<LocationSuggestion> get _canonicalLocations => canonicalLocations;
}
